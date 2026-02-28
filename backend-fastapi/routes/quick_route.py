from fastapi import APIRouter, Depends, HTTPException, status, Form, BackgroundTasks
from utils.services.public_access_link_provider import short_url_generator
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import check_guard_admin_access, jwt_middleware
from utils.models.api_models import Tourist
from datetime import date, datetime
from pydantic import BaseModel
from utils.services.jwt_file_token import generate_card_token
from utils.services.card_cache import TEMP_CARD_DIR
from utils.india_time import india_today
import jwt

router = APIRouter()

class RenewCardRequest(BaseModel):
    short_code: str 
    renew_date: date = None  # default handled in endpoint to ensure IST date


# ────────────────────────────────────────────────────────────────────────────
# RENEW CARD VIA SHORT_CODE (Quick renewal with short code)
# ────────────────────────────────────────────────────────────────────────────
@router.post("/renew", status_code=status.HTTP_201_CREATED)
async def renew_card_by_shortcode(
    short_code: str = Form(...),
    valid_date: str = Form(...),
    background_tasks: BackgroundTasks = None,
):
    """
    Renew card using short_code from previous registration.
    
    User flow:
    1. User has short_code from previous registration (from SMS or QR code)
    2. Calls this endpoint with short_code and new valid_date (27, 28, or 1 Mar)
    3. System looks up the original tourist by short_code
    4. Creates new registration for new date without re-entering data
    5. Generates new token, qr_code, short_code
    6. Reuses image_path from original registration
    
    This is the fastest renewal - just short_code + date needed!
    """
    print(f"Renewing card by short_code: {short_code}, new valid_date: {valid_date}")

    # Parse valid_date
    if valid_date:
        try:
            valid_date_obj = datetime.strptime(valid_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid date format for valid_date. Use YYYY-MM-DD.")
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "valid_date is required for renew")

    if not short_code:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "short_code is required")

    try:
        # Find short_link by short_code to get the original user_id
        short_link_resp = (
            supabaseAdmin.table("short_links")
            .select("*")
            .eq("short_code", short_code)
            .single()
            .execute()
        )
        
        if not short_link_resp.data:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND,
                "Short code not found. Please check your code."
            )

        short_link = short_link_resp.data
        original_token = short_link.get("token")
        
        # Verify token is still valid to extract user_id
        try:
            from utils.services.jwt_file_token import verify_file_token
            payload = verify_file_token(original_token, expected_type="visitor_card")
            original_user_id = payload.get("user_id")
            if not original_user_id:
                raise HTTPException(
                    status.HTTP_400_BAD_REQUEST,
                    "Could not extract user information from short code."
                )
        except jwt.ExpiredSignatureError:
            # Token expired, but we can still find the user via RPC using short_code
            # The verify_qr_code RPC will handle the lookup
            # We'll use the RPC to verify the short_code
            qr_verify_resp = supabaseAdmin.rpc(
                "verify_qr_code",
                {
                    "p_short_code": short_code,
                    "p_event_id": 1  # Default event
                }
            ).execute()
            
            if not qr_verify_resp.data or len(qr_verify_resp.data) == 0:
                raise HTTPException(
                    status.HTTP_404_NOT_FOUND,
                    "Could not find user for this short code."
                )
            
            qr_data = qr_verify_resp.data[0]
            original_user_id = qr_data.get("user_id")
            
        except jwt.InvalidTokenError:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Invalid token in short code."
            )

        # Fetch original tourist
        existing_tourist_resp = supabaseAdmin.table("tourists").select("*").eq("user_id", original_user_id).single().execute()
        if not existing_tourist_resp.data:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND,
                "Original tourist not found."
            )

        existing_tourist = existing_tourist_resp.data
        phone = str(existing_tourist.get("phone", ""))  # DB stores as int, model expects str
        registered_event_id = existing_tourist.get("registered_event_id")

        # Check if already registered for this date
        already_registered_resp = (
            supabaseAdmin.table("tourists")
            .select("user_id")
            .eq("phone", phone)
            .eq("registered_event_id", registered_event_id)
            .eq("valid_date", str(valid_date_obj))
            .execute()
        )
        
        if already_registered_resp.data:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"You are already registered for {valid_date}. No need to renew."
            )

        # Validate active event
        event_resp = supabaseAdmin.table("events").select("*").eq("is_active", True).eq("event_id", registered_event_id).execute()
        if not event_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or inactive event")
        event_data = event_resp.data[0]

        # Fetch original tourist meta to get image_path
        existing_meta_resp = (
            supabaseAdmin.table("tourist_meta")
            .select("image_path, unique_id_path")
            .eq("user_id", original_user_id)
            .execute()
        )
        
        if not existing_meta_resp.data:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Could not find original tourist images."
            )

        existing_meta = existing_meta_resp.data[0]
        existing_image_path = existing_meta.get("image_path")
        existing_unique_id_path = existing_meta.get("unique_id_path")

        if not existing_image_path:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Original tourist image not found. Cannot renew."
            )

        # ═══════════════════════════════════════════════════════════════════════
        # CREATE NEW REGISTRATION FOR NEW DATE
        # ═══════════════════════════════════════════════════════════════════════
        
        # Create new tourist entry with same data but new valid_date
        new_registration = Tourist(
            name=existing_tourist.get("name"),
            phone=phone,
            unique_id_type=existing_tourist.get("unique_id_type"),
            unique_id=existing_tourist.get("unique_id"),
            is_group=existing_tourist.get("is_group", False),
            group_count=existing_tourist.get("group_count", 1),
            registered_event_id=registered_event_id,
            valid_date=valid_date_obj
        )

        # Insert new tourist entry
        reg_dict = new_registration.dict(exclude={"user_id"})
        if isinstance(reg_dict.get("valid_date"), datetime):
            reg_dict["valid_date"] = reg_dict["valid_date"].strftime("%Y-%m-%d")
        elif hasattr(reg_dict.get("valid_date"), "isoformat"):
            reg_dict["valid_date"] = reg_dict["valid_date"].isoformat()

        insert_resp = supabaseAdmin.table("tourists").insert(reg_dict).execute()
        if not insert_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error creating new registration")
        
        new_user_id = insert_resp.data[0]["user_id"]
        print(f"Created new tourist entry with user_id: {new_user_id} for date: {valid_date_obj}")

        # Generate NEW QR code and short code
        new_qr_code = short_url_generator()
        
        # Create new meta with SAME image_path but NEW qr_code
        meta_resp = supabaseAdmin.table("tourist_meta").insert({
            "user_id": new_user_id,
            "qr_code": new_qr_code,
            "image_path": existing_image_path,  # REUSE existing image
            "unique_id_path": existing_unique_id_path,  # REUSE existing ID photo if any
        }).execute()
        if not meta_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error saving meta")

        print(f"Created new tourist_meta for user_id: {new_user_id}, new_qr_code: {new_qr_code}")

        # Generate NEW visitor card token
        card_temp_path = f"{TEMP_CARD_DIR}/card_temp_{new_user_id}.png"
        card_public_url = None
        
        try:
            visitor_card_token = generate_card_token(
                user_id=new_user_id,
                user_name=existing_tourist.get("name"),
                event_name=event_data.get("name", ""),
                valid_dates=str(valid_date_obj),
                card_temp_path=card_temp_path,
            )
            
            # Create NEW short_link with NEW token
            supabaseAdmin.table("short_links").insert({
                "short_code": new_qr_code,
                "token": visitor_card_token
            }).execute()
            card_public_url = f"/tourists/visitor-card/{visitor_card_token}"
            
            print(f"Generated new visitor card token and short_link for user_id: {new_user_id}, short_code: {new_qr_code}")
            
        except Exception as e:
            print(f"Error generating visitor card token: {e}")
            card_public_url = None

        # SMS sending would go here via background_tasks if enabled
        if phone and background_tasks:
            from utils.services.sms_handler import send_welcome_sms_background
            send_welcome_sms_background(
                background_tasks=background_tasks,
                to=phone,
                event_name="वसंतोत्सव 2026",
                e_id=str(new_qr_code),
                valid_date=str(valid_date_obj),
                short_code=new_qr_code
            )

        return {
            "message": "Card renewed successfully!",
            "previous_short_code": short_code,
            "previous_user_id": original_user_id,
            "new_user_id": new_user_id,
            "new_date": str(valid_date_obj),
            "new_short_code": new_qr_code,
            "visitor_card_url": card_public_url,
            "phone": phone,
            "name": existing_tourist.get("name"),
            "reused": {
                "image_path": existing_image_path,
                "unique_id_path": existing_unique_id_path,
                "name": existing_tourist.get("name"),
                "is_group": existing_tourist.get("is_group"),
                "group_count": existing_tourist.get("group_count"),
                "unique_id_type": existing_tourist.get("unique_id_type"),
                "unique_id": existing_tourist.get("unique_id")
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error renewing card by short_code: {err_text}")
        
        if "duplicate key value violates unique constraint" in err_text or "23505" in err_text:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "You are already registered for this date."
            )
        
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error renewing card: {err_text}")


# ────────────────────────────────────────────────────────────────────────────
# RENEW CARD VIA PHONE (Alternative renewal with phone number)
# ────────────────────────────────────────────────────────────────────────────
@router.post("/renew-by-phone", status_code=status.HTTP_201_CREATED)
async def renew_card_by_phone(
    phone: str = Form(...),
    registered_event_id: int = Form(...),
    valid_date: str = Form(...),
    background_tasks: BackgroundTasks = None,
):
    """
    Renew card using phone number (alternative to short_code).
    
    User provides:
    - phone: their phone number
    - registered_event_id: event ID
    - valid_date: new date to register (27, 28, or 1 Mar)
    
    System looks up their most recent registration and reuses all data.
    Generates new token and short_code for the new date.
    """
    print(f"Renewing card by phone: {phone}, valid_date: {valid_date}")

    # Parse valid_date
    if valid_date:
        try:
            valid_date_obj = datetime.strptime(valid_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid date format for valid_date. Use YYYY-MM-DD.")
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "valid_date is required for renew")

    if not phone:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Phone number is required")
    if not registered_event_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "registered_event_id is required")

    # Validate active event
    event_resp = supabaseAdmin.table("events").select("*").eq("is_active", True).eq("event_id", registered_event_id).execute()
    if not event_resp.data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid or inactive event")
    event_data = event_resp.data[0]

    try:
        # Find existing tourist with this phone (get the most recent one)
        existing_tourists_resp = (
            supabaseAdmin.table("tourists")
            .select("*")
            .eq("phone", phone)
            .eq("registered_event_id", registered_event_id)
            .order("user_id", desc=True)
            .limit(1)
            .execute()
        )
        
        if not existing_tourists_resp.data:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND,
                "No existing registration found for this phone number. Please register first."
            )

        existing_tourist = existing_tourists_resp.data[0]
        existing_user_id = existing_tourist["user_id"]

        # Check if already registered for this date
        already_registered_resp = (
            supabaseAdmin.table("tourists")
            .select("user_id")
            .eq("phone", phone)
            .eq("registered_event_id", registered_event_id)
            .eq("valid_date", str(valid_date_obj))
            .execute()
        )
        
        if already_registered_resp.data:
            print(f"User with phone {phone} is already registered for date {valid_date} {already_registered_resp.data}")
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                f"You are already registered for {valid_date}. No need to renew."
            )

        # Fetch existing tourist meta to get image_path
        existing_meta_resp = (
            supabaseAdmin.table("tourist_meta")
            .select("image_path, unique_id_path")
            .eq("user_id", existing_user_id)
            .execute()
        )
        
        if not existing_meta_resp.data:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Could not find existing tourist metadata. Please register first."
            )

        existing_meta = existing_meta_resp.data[0]
        existing_image_path = existing_meta.get("image_path")
        existing_unique_id_path = existing_meta.get("unique_id_path")

        if not existing_image_path:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Existing tourist image not found. Cannot renew."
            )

        # ═══════════════════════════════════════════════════════════════════════
        # CREATE NEW REGISTRATION FOR NEW DATE
        # ═══════════════════════════════════════════════════════════════════════
        
        # Create new tourist entry with same data but new valid_date
        new_registration = Tourist(
            name=existing_tourist.get("name"),
            phone=phone,
            unique_id_type=existing_tourist.get("unique_id_type"),
            unique_id=existing_tourist.get("unique_id"),
            is_group=existing_tourist.get("is_group", False),
            group_count=existing_tourist.get("group_count", 1),
            registered_event_id=registered_event_id,
            valid_date=valid_date_obj
        )

        # Insert new tourist entry
        reg_dict = new_registration.dict(exclude={"user_id"})
        if isinstance(reg_dict.get("valid_date"), datetime):
            reg_dict["valid_date"] = reg_dict["valid_date"].strftime("%Y-%m-%d")
        elif hasattr(reg_dict.get("valid_date"), "isoformat"):
            reg_dict["valid_date"] = reg_dict["valid_date"].isoformat()

        insert_resp = supabaseAdmin.table("tourists").insert(reg_dict).execute()
        if not insert_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error creating new registration")
        
        new_user_id = insert_resp.data[0]["user_id"]
        print(f"Created new tourist entry with user_id: {new_user_id}")

        # Generate new QR code and short code
        new_qr_code = short_url_generator()
        
        # Create new meta with SAME image_path but NEW qr_code
        meta_resp = supabaseAdmin.table("tourist_meta").insert({
            "user_id": new_user_id,
            "qr_code": new_qr_code,
            "image_path": existing_image_path,  # REUSE existing image
            "unique_id_path": existing_unique_id_path,  # REUSE existing ID photo if any
        }).execute()
        if not meta_resp.data:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Error saving meta")

        # Generate NEW visitor card token
        card_temp_path = f"{TEMP_CARD_DIR}/card_temp_{new_user_id}.png"
        card_public_url = None
        
        try:
            visitor_card_token = generate_card_token(
                user_id=new_user_id,
                user_name=existing_tourist.get("name"),
                event_name=event_data.get("name", ""),
                valid_dates=str(valid_date_obj),
                card_temp_path=card_temp_path,
            )
            
            # Create NEW short_link with NEW token
            supabaseAdmin.table("short_links").insert({
                "short_code": new_qr_code,
                "token": visitor_card_token
            }).execute()
            card_public_url = f"/tourists/visitor-card/{visitor_card_token}"
            
            print(f"Generated new visitor card token and short_link for user_id: {new_user_id}, short_code: {new_qr_code}")
            
        except Exception as e:
            print(f"Error generating visitor card token: {e}")
            card_public_url = None

        # SMS sending would go here via background_tasks if enabled
        if phone and background_tasks:
            from utils.services.sms_handler import send_welcome_sms_background
            send_welcome_sms_background(
                background_tasks=background_tasks,
                to=phone,
                event_name="वसंतोत्सव 2026",
                e_id=str(new_qr_code),
                valid_date=str(valid_date_obj),
                short_code=new_qr_code
            )

        return {
            "message": "Card renewed successfully",
            "previous_user_id": existing_user_id,
            "new_user_id": new_user_id,
            "new_date": str(valid_date_obj),
            "new_short_code": new_qr_code,
            "tourist": insert_resp.data[0],
            "meta": meta_resp.data[0] if meta_resp.data else None,
            "visitor_card_url": card_public_url,
            "reused": {
                "image_path": existing_image_path,
                "unique_id_path": existing_unique_id_path
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        err_text = str(e)
        print(f"Error renewing card: {err_text}")
        
        if "duplicate key value violates unique constraint" in err_text or "23505" in err_text:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "You are already registered for this date."
            )
        
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Error renewing card: {err_text}") 

