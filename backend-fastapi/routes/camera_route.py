"""
Camera backend — in-memory + Redis, no DB
==========================================
WS  /cam/stream                 ← cameras connect here (Bearer token auth)
WS  /ws                         → browser dashboard
GET /api/status                 → live cam state
GET /api/hourly                 → hourly unique counts
GET /api/stats/emotions         → emotion breakdown (exit-cam)
GET /api/stats/returns          → return-visitor stats (entry-cam)
GET /api/captures               → recent capture metadata list
GET /api/frame/{cam}            → latest live JPEG frame
GET /captures/{cam}/{filename}  → person thumbnail JPEG
GET /api/connections            → debug
"""

import os, json, base64, time, asyncio, logging
from typing import Optional
from datetime import datetime
from collections import defaultdict, deque
from utils.india_time import india_now, india_today_str

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, Query
from fastapi.responses import Response
from starlette.websockets import WebSocketState

from utils.services.redis_client import redis_client as _redis, redis_ok as _redis_ok

logger = logging.getLogger(__name__)

# ─── Config ──────────────────────────────────────────────────────────────────
BACKEND_WS_TOKEN = os.getenv("BACKEND_WS_TOKEN", "changeme")
KNOWN_CAM_IDS    = {c.strip() for c in os.getenv("KNOWN_CAM_IDS", "entry-cam,exit-cam").split(",")}
PING_INTERVAL    = int(os.getenv("CAM_PING_INTERVAL", "20"))
REDIS_TTL_STATE  = 3600        # 1 h — cam state
REDIS_TTL_DAY    = 86400 * 7   # 7 d — daily stats / capture lists
MAX_CAP_MEM      = 500         # max captures kept in-memory per cam

# ─── In-memory state ─────────────────────────────────────────────────────────
latest_frames:       dict[str, str]       = {}
camera_connections:  dict[str, WebSocket]  = {}
frontend_clients:    set[WebSocket]        = set()
# maps each frontend WS → set of cam_ids it subscribed to (empty = all cams)
frontend_subscriptions: dict[WebSocket, set[str]] = {}

cam_states: dict[str, dict] = {
    c: {"cam": c, "unique_count": 0, "active_count": 0,
        "last_seen": 0, "online": False, "last_event": None}
    for c in KNOWN_CAM_IDS
}

# hourly_counts[cam][date][hour] = int
hourly_counts: dict = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
# emotion_counts[cam][date][emotion] = int
emotion_counts: dict = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
# return_stats[cam] = {total_unique, return_visitors, seen_cids (set)}
return_stats: dict[str, dict] = {
    c: {"total_unique": 0, "return_visitors": 0, "seen_cids": set()}
    for c in KNOWN_CAM_IDS
}
# captures_list[cam] = deque of metadata dicts, newest first
captures_list:  dict[str, deque] = defaultdict(lambda: deque(maxlen=MAX_CAP_MEM))
# captures_index[cam][str(track_id)] = metadata dict
captures_index: dict[str, dict]  = defaultdict(dict)
# emotion_snapshots[cam] = latest [{emotion, count, percentage}] from camera's 'emotions' event
# This is the authoritative source — includes percentages computed by the camera
emotion_snapshots: dict[str, list] = {}

router = APIRouter()

# ─── Redis key scheme ────────────────────────────────────────────────────────
def _rk_state(cam):          return f"cam:state:{cam}"
def _rk_hourly(cam, d):      return f"cam:hourly:{cam}:{d}"
def _rk_emotions(cam, d):    return f"cam:emotions:{cam}:{d}"
def _rk_returns(cam):        return f"cam:returns:{cam}"
def _rk_returns_cids(cam):   return f"cam:returns:{cam}:cids"
def _rk_emotion_snap(cam):   return f"cam:emotion_snap:{cam}"


# ─── Redis helpers (all sync — called via asyncio.to_thread or inline) ───────
def _r_save_state(cam, state):
    if not (_redis_ok and _redis): return
    try: _redis.set(_rk_state(cam), json.dumps(state), ex=REDIS_TTL_STATE)
    except: pass

def _r_load_state(cam) -> Optional[dict]:
    if not (_redis_ok and _redis): return None
    try:
        raw = _redis.get(_rk_state(cam))
        return json.loads(raw) if raw else None
    except: return None

def _r_incr_hourly(cam, d, hour):
    if not (_redis_ok and _redis): return
    try:
        k = _rk_hourly(cam, d)
        _redis.hincrby(k, str(hour), 1)
        _redis.expire(k, REDIS_TTL_DAY)
    except: pass

def _r_get_hourly(cam, d) -> dict:
    if not (_redis_ok and _redis): return {}
    try:
        raw = _redis.hgetall(_rk_hourly(cam, d))
        return {int(h): int(c) for h, c in raw.items()}
    except: return {}

def _r_incr_emotion(cam, d, emotion):
    if not (_redis_ok and _redis): return
    try:
        k = _rk_emotions(cam, d)
        _redis.hincrby(k, emotion, 1)
        _redis.expire(k, REDIS_TTL_DAY)
    except: pass

def _r_get_emotions(cam, d) -> dict:
    if not (_redis_ok and _redis): return {}
    try:
        raw = _redis.hgetall(_rk_emotions(cam, d))
        return {e: int(c) for e, c in raw.items()}
    except: return {}

def _r_track_reentry(cam, cid: str):
    if not (_redis_ok and _redis): return
    try:
        is_new = _redis.sadd(_rk_returns_cids(cam), cid)
        if is_new:
            _redis.hincrby(_rk_returns(cam), "return_visitors", 1)
    except: pass

def _r_get_returns(cam) -> dict:
    if not (_redis_ok and _redis): return {}
    try:
        raw = _redis.hgetall(_rk_returns(cam))
        return {k: int(v) for k, v in raw.items()}
    except: return {}

def _r_set_hourly(cam, d, hour_dict: dict):
    """Overwrite full hourly hash from a stats snapshot (authoritative, not incremental)."""
    if not (_redis_ok and _redis): return
    try:
        k    = _rk_hourly(cam, d)
        pipe = _redis.pipeline()
        pipe.delete(k)
        if hour_dict:
            pipe.hset(k, mapping={str(h): c for h, c in hour_dict.items()})
        pipe.expire(k, REDIS_TTL_DAY)
        pipe.execute()
    except: pass

def _r_set_emotions(cam, d, em_dict: dict):
    """Overwrite full emotions hash from an emotions snapshot."""
    if not (_redis_ok and _redis): return
    try:
        k    = _rk_emotions(cam, d)
        pipe = _redis.pipeline()
        pipe.delete(k)
        if em_dict:
            pipe.hset(k, mapping=em_dict)
        pipe.expire(k, REDIS_TTL_DAY)
        pipe.execute()
    except: pass

def _r_save_emotion_snap(cam, snapshot: list):
    """Persist full [{emotion, count, percentage}] list."""
    if not (_redis_ok and _redis): return
    try: _redis.set(_rk_emotion_snap(cam), json.dumps(snapshot), ex=REDIS_TTL_DAY)
    except: pass

def _r_load_emotion_snap(cam) -> Optional[list]:
    if not (_redis_ok and _redis): return None
    try:
        raw = _redis.get(_rk_emotion_snap(cam))
        return json.loads(raw) if raw else None
    except: return None

def _r_reset_session_stats(cam):
    """
    Called every time a camera re-connects.  Clears per-session Redis keys so
    stale return_visitors / seen_cids from a previous run don't bleed into the
    new session.  The camera's tracker restarts fresh each time, so these must too.
    """
    if not (_redis_ok and _redis): return
    try:
        _redis.delete(_rk_returns(cam), _rk_returns_cids(cam))
        logger.info("[Camera] '%s' Redis session stats reset", cam)
    except: pass

# ─── Broadcast ───────────────────────────────────────────────────────────────
async def broadcast(payload: dict, cam: Optional[str] = None):
    """
    Send payload to frontend clients.
    If cam is given, frame-type messages are only sent to clients subscribed to
    that cam (or clients with no subscription = all cams).
    Non-frame messages (status, events) always go to everyone.
    """
    if not frontend_clients: return
    msg        = json.dumps(payload)
    is_frame   = payload.get("type") == "frame"
    dead: set[WebSocket] = set()
    for ws in list(frontend_clients):
        # filter frames by subscription; pass everything else through
        if is_frame and cam:
            subs = frontend_subscriptions.get(ws)
            if subs and cam not in subs:
                continue   # this client doesn't want this camera's frames
        try: await ws.send_text(msg)
        except: dead.add(ws)
    frontend_clients.difference_update(dead)
    for ws in dead: frontend_subscriptions.pop(ws, None)

# ─── State helpers ────────────────────────────────────────────────────────────
def _update_state(cam: str, **kw):
    state = cam_states.setdefault(cam, {"cam": cam})
    state.update(kw)
    _r_save_state(cam, state)

async def _mark_offline(cam: str):
    _update_state(cam, online=False)
    await broadcast({"type": "cam_status", "cam": cam, "online": False})

# ─── Capture helpers (in-memory only, image_b64 stored inline) ──────────────
def _upsert_capture(cam: str, track_id, **kw) -> dict:
    """Create or update a capture record in memory. image_b64 kept inline — no disk, no Redis."""
    tid_str = str(track_id)
    meta = captures_index[cam].get(tid_str, {
        "cam":           cam,
        "track_id":      track_id,
        "image_b64":     None,
        "emotion":       None,
        "emotion_score": None,
        "received_at":   india_now().isoformat(),
    })
    meta.update(kw)
    captures_index[cam][tid_str] = meta
    captures_list[cam] = deque(
        (m for m in captures_list[cam] if str(m.get("track_id")) != tid_str),
        maxlen=MAX_CAP_MEM,
    )
    captures_list[cam].appendleft(meta)
    return meta

# ─── Event handlers ──────────────────────────────────────────────────────────
async def _on_frame(cam: str, msg: dict):
    image = msg.get("image", "")
    if image:
        latest_frames[cam] = image
    await broadcast({"type": "frame", "cam": cam, "image": image, "ts": msg.get("ts")}, cam=cam)


async def _on_event(cam: str, data: dict):
    event_type = data.get("event", "")
    ts         = float(data.get("ts", time.time()))
    # Use IST for date/hour bucketing so midnight-to-5:30am events land on the correct date
    ist_dt     = india_now().replace(second=0, microsecond=0)  # approximate to now; ts used for online state
    dt_from_ts = datetime.fromtimestamp(ts, tz=ist_dt.tzinfo)  # exact ts in IST
    date_str   = dt_from_ts.strftime("%Y-%m-%d")
    hour       = dt_from_ts.hour

    if event_type == "heartbeat":
        uq = data.get("unique_count", cam_states.get(cam, {}).get("unique_count", 0))
        ac = data.get("active_count", 0)
        logger.debug("[Camera] [%s] heartbeat — unique=%s active=%s", cam, uq, ac)
        _update_state(cam, unique_count=uq, active_count=ac,
                      last_seen=ts, online=True, last_event=event_type)

    elif event_type == "new_entry":
        new_uq = data.get("unique_count", cam_states.get(cam, {}).get("unique_count", 0))
        logger.info("[Camera] [%s] new_entry — unique_count=%s hour=%02d", cam, new_uq, hour)
        _update_state(cam, unique_count=new_uq, last_seen=ts, online=True, last_event=event_type)
        # hourly bucket
        hourly_counts[cam][date_str][hour] += 1
        _r_incr_hourly(cam, date_str, hour)
        # sync total_unique into return stats
        return_stats[cam]["total_unique"] = new_uq
        if _redis_ok and _redis:
            try: _redis.hset(_rk_returns(cam), "total_unique", new_uq)
            except: pass

    elif event_type in ("enter", "exit"):
        logger.info("[Camera] [%s] %s", cam, event_type)
        _update_state(cam, last_seen=ts, online=True, last_event=event_type)

    elif event_type == "captured":
        # entry-cam: person thumbnail — kept in memory only
        track_id = data.get("track_id")
        has_img  = bool(data.get("image"))
        logger.info("[Camera] [%s] captured — track_id=%s has_image=%s", cam, track_id, has_img)
        _update_state(cam, last_seen=ts, online=True, last_event=event_type)
        _upsert_capture(cam, track_id,
                        image_b64=data.get("image"),
                        received_at=dt_from_ts.isoformat())

    elif event_type == "reentry":
        # entry-cam: known person re-entered (has a cid)
        cid = str(data.get("cid", ""))
        is_new_cid = cid and cid not in return_stats[cam]["seen_cids"]
        logger.info("[Camera] [%s] reentry — cid=%s new=%s", cam, cid, is_new_cid)
        _update_state(cam, last_seen=ts, online=True, last_event=event_type)
        if is_new_cid:
            return_stats[cam]["seen_cids"].add(cid)
            return_stats[cam]["return_visitors"] += 1
        _r_track_reentry(cam, cid)

    elif event_type == "archived":
        # exit-cam: person archived with emotion + image — kept in memory only
        track_id      = data.get("track_id")
        emotion       = data.get("emotion")
        emotion_score = data.get("emotion_score")
        has_img       = bool(data.get("image"))
        logger.info("[Camera] [%s] archived — track_id=%s emotion=%s score=%s has_image=%s",
                    cam, track_id, emotion, emotion_score, has_img)
        _update_state(cam, last_seen=ts, online=True, last_event=event_type)
        _upsert_capture(cam, track_id,
                        image_b64=data.get("image"),
                        emotion=emotion,
                        emotion_score=emotion_score)
        if emotion:
            emotion_counts[cam][date_str][emotion] += 1
            _r_incr_emotion(cam, date_str, emotion)

    elif event_type == "stats":
        # Both cams: authoritative 30-second snapshot — overrides incremental counts
        unique_total = int(data.get("unique_total", 0))
        today_count  = int(data.get("today_count",  0))
        active_now   = int(data.get("active_now",   0))
        hourly       = data.get("hourly", [])   # [{hour, count}]
        logger.info("[Camera] [%s] stats — unique_total=%s today=%s active=%s hourly_buckets=%s",
                    cam, unique_total, today_count, active_now, len(hourly))
        _update_state(cam, unique_count=unique_total, active_count=active_now,
                      today_count=today_count, last_seen=ts, online=True, last_event=event_type)
        if hourly:
            hour_dict = {int(h["hour"]): int(h["count"]) for h in hourly
                         if "hour" in h and "count" in h}
            # Overwrite in-memory hourly with the camera's authoritative snapshot
            hourly_counts[cam][date_str] = defaultdict(int, hour_dict)
            _r_set_hourly(cam, date_str, hour_dict)
        # Keep return_stats total in sync
        return_stats[cam]["total_unique"] = unique_total
        if _redis_ok and _redis:
            try: _redis.hset(_rk_returns(cam), "total_unique", unique_total)
            except: pass

    elif event_type == "emotions":
        # exit-cam: full emotion breakdown — fires on every archive + every 30 s
        emotions_list  = data.get("emotions", [])   # [{emotion, count, percentage}]
        total_archived = int(data.get("total_archived", 0))
        logger.info("[Camera] [%s] emotions — total_archived=%s breakdown=%s entries",
                    cam, total_archived, len(emotions_list))
        _update_state(cam, last_seen=ts, online=True, last_event=event_type,
                      total_archived=total_archived)
        if emotions_list:
            # Store full snapshot with percentages for the REST /api/stats/emotions endpoint
            emotion_snapshots[cam] = emotions_list
            _r_save_emotion_snap(cam, emotions_list)
            # Overwrite counts dict so /api/stats/emotions fallback stays consistent
            em_dict = {e["emotion"]: int(e["count"]) for e in emotions_list if "emotion" in e}
            emotion_counts[cam][date_str] = defaultdict(int, em_dict)
            _r_set_emotions(cam, date_str, em_dict)

    else:
        logger.warning("[Camera] [%s] unknown event_type=%r", cam, event_type)
        _update_state(cam, last_seen=ts, online=True, last_event=event_type)

    # events (new_entry, archived, etc.) go to all clients regardless of subscription
    await broadcast({"type": "event", "cam": cam, "data": data})


async def _dispatch(cam: str, msg: dict):
    t = msg.get("type")
    if   t == "frame":  await _on_frame(cam, msg)
    elif t == "event":  await _on_event(cam, msg.get("data", {}))
    else:
        logger.debug("[Camera] [%s] unhandled msg type=%r — broadcasting raw", cam, t)
        await broadcast({"type": t, "cam": cam, "raw": msg}, cam=cam)


# ─── Camera inbound WS: /cam/stream ──────────────────────────────────────────
@router.websocket("/cam/stream")
async def camera_stream(ws: WebSocket):
    """
    Cameras connect here.
    Auth: Authorization: Bearer <BACKEND_WS_TOKEN>
    Close 4001 = bad token | 4003 = unknown cam ID
    """
    client_ip = ws.client.host if ws.client else "unknown"
    auth  = ws.headers.get("authorization", "")
    token = auth.removeprefix("Bearer ").strip()
    if token != BACKEND_WS_TOKEN:
        logger.warning("[Camera] /cam/stream rejected — bad token from %s", client_ip)
        await ws.close(code=4001)
        return

    logger.info("[Camera] /cam/stream handshake accepted from %s", client_ip)
    await ws.accept()
    cam_id: Optional[str] = None

    async def _ping():
        while True:
            await asyncio.sleep(PING_INTERVAL)
            if ws.client_state != WebSocketState.CONNECTED: break
            try: await ws.send_text(json.dumps({"type": "ping"}))
            except: break

    pt = asyncio.create_task(_ping())
    try:
        while True:
            raw = await ws.receive_text()
            try: msg = json.loads(raw)
            except: continue
            if msg.get("type") == "pong": continue

            cam = msg.get("cam")
            if cam not in KNOWN_CAM_IDS:
                logger.warning("[Camera] unknown cam_id=%r from %s — closing 4003", cam, client_ip)
                await ws.close(code=4003)
                return

            if cam_id is None:
                cam_id = cam
                camera_connections[cam_id] = ws
                restored = _r_load_state(cam_id)
                if restored: cam_states[cam_id] = restored
                # Reset per-session stats — camera tracker restarted, old Redis counts are stale
                _r_reset_session_stats(cam_id)
                return_stats[cam_id] = {"total_unique": 0, "return_visitors": 0, "seen_cids": set()}
                logger.info("[Camera] '%s' registered (ip=%s, redis_restored=%s)",
                            cam_id, client_ip, bool(restored))

            # log every payload (frames logged as size-only to avoid log spam)
            msg_type = msg.get("type", "?")
            if msg_type == "frame":
                img_len = len(msg.get("image", ""))
                logger.debug("[Camera] [%s] frame received — b64_len=%d", cam_id, img_len)
            elif msg_type == "event":
                ev = msg.get("data", {}).get("event", "?")
                logger.info("[Camera] [%s] event=%s", cam_id, ev)
            else:
                logger.debug("[Camera] [%s] msg type=%r payload=%s", cam_id, msg_type, json.dumps(msg)[:200])

            asyncio.create_task(_dispatch(cam_id, msg))

    except WebSocketDisconnect:
        logger.info("[Camera] '%s' disconnected", cam_id or "?")
    except Exception as e:
        logger.error("[Camera] error [%s]: %s", cam_id or "?", e)
    finally:
        pt.cancel()
        if cam_id and camera_connections.get(cam_id) is ws:
            camera_connections.pop(cam_id, None)
            asyncio.create_task(_mark_offline(cam_id))


# ─── Frontend WS: /ws ────────────────────────────────────────────────────────
@router.websocket("/ws")
async def frontend_ws(ws: WebSocket):
    """
    Browser dashboard — receives real-time events, frames, cam status.

    On connect the client may send a subscription message to limit which
    camera's frames it receives (avoids wasting bandwidth when only one cam
    view is open at a time):

        {"type": "subscribe", "cams": ["entry-cam"]}   ← only entry-cam frames
        {"type": "subscribe", "cams": ["exit-cam"]}    ← only exit-cam frames
        {"type": "subscribe", "cams": []}              ← all cams (default)

    Non-frame messages (events, status) always arrive regardless of subscription.
    """
    client_ip = ws.client.host if ws.client else "unknown"
    await ws.accept()
    frontend_clients.add(ws)
    frontend_subscriptions[ws] = set()   # empty = all cams
    logger.info("[WS] frontend client connected (ip=%s, total=%d)", client_ip, len(frontend_clients))
    try:
        states = [(_r_load_state(c) or cam_states.get(c, {"cam": c})) for c in KNOWN_CAM_IDS]
        await ws.send_text(json.dumps({"type": "init_status", "cameras": states}))
        logger.debug("[WS] init_status sent to %s", client_ip)
    except: pass
    try:
        while True:
            raw = await ws.receive_text()
            try: msg = json.loads(raw)
            except: continue
            if msg.get("type") == "subscribe":
                requested = set(msg.get("cams") or [])
                # validate against known cams
                valid = requested & KNOWN_CAM_IDS
                frontend_subscriptions[ws] = valid
                logger.info("[WS] %s subscribed to cams=%s", client_ip, valid or "ALL")
                await ws.send_text(json.dumps({
                    "type": "subscribed",
                    "cams": list(valid) if valid else list(KNOWN_CAM_IDS)
                }))
    except: pass
    finally:
        frontend_clients.discard(ws)
        frontend_subscriptions.pop(ws, None)
        logger.info("[WS] frontend client disconnected (ip=%s, remaining=%d)", client_ip, len(frontend_clients))


# ─── REST endpoints ───────────────────────────────────────────────────────────

@router.get("/api/status", summary="Live camera state")
async def get_status():
    states = [(_r_load_state(c) or cam_states.get(c, {"cam": c})) for c in KNOWN_CAM_IDS]
    return {"cameras": states, "ws_connected": list(camera_connections.keys())}


@router.get("/api/hourly", summary="Hourly unique-person counts")
async def get_hourly(
    cam:  Optional[str] = Query(None, description="Filter by cam ID"),
    date: Optional[str] = Query(None, description="YYYY-MM-DD, defaults to today"),
):
    target = date or india_today_str()
    cam_list = [cam] if cam else list(KNOWN_CAM_IDS)
    result = []
    for c in cam_list:
        counts = await asyncio.to_thread(_r_get_hourly, c, target) if _redis_ok else dict(hourly_counts[c].get(target, {}))
        for h in range(24):
            result.append({"cam": c, "date": target, "hour": h, "count": counts.get(h, 0)})
    return result


@router.get("/api/stats/emotions", summary="Emotion breakdown for exit-cam")
async def get_emotions(
    cam:  str           = Query("exit-cam", description="Camera ID (exit-cam recommended)"),
    date: Optional[str] = Query(None, description="YYYY-MM-DD, defaults to today"),
):
    target = date or india_today_str()
    # For today, prefer the camera's own snapshot — it includes percentages and is always
    # up-to-date (fires on every archive, not just on poll).
    if target == india_today_str():
        snap = emotion_snapshots.get(cam)
        if not snap:
            snap = await asyncio.to_thread(_r_load_emotion_snap, cam)
        if snap:
            return snap   # [{emotion, count, percentage}]
    # Historical date or no snapshot yet — build from raw counts
    counts = await asyncio.to_thread(_r_get_emotions, cam, target) if _redis_ok else dict(emotion_counts[cam].get(target, {}))
    total  = sum(counts.values()) or 1
    return [
        {"emotion": e, "count": c, "percentage": round(c / total * 100, 1)}
        for e, c in sorted(counts.items(), key=lambda x: -x[1])
    ]


@router.get("/api/stats/returns", summary="Return-visitor stats for entry-cam")
async def get_returns(
    cam: str = Query("entry-cam", description="Camera ID (entry-cam recommended)"),
):
    # Always read from in-memory — return_stats is the authoritative source per session.
    # Redis is wiped on camera reconnect so it cannot be trusted here.
    rs         = return_stats.get(cam, {})
    total_uq   = rs.get("total_unique",    0)
    return_vis = rs.get("return_visitors", 0)
    rate = round(return_vis / total_uq * 100, 2) if total_uq else 0.0
    return {"cam": cam, "total_unique": total_uq, "return_visitors": return_vis, "return_rate": rate}


@router.get("/api/captures", summary="Recent in-memory person captures (includes image_b64)")
async def get_captures(
    cam:   Optional[str] = Query(None, description="Filter by cam ID"),
    limit: int           = Query(20, ge=1, le=200),
):
    if cam:
        return list(captures_list[cam])[:limit]
    merged = []
    for c in KNOWN_CAM_IDS:
        merged.extend(captures_list[c])
    merged.sort(key=lambda x: x.get("received_at", ""), reverse=True)
    return merged[:limit]


@router.get("/api/frame/{cam_id}", summary="Latest live JPEG frame", response_class=Response)
async def get_frame(cam_id: str):
    img_b64 = latest_frames.get(cam_id)
    if not img_b64:
        raise HTTPException(404, detail=f"No frame yet for '{cam_id}'")
    try:
        return Response(content=base64.b64decode(img_b64), media_type="image/jpeg",
                        headers={"Cache-Control": "no-store"})
    except Exception as e:
        raise HTTPException(500, detail=str(e))


@router.get("/api/connections", summary="Debug: live connection counts and in-memory state")
async def get_connections():
    mem_returns = {
        cam: {
            "total_unique":    rs.get("total_unique",    0),
            "return_visitors": rs.get("return_visitors", 0),
            "seen_cids_count": len(rs.get("seen_cids", set())),
        }
        for cam, rs in return_stats.items()
    }
    return {
        "cameras_connected":  list(camera_connections.keys()),
        "frontend_clients":   len(frontend_clients),
        "redis_ok":           _redis_ok,
        "cam_states":         dict(cam_states),
        "return_stats":       mem_returns,
        "emotion_snapshots":  {cam: snap[:3] for cam, snap in emotion_snapshots.items()},  # first 3 emotions only
        "latest_frames":      {cam: bool(img) for cam, img in latest_frames.items()},
    }
