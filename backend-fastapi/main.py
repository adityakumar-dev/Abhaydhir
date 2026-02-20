import os
from fastapi import FastAPI, Depends, UploadFile, File, Form, Query
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import shutil
from uuid import uuid4
from fastapi import HTTPException
import base64
from fastapi.middleware.cors import CORSMiddleware
import traceback
from dotenv import load_dotenv
load_dotenv()  # Load environment variables from .env file
from utils.supabase.auth import jwt_middleware
# from routes import analytics, app_users_handler, face_recognition, institutions, push_update, qr, users


app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
os.makedirs("static/uploads",    exist_ok=True)
os.makedirs("static/cards",      exist_ok=True)
os.makedirs("static/temp-card",  exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")


import asyncio
from utils.services.card_cache import run_cleanup_loop

@app.on_event("startup")
async def startup():
    asyncio.create_task(run_cleanup_loop())

# Import and include routers
from routes.analytics_route import router as analytics_router
from routes.event_register import router as event_router
from routes.tourist_route import router as tourist_router
from routes.users_route import router as users_router
from routes.entry_route import router as entry_router
from routes.sms_route import router as sms_router
from routes.feedback_route import router as feedback_router
from utils.services.public_access_link_provider import verify_public_access_link

app.include_router(analytics_router, prefix="/analytics", tags=["analytics"])
app.include_router(event_router, prefix="/event", tags=["events"])
app.include_router(tourist_router, prefix="/tourists", tags=["tourists"])
app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(entry_router, prefix="/entry", tags=["entries"])
app.include_router(sms_router, prefix="/sms", tags=["sms"])
app.include_router(feedback_router, prefix="/feedback", tags=["feedback"])

@app.get("/static/access")
async def serve_signed_file(file: str, expires: int, sig: str):
    """Serve files with signed URLs for security"""
    if not verify_public_access_link(file, expires, sig):
        raise HTTPException(status_code=403, detail="Invalid or expired link")
    
    file_path = os.path.join("static", file)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    # Determine media type based on file extension
    media_type = "image/png"
    if file.lower().endswith(('.jpg', '.jpeg')):
        media_type = "image/jpeg"
    elif file.lower().endswith('.pdf'):
        media_type = "application/pdf"
    
    return FileResponse(
        file_path,
        media_type=media_type,
        headers={
            "Cache-Control": "public, max-age=3600",
            "Access-Control-Allow-Origin": "*"
        }
    )

@app.get("/")
async def check():
    return {True}

@app.get("/health-check")
async def health_check():
    return {"status": "ok"}

@app.get("/debug/card-cache")
async def debug_card_cache():
    """
    Dev-only: inspect the Redis card cache state and temp-card files on disk.
    Remove or protect this endpoint before going to production.
    """
    import glob
    import time
    from utils.services.card_cache import (
        card_redis, card_redis_ok, TEMP_CARD_DIR,
        CARD_TTL_SECONDS, CARD_CLEANUP_INTERVAL_SECONDS,
    )

    redis_status = "connected" if card_redis_ok else "unavailable"

    # Scan all card_temp:* keys from Redis
    redis_keys = []
    if card_redis_ok and card_redis:
        try:
            for key in card_redis.scan_iter("card_temp:*"):
                val  = card_redis.get(key)
                ttl  = card_redis.ttl(key)
                age  = round(time.time() - float(val), 1) if val else None
                redis_keys.append({
                    "key":             key,
                    "last_access_ago": f"{age}s ago" if age is not None else "unknown",
                    "is_fresh":        age is not None and age < CARD_TTL_SECONDS,
                    "redis_ttl_remaining": f"{ttl}s",
                })
        except Exception as e:
            redis_keys = [{"error": str(e)}]

    # Scan files on disk
    disk_files = []
    for fpath in glob.glob(f"{TEMP_CARD_DIR}/card_temp_*.png"):
        size_kb = round(os.path.getsize(fpath) / 1024, 1)
        age     = round(time.time() - os.path.getmtime(fpath), 1)
        disk_files.append({
            "file":    os.path.basename(fpath),
            "size_kb": size_kb,
            "age":     f"{age}s ago",
        })

    return {
        "config": {
            "CARD_TTL_SECONDS":              CARD_TTL_SECONDS,
            "CARD_CLEANUP_INTERVAL_SECONDS": CARD_CLEANUP_INTERVAL_SECONDS,
        },
        "redis": {
            "status": redis_status,
            "keys":   redis_keys,
        },
        "disk": {
            "directory": TEMP_CARD_DIR,
            "files":     disk_files,
        },
    }
