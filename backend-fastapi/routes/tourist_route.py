from fastapi import (
    APIRouter, BackgroundTasks, Depends, HTTPException, status, UploadFile, Query
)
from fastapi.responses import FileResponse, StreamingResponse, RedirectResponse
from utils.supabase.auth import jwt_middleware, check_guard_admin_access
from utils.supabase.supabase import supabaseAdmin
from utils.models.api_models import Tourist
from fastapi import Form
from utils.services.public_access_link_provider import generate_public_access_link, verify_public_access_link
from utils.services.file_handlers import save_upload_file
from template_generator import VisitorCardGenerator, VisitorCardGenerator3
from utils.services.email_handler import send_welcome_email_background
from utils.services.sms_handler import send_welcome_sms_background
from utils.services.jwt_file_token import (
    generate_card_token,
    generate_user_image_token,
    verify_file_token,
    validate_file_path_security
)
from datetime import datetime

from io import BytesIO
from utils.services.card_cache import TEMP_CARD_DIR, touch_card, is_card_fresh
import jwt
import os
from utils.services.public_access_link_provider import short_url_generator

router = APIRouter()

# ------------------------------------------------------------
# REGISTER TOURIST (Public access)
# ------------------------------------------------------------
@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register_tourist(
    name: str = Form(...),
    phone: str = Form(...),
    unique_id_type: str = Form(None),
    unique_id: str = Form(None),
    is_group: bool = Form(...),
    group_count: int = Form(...),
    registered_event_id: int = Form(...),
    valid_date: str = Form(...),
    image: UploadFile = None,
    unique_id_photo: UploadFile = None,
    background_tasks: BackgroundTasks = None,
):
    print("Valid date : ", valid_date)

    # Parse valid_date
    if valid_date:
        try:
            valid_date = datetime.strptime(valid_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid date format for valid_date. Use YYYY-MM-DD.")
    else:
        valid_date = datetime.strptime("2026-02-27", "%Y-%m-%d").date()

    # Require image and phone
    if not image:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Profile image is required")
    if not phone:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Phone number is required")

    # ── ID validation: old (text) vs new (photo) ──────────────────────────────
    has_text_id = unique_id_type and unique_id and unique_id_type.strip() and unique_id.strip()
    has_photo_id = unique_id_photo is not None

    if not has_text_id and not has_photo_id:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Either provide unique_id_type + unique_id (text) OR upload a unique_id_photo"
        )

    # Build registration object
    registration = Tourist(
        name=name,
        phone=phone,
        unique_id_type=unique_id_type.strip() if has_text_id else None,
        unique_id=unique_id.strip() if has_text_id else None,
        is_group=is_group,
        group_count=group_count,
        registered_event_id=registered_event_id,
        valid_date=valid_date
    )

    if not registration.name:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Name is required")

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
    if not event_resp.data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or inactive event")
    event_data = event_resp.data[0]

    # Insert tourist
    try:
        reg_dict = registration.dict(exclude={"user_id"})  # Exclude auto-generated user_id
        if isinstance(reg_dict.get("valid_date"), datetime):
            reg_dict["valid_date"] = reg_dict["valid_date"].strftime("%Y-%m-%d")
        elif hasattr(reg_dict.get("valid_date"), "isoformat"):
            reg_dict["valid_date"] = reg_dict["valid_date"].isoformat()

        insert_resp = supabaseAdmin.table("tourists").insert(reg_dict).execute()
        if not insert_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error registering tourist")
        user_id = insert_resp.data[0]["user_id"]

        # Save profile image
        image_path = save_upload_file(image, prefix=f"tourist_{user_id}")

        # Save unique ID photo (if provided via photo route)
        unique_id_path = None
        if has_photo_id:
            unique_id_path = save_upload_file(unique_id_photo, prefix=f"uid_{user_id}", is_id=True)

        # Generate QR short code
        code = short_url_generator()

        # Save meta (profile image + QR + optional ID photo path)
        meta_resp = supabaseAdmin.table("tourist_meta").insert({
            "user_id": user_id,
            "qr_code": code,
            "image_path": image_path,
            "unique_id_path": unique_id_path,
        }).execute()
        if not meta_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error saving meta")

        # Generate visitor card token & short link
        card_temp_path = f"{TEMP_CARD_DIR}/card_temp_{user_id}.png"
        card_public_url = None
        try:
            visitor_card_token = generate_card_token(
                user_id=user_id,
                user_name=registration.name,
                event_name=event_data.get("name", ""),
                valid_dates=str(valid_date),
                card_temp_path=card_temp_path,
            )
            supabaseAdmin.table("short_links").insert({
                "short_code": code,
                "token": visitor_card_token
            }).execute()
            card_public_url = f"/tourists/visitor-card/{visitor_card_token}"

            # if phone and background_tasks:
            #     send_welcome_sms_background(
            #         background_tasks=background_tasks,
            #         to=phone,
            #         event_name="वसंतोत्सव 2026",
            #         e_id=str(code),
            #         valid_date=str(valid_date),
            #         short_code=code
            #     )
        except Exception as e:
            print(f"Error generating visitor card token: {e}")
            card_public_url = None

        return {
            "message": "Tourist registered successfully",
            "tourist": insert_resp.data[0],
            "meta": meta_resp.data[0] if meta_resp.data else None,
            "visitor_card_url": card_public_url,
            "id_verification_mode": "text" if has_text_id else "photo",
            "sms_sent": phone is not None,
        }

    except Exception as e:
        err_text = str(e)
        if "duplicate key value violates unique constraint" in err_text or "23505" in err_text or "already exists" in err_text:
            try:
                import re
                m = re.search(r"Key \((?P<field>[^)]+)\)=\((?P<value>[^)]+)\)", err_text)
                if m:
                    field = m.group("field")
                    value = m.group("value")
                    friendly = f"{field.replace('_', ' ').capitalize()} '{value}' already registered"
                else:
                    m2 = re.search(r'constraint "(?P<constraint>[^"]+)"', err_text)
                    if m2:
                        constraint = m2.group("constraint")
                        friendly = "Phone number already registered for this date" if "phone" in constraint else "Duplicate value already exists"
                    else:
                        friendly = "Duplicate value already exists"
            except Exception:
                friendly = "Duplicate value already exists"
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error registering tourist: {friendly}")

        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error registering tourist: {err_text}")

# ────────────────────────────────────────────────────────────────────────────
# Quick card renewal endpoints are in quick_route.py:
# - POST /quick/renew-by-shortcode (fastest renewal)
# - POST /quick/renew-by-phone (alternative renewal)
# ────────────────────────────────────────────────────────────────────────────

# ------------------------------------------------------------
# GET ALL TOURISTS (Admin only, Paginated)
# ------------------------------------------------------------
@router.get("/", status_code=status.HTTP_200_OK)
async def get_all_tourists(
    limit: int = 20,
    offset: int = 0,
    date_filter: str = Query(None, alias="date", description="Filter by valid_date (YYYY-MM-DD). Defaults to today."),
    user=Depends(jwt_middleware)
):
    """
    Get all tourists with today's entry status, filtered by valid_date.
    Pass ?date=YYYY-MM-DD to view a specific date's tourists.
    """
    from datetime import date
    today = str(date.today())
    filter_date = date_filter or today

    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view tourists.",
        )

    resp = (
        supabaseAdmin.table("tourists")
        .select("*")
        .eq("valid_date", filter_date)
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
    date_filter: str = Query(None, alias="date", description="Filter by valid_date (YYYY-MM-DD). Defaults to today."),
    user=Depends(check_guard_admin_access)
):
    """
    Fetch tourists for an event filtered by valid_date (defaults to today).
    Pass ?date=YYYY-MM-DD to view tourists for a specific date.

    Key behavior:
    - Only shows tourists whose valid_date matches the requested date
    - Entry status (inside/outside) is based on today's actual entry records
    - "Currently inside" means: entered TODAY and no departure recorded TODAY
    """
    from datetime import date
    today = str(date.today())
    filter_date = date_filter or today

    # Fetch tourists for the event filtered by valid_date
    resp = (
        supabaseAdmin.table("tourists")
        .select("*")
        .eq("registered_event_id", event_id)
        .eq("valid_date", filter_date)
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

    # Get total counts for tourists in this event for the filtered date
    all_tourists_resp = (
        supabaseAdmin.table("tourists")
        .select("user_id, is_group, group_count")
        .eq("registered_event_id", event_id)
        .eq("valid_date", filter_date)
        .execute()
    )
    
    # Calculate total statistics (STATIC - never changes)
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
    
    # ============================================================
    # Calculate DYNAMIC statistics (currently inside, today's entries)
    # These are calculated from ALL tourists, not just current page
    # ============================================================
    all_tourist_ids = [t["user_id"] for t in all_tourists_resp.data] if all_tourists_resp.data else []
    
    # Fetch TODAY's entry records for ALL tourists
    all_entries_today_resp = (
        supabaseAdmin.table("entry_records")
        .select("*")
        .in_("user_id", all_tourist_ids)
        .eq("event_id", event_id)
        .eq("entry_date", today)
        .execute()
    ) if all_tourist_ids else None
    
    # Map all entry records by user_id
    all_entry_records_map = {}
    if all_entries_today_resp and hasattr(all_entries_today_resp, 'data') and all_entries_today_resp.data:
        for record in all_entries_today_resp.data:
            all_entry_records_map[record["user_id"]] = record
    
    # Fetch entry_items for today's records
    all_record_ids = [r["record_id"] for r in all_entry_records_map.values()]
    all_entry_items_map = {}
    
    if all_record_ids:
        all_items_resp = (
            supabaseAdmin.table("entry_items")
            .select("*")
            .in_("record_id", all_record_ids)
            .execute()
        )
        
        if hasattr(all_items_resp, 'data') and all_items_resp.data:
            for item in all_items_resp.data:
                record_id = item["record_id"]
                if record_id not in all_entry_items_map:
                    all_entry_items_map[record_id] = []
                all_entry_items_map[record_id].append(item)
    
    # Calculate DYNAMIC statistics from ALL tourists
    currently_inside_registrations = 0
    currently_inside_members = 0
    with_entry_today_registrations = 0
    with_entry_today_members = 0
    
    for tourist in all_tourists_resp.data:
        user_id = tourist["user_id"]
        entry_record = all_entry_records_map.get(user_id)
        
        is_group = tourist.get("is_group", False)
        member_count = tourist.get("group_count", 1) if is_group else 1
        
        if entry_record:
            record_id = entry_record["record_id"]
            entry_items = all_entry_items_map.get(record_id, [])
            
            # Check if currently inside (has open entry)
            open_entries = [item for item in entry_items if item.get("departure_time") is None]
            is_currently_inside = len(open_entries) > 0
            
            # Update statistics
            with_entry_today_registrations += 1
            with_entry_today_members += member_count
            
            if is_currently_inside:
                currently_inside_registrations += 1
                currently_inside_members += member_count
    
    # ============================================================
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
                "total": total_tourist_registrations,
                "date": filter_date
            }
        }

    # ============================================================
    # NOW enrich the CURRENT PAGE tourists with today's entry info
    # Statistics are already calculated from ALL tourists above
    # ============================================================
    
    # Enrich tourist data with entry information for current page
    for tourist in resp.data:
        user_id = tourist["user_id"]
        entry_record = all_entry_records_map.get(user_id)
        
        if entry_record:
            record_id = entry_record["record_id"]
            entry_items = all_entry_items_map.get(record_id, [])
            
            # Calculate active status (has entry without departure today)
            open_entries = [item for item in entry_items if item.get("departure_time") is None]
            is_currently_inside = len(open_entries) > 0
            
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
            # STATIC - Total registrations (never changes, database records)
            "total_tourist_registrations": total_tourist_registrations,
            "total_individual_registrations": total_individual_registrations,
            "total_group_registrations": total_group_registrations,
            
            # STATIC - Total members (never changes, actual people count)
            "total_members": total_members,
            
            # DYNAMIC - Currently inside (updates based on TODAY's data only)
            "currently_inside_registrations": currently_inside_registrations,
            "currently_inside_members": currently_inside_members,
            
            # DYNAMIC - With entry today (updates based on TODAY's data only)
            "with_entry_today_registrations": with_entry_today_registrations,
            "with_entry_today_members": with_entry_today_members
        },
        "pagination": {
            "limit": limit,
            "offset": offset,
            "count": len(resp.data),
            "total": total_tourist_registrations,
            "date": filter_date
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
    Get single tourist with entry data organized by date.

    Response shape:
    {
      "tourist": {
        "user": { ...tourist row... },
        "meta": { ...tourist_meta row..., "image_token": "...", "image_url": "..." },
        "today": "2026-02-26",
        "dates": {
          "2026-02-27": {
            "has_entry": false,
            "is_currently_inside": false,
            "entry_record": null,
            "entry_items": [],
            "total_entries": 0,
            "open_entries": 0,
            "last_entry": null
          },
          "2026-02-28": { ... },
          "2026-03-01": { ... }
        }
      }
    }
    """
    from datetime import date
    today = str(date.today())

    # Event dates for the festival — all possible dates a visitor could have
    EVENT_DATES = ["2026-02-27", "2026-02-28", "2026-03-01"]

    if user.get("role") not in ["admin", "security"]:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not allowed")

    tourist_resp = supabaseAdmin.table("tourists").select("*").eq("user_id", user_id).single().execute()
    if not tourist_resp.data:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Tourist {user_id} not found")

    tourist_event_id = tourist_resp.data["registered_event_id"]

    # Security guard access check
    event_resp = supabaseAdmin.table("events").select("allowed_guards").eq("event_id", tourist_event_id).single().execute()
    if not event_resp.data:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")

    allowed_guards = event_resp.data.get("allowed_guards") or []
    uid = user.get("uid") or user.get("sub")
    if allowed_guards:
        if user["role"] == "security" and uid not in allowed_guards:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not authorized to access this event.",
            )

    # Fetch meta
    meta_resp = supabaseAdmin.table("tourist_meta").select("*").eq("user_id", user_id).execute()
    meta = meta_resp.data[0] if meta_resp.data else None

    # Add secure image token to meta
    image_token = None
    if meta and meta.get("image_path"):
        image_path = meta["image_path"]
        if os.path.exists(image_path):
            image_token = generate_user_image_token(image_path, user_id, expires_in=86400 * 30)
            meta["image_token"] = image_token
            meta["image_url"] = f"/tourists/user-image/{image_token}"

    # Fetch ALL entry records for this user across all dates in one query
    all_records_resp = (
        supabaseAdmin.table("entry_records")
        .select("*")
        .eq("user_id", user_id)
        .in_("entry_date", EVENT_DATES)
        .order("entry_date", desc=False)
        .execute()
    )
    all_records = all_records_resp.data or []

    # Build a map: entry_date -> record
    records_by_date = {r["entry_date"]: r for r in all_records}

    # Fetch ALL entry_items for all those records in one query
    record_ids = [r["record_id"] for r in all_records]
    items_by_record = {}
    if record_ids:
        all_items_resp = (
            supabaseAdmin.table("entry_items")
            .select("*")
            .in_("record_id", record_ids)
            .order("arrival_time", desc=False)
            .execute()
        )
        for item in (all_items_resp.data or []):
            rid = item["record_id"]
            items_by_record.setdefault(rid, []).append(item)

    # Build date-keyed response
    dates_data = {}
    for d in EVENT_DATES:
        record = records_by_date.get(d)
        if record:
            items = items_by_record.get(record["record_id"], [])
            open_entries = [i for i in items if i.get("departure_time") is None]
            dates_data[d] = {
                "has_entry": True,
                "is_currently_inside": len(open_entries) > 0,
                "entry_record": record,
                "entry_items": items,
                "total_entries": len(items),
                "open_entries": len(open_entries),
                "last_entry": items[-1] if items else None
            }
        else:
            dates_data[d] = {
                "has_entry": False,
                "is_currently_inside": False,
                "entry_record": None,
                "entry_items": [],
                "total_entries": 0,
                "open_entries": 0,
                "last_entry": None
            }

    return {
        "tourist": {
            "user": tourist_resp.data,
            "meta": meta,
            "today": today,
            "dates": dates_data
        }
    }

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


# ─── Card cache helper ───────────────────────────────────────────────────────
async def _get_or_generate_card_path(user_id: int, card_temp_path: str, valid_date : str) -> str:
    """
    Return a valid path to the visitor card PNG, using a file cache under static/temp-card/.

    Cache HIT  (file on disk + Redis says it's fresh):
        → update last-access timestamp in Redis → return existing file path.

    Cache MISS (file absent or Redis says it's stale):
        → query tourists / tourist_meta / events
        → generate PNG with VisitorCardGenerator.generate_card_in_memory()
        → write to card_temp_path (deterministic per user_id)
        → stamp Redis timestamp → return path.

    Multiple simultaneous requests for the same user_id are fine because:
        - writing a completed PNG over the same path is an atomic OS rename on Linux;
        - even if two workers race, the second write just overwrites an identical file.
    """
    os.makedirs(TEMP_CARD_DIR, exist_ok=True)

    # ── Cache hit ──────────────────────────────────────────────────────────
    if os.path.exists(card_temp_path) and is_card_fresh(user_id):
        touch_card(user_id)
        return card_temp_path

    # ── Cache miss — fetch from DB and render ──────────────────────────────
    tourist_resp = supabaseAdmin.table("tourists").select("*").eq("user_id", user_id).single().execute()
    if not tourist_resp.data:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tourist not found")
    tourist = tourist_resp.data

    meta_resp = supabaseAdmin.table("tourist_meta").select("image_path, qr_code").eq("user_id", user_id).execute()
    meta = meta_resp.data[0] if meta_resp.data else {}

    event_id = tourist.get("registered_event_id")
    event_resp = supabaseAdmin.table("events").select("name, start_date, end_date").eq("event_id", event_id).single().execute()
    event = event_resp.data or {}


    card_data = {
        "name":               tourist.get("name", ""),
        "phone":              tourist.get("phone", ""),
        "profile_image_path": meta.get("image_path"),
        "qr_data":            meta.get("qr_code") or f"TOURIST-{user_id}",
        "valid_date":         valid_date,
        "group_count":         tourist.get("group_count", 1),
    }

    generator = VisitorCardGenerator3()
    card_bytes = generator.generate_card_in_memory(card_data)

    # Write to a tmp file first, then rename — prevents half-written files being served
    tmp_path = card_temp_path + ".tmp"
    with open(tmp_path, "wb") as f:
        f.write(card_bytes.read())
    os.replace(tmp_path, card_temp_path)  # atomic on Linux

    touch_card(user_id)
    return card_temp_path


# ------------------------------------------------------------
# SHORT URL RESOLVE — Get card URLs from short code
# ------------------------------------------------------------
@router.get("/short/{short_code}", status_code=status.HTTP_200_OK)
async def resolve_short_url(short_code: str):
    """
    Resolve a short code to get visitor card URLs.
    Frontend gets both preview and download URLs, then decides what to do.
    
    Response:
    {
      "short_code": "a7b2c9",
      "user_id": 34,
      "card_urls": {
        "preview": "/tourists/visitor-card/{token}",
        "download": "/tourists/visitor-card/{token}?download=true"
      },
      "token": "eyJhbGc..."
    }
    
    Frontend can then:
    - Open in browser: window.open(response.card_urls.preview)
    - Download: window.open(response.card_urls.download)
    - Or navigate: window.location.href = response.card_urls.preview
    """
    try:
        # Query short_links table for the code
        short_link_resp = (
            supabaseAdmin.table("short_links")
            .select("short_code, token")
            .eq("short_code", short_code)
            .single()
            .execute()
        )
        
        if not short_link_resp.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Short link not found"
            )
        
        short_link = short_link_resp.data
        token = short_link.get("token")
        
        if not token:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Invalid short link: missing token"
            )
        
        # Verify token is still valid and extract payload fields
        try:
            payload = verify_file_token(token, expected_type="visitor_card")
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_410_GONE,
                detail="Short link has expired"
            )
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Invalid token in short link"
            )
        
        # user_id, user_name, valid_date etc. all live inside the JWT payload
        user_id       = payload.get("user_id")
        user_name     = payload.get("user_name", "")
        valid_date    = payload.get("valid_date", "")
        event_name    = payload.get("event_name", "")

        # Return both URLs so frontend can decide what to do
        return {
            "success": True,
            "short_code": short_code,
            "user_id": user_id,
            "user_name": user_name,
            "valid_date": valid_date,
            "event_name": event_name,
            "card_urls": {
                "preview": f"/tourists/visitor-card/{token}",
                "download": f"/tourists/visitor-card/{token}?download=true"
            },
            "token": token,
            "created_at": short_link.get("created_at")
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error resolving short URL: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to resolve short link"
        )


# ------------------------------------------------------------
# VISITOR CARD — temp-card file cache (Public Access)
# Serve inline (view) by default, or download as attachment
# ------------------------------------------------------------
@router.get("/visitor-card/{token}", status_code=status.HTTP_200_OK)
async def visitor_card(token: str, download: bool = Query(False, description="If true, download as attachment; else view inline")):
    """
    Serve or download the visitor card PNG.
    
    Query Parameters:
    - download: bool (default: False)
        - False → serve inline with Cache-Control headers (view mode)
        - True → serve as attachment with Content-Disposition header (download mode)
    
    Cache behavior:
    - First request → generated fresh from DB and cached in static/temp-card/
    - Subsequent requests within TTL → served from disk (no DB hit)
    - Cache is refreshed by touching the Redis last-access key on every hit
    """
    try:
        payload = verify_file_token(token, expected_type="visitor_card")
        user_id = payload.get("user_id")
        valid_date = payload.get("valid_date", "")
        print("Visitor card token payload:", payload)
        if not user_id:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token: missing user_id")

        # card_temp_path is baked into the token; fall back to default if old token
        card_temp_path = payload.get("card_temp_path") or f"{TEMP_CARD_DIR}/card_temp_{user_id}.png"
        path = await _get_or_generate_card_path(int(user_id), card_temp_path, valid_date=valid_date)
        tourist_name = payload.get("user_name", f"tourist_{user_id}").replace(" ", "_")

        # Build headers based on download flag
        headers = {"Access-Control-Allow-Origin": "*"}
        
        if download:
            headers["Content-Disposition"] = f"attachment; filename=visitor_card_{tourist_name}.png"
        else:
            headers["Cache-Control"] = "public, max-age=300"

        return FileResponse(
            path,
            media_type="image/png",
            headers=headers,
        )

    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid token")
    except ValueError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error serving visitor card: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to generate visitor card")


# ------------------------------------------------------------
# GET ENTRY DATE RANGE FOR AN EVENT
# ------------------------------------------------------------
@router.get("/event/{event_id}/entry-date-range", status_code=status.HTTP_200_OK)
async def get_event_entry_date_range(
    event_id: int,
    user=Depends(check_guard_admin_access)
):
    """
    Get the date range (first entry to last entry) for an event.
    Useful for showing available date range before downloading data.
    """
    try:
        # Get the earliest and latest entry dates for this event
        entry_records_resp = (
            supabaseAdmin.table("entry_records")
            .select("entry_date")
            .eq("event_id", event_id)
            .order("entry_date", desc=False)
            .limit(1)
            .execute()
        )
        
        latest_records_resp = (
            supabaseAdmin.table("entry_records")
            .select("entry_date")
            .eq("event_id", event_id)
            .order("entry_date", desc=True)
            .limit(1)
            .execute()
        )
        
        first_entry_date = None
        last_entry_date = None
        
        if entry_records_resp.data and len(entry_records_resp.data) > 0:
            first_entry_date = entry_records_resp.data[0]["entry_date"]
            
        if latest_records_resp.data and len(latest_records_resp.data) > 0:
            last_entry_date = latest_records_resp.data[0]["entry_date"]
        
        # Get event details
        event_resp = supabaseAdmin.table("events").select("name, start_date, end_date").eq("event_id", event_id).single().execute()
        
        if hasattr(event_resp, 'error'):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
        
        return {
            "success": True,
            "event": {
                "event_id": event_id,
                "name": event_resp.data.get("name"),
                "event_start_date": str(event_resp.data.get("start_date", ""))[:10],
                "event_end_date": str(event_resp.data.get("end_date", ""))[:10]
            },
            "entry_date_range": {
                "first_entry_date": first_entry_date,
                "last_entry_date": last_entry_date,
                "has_entries": first_entry_date is not None
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting entry date range: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get entry date range: {str(e)}"
        )


# ------------------------------------------------------------
# DOWNLOAD ENTRY DATA FOR DATE RANGE (CSV)
# ------------------------------------------------------------
@router.get("/event/{event_id}/download-entries", status_code=status.HTTP_200_OK)
async def download_event_entries(
    event_id: int,
    from_date: str = Query(..., description="Start date (YYYY-MM-DD format)"),
    to_date: str = Query(..., description="End date (YYYY-MM-DD format)"),
    user=Depends(check_guard_admin_access)
):
    """
    Download all entry records for an event within a specific date range.
    
    Returns a CSV file with the following columns:
    - Entry Date
    - Tourist Name
    - Email
    - Unique ID Type
    - Unique ID
    - Is Group
    - Group Count
    - Arrival Time
    - Departure Time
    - Duration
    - Entry Type
    - Entry Point
    - Status (Inside/Exited)
    
    Query Parameters:
    - from_date: Start date in YYYY-MM-DD format
    - to_date: End date in YYYY-MM-DD format
    """
    try:
        from datetime import datetime
        import csv
        import io
        from fastapi.responses import StreamingResponse
        
        # Validate dates
        try:
            from_date_obj = datetime.strptime(from_date, "%Y-%m-%d").date()
            to_date_obj = datetime.strptime(to_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD format."
            )
        
        if from_date_obj > to_date_obj:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="from_date cannot be after to_date"
            )
        
        # Get event details
        event_resp = supabaseAdmin.table("events").select("name").eq("event_id", event_id).single().execute()
        if hasattr(event_resp, 'error'):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
        
        event_name = event_resp.data.get("name", f"Event_{event_id}")
        
        # Fetch all entry records within the date range
        entry_records_resp = (
            supabaseAdmin.table("entry_records")
            .select("*")
            .eq("event_id", event_id)
            .gte("entry_date", from_date)
            .lte("entry_date", to_date)
            .order("entry_date", desc=False)
            .execute()
        )
        
        if not entry_records_resp.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No entry records found for the specified date range"
            )
        
        # Get all user IDs
        user_ids = list(set([record["user_id"] for record in entry_records_resp.data]))
        
        # Fetch tourist details
        tourists_resp = (
            supabaseAdmin.table("tourists")
            .select("*")
            .in_("user_id", user_ids)
            .execute()
        )
        
        tourists_map = {t["user_id"]: t for t in tourists_resp.data} if tourists_resp.data else {}
        
        # Fetch all entry items for these records
        record_ids = [record["record_id"] for record in entry_records_resp.data]
        entry_items_resp = (
            supabaseAdmin.table("entry_items")
            .select("*")
            .in_("record_id", record_ids)
            .order("arrival_time", desc=False)
            .execute()
        )
        
        # Fetch verifier (security/admin) information
        # Get unique verifier IDs from entry_items
        verifier_ids = []
        if entry_items_resp.data:
            verifier_ids = list(set([
                item.get("verified_by") 
                for item in entry_items_resp.data 
                if item.get("verified_by")
            ]))
        
        # Fetch verifier details from users table (or auth.users)
        verifiers_map = {}
        if verifier_ids:
            try:
                # Fetch from Supabase auth users
                for verifier_id in verifier_ids:
                    try:
                        # Get user from auth
                        user_resp = supabaseAdmin.auth.admin.get_user_by_id(verifier_id)
                        if user_resp and user_resp.user:
                            verifiers_map[verifier_id] = {
                                "name": user_resp.user.user_metadata.get("name", "Unknown"),
                                "phone": user_resp.user.phone or "No phone"
                            }
                    except:
                        verifiers_map[verifier_id] = {
                            "name": "Unknown",
                            "phone": "phone"
                        }
            except Exception as e:
                print(f"Error fetching verifiers: {e}")
        
        # Create CSV in memory
        output = io.StringIO()
        csv_writer = csv.writer(output)
        
        # Write header (removed IDs and bypass_reason, added verifier info)
        csv_writer.writerow([
            "Entry Date",
            "Tourist Name",
            "Email",
            "Unique ID Type",
            "Unique ID",
            "Is Group",
            "Group Count",
            "Total Members",
            "Arrival Time",
            "Departure Time",
            "Duration (minutes)",
            "Entry Type",
            "Entry Point",
            "Status",
            "Verified By Name",
            "Verified By Email"
        ])
        
        # Write data rows
        for entry_item in entry_items_resp.data if entry_items_resp.data else []:
            record_id = entry_item["record_id"]
            
            # Find the entry record
            entry_record = next((r for r in entry_records_resp.data if r["record_id"] == record_id), None)
            if not entry_record:
                continue
            
            # Get tourist details
            tourist = tourists_map.get(entry_record["user_id"], {})
            
            # Calculate duration in minutes
            duration_minutes = ""
            if entry_item.get("duration"):
                try:
                    # duration is in format like "1 days 00:30:00" or "00:30:00"
                    duration_str = str(entry_item["duration"])
                    # Simple parsing - this can be improved
                    if "days" in duration_str:
                        parts = duration_str.split()
                        days = int(parts[0])
                        time_part = parts[2]
                    else:
                        days = 0
                        time_part = duration_str
                    
                    time_parts = time_part.split(":")
                    hours = int(time_parts[0])
                    minutes = int(time_parts[1])
                    
                    total_minutes = (days * 24 * 60) + (hours * 60) + minutes
                    duration_minutes = str(total_minutes)
                except:
                    duration_minutes = "N/A"
            
            # Determine status
            status = "Exited" if entry_item.get("departure_time") else "Inside"
            
            # Calculate total members
            is_group = tourist.get("is_group", False)
            group_count = tourist.get("group_count", 1)
            total_members = group_count if is_group else 1
            
            # Get verifier information
            verifier_id = entry_item.get("verified_by")
            verifier_info = verifiers_map.get(verifier_id, {"name": "N/A", "phone": "N/A"})
            
            csv_writer.writerow([
                entry_record.get("entry_date", ""),
                tourist.get("name", ""),
                tourist.get("phone", ""),
                tourist.get("unique_id_type", ""),
                tourist.get("unique_id", ""),
                "Yes" if is_group else "No",
                group_count,
                total_members,
                entry_item.get("arrival_time", ""),
                entry_item.get("departure_time", "") or "Still Inside",
                duration_minutes or "N/A",
                entry_item.get("entry_type", ""),
                entry_item.get("entry_point", ""),
                status,
                verifier_info["name"],
                verifier_info["phone"]
            ])
        
        # Prepare the response
        output.seek(0)
        filename = f"{event_name.replace(' ', '_')}_entries_{from_date}_to_{to_date}.csv"
        
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename={filename}",
                "Access-Control-Allow-Origin": "*"
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error downloading entries: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to download entries: {str(e)}"
        )
