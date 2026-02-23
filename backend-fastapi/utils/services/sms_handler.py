"""
SMS Handler for sending greeting messages and visitor card links
Supports multiple SMS providers (Twilio, AWS SNS, etc.)
"""
import os
import re
import requests
from typing import Optional
from fastapi import BackgroundTasks
import logging

logger = logging.getLogger(__name__)

class SMSConfig:
    # SMS Provider Configuration
    SMS_PROVIDER = os.getenv("SMS_PROVIDER", "twilio")  # twilio, aws_sns, msg91, etc.
    
    # Twilio Configuration
    TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
    TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
    TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")
    
    # MSG91 Configuration (Indian SMS Provider)
    MSG91_AUTH_KEY = os.getenv("MSG91_AUTH_KEY")
    MSG91_SENDER_ID = os.getenv("MSG91_SENDER_ID")
    MSG91_ROUTE = os.getenv("MSG91_ROUTE", "4")  # 4 = Transactional
    
    # AWS SNS Configuration
    AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY")
    AWS_SECRET_KEY = os.getenv("AWS_SECRET_KEY")
    AWS_REGION = os.getenv("AWS_REGION", "us-east-1")


class SMSHandler:
    def __init__(self):
        self.provider = SMSConfig.SMS_PROVIDER
        self.base_url = os.getenv("HOST_URL", "http://localhost:3000")
        self.default_country_code = os.getenv("DEFAULT_COUNTRY_CODE", "+91")  # Default to India
    
    def format_phone_number(self, phone: str) -> str:
        """
        Format phone number to E.164 format required by SMS providers
        
        Args:
            phone: Phone number (can be with/without country code)
        
        Returns:
            Formatted phone number in E.164 format (e.g., +918171839601)
        
        Examples:
            8171839601 -> +918171839601
            +918171839601 -> +918171839601
            91-8171839601 -> +918171839601
        """
        # Remove all non-digit characters except +
        cleaned = re.sub(r'[^\d+]', '', phone)
        
        # If already has + at start, return as is (assume it's already formatted)
        if cleaned.startswith('+'):
            return cleaned
        
        # If starts with country code without +, add +
        if len(cleaned) > 10:
            # Likely has country code already (e.g., 918171839601)
            return f"+{cleaned}"
        
        # If it's just a 10-digit number, add default country code
        if len(cleaned) == 10:
            return f"{self.default_country_code}{cleaned}"
        
        # If starts with 0, remove it and add country code (common in India)
        if cleaned.startswith('0') and len(cleaned) == 11:
            return f"{self.default_country_code}{cleaned[1:]}"
        
        # Otherwise, just add default country code
        return f"{self.default_country_code}{cleaned}"
    
    def validate_phone_number(self, phone: str) -> bool:
        """
        Validate if phone number is in correct format after formatting
        
        Args:
            phone: Formatted phone number
        
        Returns:
            True if valid, False otherwise
        """
        # E.164 format: +[country code][number]
        # Total length should be between 10-15 digits (including country code)
        if not phone.startswith('+'):
            return False
        
        digits_only = phone[1:]  # Remove +
        if not digits_only.isdigit():
            return False
        
        # Length should be reasonable (typically 10-15 digits total)
        if len(digits_only) < 10 or len(digits_only) > 15:
            return False
        
        return True
        
    def send_sms_twilio(self, to_phone: str, message: str) -> bool:
        """Send SMS using Twilio"""
        try:
            from twilio.rest import Client
            
            # Format phone number to E.164 format
            formatted_phone = self.format_phone_number(to_phone)
            
            # Validate phone number
            if not self.validate_phone_number(formatted_phone):
                logger.error(f"❌ Invalid phone number format: {to_phone} (formatted: {formatted_phone})")
                return False
            
            logger.info(f"📱 Sending SMS to {formatted_phone} (original: {to_phone})")
            
            client = Client(SMSConfig.TWILIO_ACCOUNT_SID, SMSConfig.TWILIO_AUTH_TOKEN)
            
            sms_message = client.messages.create(
                body=message,
                from_=SMSConfig.TWILIO_PHONE_NUMBER,
                to=formatted_phone
            )
            
            logger.info(f"✅ Twilio SMS sent successfully to {formatted_phone}, SID: {sms_message.sid}")
            return True
            
        except Exception as e:
            logger.error(f"❌ Twilio SMS failed: {str(e)}")
            return False
    
    def send_sms_msg91(self, to_phone: str, message: str) -> bool:
        """Send SMS using MSG91 (Indian provider)"""
        try:
            # Format phone number to E.164 format
            formatted_phone = self.format_phone_number(to_phone)
            
            # Validate phone number
            if not self.validate_phone_number(formatted_phone):
                logger.error(f"❌ Invalid phone number format: {to_phone}")
                return False
            
            # MSG91 needs number without + sign
            phone_without_plus = formatted_phone.replace("+", "")
            
            logger.info(f"📱 Sending SMS to {formatted_phone} (original: {to_phone})")
            
            url = "https://api.msg91.com/api/v5/flow/"
            
            headers = {
                "authkey": SMSConfig.MSG91_AUTH_KEY,
                "content-type": "application/json"
            }
            
            payload = {
                "sender": SMSConfig.MSG91_SENDER_ID,
                "route": SMSConfig.MSG91_ROUTE,
                "country": "91",
                "sms": [
                    {
                        "message": message,
                        "to": [phone_without_plus]
                    }
                ]
            }
            
            response = requests.post(url, json=payload, headers=headers, timeout=10)
            
            if response.status_code == 200:
                logger.info(f"✅ MSG91 SMS sent successfully to {formatted_phone}")
                return True
            else:
                logger.error(f"❌ MSG91 SMS failed: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"❌ MSG91 SMS failed: {str(e)}")
            return False
    
    def send_welcome_sms(
        self,
        to_phone: str,
        user_name: str,
        event_name: str = None,
        valid_dates: str = None,
        short_code: str = None
    ) -> bool:
        """
        Send welcome SMS with visitor card link
        
        Args:
            to_phone: Phone number with country code (e.g., +919876543210)
            user_name: Name of the visitor
            visitor_card_token: JWT token for visitor card access
            event_name: Name of the event
            valid_dates: Valid date range
            user_id: Tourist user ID
        
        Returns:
            bool: True if SMS sent successfully
        """
        try:
            # Generate visitor card view/download link
            card_view_url = f"{self.base_url}/c/{short_code}"
            
            # Create short, concise message for SMS (160 char limit consideration)
            message = (
                f"Welcome {user_name}!\n"
                f"Event: {event_name or 'Festival'}\n"
                f"Valid: {valid_dates or 'As per schedule'}\n"
                f"View your visitor card: {card_view_url}\n"
                f"Show this at entry."
            )
            
            # Send based on provider
            if self.provider == "twilio":
                return self.send_sms_twilio(to_phone, message)
            elif self.provider == "msg91":
                return self.send_sms_msg91(to_phone, message)
            else:
                logger.warning(f"⚠️ SMS provider '{self.provider}' not configured, skipping SMS")
                return False
                
        except Exception as e:
            logger.error(f"❌ Failed to send welcome SMS: {str(e)}")
            return False


def send_welcome_sms_background(
    background_tasks: BackgroundTasks,
    to_phone: str,
    user_name: str,
    event_name: str = None,
    valid_dates: str = None,
    short_code: str = None,
):
    """Send welcome SMS in background"""
    def send_sms():
        try:
            sms_handler = SMSHandler()
            success = sms_handler.send_welcome_sms(
                to_phone=to_phone,
                user_name=user_name,
                event_name=event_name,
                valid_dates=valid_dates,
                short_code=short_code
            )
            if success:
                logger.info(f"✅ Background SMS sent successfully to {to_phone}")
            else:
                logger.warning(f"⚠️ Failed to send background SMS to {to_phone}")
        except Exception as e:
            logger.error(f"❌ Background SMS task failed: {str(e)}")
    
    background_tasks.add_task(send_sms)
