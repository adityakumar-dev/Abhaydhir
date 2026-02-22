from fastapi import APIRouter, Depends, HTTPException

from utils.supabase.supabase import supabaseAdmin

router = APIRouter()

@router.get("/c/{code}")
async def redirect_short_link(code: str):
    """
    Redirect to the original URL based on the short code.
    - Validate short code exists and is active
    - Validate token is valid and not expired
    - Increment click count
    - Redirect to original URL (extracted from token)
    """
    response = supabaseAdmin.table("short_links").select("*").eq("short_code", code).eq("is_active", True).execute().data
    if not response:
        raise HTTPException(status_code=404, detail="Short link not found or inactive")
    if hasattr(response, "data"):
        link = response.data[0]['token']
        
        
    else :
        HTTPException(status_code=404, detail="Short link not found or inactive")
    
    return {"message": f"Redirecting for code: {code}"}