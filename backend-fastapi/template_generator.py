from datetime import datetime
from PIL import Image, ImageDraw, ImageFont
import os
import qrcode
from io import BytesIO
import base64

class VisitorCardGenerator:
    def __init__(self):
        self.template_path = "template/template.jpeg"
        self.font_path = "fonts/arial.ttf"
        self.card_size = (720, 1280)
        
    def create_visitor_card(self, user_data):
        """
        Generate a visitor card for a user
        user_data should contain: name, email, profile_image_path, qr_data (tourist ID string)
        """
        try:
            # Load template
            template = Image.open(self.template_path)
            template = template.resize(self.card_size)
            
            # Load user profile image
            profile_img = Image.open(user_data["profile_image_path"])
            profile_img = self._resize_image(profile_img, (200, 200))
            
            # Generate QR code dynamically (not stored)
            qr_img = self._generate_qr_code(user_data["qr_data"])
            qr_img = self._resize_image(qr_img, (200, 200))  # Same size as profile image
            
            # Create a copy of template to work on
            card = template.copy()
            profile_pos = (100, 400)  # Profile image position
            qr_pos = (420, 400)  # QR code position (same vertical position, next to profile)
            name_pos = (100, 620)
            email_pos = (100, 670)
            id_pos = (100, 710)
            valid_pos = (100, 760)
            
            # Paste images with transparency
            if profile_img.mode == 'RGBA':
                card.paste(profile_img, profile_pos, profile_img)
            else:
                card.paste(profile_img, profile_pos)
                
            if qr_img.mode == 'RGBA':
                card.paste(qr_img, qr_pos, qr_img)
            else:
                card.paste(qr_img, qr_pos)
            
            # Add text
            draw = ImageDraw.Draw(card)
            font_name = ImageFont.truetype(self.font_path, 40)
            font_email = ImageFont.truetype(self.font_path, 24)
            font_id = ImageFont.truetype(self.font_path, 28)
            
            draw.text(name_pos, user_data["name"], fill="black", font=font_name, stroke_width=2, stroke_fill="black")
            if user_data.get("email"):
                draw.text(email_pos, user_data["email"], fill="black", font=font_email)
            draw.text(id_pos, f"ID: {user_data['qr_data']}", fill="black", font=font_id, stroke_width=1, stroke_fill="black")
            if user_data.get("valid_dates"):
                draw.text(valid_pos, f"Valid: {user_data['valid_dates']}", fill="black", font=font_email)
            
            # Save the card
            output_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'static/cards'))
            os.makedirs(output_dir, exist_ok=True)
            output_path = f"{output_dir}/{user_data['name'].replace(' ', '_')}_card_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
            card.save(output_path, "PNG", quality=95)
            
            return output_path
        
        except Exception as e:
            print(f"Error generating visitor card: {str(e)}")
            raise
    
    def _generate_qr_code(self, data):
        """Generate QR code image in memory"""
        qr = qrcode.QRCode(version=1, box_size=10, border=2)
        qr.add_data(data)
        qr.make(fit=True)
        qr_img = qr.make_image(fill='black', back_color='white')
        return qr_img
    
    def _resize_image(self, image, box_size):
        """Resize and crop image to exactly fit the given box size, maintaining aspect ratio."""
        img_width, img_height = image.size
        box_width, box_height = box_size
        img_ratio = img_width / img_height
        box_ratio = box_width / box_height
        
        if img_ratio > box_ratio:
            new_height = box_height
            new_width = int(new_height * img_ratio)
        else:
            new_width = box_width
            new_height = int(new_width / img_ratio)
        
        image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
        left = (new_width - box_width) // 2
        top = (new_height - box_height) // 2
        right = left + box_width
        bottom = top + box_height
        
        return image.crop((left, top, right, bottom))

