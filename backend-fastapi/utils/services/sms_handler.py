
import requests
from fastapi import BackgroundTasks
import logging
import os
logger = logging.getLogger(__name__)
enitity_id = os.getenv("E_ID", "")
template_id = os.getenv("TEMPLATE_ID", "")
sender = os.getenv("SENDER", "")
api_password = os.getenv("API_PASSWORD", "")
class SMSHandler:
    def send_sms(self, to: str, event_name: str, valid_date: str, e_id: str, short_code: str) -> bool:
        if not all([enitity_id, template_id, sender]):
            logger.error("Missing SMS configuration. Please set E_ID, TEMPLATE_ID, and SENDER environment variables.")
            return False
        """

        Send SMS using the specified HTTP GET endpoint, filling variables in the message.
        Args:
            to: recipient phone number (string)
            event_name: event name (string)
            valid_date: valid date (string)
            e_id: e-Visitor ID (string)
            short_code: short code for link (string)
        Returns:
            bool: True if sent successfully, False otherwise
        """
        url = "http://itda.hmimedia.in/pushsms.php"
        message_template = (
            f"RAJBUK-महोदय/महोदया, लोक भवन, देहरादून में आयोजित {event_name} दिनांक {valid_date} हेतु आपकी e-Visitor ID {e_id} है। आपका प्रवेश पास नीचे दिए गए लिंक पर उपलब्ध है: https://vmsbutu.live/c/?id={short_code}"
        )
        params = {
            "username": sender,
            "api_password": api_password,
            "sender": "RAJBUK",
            "to": to,
            "message": message_template,
            "priority": "11",
            "e_id": enitity_id,
            "t_id": template_id
        }
        try:
            response = requests.get(url, params=params, timeout=10)
            logger.info(f"SMS API response: {response.status_code} {response.text}")
            return response.status_code == 200
        except Exception as e:
            logger.error(f"SMS sending failed: {str(e)}")
            return False


def send_welcome_sms_background(background_tasks: BackgroundTasks, to: str, event_name: str, valid_date: str, e_id: str, short_code: str):
    """
    Background task to send welcome SMS.
    Args:
        background_tasks: FastAPI BackgroundTasks instance
        to: recipient phone number (string)
        event_name: event name (string)
        valid_date: valid date (string)
        e_id: e-Visitor ID (string)
        short_code: short code for link (string)
    """
    sms_handler = SMSHandler()
    background_tasks.add_task(sms_handler.send_sms, to, event_name, valid_date, e_id, short_code)