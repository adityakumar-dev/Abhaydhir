from PIL import Image, ImageDraw, ImageFont
import numpy as np

img = Image.open("template/template3.jpg").convert("RGB")
arr = np.array(img)
w, h = img.size
print(f"Template size: {w}x{h}")

# ── QR white box: scan horizontally at y=1030 to find x bounds ──
print("\n--- QR box x-scan at y=1030 ---")
row = arr[1030, :, :]
white = (row[:, 0] > 245) & (row[:, 1] > 245) & (row[:, 2] > 245)
idxs = np.where(white)[0]
if len(idxs):
    print(f"  White x range: {idxs.min()} .. {idxs.max()}  (width={idxs.max()-idxs.min()})")

# ── QR box: scan vertically at x=384 to find y bounds precisely ──
print("\n--- QR box y-scan at x=384 ---")
col = arr[:, 384, :]
white_v = (col[:, 0] > 245) & (col[:, 1] > 245) & (col[:, 2] > 245)
white_ys = np.where(white_v)[0]
qr_ys = white_ys[white_ys > 700]
if len(qr_ys):
    print(f"  White y range: {qr_ys.min()} .. {qr_ys.max()}  (height={qr_ys.max()-qr_ys.min()})")

# ── Circle frame: find the blue ring boundary ──
print("\n--- Circle blue outline scan at y=449 ---")
row449 = arr[449, :, :]
blue = (row449[:, 2] > 100) & (row449[:, 2] > row449[:, 0]) & (row449[:, 2] > row449[:, 1])
blue_xs = np.where(blue)[0]
blue_xs_left = blue_xs[blue_xs < 200]
if len(blue_xs_left):
    print(f"  Blue ring x: {blue_xs_left.min()} .. {blue_xs_left.max()}")

# ── Scan top of circle (y=300..310) to find the circle top ──
print("\n--- Find circle frame top/bottom edges (x=160 vertical) ---")
col160 = arr[:, 160, :]
dark_border = (col160[:, 0] < 80) | ((col160[:, 2] > 100) & (col160[:, 2] > col160[:, 0] + 30))
# Find where cream/white gives way to something else in circle range
for y in range(285, 620, 5):
    r, g, b = arr[y, 160]
    if r < 200:
        print(f"  Non-cream at (160,{y}): rgb({r},{g},{b})")

# ── Text region: find the inner rectangle ──
print("\n--- Inner bordered rectangle scan (find left/right walls) ---")
print("y=560 horizontal (text row):")
for x in range(20, 760, 15):
    r, g, b = arr[560, x]
    if r < 150:  # dark pixels = border
        print(f"  Dark at x={x}: rgb({r},{g},{b})")

print("\ny=580 horizontal:")
for x in range(20, 760, 5):
    r, g, b = arr[580, x]
    if r < 140:
        print(f"  Dark at x={x}: rgb({r},{g},{b})")

# ── Find bottom of the inner rectangle ──
print("\n--- Bottom edge scan at x=384 (center) ---")
for y in range(830, 960, 5):
    r, g, b = arr[y, 384]
    print(f"  (384,{y}): rgb({r},{g},{b})")

# ── Find where text area naturally sits by sampling rows ──
print("\n--- Cream area right of circle, y=560..870, x=300 ---")
for y in range(560, 880, 20):
    r, g, b = arr[y, 300]
    print(f"  (300,{y}): rgb({r},{g},{b})")

# ── Save annotated debug image ──
overlay = img.copy()
draw = ImageDraw.Draw(overlay)

# Real circle
cx, cy, r = 160, 449, 118
draw.ellipse((cx-r, cy-r, cx+r, cy+r), outline="red", width=5)

# QR box (approximate)
if len(idxs) and len(qr_ys):
    draw.rectangle((idxs.min(), qr_ys.min(), idxs.max(), qr_ys.max()), outline="blue", width=5)

# Text start line
draw.line((40, 580, 728, 580), fill="green", width=3)

overlay.convert("RGB").save("static/temp-card/debug_real.png")
print("\nSaved debug_real.png")
