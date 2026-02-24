from fastapi import Request, HTTPException, status, Depends
from fastapi import APIRouter, Depends
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import jwt_middleware
router = APIRouter()

EVENT_ID = 1

TARGET_DATES = [
    "2026-02-27",
    "2026-02-28",
    "2026-03-01"
]


@router.post("/onboarding")
async def onboarding(request: Request):
    user = await jwt_middleware(request)
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this resource."
        )
    response = (
        supabaseAdmin
        .rpc("get_admin_dashboard",
             {"event_id_param": EVENT_ID})
        .execute()
    )
    print("RPC Response: ", response)

    # -------------------------
    # Final Structured Response
    # -------------------------
    data = response.data or {}
    return {
        "total_registered": data.get("total_registered", 0),
        "currently_inside": data.get("currently_inside", 0),
        "feedback_submissions": data.get("feedback_count", 0),
        "date_wise": {
            "registrations": data.get("registration_counts", {}),
            "entries": data.get("entry_counts", {})
        }
    }