import os
import time
import hmac
import hashlib
import base64
from urllib.parse import urlencode

SECRET_KEY = os.getenv("PUBLIC_LINK_SECRET", "default_secret")
STATIC_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../static'))
BASE_URL = "/static"  # Adjust if you serve static differently


def generate_public_access_link(file_path: str, expires_in: int = 600) -> str:
    """
    Generate a signed public access link for a file in static/ valid for expires_in seconds.
    Returns a URL with a signature and expiry timestamp.
    """
    abs_path = os.path.abspath(file_path)
    if not abs_path.startswith(STATIC_ROOT):
        raise ValueError(f"File is not in static/ folder. Got: {abs_path}, Expected to start with: {STATIC_ROOT}")
    rel_path = os.path.relpath(abs_path, STATIC_ROOT)
    expires = int(time.time()) + expires_in
    data = f"{rel_path}:{expires}"
    signature = hmac.new(SECRET_KEY.encode(), data.encode(), hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(signature).decode()
    params = urlencode({"file": rel_path, "expires": expires, "sig": sig_b64})
    return f"{BASE_URL}/access?{params}"


def verify_public_access_link(file: str, expires: int, sig: str) -> bool:
    """
    Verify the signature and expiry for a public access link.
    Returns True if valid, False otherwise.
    """
    if int(time.time()) > int(expires):
        return False
    data = f"{file}:{expires}"
    expected_sig = hmac.new(SECRET_KEY.encode(), data.encode(), hashlib.sha256).digest()
    expected_sig_b64 = base64.urlsafe_b64encode(expected_sig).decode()
    return hmac.compare_digest(sig, expected_sig_b64)
