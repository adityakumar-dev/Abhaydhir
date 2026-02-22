"""
SMS Routes for sending greeting messages and viewing visitor cards
Public access routes for SMS recipients
"""
from fastapi import APIRouter, HTTPException, status, BackgroundTasks
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel
from utils.services.sms_handler import SMSHandler, send_welcome_sms_background
from utils.services.jwt_file_token import verify_file_token, validate_file_path_security
import os
import jwt
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


class SendSMSRequest(BaseModel):
    phone: str
    user_name: str
    visitor_card_token: str
    event_name: str = None
    valid_dates: str = None
    user_id: int = None


# ============================================================
# VIEW VISITOR CARD (Public Access via SMS Link)
# ============================================================
@router.get("/view-card", response_class=HTMLResponse, status_code=status.HTTP_200_OK)
async def view_visitor_card(token: str):
    """
    View visitor card via SMS link - returns HTML page with card image and download button
    URL format: /sms/view-card?token={jwt_token}
    """
    try:
        # Decode and verify JWT token
        payload = verify_file_token(token, expected_type="visitor_card")

        # Token now carries user_id — card is generated on-the-fly, no file on disk
        user_id = payload.get("user_id")
        if not user_id:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid token payload: missing user_id")

        # Both URLs point to on-the-fly generation endpoints
        base_url = os.getenv("BASE_URL", "http://localhost:8000")
        view_image_url = f"{base_url}/tourists/visitor-card/{token}"
        download_url = f"{base_url}/tourists/download-visitor-card/{token}"
        
        
        # Return HTML page using external template file
        template_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'template', 'view_card.html'))
        try:
            with open(template_path, 'r', encoding='utf-8') as f:
                tpl = f.read()
        except Exception as e:
            logger.error(f"Failed to load visitor card template: {e}")
            raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Visitor card template not found")

        # Optional metadata from token payload (if present)
        visitor_name = payload.get('user_name', '') or ''
        event_title = payload.get('event_name', '') or ''
        valid_dates_text = payload.get('valid_dates', '') or ''

        # Substitute placeholders in template
        html_content = tpl.replace('%VIEW_IMAGE_URL%', view_image_url) \
                         .replace('%DOWNLOAD_URL%', download_url) \
                         .replace('%NAME%', visitor_name) \
                         .replace('%EVENT_NAME%', event_title) \
                         .replace('%VALID_DATES%', valid_dates_text)

        return FileResponse(content)
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid token")
    except ValueError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except Exception as e:
        logger.error(f"Error viewing visitor card: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to retrieve visitor card")


# ============================================================
# DOWNLOAD VISITOR CARD (via SMS Link)
# ============================================================
@router.get("/download-card", status_code=status.HTTP_200_OK)
async def download_visitor_card_sms(token: str):
    """
    Redirect to the on-the-fly visitor card download endpoint.
    Kept for backward compatibility with existing SMS links.
    """
    from fastapi.responses import RedirectResponse
    try:
        verify_file_token(token, expected_type="visitor_card")
        base_url = os.getenv("BASE_URL", "http://localhost:8000")
        return RedirectResponse(url=f"{base_url}/tourists/download-visitor-card/{token}", status_code=302)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid token")
    except ValueError as e:
        raise HTTPException(status.HTTP_403_FORBIDDEN, str(e))
    except Exception as e:
        logger.error(f"Error redirecting to visitor card download: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to download visitor card")


# ============================================================
# SEND SMS MANUALLY (Admin only - for testing or resending)
# ============================================================
@router.post("/send-greeting", status_code=status.HTTP_200_OK)
async def send_greeting_sms(
    sms_request: SendSMSRequest,
    background_tasks: BackgroundTasks
):
    """
    Send greeting SMS with visitor card link
    Can be used to resend SMS or send to new number
    """
    try:
        # Send SMS in background
        send_welcome_sms_background(
            background_tasks=background_tasks,
            to_phone=sms_request.phone,
            user_name=sms_request.user_name,
            visitor_card_token=sms_request.visitor_card_token,
            event_name=sms_request.event_name,
            valid_dates=sms_request.valid_dates,
            user_id=sms_request.user_id
        )
        
        return {
            "success": True,
            "message": f"SMS greeting sent to {sms_request.phone}",
            "phone": sms_request.phone
        }
        
    except Exception as e:
        logger.error(f"Error sending SMS: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send SMS: {str(e)}"
        )
