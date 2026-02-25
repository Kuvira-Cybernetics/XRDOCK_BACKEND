"""
Pure-Python PNG writer to create XRDOCK logo icons without any external dependencies.
Writes a minimal PNG file using zlib compression.
"""
import zlib
import struct
import os

def write_png(filename, width, height, rgba_rows):
    """Write a minimal RGBA PNG file."""
    def png_chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    
    raw_data = b''
    for row in rgba_rows:
        raw_data += b'\x00'  # filter type: None
        raw_data += bytes(row)
    
    compressed = zlib.compress(raw_data, 9)
    
    signature = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    ihdr = png_chunk(b'IHDR', ihdr_data)
    idat = png_chunk(b'IDAT', compressed)
    iend = png_chunk(b'IEND', b'')
    
    with open(filename, 'wb') as f:
        f.write(signature + ihdr + idat + iend)

def make_xrdock_icon(size, dark_bg=False):
    """
    Create a simple XRDOCK icon:
    - Dark charcoal (#333) logo on white/transparent background
    - Or white logo on dark background for maskable
    """
    bg_color = [51, 51, 51, 255] if dark_bg else [255, 255, 255, 0]
    fg_color = [255, 255, 255, 255] if dark_bg else [51, 51, 51, 255]
    
    # Initialize all pixels to background
    pixels = [[list(bg_color) for _ in range(size)] for _ in range(size)]
    
    def draw_rect(x, y, w, h):
        for py in range(max(0, y), min(size, y + h)):
            for px in range(max(0, x), min(size, x + w)):
                pixels[py][px] = list(fg_color)
    
    def draw_circle(cx, cy, r, fill=True, hole_r=0):
        for py in range(max(0, cy - r), min(size, cy + r + 1)):
            for px in range(max(0, cx - r), min(size, cx + r + 1)):
                dist = ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5
                if fill and dist <= r:
                    if hole_r == 0 or dist > hole_r:
                        pixels[py][px] = list(fg_color)
                    else:
                        pixels[py][px] = list(bg_color)
    
    p = size // 10  # padding
    half = size // 2
    
    # TOP HALF: "XR"
    # X: left chevron
    t = size // 30  # thickness
    for i in range(size // 5):
        y_top = p + i
        y_bot = p + (size // 5) - 1 - i
        x_start = p + i * 2 // 3
        draw_rect(x_start, y_top, t * 4, t * 3)
        draw_rect(x_start, y_bot, t * 4, t * 3)
    
    # R: big circle with hole + leg
    r_cx = size * 3 // 4
    r_cy = p + size // 10
    r_r = size // 8
    draw_circle(r_cx, r_cy, r_r, fill=True, hole_r=r_r // 2)
    # leg of R
    draw_rect(r_cx, r_cy, r_r, r_r)
    draw_rect(r_cx + r_r // 2, r_cy, size - r_cx - r_r // 2 - p, t * 3)
    
    # BOTTOM HALF: "DOCK" - simplified as bold text blocks
    seg_w = (size - 2 * p) // 4
    bh = size // 5  # block height
    by = half + p  # block y start
    
    # D - rectangle + arc (simplified as rect)
    draw_rect(p, by, t * 3, bh)
    draw_circle(p + seg_w // 2, by + bh // 2, bh // 2, fill=True, hole_r=bh // 4)
    
    # O
    o_cx = p + seg_w + seg_w // 2
    draw_circle(o_cx, by + bh // 2, bh // 2, fill=True, hole_r=bh // 4)
    
    # C - arc (simplified as partial circle)
    c_cx = p + seg_w * 2 + seg_w // 2
    draw_circle(c_cx, by + bh // 2, bh // 2, fill=True, hole_r=bh // 4)
    draw_rect(c_cx, by, bh // 2 + t, bh)  # cut right side to make C
    
    # K - vertical bar + arrows
    k_x = p + seg_w * 3
    draw_rect(k_x, by, t * 3, bh)
    mid_y = by + bh // 2
    for i in range(bh // 2):
        draw_rect(k_x + t * 3 + i, mid_y - i, t * 2, t * 2)
        draw_rect(k_x + t * 3 + i, mid_y + i, t * 2, t * 2)
    
    rows = []
    for py in range(size):
        row = []
        for px in range(size):
            row.extend(pixels[py][px])
        rows.append(row)
    return rows

# Output paths
WEB = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\web"
ASSETS = r"d:\Peter Work Space\XRDOCK\XRDOCK_BACKEND\frontend\assets\images"
os.makedirs(ASSETS, exist_ok=True)

configs = [
    (os.path.join(WEB, "favicon.png"), 32, False),
    (os.path.join(WEB, "icons", "Icon-192.png"), 192, False),
    (os.path.join(WEB, "icons", "Icon-512.png"), 512, False),
    (os.path.join(WEB, "icons", "Icon-maskable-192.png"), 192, True),
    (os.path.join(WEB, "icons", "Icon-maskable-512.png"), 512, True),
    (os.path.join(ASSETS, "logo.png"), 256, False),
]

for path, sz, dark in configs:
    rows = make_xrdock_icon(sz, dark)
    write_png(path, sz, sz, rows)
    print(f"Written: {path} ({sz}x{sz})")

print("\nAll icons generated successfully!")
