from fastapi import Request, HTTPException, status
from jose import jwt, jwk
import requests
import time
import os

# Extract SUPABASE_URL - handle various input formats
_supabase_url = os.getenv("SUPABASE_URL", "zxffvykqyoahuwrsqvhj")

# Clean up: remove https://, trailing slashes, and .supabase.co suffix
_supabase_url = _supabase_url.replace("https://", "").replace("http://", "").strip("/")
_supabase_url = _supabase_url.replace(".supabase.co", "")

SUPABASE_URL = _supabase_url
JWKS_URL = f"https://{SUPABASE_URL}.supabase.co/auth/v1/.well-known/jwks.json"
ISSUER = f"https://{SUPABASE_URL}.supabase.co/auth/v1"

print(f"[DEBUG] SUPABASE_URL: {SUPABASE_URL}")
print(f"[DEBUG] JWKS_URL: {JWKS_URL}")
print(f"[DEBUG] ISSUER: {ISSUER}")

# ---- JWKS CACHE (in-memory) ----
JWKS_CACHE = {"keys": None, "fetched_at": 0}
JWKS_TTL = 60 * 60  # refresh every 1 hour

def get_jwks():
    """Fetch and cache Supabase public keys (only once per hour)."""
    now = time.time()

    if JWKS_CACHE["keys"] and (now - JWKS_CACHE["fetched_at"] < JWKS_TTL):
        return JWKS_CACHE["keys"]

    try:
        print(f"[DEBUG] Fetching JWKS from: {JWKS_URL}")
        response = requests.get(JWKS_URL, timeout=5)
        response.raise_for_status()
        jwks = response.json()
        JWKS_CACHE["keys"] = jwks["keys"]
        JWKS_CACHE["fetched_at"] = now
        print(f"[DEBUG] Successfully fetched {len(jwks['keys'])} keys from JWKS")
        return jwks["keys"]
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Failed to fetch JWKS: {e}")
        raise Exception(f"Failed to fetch JWKS from {JWKS_URL}: {e}")

def get_public_key(token: str):
    """Extract and construct the public key from JWKS based on token's kid (key ID)."""
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")

    if not kid:
        raise Exception("Token missing 'kid' in header")

    keys = get_jwks()

    for key in keys:
        if key["kid"] == kid:
            # Construct the public key from JWK
            public_key = jwk.construct(key)
            return public_key.to_pem()

    raise Exception(f"Public key with kid '{kid}' not found in JWKS")
