"""
Shared Redis client — single connection for the whole application.

Import:
    from utils.services.redis_client import redis_client, redis_ok

redis_client is None when Redis is unavailable; all callers must guard
with `if redis_ok and redis_client:` before use.
"""

import os
import logging

redis_client = None
redis_ok     = False

try:
    import redis as _redis_lib

    redis_client = _redis_lib.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=int(os.getenv("REDIS_PORT", 6379)),
        db=int(os.getenv("REDIS_DB", "0")),
        password=os.getenv("REDIS_PASSWORD") or None,
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )
    redis_client.ping()
    redis_ok = True
    logging.info(
        "[Redis] Connected at %s:%s",
        os.getenv("REDIS_HOST", "localhost"),
        os.getenv("REDIS_PORT", 6379),
    )
except Exception as _e:
    redis_client = None
    redis_ok     = False
    logging.warning("[Redis] Unavailable — falling back to in-memory: %s", _e)
