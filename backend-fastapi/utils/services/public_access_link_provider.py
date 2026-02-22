import os
import time
import hmac
import hashlib
import base64
import secrets
import string
from urllib.parse import urlencode
from utils.supabase.supabase import supabaseAdmin

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


def short_url_generator(length: int = 6, max_retries: int = 5) -> str:
    """
    Generate a unique short code for URL shortening.
    
    Args:
        length: Length of the short code (default: 6 chars) → ~2.2 billion combinations
        max_retries: Max collision retry attempts (default: 5)
    
    Returns:
        A unique alphanumeric short code (e.g., "a7b2c9")
    
    Raises:
        RuntimeError if unable to generate unique code after max_retries attempts
    """
    alphabet = string.ascii_letters + string.digits  # A-Z, a-z, 0-9 (62 chars)
    
    for attempt in range(max_retries):
        # Generate random short code
        short_code = ''.join(secrets.choice(alphabet) for _ in range(length))
        
        # Check if already exists in short_links table
        try:
            resp = (
                supabaseAdmin.table("short_links")
                .select("short_code")
                .eq("short_code", short_code)
                .execute()  # Use execute() instead of .single() to avoid errors on 0 rows
            )
            
            # If no data returned, short_code is unique
            if not resp.data or len(resp.data) == 0:
                return short_code
            
        except Exception as e:
            # Log error but continue retrying
            print(f"Error checking short_code uniqueness (attempt {attempt + 1}): {e}")
            continue
    
    # Failed to generate unique code after retries
    raise RuntimeError(f"Failed to generate unique short code after {max_retries} attempts") 
