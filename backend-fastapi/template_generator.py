from datetime import datetime
from PIL import Image, ImageDraw, ImageFont
import os
import qrcode
from io import BytesIO


class VisitorCardGenerator:
    """
    Generates visitor cards using template_2026.jpg (3375 × 6000 px).

    Template zones (full-resolution pixel coordinates):
      • Profile circle   — center (521, 2050),  radius 275
      • White panel      — x 1235..2139, y 4100..4950  (904 × 850 px)
          ↳ QR code      — top portion of panel (380 × 380, centred)
          ↳ Data text    — below QR, up to 5 lines
    """

    # ── template zone constants ───────────────────────────────────────────
    CIRCLE_CX, CIRCLE_CY, CIRCLE_R = 521, 2050, 275

    PANEL_X1, PANEL_Y1 = 1235, 4100
    PANEL_X2, PANEL_Y2 = 2139, 4950

    # ─────────────────────────────────────────────────────────────────────
    def __init__(self):
        self.template_path = "template/template_2026.jpg"
        self.font_path = "fonts/arial.ttf"

    # ── public API ────────────────────────────────────────────────────────

    def generate_card_in_memory(self, user_data: dict) -> BytesIO:
        """
        Generate a visitor card in memory without writing to disk.

        user_data keys:
            name               – tourist full name
            unique_id          – e.g. "Aadhar: 123456789012"
            profile_image_path – path to photo (may be absent/None)
            qr_data            – string encoded in QR, e.g. "TOURIST-34"
            valid_dates        – e.g. "2026-02-01 to 2026-02-28"
            group_count        – integer (1 = solo)
        """
        card = Image.open(self.template_path).convert("RGBA")

        # ── 1. Circular profile photo ─────────────────────────────────
        diameter = self.CIRCLE_R * 2          # 550 px
        photo_path = user_data.get("profile_image_path")
        if photo_path and os.path.exists(str(photo_path)):
            try:
                photo = Image.open(photo_path)
                circle_img = self._make_circle_crop(photo, diameter)
            except Exception:
                circle_img = self._make_placeholder_circle(
                    diameter, user_data.get("name", "")
                )
        else:
            circle_img = self._make_placeholder_circle(
                diameter, user_data.get("name", "")
            )

        paste_x = self.CIRCLE_CX - self.CIRCLE_R   # 246
        paste_y = self.CIRCLE_CY - self.CIRCLE_R   # 1775
        card.paste(circle_img, (paste_x, paste_y), circle_img)

        # ── 2. QR code — fills the entire white panel ────────────────
        panel_w = self.PANEL_X2 - self.PANEL_X1    # 904
        panel_h = self.PANEL_Y2 - self.PANEL_Y1    # 850
        qr_pad  = 35
        qr_size = min(panel_w, panel_h) - qr_pad * 2   # 780
        qr_x = self.PANEL_X1 + (panel_w - qr_size) // 2
        qr_y = self.PANEL_Y1 + (panel_h - qr_size) // 2
        qr_img = self._generate_qr(user_data.get("qr_data", "TOURIST"), qr_size)
        card.paste(qr_img, (qr_x, qr_y))

        # ── 3. Data text inside the cream/gold-bordered rectangle ────
        # Rectangle inner text area: x 250..3125, below circle (bottom ≈ y 2325)
        draw   = ImageDraw.Draw(card)
        RECT_X1, RECT_X2 = 250, 3125
        text_w = RECT_X2 - RECT_X1 - 300      # 2575 px usable width (150px padding per side)
        text_y = 2430                           # below circle bottom

        fn_name   = self._font(200)
        fn_detail = self._font(140)
        fn_small  = self._font(115)

        name = user_data.get("name", "")
        if name:
            # Auto-scale name if too long
            actual_font = self._fit_text(draw, name, text_w, fn_name, min_size=100)
            self._draw_centered(draw, name, RECT_X1 + 150, text_y, text_w,
                                actual_font, fill="#1a1a5e", stroke=2)
            text_y += 280

        phone = user_data.get("phone", "")
        if phone:
            self._draw_centered(draw, f"Phone: {phone}", RECT_X1 + 150, text_y, text_w,
                                fn_detail, fill="#2c2c2c")
            text_y += 200

        qr_str = user_data.get("qr_data", "")
        if qr_str:
            self._draw_centered(draw, f"ID: {qr_str}", RECT_X1 + 150, text_y, text_w,
                                fn_detail, fill="#2c2c2c")
            text_y += 200

        dates = user_data.get("valid_dates", "")
        if dates:
            self._draw_centered(draw, f"Valid: {dates}", RECT_X1 + 150, text_y, text_w,
                                fn_small, fill="#444444")
            text_y += 170

        gc = user_data.get("group_count")
        if gc is not None:
            try:
                gc_int = int(gc)
                label = f"Group: {gc_int} {'person' if gc_int == 1 else 'persons'}"
            except (ValueError, TypeError):
                label = f"Group: {gc}"
            self._draw_centered(draw, label, RECT_X1 + 150, text_y, text_w,
                                fn_small, fill="#444444")

        # ── serialise ─────────────────────────────────────────────────
        output = BytesIO()
        card.convert("RGB").save(output, "PNG", optimize=False)
        output.seek(0)
        return output

    def create_visitor_card(self, user_data: dict) -> str:
        """Generate card and save to static/cards/. Returns the file path."""
        buf = self.generate_card_in_memory(user_data)
        output_dir = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "static", "cards")
        )
        os.makedirs(output_dir, exist_ok=True)
        name_slug = user_data.get("name", "card").replace(" ", "_")
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_path = os.path.join(output_dir, f"{name_slug}_card_{ts}.png")
        with open(out_path, "wb") as fh:
            fh.write(buf.read())
        return out_path

    # ── private helpers ───────────────────────────────────────────────────

    def _make_circle_crop(self, image: Image.Image, diameter: int) -> Image.Image:
        """Return a diameter×diameter RGBA image with a circular crop."""
        img = self._crop_to_square(image).resize(
            (diameter, diameter), Image.Resampling.LANCZOS
        )
        mask = Image.new("L", (diameter, diameter), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, diameter - 1, diameter - 1), fill=255)
        result = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
        result.paste(img.convert("RGBA"), mask=mask)
        return result

    def _make_placeholder_circle(self, diameter: int, name: str) -> Image.Image:
        """Grey circle with initials — shown when no profile photo is available."""
        result = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
        draw = ImageDraw.Draw(result)
        draw.ellipse(
            (0, 0, diameter - 1, diameter - 1),
            fill=(180, 180, 180, 255),
            outline=(120, 120, 120, 255),
            width=6,
        )
        initials = "".join(w[0].upper() for w in name.split() if w)[:2] or "?"
        try:
            font = ImageFont.truetype(self.font_path, diameter // 3)
        except Exception:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), initials, font=font)
        tx = (diameter - (bbox[2] - bbox[0])) // 2 - bbox[0]
        ty = (diameter - (bbox[3] - bbox[1])) // 2 - bbox[1]
        draw.text((tx, ty), initials, fill=(50, 50, 50, 255), font=font)
        return result

    def _generate_qr(self, data: str, size: int) -> Image.Image:
        """Generate a QR code and resize it to size×size."""
        qr = qrcode.QRCode(
            version=1,
            box_size=10,
            border=2,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
        )
        qr.add_data(data)
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
        return qr_img.resize((size, size), Image.Resampling.LANCZOS)

    def _crop_to_square(self, image: Image.Image) -> Image.Image:
        """Centre-crop to square (no resize)."""
        w, h = image.size
        if w == h:
            return image
        side = min(w, h)
        left = (w - side) // 2
        top  = (h - side) // 2
        return image.crop((left, top, left + side, top + side))

    def _font(self, size: int) -> ImageFont.FreeTypeFont:
        return ImageFont.truetype(self.font_path, size)

    def _draw_centered(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        x: int,
        y: int,
        max_w: int,
        font: ImageFont.FreeTypeFont,
        fill: str = "#000000",
        stroke: int = 0,
    ) -> None:
        """Draw *text* centred within a horizontal band of width *max_w* starting at *x*."""
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        tx = x + max(0, (max_w - text_w) // 2)
        kwargs: dict = dict(font=font, fill=fill)
        if stroke:
            kwargs["stroke_width"] = stroke
            kwargs["stroke_fill"] = fill
        draw.text((tx, y), text, **kwargs)

    def _fit_text(
        self,
        draw: ImageDraw.ImageDraw,
        text: str,
        max_width: int,
        initial_font: ImageFont.FreeTypeFont,
        min_size: int = 50,
    ) -> ImageFont.FreeTypeFont:
        """
        Return a font that fits *text* within *max_width*.
        Starts at *initial_font* size and reduces if necessary down to *min_size*.
        """
        bbox = draw.textbbox((0, 0), text, font=initial_font)
        text_w = bbox[2] - bbox[0]
        if text_w <= max_width:
            return initial_font
        
        # Extract current font size from the font's path or estimate
        try:
            current_size = initial_font.size
        except AttributeError:
            current_size = 200  # fallback
        
        # Binary search or linear reduction for the right size
        for size in range(current_size - 10, min_size - 1, -5):
            test_font = self._font(size)
            bbox = draw.textbbox((0, 0), text, font=test_font)
            test_w = bbox[2] - bbox[0]
            if test_w <= max_width:
                return test_font
        
        # Return minimum size if still too wide
        return self._font(min_size)

    # ── backward-compat shim ──────────────────────────────────────────────

    def _resize_image(self, image: Image.Image, box_size) -> Image.Image:
        """Legacy helper kept so old callers don't break."""
        size = box_size[0] if isinstance(box_size, (tuple, list)) else int(box_size)
        return self._crop_to_square(image).resize(
            (size, size), Image.Resampling.LANCZOS
        )

    # keep old name as alias
    def _generate_qr_code(self, data: str) -> Image.Image:
        return self._generate_qr(data, 380)

