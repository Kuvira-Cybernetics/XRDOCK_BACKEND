"""
Script to create XRDOCK logo PNG from SVG using cairosvg or Pillow.
Falls back to creating a simple PNG directly with Pillow if cairosvg unavailable.
"""
import subprocess
import sys
import os

# Try to install cairosvg
try:
    import cairosvg
    HAS_CAIRO = True
except ImportError:
    HAS_CAIRO = False

try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False

SVG_PATH = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web\xrdock_logo.svg"
FAVICON_PATH = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web\favicon.png"
ICON_192 = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web\icons\Icon-192.png"
ICON_512 = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web\icons\Icon-512.png"
ICON_M192 = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web\icons\Icon-maskable-192.png"
ICON_M512 = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web\icons\Icon-maskable-512.png"
ASSETS_DIR = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\assets\images"

os.makedirs(ASSETS_DIR, exist_ok=True)

if HAS_CAIRO:
    print("Using cairosvg...")
    cairosvg.svg2png(url=SVG_PATH, write_to=FAVICON_PATH, output_width=32, output_height=32)
    cairosvg.svg2png(url=SVG_PATH, write_to=ICON_192, output_width=192, output_height=192)
    cairosvg.svg2png(url=SVG_PATH, write_to=ICON_512, output_width=512, output_height=512)
    cairosvg.svg2png(url=SVG_PATH, write_to=ICON_M192, output_width=192, output_height=192)
    cairosvg.svg2png(url=SVG_PATH, write_to=ICON_M512, output_width=512, output_height=512)
    cairosvg.svg2png(url=SVG_PATH, write_to=os.path.join(ASSETS_DIR, "logo.png"), output_width=256, output_height=256)
    print("Done! All icons generated.")
elif HAS_PILLOW:
    print("cairosvg unavailable. Creating logo with Pillow...")
    def make_logo(size, bg=(255,255,255,0)):
        img = Image.new("RGBA", (size, size), bg)
        draw = ImageDraw.Draw(img)
        color = (51, 51, 51, 255)
        # Draw "XR" text row and "DOCK" text row simply
        try:
            font_big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", size // 3)
        except:
            font_big = ImageFont.load_default()
        draw.text((size*0.05, size*0.05), "XR", fill=color, font=font_big)
        draw.text((size*0.05, size*0.55), "DOCK", fill=color, font=font_big)
        return img
    
    for path, sz in [(FAVICON_PATH,32),(ICON_192,192),(ICON_512,512),(ICON_M192,192),(ICON_M512,512)]:
        bg = (51,51,51,255) if "maskable" in path else (255,255,255,0)
        img = make_logo(sz, bg)
        img.save(path)
    make_logo(256).save(os.path.join(ASSETS_DIR, "logo.png"))
    print("Done! Basic Pillow logo generated.")
else:
    print("Neither cairosvg nor Pillow available.")
    print("Please run: pip install cairosvg  OR  pip install Pillow")
