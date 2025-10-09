from fastapi import (
    APIRouter, BackgroundTasks, Depends, HTTPException, status, UploadFile
)
from fastapi.responses import FileResponse
from utils.supabase.auth import jwt_middleware, check_guard_admin_access
from utils.supabase.supabase import supabaseAdmin
from utils.models.api_models import Tourist
from fastapi import Form
from utils.services.public_access_link_provider import generate_public_access_link, verify_public_access_link
from utils.services.file_handlers import save_upload_file
from template_generator import VisitorCardGenerator
from utils.services.email_handler import send_welcome_email_background
from utils.services.jwt_file_token import (
    generate_visitor_card_token, 
    generate_user_image_token,
    verify_file_token,
    validate_file_path_security
)
import jwt
import os

router = APIRouter()

# ------------------------------------------------------------
# REGISTER TOURIST (Public access)
# ------------------------------------------------------------
@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register_tourist(
    name: str = Form(...),
    email: str = Form(None),
    unique_id_type: str = Form(...),
    unique_id: str = Form(...),
    is_group: bool = Form(...),
    group_count: int = Form(...),
    registered_event_id: int = Form(...),
    image: UploadFile = None,
    background_tasks: BackgroundTasks = None,
):
    # Build registration object from form fields
    registration = Tourist(
        name=name,
        email=email,
        unique_id_type=unique_id_type,
        unique_id=unique_id,
        is_group=is_group,
        group_count=group_count,
        registered_event_id=registered_event_id
    )
    if hasattr(registration, "user_id"):
        delattr(registration, "user_id")

    # Require image
    if not image:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Image file is required")

    # Basic validation
    if not registration.name or not registration.unique_id_type or not registration.unique_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Missing required fields")

    if not registration.is_group:
        registration.group_count = 1
    if registration.group_count < 1:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "group_count must be ≥ 1")
    if registration.is_group and registration.group_count < 2:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "group_count must be ≥ 2 for groups")
    if not registration.registered_event_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "registered_event_id is required")

    # Validate active event
    event_resp = supabaseAdmin.table("events").select("*").eq("is_active", True).eq("event_id", registration.registered_event_id).execute()
    if hasattr(event_resp , 'error'):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or inactive event")
    event_data = event_resp.data[0]

    # check user email exist for the same event
    email_check_resp = supabaseAdmin.table('tourists').select('*').eq('email', registration.email).eq('registered_event_id', registration.registered_event_id).execute()
    if hasattr(email_check_resp, 'data') and email_check_resp.data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "User with this email is already registered for the event")

    # Insert tourist
    insert_resp = supabaseAdmin.table("tourists").insert(registration.dict()).execute()
    if hasattr(insert_resp, "error") or not insert_resp.data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error registering: {insert_resp.error.message}")
    user_id = insert_resp.data[0]["user_id"]

    # QR + Image save
    qr_code = f"TOURIST-{user_id}"
    image_path = save_upload_file(image, prefix=f"tourist_{user_id}")

    meta_resp = supabaseAdmin.table("tourist_meta").insert({
        "user_id": user_id,
        "qr_code": qr_code,
        "image_path": image_path
    }).execute()
    if hasattr(meta_resp, 'error'):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error saving meta: {meta_resp.error.message}")

    # Generate visitor card and send email in background
    start = str(event_data.get("start_date", ""))[:10]
    end = str(event_data.get("end_date", ""))[:10]
    valid_dates = f"{start} to {end}"
    
    # Generate card synchronously (fast enough with optimization)
    card_public_url = None
    try:
        generator = VisitorCardGenerator()
        card_data = {
            "name": registration.name,
            "email": registration.email or "",
            "profile_image_path": image_path,
            "qr_data": qr_code,
            "valid_dates": valid_dates,
        }
        card_path = generator.create_visitor_card(card_data)
        
        # Generate JWT token for secure access (30 days validity)
        jwt_token = generate_visitor_card_token(card_path, expires_in=86400 * 30)
        card_public_url = f"/tourists/visitor-card/{jwt_token}"

        # Background email send
        if registration.email and background_tasks:
            send_welcome_email_background(
                background_tasks=background_tasks,
                user_email=registration.email,
                user_name=registration.name,
                visitor_card_path=card_path,
                event_name=event_data.get("name", "Event"),
                valid_dates=valid_dates,
                extra_info={"user_id": user_id, "qr_code": qr_code},
            )
    except Exception as e:
        print(f"Error generating visitor card: {e}")
        import traceback
        traceback.print_exc()
        card_public_url = None
    
    print({
        "message": "Tourist registered successfully",
        "tourist": insert_resp.data[0],
        "meta": meta_resp.data[0] if meta_resp.data else None,
        "visitor_card_url": card_public_url,
    })

    return {
        "message": "Tourist registered successfully",
        "tourist": insert_resp.data[0],
        "meta": meta_resp.data[0] if meta_resp.data else None,
        "visitor_card_url": card_public_url,
    }

# ------------------------------------------------------------
# GET ALL TOURISTS (Admin only, Paginated)
# ------------------------------------------------------------
@router.get("/", status_code=status.HTTP_200_OK)
async def get_all_tourists(
    limit: int = 20,
    offset: int = 0,
    user=Depends(jwt_middleware)
):
    """
    Get all tourists with today's entry status
    Includes active status to show on UI
    """
    from datetime import date
    today = str(date.today())
    
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view tourists.",
        )

    resp = (
        supabaseAdmin.table("tourists")
        .select("*")
        .range(offset, offset + limit - 1)
        .order("user_id", desc=True)
        .execute()
    )
    if hasattr(resp, "error") and resp.error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error fetching tourists: {resp.error.message}",
        )

    tourist_ids = [t["user_id"] for t in resp.data]
    
    if tourist_ids:
        # Fetch TODAY's entry records
        entries_resp = (
            supabaseAdmin.table("entry_records")
            .select("*")
            .in_("user_id", tourist_ids)
            .eq("entry_date", today)
            .execute()
        )
        
        entry_records_map = {}
        if hasattr(entries_resp, 'data') and entries_resp.data:
            for record in entries_resp.data:
                entry_records_map[record["user_id"]] = record
        
        # Fetch entry_items for today's records
        record_ids = [r["record_id"] for r in entry_records_map.values()]
        entry_items_map = {}
        
        if record_ids:
            items_resp = (
                supabaseAdmin.table("entry_items")
                .select("*")
                .in_("record_id", record_ids)
                .order("arrival_time", desc=True)
                .execute()
            )
            
            if hasattr(items_resp, 'data') and items_resp.data:
                for item in items_resp.data:
                    record_id = item["record_id"]
                    if record_id not in entry_items_map:
                        entry_items_map[record_id] = []
                    entry_items_map[record_id].append(item)
        
        # Enrich tourist data with today's entry info
        for tourist in resp.data:
            user_id = tourist["user_id"]
            entry_record = entry_records_map.get(user_id)
            
            if entry_record:
                record_id = entry_record["record_id"]
                entry_items = entry_items_map.get(record_id, [])
                open_entries = [item for item in entry_items if item.get("departure_time") is None]
                
                tourist["today_entry"] = {
                    "has_entry_today": True,
                    "is_currently_inside": len(open_entries) > 0,
                    "total_entries_today": len(entry_items),
                    "open_entries": len(open_entries)
                }
            else:
                tourist["today_entry"] = {
                    "has_entry_today": False,
                    "is_currently_inside": False,
                    "total_entries_today": 0,
                    "open_entries": 0
                }

    # Get total count for pagination info
    total_resp = supabaseAdmin.rpc("count_tourists").execute() if hasattr(supabaseAdmin, "rpc") else None
    total_count = total_resp.data if total_resp and not hasattr(total_resp, "error") else None

    return {
        "tourists": resp.data,
        "pagination": {
            "limit": limit,
            "offset": offset,
            "count": len(resp.data),
            "total": total_count
        }
    }


# ------------------------------------------------------------
# GET TOURISTS BY EVENT (Admin or Allowed Guard, Paginated)
# ------------------------------------------------------------
@router.get("/event/{event_id}", status_code=status.HTTP_200_OK)
async def get_tourists_by_event(
    event_id: int,
    limit: int = 20,
    offset: int = 0,
    user=Depends(check_guard_admin_access)
):
    """
    Fetch tourists for an event with their entry status
    Returns clear separation between:
    - Total tourist registrations (records) vs Total members (actual people)
    - Groups vs Individuals
    - Currently inside (both registration count and people count)
    """
    from datetime import date
    today = str(date.today())
    
    # Fetch tourists for the event
    resp = (
        supabaseAdmin.table("tourists")
        .select("*")
        .eq("registered_event_id", event_id)
        .range(offset, offset + limit - 1)
        .order("user_id", desc=True)
        .execute()
    )
    if hasattr(resp, 'error') and resp.error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error fetching tourists: {resp.error.message}",
        )

    tourist_ids = [t["user_id"] for t in resp.data]
    
    # Get total counts for ALL tourists in this event (not just current page)
    all_tourists_resp = (
        supabaseAdmin.table("tourists")
        .select("user_id, is_group, group_count")
        .eq("registered_event_id", event_id)
        .execute()
    )
    
    # Calculate total statistics
    total_tourist_registrations = len(all_tourists_resp.data) if all_tourists_resp.data else 0
    total_group_registrations = sum(1 for t in all_tourists_resp.data if t.get("is_group", False)) if all_tourists_resp.data else 0
    total_individual_registrations = total_tourist_registrations - total_group_registrations
    
    # Calculate total members (actual people count)
    # For groups: use group_count, for individuals: count as 1
    total_members = 0
    if all_tourists_resp.data:
        for tourist in all_tourists_resp.data:
            if tourist.get("is_group", False):
                total_members += tourist.get("group_count", 1)
            else:
                total_members += 1
    
    if not tourist_ids:
        return {
            "tourists": [],
            "statistics": {
                "total_tourist_registrations": total_tourist_registrations,
                "total_individual_registrations": total_individual_registrations,
                "total_group_registrations": total_group_registrations,
                "total_members": total_members,
                "currently_inside_registrations": 0,
                "currently_inside_members": 0,
                "with_entry_today_registrations": 0,
                "with_entry_today_members": 0
            },
            "pagination": {
                "limit": limit,
                "offset": offset,
                "count": 0,
                "total": total_tourist_registrations
            }
        }

    # Fetch TODAY's entry records for these tourists
    entries_resp = (
        supabaseAdmin.table("entry_records")
        .select("*")
        .in_("user_id", tourist_ids)
        .eq("event_id", event_id)
        .eq("entry_date", today)
        .execute()
    )
    
    entry_records_map = {}
    if hasattr(entries_resp, 'data') and entries_resp.data:
        for record in entries_resp.data:
            entry_records_map[record["user_id"]] = record
    
    # Fetch entry_items for today's records
    record_ids = [r["record_id"] for r in entry_records_map.values()]
    entry_items_map = {}
    
    if record_ids:
        items_resp = (
            supabaseAdmin.table("entry_items")
            .select("*")
            .in_("record_id", record_ids)
            .order("arrival_time", desc=True)
            .execute()
        )
        
        if hasattr(items_resp, 'data') and items_resp.data:
            for item in items_resp.data:
                record_id = item["record_id"]
                if record_id not in entry_items_map:
                    entry_items_map[record_id] = []
                entry_items_map[record_id].append(item)
    
    # Calculate statistics for currently inside and with entry today
    currently_inside_registrations = 0
    currently_inside_members = 0
    with_entry_today_registrations = 0
    with_entry_today_members = 0
    
    # Enrich tourist data with entry information
    for tourist in resp.data:
        user_id = tourist["user_id"]
        entry_record = entry_records_map.get(user_id)
        
        is_group = tourist.get("is_group", False)
        member_count = tourist.get("group_count", 1) if is_group else 1
        
        if entry_record:
            record_id = entry_record["record_id"]
            entry_items = entry_items_map.get(record_id, [])
            
            # Calculate active status (has entry without departure today)
            open_entries = [item for item in entry_items if item.get("departure_time") is None]
            is_currently_inside = len(open_entries) > 0
            
            # Update statistics
            with_entry_today_registrations += 1
            with_entry_today_members += member_count
            
            if is_currently_inside:
                currently_inside_registrations += 1
                currently_inside_members += member_count
            
            tourist["today_entry"] = {
                "has_entry_today": True,
                "is_currently_inside": is_currently_inside,
                "entry_record": entry_record,
                "entry_items": entry_items,
                "total_entries_today": len(entry_items),
                "open_entries": len(open_entries),
                "last_entry": entry_items[0] if entry_items else None
            }
        else:
            tourist["today_entry"] = {
                "has_entry_today": False,
                "is_currently_inside": False,
                "entry_record": None,
                "entry_items": [],
                "total_entries_today": 0,
                "open_entries": 0,
                "last_entry": None
            }

    response_data  ={
        "tourists": resp.data,
        "statistics": {
            # Total registrations (database records)
            "total_tourist_registrations": total_tourist_registrations,
            "total_individual_registrations": total_individual_registrations,
            "total_group_registrations": total_group_registrations,
            
            # Total members (actual people count)
            "total_members": total_members,
            
            # Currently inside (from current page data)
            "currently_inside_registrations": currently_inside_registrations,
            "currently_inside_members": currently_inside_members,
            
            # With entry today (from current page data)
            "with_entry_today_registrations": with_entry_today_registrations,
            "with_entry_today_members": with_entry_today_members
        },
        "pagination": {
            "limit": limit,
            "offset": offset,
            "count": len(resp.data),
            "total": total_tourist_registrations
        }
    }
    print(response_data)
    return response_data

# ------------------------------------------------------------
# GET SINGLE TOURIST (Admin or Guard)
# ------------------------------------------------------------
@router.get("/{user_id}", status_code=status.HTTP_200_OK)
async def get_tourist(user_id: int, user=Depends(jwt_middleware)):
    """
    Get single tourist with complete entry history and today's status
    """
    from datetime import date
    today = str(date.today())
    
    if user.get("role") not in ["admin", "security"]:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not allowed")

    tourist_resp = supabaseAdmin.table("tourists").select("*").eq("user_id", user_id).single().execute()
    if hasattr(tourist_resp, 'error') and tourist_resp.error:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error fetching tourist: {tourist_resp.error.message}")

    tourist_event_id = tourist_resp.data['registered_event_id']
    # check guard has allowed to seee or not 
    event_resp =supabaseAdmin.table("events").select("*").eq("event_id", tourist_event_id).single().execute()
    if hasattr(event_resp,'error'):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Event not found")
    allowed_guards = event_resp.data.get("allowed_guards") or []

    uid = user.get('uid') or user.get('sub')
    print(uid);
    print(allowed_guards);
    if allowed_guards != []:
        if (user['role'] == "security" and uid not in allowed_guards) :
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not authorized to access this event.",
            )
    meta_resp = supabaseAdmin.table("tourist_meta").select("*").eq("user_id", user_id).execute()
    
    # Get all entry records
    entries_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).order("entry_date", desc=True).execute()
    
    # Get today's entry record specifically
    today_entry_resp = supabaseAdmin.table("entry_records").select("*").eq("user_id", user_id).eq("entry_date", today).execute()
    
    today_entry_data = None
    if hasattr(today_entry_resp, 'data') and today_entry_resp.data:
        today_record = today_entry_resp.data[0]
        record_id = today_record["record_id"]
        
        # Get entry_items for today
        items_resp = supabaseAdmin.table("entry_items").select("*").eq("record_id", record_id).order("arrival_time", desc=True).execute()
        
        entry_items = items_resp.data if hasattr(items_resp, 'data') else []
        open_entries = [item for item in entry_items if item.get("departure_time") is None]
        
        today_entry_data = {
            "has_entry_today": True,
            "is_currently_inside": len(open_entries) > 0,
            "entry_record": today_record,
            "entry_items": entry_items,
            "total_entries_today": len(entry_items),
            "open_entries": len(open_entries),
            "last_entry": entry_items[0] if entry_items else None
        }
    else:
        today_entry_data = {
            "has_entry_today": False,
            "is_currently_inside": False,
            "entry_record": None,
            "entry_items": [],
            "total_entries_today": 0,
            "open_entries": 0,
            "last_entry": None
        }

    data = {
        "user": tourist_resp.data,
        "meta": meta_resp.data[0] if meta_resp.data else None,
        "all_entry_records": entries_resp.data if entries_resp.data else [],
        "today_entry": today_entry_data
    }

    # Add secure image URL with JWT token
    if data["meta"] and data["meta"].get("image_path"):
        image_path = data["meta"]["image_path"]
        
        # Generate JWT token for secure image access (30 days validity)
        image_token = generate_user_image_token(image_path, user_id, expires_in=86400 * 30)
        
        # Add both the JWT-protected URL and legacy public URL (for backward compatibility)
        data["image_token"] = image_token
        
    
    print(f"Image tokens is : {image_token}")
    
    print(data)
    return {"tourist": data}

# ------------------------------------------------------------
# GET USER IMAGE WITH JWT TOKEN (Public Access)
# ------------------------------------------------------------
@router.get("/user-image/{token}", status_code=status.HTTP_200_OK)
async def get_user_image(token: str):
    """
    Serve user image using JWT token for security
    URL format: /tourists/user-image/{jwt_token}
    """
    try:
        # Decode and verify JWT token
        payload = verify_file_token(token, expected_type="user_image")
        
        # Get file path from payload
        file_path = payload.get("file_path")
        if not file_path:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token payload")
        
        # Security check: Ensure file is within allowed directories
        allowed_dirs = [
            "static/uploads",
            "static/images"
        ]
        
        if not validate_file_path_security(file_path, allowed_dirs):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Access to this file is not allowed")
        
        # Check if file exists
        if not os.path.exists(file_path):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User image not found")
        
        # Determine media type based on file extension
        file_ext = os.path.splitext(file_path)[1].lower()
        media_types = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp'
        }
        media_type = media_types.get(file_ext, 'image/jpeg')
        
        # Return the file
        return FileResponse(
            file_path,
            media_type=media_type,
            headers={
                "Cache-Control": "public, max-age=3600",
                "Access-Control-Allow-Origin": "*"
            }
        )
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid token")
    except ValueError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except Exception as e:
        print(f"Error serving user image: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to retrieve user image")


# ------------------------------------------------------------
# GET USER IMAGE TOKEN BY USER ID (Admin/Security)
# ------------------------------------------------------------
@router.get("/{user_id}/image-token", status_code=status.HTTP_200_OK)
async def get_user_image_token(
    user_id: int,
    user=Depends(jwt_middleware)
):
    """
    Generate a JWT token for accessing a user's image
    URL format: /tourists/{user_id}/image-token
    Returns a token that can be used with /tourists/user-image/{token}
    """
    try:
        # Fetch tourist meta to get image path
        meta_resp = supabaseAdmin.table("tourist_meta").select("image_path").eq("user_id", user_id).execute()
        
        if not meta_resp.data or len(meta_resp.data) == 0:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User image not found")
        
        image_path = meta_resp.data[0].get("image_path")
        if not image_path:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User image path is missing")
        
        # Check if file exists
        if not os.path.exists(image_path):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User image file does not exist")
        
        # Generate JWT token for the image
        token = generate_user_image_token(image_path, user_id, expires_in=86400 * 30)
        
        return {
            "user_id": user_id,
            "image_token": token,
            "image_url": f"/tourists/user-image/{token}"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error generating user image token: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to generate image token")


# ------------------------------------------------------------
# SERVE VISITOR CARD WITH JWT TOKEN (Public Access)
# ------------------------------------------------------------
@router.get("/visitor-card/{token}", status_code=status.HTTP_200_OK)
async def get_visitor_card(token: str):
    """
    Serve visitor card using JWT token for security
    URL format: /tourists/visitor-card/{jwt_token}
    """
    try:
        # Decode and verify JWT token
        payload = verify_file_token(token, expected_type="visitor_card")
        
        # Get file path from payload
        file_path = payload.get("file_path")
        if not file_path:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token payload")
        
        # Security check: Ensure file is within allowed directories
        allowed_dirs = [
            "static/cards",
            "static/uploads"
        ]
        
        if not validate_file_path_security(file_path, allowed_dirs):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Access to this file is not allowed")
        
        # Check if file exists
        if not os.path.exists(file_path):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Visitor card not found")
        
        # Return the file
        return FileResponse(
            file_path,
            media_type="image/png",
            headers={
                "Cache-Control": "public, max-age=3600",
                "Access-Control-Allow-Origin": "*"
            }
        )
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid token")
    except ValueError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except Exception as e:
        print(f"Error serving visitor card: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to retrieve visitor card")

# ------------------------------------------------------------
# DOWNLOAD VISITOR CARD WITH JWT TOKEN (Public Access)
# ------------------------------------------------------------
@router.get("/download-visitor-card/{token}", status_code=status.HTTP_200_OK)
async def download_visitor_card(token: str):
    """
    Download visitor card using JWT token
    URL format: /tourists/download-visitor-card/{jwt_token}
    Adds Content-Disposition header to force download
    """
    try:
        # Decode and verify JWT token
        payload = verify_file_token(token, expected_type="visitor_card")
        
        # Get file path from payload
        file_path = payload.get("file_path")
        if not file_path:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token payload")
        
        # Security check: Ensure file is within allowed directories
        allowed_dirs = [
            "static/cards",
            "static/uploads"
        ]
        
        if not validate_file_path_security(file_path, allowed_dirs):
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Access to this file is not allowed")
        
        # Check if file exists
        if not os.path.exists(file_path):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Visitor card not found")
        
        # Return the file with download header
        return FileResponse(
            file_path,
            media_type="image/png",
            headers={
                "Content-Disposition": f"attachment; filename={os.path.basename(file_path)}",
                "Access-Control-Allow-Origin": "*"
            }
        )
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid token")
    except ValueError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except Exception as e:
        print(f"Error downloading visitor card: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to download visitor card")
