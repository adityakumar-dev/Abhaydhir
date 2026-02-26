from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime, date, timezone
from pydantic import BaseModel
from typing import Optional
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import jwt_middleware, check_guard_admin_access
from utils.india_time import india_today, india_today_str

router = APIRouter()

class EntryRequest(BaseModel):
    short_code: str
    event_id: int = 1  # Default to event 1


class DepartureRequest(BaseModel):
    short_code: str
    event_id: int = 1  # Default to event 1


# ============================================================
# CREATE ENTRY (Arrival) - Using QR Code RPC
# ============================================================
@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_entry(
    entry: EntryRequest,
    user=Depends(check_guard_admin_access)
):
    """
    Register a new entry for a tourist using QR code (short_code).
    
    Flow:
    1. Call RPC verify_qr_code(short_code, event_id) to get tourist details
    2. Validate QR code validity and date match
    3. Create entry_record if doesn't exist for today
    4. Create entry_item with arrival time
    
    The RPC handles:
    - QR code lookup in tourist_meta
    - Tourist detail retrieval
    - Valid date validation
    - Current inside status check
    - Entry history for today
    """
    today = india_today()
    
    print(f"Processing entry for short_code: {entry.short_code}, event_id: {entry.event_id}")

    try:
        # STEP 1: Call RPC to verify QR code and get all details
        qr_verify_resp = supabaseAdmin.rpc(
            "verify_qr_code",
            {
                "p_short_code": entry.short_code,
                "p_event_id": entry.event_id,
                "p_entry_date": str(today)
            }
        ).execute()

        if not qr_verify_resp.data or len(qr_verify_resp.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="QR code not found or invalid"
            )

        qr_data = qr_verify_resp.data[0]
        
        # STEP 2: Check QR code validity
        if not qr_data.get("success"):
            message = qr_data.get("message", "QR code verification failed")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=message
            )

        user_id = qr_data.get("user_id")
        valid_date = qr_data.get("valid_date")
        is_already_inside = qr_data.get("is_already_inside", False)
        total_entries_today = qr_data.get("total_entries_today", 0)
        
        # STEP 3: Validate date match
        if valid_date:
            try:
                valid_date_obj = date.fromisoformat(str(valid_date))
            except (ValueError, TypeError):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid valid_date in QR code"
                )
            
            # Check if today matches valid_date
            if today != valid_date_obj:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Your card is valid for {valid_date_obj.strftime('%Y-%m-%d')}. Please renew your card for today's date ({today.strftime('%Y-%m-%d')})"
                )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No valid_date in QR code"
            )

        # STEP 5: Get or create entry_record for today
        record_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("event_id", entry.event_id).eq("entry_date", str(today)).execute()
        
        if record_resp.data:
            # Use existing record
            record_id = record_resp.data[0]["record_id"]
            print(f"Using existing entry_record: {record_id}")
        else:
            # Create new entry_record for today
            new_record_resp = supabaseAdmin.table("entry_records").insert({
                "user_id": user_id,
                "event_id": entry.event_id,
                "entry_date": str(today)
                # Don't insert time_logs - let database use default
            }).execute()
            
            if not new_record_resp.data:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Failed to create entry record"
                )
            record_id = new_record_resp.data[0]["record_id"]
            print(f"Created new entry_record: {record_id}")

        # STEP 6: Create entry_item (arrival)
        # Extract verifier info from JWT (role is in app_metadata, name is in user_metadata)
        verified_by_role = user.get("app_metadata", {}).get("role")  # e.g., 'admin', 'security'
        verified_by_name = user.get("user_metadata", {}).get("name")  # e.g., 'Aditya Kumar'
        verified_by_uid = user.get("sub")  # UUID of the security/admin person
        
        entry_item_data = {
            "record_id": record_id,
            "arrival_time": datetime.now(timezone.utc).isoformat(),
            "entry_type": "qr_code_scan",
            "bypass_reason": None,
            "approved_by_uid": verified_by_uid,  # Store who verified the entry
            "metadata": {
                "short_code": entry.short_code,
                "verified_by_role": verified_by_role,  # Role from JWT
                "verified_by_name": verified_by_name,  # Name from JWT
                "entry_number": total_entries_today + 1  # Track which entry this is
            }
        }
        
        item_resp = supabaseAdmin.table("entry_items").insert(entry_item_data).execute()
        
        if not item_resp.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create entry item"
            )

        entry_item = item_resp.data[0]
        
        print(f"Entry created successfully for user_id: {user_id}, item_id: {entry_item.get('item_id')}, entry_number: {total_entries_today + 1}")

        # Determine if this is a re-entry
        is_reentry = total_entries_today > 0
        
        return {
            "message": "Re-entry recorded" if is_reentry else "Entry registered successfully",
            "user_id": user_id,
            "name": qr_data.get("name"),
            "phone": qr_data.get("phone"),
            "is_group": qr_data.get("is_group"),
            "group_count": qr_data.get("group_count"),
            "record_id": record_id,
            "entry_item": entry_item,
            "arrival_time": entry_item.get("arrival_time"),
            "qr_code": entry.short_code,
            "entry_number": total_entries_today + 1,  # Show which entry this is
            "total_entries_today": total_entries_today + 1,  # Total count after this entry
            "is_reentry": is_reentry,
            "status": "re-entered" if is_reentry else "entered"
        }

    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error creating entry: {err_text}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error registering entry: {err_text}"
        )



# ============================================================
# REGISTER DEPARTURE - Using QR Code
# ============================================================
@router.post("/departure", status_code=status.HTTP_200_OK)
async def register_departure(
    departure: DepartureRequest,
    user=Depends(check_guard_admin_access)
):
    """
    Register departure for a tourist using QR code.
    - Calls RPC to verify QR code and get user_id
    - Finds the last entry_item for today without departure_time
    - Updates it with departure_time and calculates duration
    """
    today = india_today()

    print(f"Processing departure for short_code: {departure.short_code}, event_id: {departure.event_id}")

    try:
        # STEP 1: Verify QR code and get user_id
        qr_verify_resp = supabaseAdmin.rpc(
            "verify_qr_code",
            {
                "p_short_code": departure.short_code,
                "p_event_id": departure.event_id,
                "p_entry_date": str(today)
            }
        ).execute()

        if not qr_verify_resp.data or len(qr_verify_resp.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="QR code not found or invalid"
            )

        qr_data = qr_verify_resp.data[0]
        user_id = qr_data.get("user_id")
        valid_date = qr_data.get("valid_date")

        # Validate date match
        if valid_date:
            try:
                valid_date_obj = date.fromisoformat(str(valid_date))
            except (ValueError, TypeError):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid valid_date in QR code"
                )
            
            if today != valid_date_obj:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Your card is valid for {valid_date_obj.strftime('%Y-%m-%d')}. Cannot register departure."
                )

        # STEP 2: Find entry_record for today
        record_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("event_id", departure.event_id).eq("entry_date", str(today)).execute()

        if not record_resp.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No entry record found for user on {today}"
            )

        record_id = record_resp.data[0]["record_id"]

        # STEP 3: Find the last entry_item without departure_time
        query = supabaseAdmin.table("entry_items").select("*").eq("record_id", record_id).is_("departure_time", "null").order("arrival_time", desc=True)
        item_resp = query.limit(1).execute()

        if not item_resp.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No open entry found. User may need to register a new entry first."
            )

        entry_item = item_resp.data[0]
        item_id = entry_item["item_id"]
        
        # Parse arrival_time and calculate duration
        arrival_time_str = entry_item["arrival_time"]
        if arrival_time_str.endswith("Z"):
            arrival_time = datetime.fromisoformat(arrival_time_str.replace("Z", "+00:00"))
        else:
            arrival_time = datetime.fromisoformat(arrival_time_str)
        
        # Make departure_time timezone-aware (UTC)
        departure_time = datetime.now(timezone.utc)

        # Calculate duration
        duration = departure_time - arrival_time
        duration_str = str(duration)  # PostgreSQL interval format

        # STEP 4: Update entry_item with departure
        update_resp = supabaseAdmin.table("entry_items").update({
            "departure_time": departure_time.isoformat(),
            "duration": duration_str
        }).eq("item_id", item_id).execute()

        if not update_resp.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to update departure time"
            )

        updated_item = update_resp.data[0]
        
        # Extract verifier info for logging
        verified_by_role = user.get("app_metadata", {}).get("role")
        verified_by_name = user.get("user_metadata", {}).get("name")
        
        print(f"Departure registered for user_id: {user_id}, item_id: {item_id}, duration: {duration_str}, verified_by: {verified_by_name} ({verified_by_role})")

        return {
            "message": "Departure registered successfully",
            "user_id": user_id,
            "name": qr_data.get("name"),
            "entry_item": updated_item,
            "duration": duration_str,
            "arrival_time": entry_item.get("arrival_time"),
            "departure_time": updated_item.get("departure_time"),
            "status": "exited"
        }

    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error registering departure: {err_text}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error registering departure: {err_text}"
        )


# ============================================================
# GET TODAY'S ENTRIES FOR A USER
# ============================================================
@router.get("/today/{user_id}", status_code=status.HTTP_200_OK)
async def get_today_entries(
    user_id: int,
    event_id: int = 1,
    user=Depends(check_guard_admin_access)
):
    """
    Get all entries for a user today, including open/closed status
    """
    today = india_today()
    
    # Get entry_record for today
    record_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("event_id", event_id).eq("entry_date", str(today)).execute()
    
    if not record_resp.data:
        return {
            "message": "No entries found for today",
            "user_id": user_id,
            "entry_record": None,
            "entry_items": [],
            "open_entries": 0,
            "total_entries": 0
        }
    
    record_id = record_resp.data[0]["record_id"]
    
    # Get all entry_items for this record
    items_resp = supabaseAdmin.table("entry_items").select("*").eq("record_id", record_id).order("arrival_time", desc=True).execute()
    
    open_entries = sum(1 for item in items_resp.data if item.get("departure_time") is None) if items_resp.data else 0
    
    return {
        "user_id": user_id,
        "event_id": event_id,
        "entry_record": record_resp.data[0],
        "entry_items": items_resp.data or [],
        "open_entries": open_entries,
        "total_entries": len(items_resp.data) if items_resp.data else 0
    }


# ============================================================
# GET ENTRY HISTORY FOR A USER
# ============================================================
@router.get("/history/{user_id}", status_code=status.HTTP_200_OK)
async def get_entry_history(
    user_id: int,
    event_id: int = 1,
    limit: int = 10,
    user=Depends(check_guard_admin_access)
):
    """
    Get entry history for a user across all dates
    """
    # Get all entry_records ordered by date descending
    records_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("event_id", event_id).order("entry_date", desc=True).limit(limit).execute()
    
    if not records_resp.data:
        return {
            "user_id": user_id,
            "event_id": event_id,
            "message": "No entry history found",
            "history": []
        }
    
    history = []
    for record in records_resp.data:
        # Get entry_items for each record
        items_resp = supabaseAdmin.table("entry_items").select("*").eq("record_id", record["record_id"]).order("arrival_time", desc=True).execute()
        
        history.append({
            "date": record["entry_date"],
            "record_id": record["record_id"],
            "entry_items": items_resp.data or [],
            "total_entries": len(items_resp.data) if items_resp.data else 0,
            "created_at": record.get("created_at")
        })
    
    return {
        "user_id": user_id,
        "event_id": event_id,
        "history": history,
        "total_records": len(history)
    }