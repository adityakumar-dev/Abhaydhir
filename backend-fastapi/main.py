import os
from fastapi import FastAPI, Depends, UploadFile, File, Form, Query
from fastapi.responses import  JSONResponse
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
os.makedirs("static/uploads", exist_ok=True)
os.makedirs("static/cards", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Import and include routers
from routes.analytics_route import router as analytics_router
from routes.event_register import router as event_router
from routes.tourist_route import router as tourist_router
from routes.users_route import router as users_router
from routes.entry_route import router as entry_router
from utils.services.public_access_link_provider import verify_public_access_link

app.include_router(analytics_router, prefix="/analytics", tags=["analytics"])
app.include_router(event_router, prefix="/event", tags=["events"])
app.include_router(tourist_router, prefix="/tourists", tags=["tourists"])
app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(entry_router, prefix="/entry", tags=["entries"])

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
