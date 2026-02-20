"""
Visitor card temp-file cache — single source of truth.

Imported by tourist_route.py (serving) and main.py (startup / cleanup).
Having one module means one Redis client, one TTL value, one cleanup loop —
no more split-brain between the route and the cleaner.
"""

import os
import time
import glob
import asyncio
import logging

# ─── Config ───────────────────────────────────────────────────────────────────
TEMP_CARD_DIR                 = "static/temp-card"
CARD_TTL_SECONDS              = int(os.getenv("CARD_TEMP_TTL_SECONDS",          str(15 * 60)))
CARD_CLEANUP_INTERVAL_SECONDS = int(os.getenv("CARD_CLEANUP_INTERVAL_SECONDS",  str(5  * 60)))

# ─── Shared Redis client ───────────────────────────────────────────────────────
try:
    import redis as _redis_lib
    card_redis: "_redis_lib.Redis | None" = _redis_lib.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=int(os.getenv("REDIS_PORT", 6379)),
        db=int(os.getenv("REDIS_DB", 0)),
        password=os.getenv("REDIS_PASSWORD") or None,
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )
    card_redis.ping()
    card_redis_ok = True
    logging.info("[CardCache] Redis connected at %s:%s",
                 os.getenv("REDIS_HOST", "localhost"), os.getenv("REDIS_PORT", 6379))
except Exception as _ce:
    card_redis    = None
    card_redis_ok = False
    logging.warning("[CardCache] Redis unavailable — falling back to mtime-only cleanup: %s", _ce)


# ─── Helpers ──────────────────────────────────────────────────────────────────
def card_redis_key(user_id: int) -> str:
    return f"card_temp:{user_id}"


def touch_card(user_id: int) -> None:
    """Record current unix timestamp as last-access for this card."""
    if not card_redis_ok or not card_redis:
        return
    try:
        # Redis TTL = file TTL + 5 min buffer so the key is never evicted before the file is cleaned up
        card_redis.set(card_redis_key(user_id), time.time(), ex=CARD_TTL_SECONDS + 300)
    except Exception:
        pass


def is_card_fresh(user_id: int) -> bool:
    """
    True  → last touch was within CARD_TTL_SECONDS → serve from disk.
    False → key absent or stale → regenerate from DB.
    Falls back to True when Redis is down so file-existence has the final say.
    """
    if not card_redis_ok or not card_redis:
        return True
    try:
        val = card_redis.get(card_redis_key(user_id))
        if val is None:
            return False
        return (time.time() - float(val)) < CARD_TTL_SECONDS
    except Exception:
        return True


# ─── Background cleanup loop ──────────────────────────────────────────────────
async def run_cleanup_loop() -> None:
    """
    Background coroutine — call once at startup with asyncio.create_task().

    Schedule:
      • First run: 10 seconds after startup (gives the server time to boot and
        makes early test runs visible without a 5-minute wait)
      • Subsequent runs: every CARD_CLEANUP_INTERVAL_SECONDS

    Stale = last Redis touch older than CARD_TTL_SECONDS.
    Falls back to file mtime when Redis is unavailable.
    """
    logging.info(
        "[CardCleanup] Task started — TTL=%ds  interval=%ds",
        CARD_TTL_SECONDS, CARD_CLEANUP_INTERVAL_SECONDS,
    )

    first_run = True
    while True:
        # Short initial delay so the server finishes booting before the first scan
        await asyncio.sleep(10 if first_run else CARD_CLEANUP_INTERVAL_SECONDS)
        first_run = False

        try:
            os.makedirs(TEMP_CARD_DIR, exist_ok=True)
            files   = glob.glob(f"{TEMP_CARD_DIR}/card_temp_*.png")
            deleted = 0
            now     = time.time()

            for fpath in files:
                try:
                    uid_str = os.path.basename(fpath).replace("card_temp_", "").replace(".png", "")
                    if not uid_str.isdigit():
                        continue
                    uid = int(uid_str)

                    if card_redis_ok and card_redis:
                        val   = card_redis.get(card_redis_key(uid))
                        stale = val is None or (now - float(val)) > CARD_TTL_SECONDS
                    else:
                        # Redis unavailable: fall back to file mtime
                        stale = now - os.path.getmtime(fpath) > CARD_TTL_SECONDS

                    if stale:
                        os.remove(fpath)
                        if card_redis_ok and card_redis:
                            card_redis.delete(card_redis_key(uid))
                        deleted += 1
                        logging.info("[CardCleanup] Deleted stale card — user_id=%d", uid)

                except Exception as _fe:
                    logging.warning("[CardCleanup] Error processing %s: %s", fpath, _fe)

            logging.info(
                "[CardCleanup] Scan complete — %d deleted / %d total files",
                deleted, len(files),
            )

        except Exception as _ce:
            logging.error("[CardCleanup] Cycle error: %s", _ce)
