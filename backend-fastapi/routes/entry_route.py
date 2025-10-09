from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime, date
from pydantic import BaseModel
from typing import Optional
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import jwt_middleware, check_guard_admin_access

router = APIRouter()

class EntryRequest(BaseModel):
    user_id: int
    event_id: int
    entry_type: str = 'normal'  # 'normal', 'bypass', 'manual'
    bypass_reason: Optional[str] = None
    metadata: Optional[dict] = None

class DepartureRequest(BaseModel):
    user_id: int
    event_id: int


# ============================================================
# CREATE ENTRY (Arrival)
# ============================================================
@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_entry(
    entry: EntryRequest,
    user=Depends(check_guard_admin_access)
):
    """
    Register a new entry for a tourist.
    - If entry_record exists for today, reuse it
    - If not, create new entry_record first, then create entry_item
    """
    today = date.today()
    
    # Validate user exists
    user_resp = supabaseAdmin.table("tourists").select("*").eq("user_id", entry.user_id).execute()
    if not user_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tourist with user_id {entry.user_id} not found"
        )
    
    # Validate event exists and is active
    event_resp = supabaseAdmin.table("events").select("*").eq("event_id", entry.event_id).eq("is_active", True).execute()
    if not event_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event {entry.event_id} not found or not active"
        )
    
    record_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", entry.user_id).eq("event_id", entry.event_id).eq("entry_date", str(today)).execute()
    
    if record_resp.data:
        # Use existing record
        record_id = record_resp.data[0]["record_id"]
    else:
        # Create new entry_record for today
        new_record_resp = supabaseAdmin.table("entry_records").insert({
            "user_id": entry.user_id,
            "event_id": entry.event_id,
            "entry_date": str(today),
            "time_logs": []
        }).execute()
        
        if not new_record_resp.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create entry record"
            )
        record_id = new_record_resp.data[0]["record_id"]
    print(user)
    # Create entry_item
    entry_item_data = {
        "record_id": record_id,
        "arrival_time": datetime.now().isoformat(),
        "entry_type": entry.entry_type,
        "bypass_reason": entry.bypass_reason,
        "approved_by_uid": str(user.get("sub")) if user.get("sub") else None,
        "metadata": entry.metadata or {}
    }
    
    item_resp = supabaseAdmin.table("entry_items").insert(entry_item_data).execute()
    
    if not item_resp.data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create entry item"
        )
    
    return {
        "message": "Entry registered successfully",
        "record_id": record_id,
        "entry_item": item_resp.data[0]
    }


# ============================================================
# REGISTER DEPARTURE
# ============================================================
@router.post("/departure", status_code=status.HTTP_200_OK)
async def register_departure(
    departure: DepartureRequest,
    user=Depends(check_guard_admin_access)
):
    """
    Register departure for a tourist.
    - Finds the last entry_item for today without departure_time
    - Updates it with departure_time and calculates duration
    - If no open entry found, returns error (but allows new entries to be created separately)
    """
    today = date.today()

    # Find entry_record for today
    record_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", departure.user_id).eq("event_id", departure.event_id).eq("entry_date", str(today)).execute()

    if not record_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No entry record found for user {departure.user_id} on {today}"
        )

    record_id = record_resp.data[0]["record_id"]

    

    # Find the last entry_item without departure_time
    query = supabaseAdmin.table("entry_items").select("*").eq("record_id", record_id).is_("departure_time", "null").order("arrival_time", desc=True)
    item_resp = query.limit(1).execute()

    if not item_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No open entry found for user {departure.user_id}. User may need to register a new entry first."
        )

    entry_item = item_resp.data[0]
    item_id = entry_item["item_id"]
    arrival_time = datetime.fromisoformat(entry_item["arrival_time"].replace("Z", "+00:00"))
    # Make departure_time timezone-aware (UTC)
    from datetime import timezone
    departure_time = datetime.now(timezone.utc)

    # Calculate duration
    duration = departure_time - arrival_time
    duration_str = str(duration)  # PostgreSQL interval format

    # Update entry_item with departure
    update_resp = supabaseAdmin.table("entry_items").update({
        "departure_time": departure_time.isoformat(),
        "duration": duration_str
    }).eq("item_id", item_id).execute()

    if not update_resp.data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update departure time"
        )

    return {
        "message": "Departure registered successfully",
        "entry_item": update_resp.data[0],
        "duration": duration_str
    }


# ============================================================
# GET TODAY'S ENTRIES FOR A USER
# ============================================================
@router.get("/today/{user_id}/{event_id}", status_code=status.HTTP_200_OK)
async def get_today_entries(
    user_id: int,
    event_id: int,
    user=Depends(check_guard_admin_access)
):
    """
    Get all entries for a user today, including open/closed status
    """
    today = date.today()
    
    # Get entry_record for today
    record_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("event_id", event_id).eq("entry_date", str(today)).execute()
    
    if not record_resp.data:
        return {
            "message": "No entries found for today",
            "entry_record": None,
            "entry_items": []
        }
    
    record_id = record_resp.data[0]["record_id"]
    
    # Get all entry_items for this record
    items_resp = supabaseAdmin.table("entry_items").select("*").eq("record_id", record_id).order("arrival_time", desc=True).execute()
    
    return {
        "entry_record": record_resp.data[0],
        "entry_items": items_resp.data,
        "open_entries": sum(1 for item in items_resp.data if item.get("departure_time") is None),
        "total_entries": len(items_resp.data)
    }


# ============================================================
# GET ENTRY HISTORY FOR A USER
# ============================================================
@router.get("/history/{user_id}/{event_id}", status_code=status.HTTP_200_OK)
async def get_entry_history(
    user_id: int,
    event_id: int,
    limit: int = 10,
    user=Depends(check_guard_admin_access)
):
    """
    Get entry history for a user across all dates
    """
    # Get all entry_records
    records_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("event_id", event_id).order("entry_date", desc=True).limit(limit).execute()
    
    if not records_resp.data:
        return {
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
            "entry_items": items_resp.data,
            "total_entries": len(items_resp.data)
        })
    
    return {
        "user_id": user_id,
        "event_id": event_id,
        "history": history
    }