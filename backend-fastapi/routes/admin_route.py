from fastapi import Request, HTTPException, status, Depends
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import jwt_middleware
from datetime import datetime
from utils.india_time import india_today_str
router = APIRouter()

EVENT_ID = 1

TARGET_DATES = [
    "2026-02-27",
    "2026-02-28",
    "2026-03-01"
]

TARGET_DATE_DATA = {
    '2026-03-01': {
        "registration": {
            "total_registration": 4875,
            "total_members": 13681,
            "total_groups": 4137,
            "total_individual": 738,
        },
        "Camera": {
            "exit-cam": {
                "Count": 8340,
                "Happy": 7208,
                "Sad": 1018,
                "undetected" : 114
            },
            "entry-cam": {
                "unique_count": 16910,
                "duplicacy_count": 6157
            }
        }
    },
    '2026-02-28': {
        "registration": {
            "total_registration": 5204,
            "total_members": 15074,
            "total_groups": 4298,
            "total_individual": 906,
        },
        "Camera": {
            "exit-cam": {
                "Count": 8546,
                "Happy": 7242,
                "Sad": 1152,
                "undetected": 152
            },
            "entry-cam": {
                "unique_count": 16207,
                "duplicacy_count": 6452
            }
        }
    },
    '2026-02-27': {
        "registration": {
            "total_registration": 1805,
            "total_members": 6148,
            "total_groups": 1273,
            "total_individual": 532,
        },
        "Camera": {
            "exit-cam": {
                "Count": 3696,
                "Happy": 2956,  # 89%
                "Sad": 483,    # 8%
                "undetected": 257  # remaining 3%
            },
            "entry-cam": {
                "unique_count": 5561,
                "duplicacy_count": 2796
            }
        }
    }
}


@router.get("/camera")
async def camera_dashboard(request: Request):
    """
    Admin-only snapshot of all camera data.
    Returns cam states, today's hourly counts, emotion breakdown,
    return-visitor stats, and the last 20 recent captures (with image_b64).
    """
    user = await jwt_middleware(request)
    if user.get("role") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")

    # Local import avoids circular dependency
    from routes.camera_route import (
        cam_states, camera_connections, captures_list,
        hourly_counts, emotion_counts, return_stats, KNOWN_CAM_IDS,
        _r_load_state, _r_get_hourly, _r_get_emotions, _r_get_returns, _redis_ok,
    )

    today = india_today_str()

    # ── Camera status ─────────────────────────────────────────────────────────
    cameras = []
    for c in KNOWN_CAM_IDS:
        state = dict(_r_load_state(c) or cam_states.get(c, {"cam": c}))
        state["ws_connected"] = c in camera_connections
        cameras.append(state)

    # ── Hourly unique counts (all cams, today) ────────────────────────────────
    hourly = []
    for c in KNOWN_CAM_IDS:
        counts = _r_get_hourly(c, today) if _redis_ok else dict(hourly_counts[c].get(today, {}))
        for h in range(24):
            hourly.append({"cam": c, "hour": h, "count": counts.get(h, 0)})

    # ── Emotion breakdown (exit-cam, today) ───────────────────────────────────
    raw_em = _r_get_emotions("exit-cam", today) if _redis_ok else dict(emotion_counts["exit-cam"].get(today, {}))
    emotions = [{"emotion": e, "count": c} for e, c in sorted(raw_em.items(), key=lambda x: -x[1])]

    # ── Return-visitor stats (entry-cam) ──────────────────────────────────────
    if _redis_ok:
        r          = _r_get_returns("entry-cam")
        total_uq   = int(r.get("total_unique",    0))
        return_vis = int(r.get("return_visitors", 0))
    else:
        total_uq   = return_stats["entry-cam"]["total_unique"]
        return_vis = return_stats["entry-cam"]["return_visitors"]
    return_rate = round(return_vis / total_uq * 100, 2) if total_uq else 0.0

    # ── Recent captures — strip image_b64 for the list (keep lightweight) ────
    recent: list = []
    for c in KNOWN_CAM_IDS:
        for cap in list(captures_list[c])[:20]:
            recent.append({k: v for k, v in cap.items() if k != "image_b64"})
    recent.sort(key=lambda x: x.get("received_at", ""), reverse=True)

    return {
        "cameras":         cameras,
        "today":           today,
        "hourly":          hourly,
        "emotions":        emotions,
        "returns":         {
            "total_unique":    total_uq,
            "return_visitors": return_vis,
            "return_rate":     return_rate,
        },
        "recent_captures": recent[:20],
    }
class OnboardingRequest(BaseModel):
    event_id : str = "1"

@router.post("/onboarding")
async def onboarding(onboarding_request: OnboardingRequest, request: Request):
    user = await jwt_middleware(request)
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this resource."
        )
    try :
            response = (
            supabaseAdmin
            .rpc("get_event_full_summary",
                {"p_event_id": onboarding_request.event_id})
            .execute()
            )
            print("RPC Response: ", response)
            return response.data
    except Exception as e:
        print("Error during RPC call: ", str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An error occurred while fetching the onboarding data."
        )
    # -------------------------
    # Final Structured Response
    # -------------------------
 