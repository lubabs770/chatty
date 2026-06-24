#!/usr/bin/env python3
"""Render Chatty's app icon: an orange speech bubble with a typing indicator
on a deep-maroon rounded square. Original art, maroon/orange palette."""
from PIL import Image, ImageDraw

SCALE = 4                      # supersample for smooth edges
S = 1024 * SCALE
MAROON = (58, 14, 14, 255)     # #3A0E0E background
ORANGE = (255, 140, 26, 255)   # #FF8C1A bubble

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Rounded-square background (macOS squircle-ish), slight transparent margin.
m = int(54 * SCALE)
d.rounded_rectangle([m, m, S - m, S - m], radius=int(200 * SCALE), fill=MAROON)

# Speech bubble body.
bx0, by0, bx1, by1 = (int(v * SCALE) for v in (250, 300, 774, 650))
d.rounded_rectangle([bx0, by0, bx1, by1], radius=int(96 * SCALE), fill=ORANGE)

# Bubble tail (points down-left).
tail = [(int(330 * SCALE), int(610 * SCALE)),
        (int(470 * SCALE), int(610 * SCALE)),
        (int(322 * SCALE), int(772 * SCALE))]
d.polygon(tail, fill=ORANGE)

# Three "typing" dots punched in maroon.
cy = int(478 * SCALE)
r = int(42 * SCALE)
for cx in (int(382 * SCALE), int(512 * SCALE), int(642 * SCALE)):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MAROON)

master = img.resize((1024, 1024), Image.LANCZOS)
master.save("icon/icon_1024.png")
print("wrote icon/icon_1024.png")
