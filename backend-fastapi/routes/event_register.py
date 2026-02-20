from fastapi import APIRouter, Depends, HTTPException, status, Request
from datetime import datetime, timezone
from utils.supabase.auth import jwt_middleware
from utils.supabase.supabase import supabaseAdmin
from utils.models.api_models import Event

router = APIRouter()

# ------------------------------------------------------------
# CREATE NEW EVENT (Admin only)
# ------------------------------------------------------------
@router.post("/register", status_code=status.HTTP_201_CREATED)
def register_for_event(
    registration: Event,
    user=Depends(jwt_middleware)
):
    try:
        if user['role'] != 'admin':
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to register events."
            )

        # Prevent client from sending event_id manually
        if hasattr(registration, "event_id"):
            delattr(registration, "event_id")

        # registration['created_at'] = datetime.now()

        # Deeply serialize all datetime/date fields and remove None values
        def deep_serialize(obj):
            if isinstance(obj, dict):
                return {k: deep_serialize(v) for k, v in obj.items() if v is not None}
            elif isinstance(obj, list):
                return [deep_serialize(v) for v in obj if v is not None]
            elif hasattr(obj, 'isoformat'):
                return obj.isoformat()
            else:
                return obj

        reg_dict = deep_serialize(registration.dict())
        print(f"Inserting event: {reg_dict}")
        
        response = supabaseAdmin.table("events").insert(reg_dict).execute()
        
        # Supabase Python client structure: response.data is a list, response.error is None on success
        if hasattr(response, 'data') and response.data:
            # Insert returns a list, get the first element
            event_data = response.data[0] if isinstance(response.data, list) else response.data
            return {"message": "Event registered successfully", "event": event_data}
        else:
            # If no data, something went wrong
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create event: No data returned from Supabase"
            )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error registering event: {str(e)}"
        )
   

# ------------------------------------------------------------
# GET ALL EVENTS (Admin only)
# ------------------------------------------------------------
@router.get("/", status_code=status.HTTP_200_OK)
async def get_events(
    user=Depends(jwt_middleware)
):
    if user.get('role') != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view events.",
        )

    response = supabaseAdmin.table("events").select("*").execute()
    
    # Supabase returns data as a list
    if hasattr(response, 'data') and response.data is not None:
        return {"events": response.data}
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to fetch events: No data returned from Supabase"
        )


# ------------------------------------------------------------
# GET ACTIVE EVENTS (Public Access)
# ------------------------------------------------------------
@router.get("/public/active", status_code=status.HTTP_200_OK)
async def get_active_events(user = Depends(jwt_middleware)):
    """Get all active events for public registration"""
    if user.get('role') not in ['admin', 'security']:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view active events.",
        )
    
    
    response = supabaseAdmin.table("events").select("*").eq("is_active", True).execute()
    
    
    
    if hasattr(response, 'data') and response.data is not None:
        if user.get('role') == 'security':
            # Filter events based on allowed_guards for security role
            uid = user.get('uid') or user.get('sub')
            filtered_events = []
            for event in response.data:
                allowed_guards = event.get('allowed_guards') or []
                # if array is empty then allow to add the event in the fliterevnts
                if allowed_guards == [] :
                    filtered_events.append(event)

                elif not allowed_guards or uid in allowed_guards:
                    filtered_events.append(event)
            return {"events": filtered_events}
        else:
            return {"events": response.data}
    
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to fetch active events: No data returned from Supabase"
        )


# ------------------------------------------------------------
# GET SINGLE EVENT (Admin + Security)
# ------------------------------------------------------------
@router.get("/{event_id}", status_code=status.HTTP_200_OK)
async def get_event(
    event_id: int,
    user=Depends(jwt_middleware)
):
    if user.get('role') not in ['admin', 'security']:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this event.",
        )

    response = supabaseAdmin.table("events").select("*").eq("event_id", event_id).single().execute()
    
    if hasattr(response, 'data') and response.data:
        event_data = response.data
        Event(**event_data)  # Validate structure

        # Security guards must be in allowed_guards if list exists
        if user.get('role') == 'security':
            allowed_list = event_data.get('allowed_guards', [])
            if allowed_list and user.get('uid') not in allowed_list:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You are not authorized to access this event.",
                )

        return {"event": event_data}
    else:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event with ID {event_id} not found"
        )


# ------------------------------------------------------------
# UPDATE ALLOWED GUARDS (Admin only)
# ------------------------------------------------------------
@router.put("/{event_id}/guards", status_code=status.HTTP_200_OK)
async def update_guard_list(
    event_id: int,
    allowed_guards: list[str],
    user=Depends(jwt_middleware)
):
    if user.get('role') != 'admin':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to update guard list.",
        )

    # If guard list provided, validate each guard UID exists in Supabase Auth
    if allowed_guards:
        all_users = supabaseAdmin.auth.admin.list_users()
        existing_user_ids = {u.id for u in all_users.users}

        for guard_uid in allowed_guards:
            if guard_uid not in existing_user_ids:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"User {guard_uid} does not exist in Supabase Auth.",
                )

    response = supabaseAdmin.table("events").update({"allowed_guards": allowed_guards}).eq("event_id", event_id).execute()
    
    if hasattr(response, 'data') and response.data:
        updated_event = response.data[0] if isinstance(response.data, list) else response.data
        return {"message": "Guard list updated successfully", "event": updated_event}
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update guard list: No data returned from Supabase"
        )


# ------------------------------------------------------------
# UPDATE EVENT STATUS (Admin only)
# ------------------------------------------------------------
@router.put("/status", status_code=status.HTTP_200_OK)
def update_event_status(
    event_id: int,
    is_active: bool,
    user=Depends(jwt_middleware)

):
    if( user.get('role') != 'admin' ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to update event status.",
        )
   
    response = supabaseAdmin.table("events").update({"is_active": is_active}).eq("event_id", event_id).execute()
    
    if hasattr(response, 'data') and response.data:
        updated_event = response.data[0] if isinstance(response.data, list) else response.data
        return {"message": "Event status updated successfully", "event": updated_event}
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update event status: No data returned from Supabase"
        )

# frontend event requests
# anyone can see the event is active
@router.get("/check/{event_id}", status_code=status.HTTP_200_OK)
async def get_active_event(event_id: int, request: Request):
    """
    Get event details with client information.
    Captures request headers for analytics/tracking purposes.
    """
    # Extract client headers
    client_ip = request.client.host if request.client else "unknown"
    forwarded_for = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
    actual_ip = forwarded_for if forwarded_for else client_ip
    user_agent = request.headers.get("User-Agent", "unknown")

    feeback_route = request.headers.get("feedback-check", "false")
      
    
    response = supabaseAdmin.table("events").select("*").eq("event_id", event_id).single().execute()
    print(response)
    print("Feedback route header:", feeback_route)

    if response is None or response.data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event with ID {event_id} not found"
        )
    
    if hasattr(response, 'data') and response.data:
        data = response.data
        
        # Check if event is active
        if data.get('is_active') is False: 
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Event is not active"
            )
        
        # Parse and validate date range
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        current_time = datetime.now(timezone.utc)
        
        if isinstance(start_date, str):
            start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).replace(tzinfo=timezone.utc)
        if isinstance(end_date, str):
            end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).replace(tzinfo=timezone.utc)
       
        
        # Return based on feedback route header
        print(feeback_route == "false")
        print(feeback_route)
        if feeback_route == "false": 
            print("Normal register event check - returning event data only")
            return {"event": data}
        else: 
            print("Feedback route - returning event data with client headers")
             
            if current_time < start_date or current_time > end_date:
                print(f"Current time {current_time} is outside event date range {start_date} to {end_date}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Event is not currently active"
                )
            else:
                return {
                    "event": data,
                    "client_info": {
                        "user_agent": user_agent,
                        "ip_address": client_ip
                    }
                }
    else:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event with ID {event_id} not found"
        )
