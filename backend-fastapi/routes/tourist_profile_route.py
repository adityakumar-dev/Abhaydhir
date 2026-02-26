"""
Tourist Profile Route - Single call to get complete tourist data
Fetches: Profile, Today's entries, Historical entries in one RPC call
"""

from fastapi import APIRouter, Depends, HTTPException, status
from datetime import date
from utils.services.jwt_file_token import generate_user_image_token
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import check_guard_admin_access

router = APIRouter()

import os 
HOST_BACKEND_URL = os.getenv("HOST_BACKEND_URL", "http://localhost:8000")
# ============================================================
# GET TOURIST COMPLETE PROFILE
# ============================================================
@router.get("/{user_id}", status_code=status.HTTP_200_OK)
async def get_tourist_profile(
    user_id: int,
    event_id: int = 1,
    user=Depends(check_guard_admin_access)
):
    """
    Get complete tourist information in a single call:
    - Tourist profile (name, phone, ID, dates, etc.)
    - Today's entry records with all entry items
    - Historical entries for last 10 days
    - Entry statistics (open entries, total today, last entry time)
    
    Uses RPC: get_tourist_complete(user_id, event_id)
    
    Returns:
    {
      "user_id": 123,
      "name": "Aditya Kumar",
      "phone": 9876543210,
      "valid_date": "2026-02-26",
      "is_group": false,
      "group_count": 1,
      "qr_code": "ABC123",
      "image_path": "/static/uploads/images/...",
      "unique_id_path": "/static/uploads/ids/...",
      "has_entry_today": true,
      "entry_record_id": 456,
      "today_entry_count": 2,
      "today_open_entries": 0,
      "last_entry_time": "2026-02-26T10:30:00+00:00",
      "today_entries": [
        {
          "item_id": 789,
          "arrival_time": "2026-02-26T09:00:00+00:00",
          "departure_time": "2026-02-26T09:30:00+00:00",
          "duration": "00:30:00",
          "entry_type": "qr_code_scan",
          "entry_number": 1,
          "metadata": {...}
        }
      ],
      "entry_history": [
        {
          "entry_date": "2026-02-25",
          "record_id": 454,
          "entry_count": 3,
          "items": [...]
        }
      ],
      "message": "Has entries today"
    }
    """
    
    print(f"Fetching complete profile for user_id: {user_id}, event_id: {event_id}")
    
    try:
        # Call RPC to get all tourist data in one call
        resp = supabaseAdmin.rpc(
            "get_tourist_complete",
            {
                "p_user_id": user_id,
                "p_event_id": event_id
            }
        ).execute()
        
        if not resp.data or len(resp.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tourist not found"
            )
        
        tourist_data = resp.data[0]
        
        # Check if tourist was actually found (not the empty fallback response)
        if tourist_data.get("user_id") is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tourist not found in database"
            )
        
        print(f"Successfully retrieved profile for user_id: {user_id}")
        image_token = generate_user_image_token(tourist_data.get("image_path"), user_id, expires_in=86400 * 30)

        image_url = f"{HOST_BACKEND_URL}/tourists/user-image/{image_token}"
        id_token = generate_user_image_token(tourist_data.get("unique_id_path"), user_id, expires_in=86400 * 30)
        id_url = f"{HOST_BACKEND_URL}/tourists/unique-id/{id_token}"
        return {
            "status": "success",
            "message": tourist_data.get("message"),
            "tourist": {
                "user_id": tourist_data.get("user_id"),
                "name": tourist_data.get("name"),
                "phone": tourist_data.get("phone"),
                "unique_id_type": tourist_data.get("unique_id_type"),
                "unique_id": tourist_data.get("unique_id"),
                "is_student": tourist_data.get("is_student"),
                "is_group": tourist_data.get("is_group"),
                "group_count": tourist_data.get("group_count"),
                "valid_date": tourist_data.get("valid_date"),
                "registered_event_id": tourist_data.get("registered_event_id"),
                "created_at": tourist_data.get("created_at"),
                "qr_code": tourist_data.get("qr_code"),
                "image_path": image_url,
                "unique_id_path": id_url
            },
            "today": {
                "has_entry": tourist_data.get("has_entry_today"),
                "entry_record_id": tourist_data.get("entry_record_id"),
                "entry_count": tourist_data.get("today_entry_count"),
                "open_entries": tourist_data.get("today_open_entries"),
                "last_entry_time": tourist_data.get("last_entry_time"),
                "entries": tourist_data.get("today_entries", [])
            },
            "history": {
                "last_10_days": tourist_data.get("entry_history", []),
                "total_records": len(tourist_data.get("entry_history", []))
            }
        }
    
    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error fetching tourist profile: {err_text}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error retrieving profile: {err_text}"
        )


# ============================================================
# GET TOURIST BY PHONE (Alternative lookup)
# ============================================================
@router.get("/phone/{phone}", status_code=status.HTTP_200_OK)
async def get_tourist_profile_by_phone(
    phone: str,
    event_id: int = 1,
    user=Depends(check_guard_admin_access)
):
    """
    Get complete tourist profile by phone number
    First looks up user_id by phone, then fetches complete profile
    """
    
    print(f"Looking up tourist by phone: {phone}")
    
    try:
        # First find user_id by phone
        tourist_lookup = supabaseAdmin.table("tourists").select("user_id").eq("phone", int(phone)).limit(1).execute()
        
        if not tourist_lookup.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No tourist found with phone: {phone}"
            )
        
        user_id = tourist_lookup.data[0]["user_id"]
        
        # Now get complete profile using the RPC
        resp = supabaseAdmin.rpc(
            "get_tourist_complete",
            {
                "p_user_id": user_id,
                "p_event_id": event_id
            }
        ).execute()
        
        if not resp.data or len(resp.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tourist profile not found"
            )
        
        tourist_data = resp.data[0]
        
        print(f"Successfully retrieved profile for phone: {phone}, user_id: {user_id}")
        image_token = generate_user_image_token(tourist_data.get("image_path"), user_id, expires_in=86400 * 30)

        image_url = f"{HOST_BACKEND_URL}/tourists/user-image/{image_token}"
        id_token = generate_user_image_token(tourist_data.get("unique_id_path"), user_id, expires_in=86400 * 30)
        id_url = f"{HOST_BACKEND_URL}/tourists/unique-id/{id_token}"
        return {
            "status": "success",
            "message": tourist_data.get("message"),
            "tourist": {
                "user_id": tourist_data.get("user_id"),
                "name": tourist_data.get("name"),
                "phone": tourist_data.get("phone"),
                "unique_id_type": tourist_data.get("unique_id_type"),
                "unique_id": tourist_data.get("unique_id"),
                "is_student": tourist_data.get("is_student"),
                "is_group": tourist_data.get("is_group"),
                "group_count": tourist_data.get("group_count"),
                "valid_date": tourist_data.get("valid_date"),
                "registered_event_id": tourist_data.get("registered_event_id"),
                "created_at": tourist_data.get("created_at"),
                "qr_code": tourist_data.get("qr_code"),
                "image_path": image_url,
                "unique_id_path": id_url
            },
            "today": {
                "has_entry": tourist_data.get("has_entry_today"),
                "entry_record_id": tourist_data.get("entry_record_id"),
                "entry_count": tourist_data.get("today_entry_count"),
                "open_entries": tourist_data.get("today_open_entries"),
                "last_entry_time": tourist_data.get("last_entry_time"),
                "entries": tourist_data.get("today_entries", [])
            },
            "history": {
                "last_10_days": tourist_data.get("entry_history", []),
                "total_records": len(tourist_data.get("entry_history", []))
            }
        }
    
    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error fetching tourist profile by phone: {err_text}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error retrieving profile: {err_text}"
        )


# ============================================================
# GET TOURIST WITH RELATED USERS (SAME PHONE)
# ============================================================
@router.get("/complete/{user_id}", status_code=status.HTTP_200_OK)
async def get_tourist_complete_with_related(
    user_id: int,
    event_id: int = 1,
    user=Depends(check_guard_admin_access)
):
    """
    Get complete tourist data + all related users with same phone number.
    
    Perfect for family registrations where multiple people register with the same phone:
    - Parent registers for Feb 27 with phone 9876543210
    - Child registers for Feb 28 with phone 9876543210
    - Spouse registers for Mar 1 with phone 9876543210
    
    Single call returns ALL 3 users' complete data (profile + today's entries + history).
    
    Returns:
    {
      "primary_user": {
        "user_id": 123,
        "name": "Parent",
        "phone": 9876543210,
        "valid_date": "2026-02-27",
        "has_entry_today": true,
        "today_entries": [...],
        "entry_history": [...]
      },
      "related_users": [
        {
          "user_id": 124,
          "name": "Child",
          "phone": 9876543210,
          "valid_date": "2026-02-28",
          "has_entry_today": false,
          "today_entries": [],
          "entry_history": [...]
        },
        {
          "user_id": 125,
          "name": "Spouse",
          "phone": 9876543210,
          "valid_date": "2026-03-01",
          "has_entry_today": false,
          "today_entries": [],
          "entry_history": [...]
        }
      ],
      "related_count": 2,
      "message": "Found primary user + 2 related users with same phone"
    }
    """
    
    print(f"Fetching complete profile with related users for user_id: {user_id}, event_id: {event_id}")
    
    try:
        # Call RPC to get all data including related users
        resp = supabaseAdmin.rpc(
            "get_tourist_with_related",
            {
                "p_user_id": user_id,
                "p_event_id": event_id
            }
        ).execute()
        
        if not resp.data or len(resp.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tourist not found"
            )
        
        tourist_data = resp.data[0]
        
        # Check if tourist was actually found
        if tourist_data.get("user_id") is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tourist not found in database"
            )
        
        print(f"Successfully retrieved complete profile for user_id: {user_id}")
        print(f"Related users count: {tourist_data.get('related_count', 0)}")
        
        # Parse related users from JSONB
        related_users = tourist_data.get("related_users", [])
        if isinstance(related_users, str):
            import json
            related_users = json.loads(related_users)
        image_token = generate_user_image_token(tourist_data.get("image_path"), user_id, expires_in=86400 * 30)

        image_url = f"{HOST_BACKEND_URL}/tourists/user-image/{image_token}"
        id_token = generate_user_image_token(tourist_data.get("unique_id_path"), user_id, expires_in=86400 * 30)
        id_url = f"{HOST_BACKEND_URL}/tourists/unique-id/{id_token}"
        return {
            "status": "success",
            "message": tourist_data.get("message"),
            "primary_user": {
                "user_id": tourist_data.get("user_id"),
                "name": tourist_data.get("name"),
                "phone": tourist_data.get("phone"),
                "unique_id_type": tourist_data.get("unique_id_type"),
                "unique_id": tourist_data.get("unique_id"),
                "is_student": tourist_data.get("is_student"),
                "is_group": tourist_data.get("is_group"),
                "group_count": tourist_data.get("group_count"),
                "valid_date": tourist_data.get("valid_date"),
                "registered_event_id": tourist_data.get("registered_event_id"),
                "created_at": tourist_data.get("created_at"),
                "qr_code": tourist_data.get("qr_code"),
                "image_path": image_url,
                "unique_id_path": id_url,
                "today": {
                    "has_entry": tourist_data.get("has_entry_today"),
                    "entry_record_id": tourist_data.get("entry_record_id"),
                    "entry_count": tourist_data.get("today_entry_count"),
                    "open_entries": tourist_data.get("today_open_entries"),
                    "last_entry_time": tourist_data.get("last_entry_time"),
                    "entries": tourist_data.get("today_entries", [])
                },
                "history": tourist_data.get("entry_history", [])
            },
            "related_users": related_users if isinstance(related_users, list) else [],
            "related_count": tourist_data.get("related_count", 0),
            "family_summary": {
                "total_registrations": 1 + tourist_data.get("related_count", 0),
                "phone_number": tourist_data.get("phone"),
                "event_id": event_id
            }
        }
    
    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error fetching tourist complete profile: {err_text}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error retrieving profile: {err_text}"
        )
