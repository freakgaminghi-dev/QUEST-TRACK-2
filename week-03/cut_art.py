"""Step 2: clean and cut the COCO picture.

Reads  art/sheet.png  (2x2 grid, fake checkerboard background, never changed)
Makes  art/poses/up.png, hit_left.png, hit_right.png, sleep.png

What it does:
  1. Cuts the sheet into 4 cells.
  2. Turns the painted checkerboard into real transparency
     (flood fill from the edges, stopping at COCO's dark outline).
  3. Softens the edge so there is no white fringe.
  4. Moves each cell so the drum is in exactly the same spot.
  5. Crops all 4 to the same size.

Run once:  python cut_art.py
"""

import os
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "art", "sheet.png")
OUT_DIR = os.path.join(HERE, "art", "poses")

# cell position in the sheet (column, row)
CELLS = {"up": (0, 0), "hit_left": (1, 0), "hit_right": (0, 1), "sleep": (1, 1)}

BG = 251  # average checkerboard brightness


def is_bg_like(p):
    """Light, almost gray pixel = checkerboard."""
    return min(p) >= 236 and max(p) - min(p) <= 12


def background_mask(img):
    w, h = img.size
    px = img.load()
    bg = bytearray(w * h)  # 1 = background

    # flood fill from every edge pixel
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if bg[i] or not is_bg_like(px[x, y]):
            continue
        bg[i] = 1
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))

    # Only the outside is background. White spots inside COCO's outline
    # (eye shines, drum bolts, name tag) stay solid.
    return bg


def cut_out(img):
    """Return an RGBA image with the checkerboard made transparent."""
    w, h = img.size
    px = img.load()
    bg = background_mask(img)
    out = Image.new("RGBA", (w, h))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if bg[i]:
                continue
            r, g, b = px[x, y]
            # edge pixels (next to background) get soft alpha, unblended from the bg
            near_bg = any(
                0 <= x + dx < w and 0 <= y + dy < h and bg[(y + dy) * w + x + dx]
                for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)
            )
            if near_bg:
                d = max(BG - r, BG - g, BG - b)
                a = max(0.0, min(1.0, d / 140))
                if a < 0.04:
                    continue
                if a < 1:
                    r, g, b = (max(0, min(255, round((c - BG * (1 - a)) / a))) for c in (r, g, b))
                opx[x, y] = (r, g, b, round(a * 255))
            else:
                opx[x, y] = (r, g, b, 255)
    return out


def drum_box(img):
    """Bounding box of the red drum (lower part of the cell)."""
    px = img.load()
    w, h = img.size
    xs, ys = [], []
    for y in range(int(h * 0.7), h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 200 and r > 190 and g < 110 and b < 90:
                xs.append(x); ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)


def main():
    sheet = Image.open(SRC).convert("RGB")
    cell = sheet.size[0] // 2
    cuts = {}
    for name, (cx, cy) in CELLS.items():
        print("cleaning", name)
        part = sheet.crop((cx * cell, cy * cell, (cx + 1) * cell, (cy + 1) * cell))
        cuts[name] = cut_out(part)

    # line every cell up with "up" using the drum
    ref = drum_box(cuts["up"])
    pad = 20
    aligned = {}
    for name, im in cuts.items():
        box = drum_box(im)
        dx = round(((ref[0] + ref[2]) - (box[0] + box[2])) / 2)
        dy = ref[3] - box[3]
        canvas = Image.new("RGBA", (cell + 2 * pad, cell + 2 * pad))
        canvas.paste(im, (pad + dx, pad + dy))
        aligned[name] = canvas
        print(f"  {name}: moved by ({dx}, {dy})")

    # same crop for all 4, square, with COCO centred left-right
    boxes = [im.getbbox() for im in aligned.values()]
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    side = max(x1 - x0, y1 - y0) + 8
    cx = (x0 + x1) // 2
    crop = (cx - side // 2, y1 + 4 - side, cx - side // 2 + side, y1 + 4)

    os.makedirs(OUT_DIR, exist_ok=True)
    for name, im in aligned.items():
        path = os.path.join(OUT_DIR, name + ".png")
        im.crop(crop).save(path)
        print("saved", path, im.crop(crop).size)


if __name__ == "__main__":
    main()
