from supabase import create_client, Client
# Temporary mock for supabase client
import os

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
LEGACY_JWT_SECRET = os.getenv("LEGACY_JWT_SECRET")
supabaseAdmin = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)