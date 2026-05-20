from PIL import Image
import os

def process_spritesheet(input_path, output_path, cols, rows):
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    frame_w = width // cols
    frame_h = height // rows

    new_img = Image.new("RGBA", (frame_w * cols, frame_h * rows), (0, 0, 0, 0))

    for r in range(rows):
        for c in range(cols):
            box = (c * frame_w, r * frame_h, (c + 1) * frame_w, (r + 1) * frame_h)
            frame = img.crop(box)
            # The new sheet is already aligned; keep each frame exactly in its cell.
            new_img.paste(frame, box[:2], frame)

    new_img.save(output_path)

print("Processing spritesheet...")
process_spritesheet('assets/player_running.png', 'assets/player_running.png', 4, 4)
print("Done!")
