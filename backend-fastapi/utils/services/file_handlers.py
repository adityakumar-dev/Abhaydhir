import os
import shutil
from uuid import uuid4
from fastapi import UploadFile

UPLOAD_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../static/uploads'))
ID_UPLOAD_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../static/id_uploads'))
def save_upload_file(file: UploadFile, prefix: str = "" , is_id: bool = False) -> str:
    """Save an uploaded file and return the absolute path from project root/static/uploads"""
    filename = f"{prefix}_{uuid4().hex}_{file.filename}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    os.makedirs(ID_UPLOAD_DIR, exist_ok=True)
    if is_id:
        file_path = os.path.join(ID_UPLOAD_DIR, filename)
    else :
        file_path = os.path.join(UPLOAD_DIR, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return file_path

def delete_file(file_path: str) -> bool:
    """Delete a file if it exists"""
    try:
        if file_path and os.path.exists(file_path):
            os.remove(file_path)
            return True
    except Exception as e:
        print(f"Error deleting file: {e}")
    return False 