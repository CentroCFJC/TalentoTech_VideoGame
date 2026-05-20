"""Generate proper PNG placeholder sprites for the platformer."""
import struct, zlib, os

def create_png(width, height, pixels, filepath):
    """Create a minimal PNG file. pixels is a list of (r,g,b,a) tuples, row-major."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack('>I', len(data)) + c + crc

    header = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))

    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter byte
        for x in range(width):
            idx = y * width + x
            r, g, b, a = pixels[idx]
            raw += struct.pack('BBBB', r, g, b, a)

    idat = chunk(b'IDAT', zlib.compress(raw))
    iend = chunk(b'IEND', b'')

    with open(filepath, 'wb') as f:
        f.write(header + ihdr + idat + iend)

def make_player():
    """32x32 blue character."""
    w, h = 32, 32
    pixels = [(0,0,0,0)] * (w * h)

    def fill(x1, y1, x2, y2, color):
        for y in range(max(0,y1), min(h,y2)):
            for x in range(max(0,x1), min(w,x2)):
                pixels[y*w+x] = color

    # Body
    fill(10, 10, 22, 26, (30, 120, 230, 255))
    # Head
    fill(11, 2, 21, 12, (60, 140, 240, 255))
    # Helmet top
    fill(11, 2, 21, 5, (100, 180, 255, 255))
    # Eyes
    fill(13, 6, 16, 9, (255, 255, 255, 255))
    fill(17, 6, 20, 9, (255, 255, 255, 255))
    fill(14, 7, 16, 9, (20, 20, 40, 255))
    fill(18, 7, 20, 9, (20, 20, 40, 255))
    # Arms
    fill(6, 12, 10, 22, (30, 100, 200, 255))
    fill(22, 12, 26, 22, (30, 100, 200, 255))
    # Legs
    fill(10, 26, 15, 31, (20, 60, 160, 255))
    fill(17, 26, 22, 31, (20, 60, 160, 255))
    # Belt
    fill(10, 20, 22, 22, (220, 180, 40, 255))
    # Belt buckle
    fill(14, 20, 18, 22, (255, 220, 60, 255))

    create_png(w, h, pixels, os.path.join(ASSETS, 'player.png'))

def make_enemy():
    """32x32 red slime."""
    w, h = 32, 32
    pixels = [(0,0,0,0)] * (w * h)

    def fill(x1, y1, x2, y2, color):
        for y in range(max(0,y1), min(h,y2)):
            for x in range(max(0,x1), min(w,x2)):
                pixels[y*w+x] = color

    # Slime body (rounded blob)
    cx, cy = 16, 18
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / 14.0
            dy = (y - cy) / 11.0
            if dx*dx + dy*dy <= 1.0 and y >= 6:
                shade = int(200 - dy * 40)
                pixels[y*w+x] = (shade, 30, 30, 255)

    # Flat bottom
    fill(4, 26, 28, 30, (160, 20, 20, 255))
    # Eyes
    fill(8, 13, 13, 18, (255, 255, 255, 255))
    fill(19, 13, 24, 18, (255, 255, 255, 255))
    # Pupils
    fill(10, 14, 12, 17, (20, 0, 0, 255))
    fill(21, 14, 23, 17, (20, 0, 0, 255))
    # Angry eyebrows
    fill(7, 11, 14, 13, (120, 0, 0, 255))
    fill(18, 11, 25, 13, (120, 0, 0, 255))
    # Highlight
    fill(8, 8, 12, 10, (255, 100, 100, 255))

    create_png(w, h, pixels, os.path.join(ASSETS, 'enemy.png'))

def make_powerup():
    """16x16 golden gem."""
    w, h = 16, 16
    pixels = [(0,0,0,0)] * (w * h)

    # Diamond shape
    cx, cy = 8, 8
    for y in range(h):
        for x in range(w):
            dist = abs(x - cx) + abs(y - cy)
            if dist <= 7:
                if dist <= 4:
                    pixels[y*w+x] = (255, 240, 80, 255)  # bright center
                elif dist <= 6:
                    pixels[y*w+x] = (240, 200, 40, 255)  # mid
                else:
                    pixels[y*w+x] = (200, 160, 20, 255)  # edge

    # Sparkle
    for pos in [(8,4), (8,12), (4,8), (12,8)]:
        x, y = pos
        if 0 <= x < w and 0 <= y < h:
            pixels[y*w+x] = (255, 255, 255, 255)
    # Center
    pixels[8*w+8] = (255, 255, 255, 255)
    pixels[7*w+8] = (255, 255, 240, 255)
    pixels[8*w+7] = (255, 255, 240, 255)

    create_png(w, h, pixels, os.path.join(ASSETS, 'powerup.png'))

ASSETS = r'c:\Users\Centro de Ciencia\Desktop\godot\plataform-test\assets'
os.makedirs(ASSETS, exist_ok=True)
make_player()
make_enemy()
make_powerup()
print("All sprites created successfully!")
