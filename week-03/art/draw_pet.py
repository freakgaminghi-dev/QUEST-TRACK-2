"""Draws the desktop pet sprite sheet (2x2 grid, transparent background).

Uses only the Python standard library, so nothing needs to be installed.
Run:  python draw_pet.py
Makes: pet_sheet.png (1024 x 1024, each cell 512 x 512)

Cells:
  top-left     = both paws up
  top-right    = left paw (on screen) hits the drum, right paw up
  bottom-left  = right paw (on screen) hits the drum, left paw up
  bottom-right = both paws resting on the drum, eyes closed (dozing)

The body, face and drum are drawn by the same code in every cell,
so they are in exactly the same place. Only paws and eyes change.
"""

import math
import os
import struct
import zlib

CELL = 512
W = 7  # outline thickness in pixels

# colors
OUTLINE = (0x3B, 0x24, 0x16)
FUR = (0xE0, 0xA8, 0x6E)
EAR = (0xB9, 0x7A, 0x45)
CREAM = (0xFF, 0xF0, 0xD8)
PINK = (0xF4, 0x9A, 0xA5)
PAD = (0xE8, 0x83, 0x8C)
DARK = (0x2B, 0x1A, 0x10)
WHITE = (0xFF, 0xFF, 0xFF)
RED = (0xE8, 0x55, 0x45)
GOLD = (0xF5, 0xC2, 0x42)
DRUMHEAD = (0xFF, 0xF6, 0xE6)


# ---------- shapes (signed distance: negative = inside) ----------

def ellipse(cx, cy, rx, ry, rot=0.0):
    c, s = math.cos(-rot), math.sin(-rot)

    def f(x, y):
        dx, dy = x - cx, y - cy
        if rot:
            dx, dy = dx * c - dy * s, dx * s + dy * c
        k0 = math.hypot(dx / rx, dy / ry)
        k1 = math.hypot(dx / (rx * rx), dy / (ry * ry))
        if k1 == 0:
            return -min(rx, ry)
        return k0 * (k0 - 1) / k1

    r = max(rx, ry)
    return f, (cx - r, cy - r, cx + r, cy + r)


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def capsule(ax, ay, bx, by, r):
    vx, vy = bx - ax, by - ay
    vv = vx * vx + vy * vy or 1e-9

    def f(x, y):
        px, py = x - ax, y - ay
        t = max(0.0, min(1.0, (px * vx + py * vy) / vv))
        return math.hypot(px - vx * t, py - vy * t) - r

    return f, (min(ax, bx) - r, min(ay, by) - r, max(ax, bx) + r, max(ay, by) + r)


def box(cx, cy, hw, hh, rad=0.0):
    def f(x, y):
        qx = abs(x - cx) - hw + rad
        qy = abs(y - cy) - hh + rad
        return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - rad

    return f, (cx - hw, cy - hh, cx + hw, cy + hh)


def union(*shapes):
    fs = [s[0] for s in shapes]

    def f(x, y):
        return min(g(x, y) for g in fs)

    bb = (min(s[1][0] for s in shapes), min(s[1][1] for s in shapes),
          max(s[1][2] for s in shapes), max(s[1][3] for s in shapes))
    return f, bb


def polyline(points, r):
    return union(*[capsule(*points[i], *points[i + 1], r) for i in range(len(points) - 1)])


def arc(cx, cy, rad, t0, t1, r, n=14):
    pts = [(cx + rad * math.cos(t0 + (t1 - t0) * i / n),
            cy + rad * math.sin(t0 + (t1 - t0) * i / n)) for i in range(n + 1)]
    return polyline(pts, r)


# ---------- canvas ----------

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        n = w * h
        # premultiplied color
        self.r = [0.0] * n
        self.g = [0.0] * n
        self.b = [0.0] * n
        self.a = [0.0] * n

    def paint(self, shape, color, alpha=1.0, grow=0.0):
        f, (x0, y0, x1, y1) = shape
        pad = grow + 2
        x0 = max(0, int(x0 - pad)); y0 = max(0, int(y0 - pad))
        x1 = min(self.w, int(x1 + pad) + 1); y1 = min(self.h, int(y1 + pad) + 1)
        cr, cg, cb = (c / 255 for c in color)
        R, G, B, A, w = self.r, self.g, self.b, self.a, self.w
        for y in range(y0, y1):
            for x in range(x0, x1):
                d = f(x + 0.5, y + 0.5) - grow
                if d >= 0.5:
                    continue
                k = (0.5 - d if d > -0.5 else 1.0) * alpha
                i = y * w + x
                inv = 1 - k
                R[i] = cr * k + R[i] * inv
                G[i] = cg * k + G[i] * inv
                B[i] = cb * k + B[i] * inv
                A[i] = k + A[i] * inv

    def shape(self, shape, fill, outline=W):
        if outline:
            self.paint(shape, OUTLINE, grow=outline)
        self.paint(shape, fill)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            src = y * other.w
            dst = (y + oy) * self.w + ox
            for arr_d, arr_s in ((self.r, other.r), (self.g, other.g),
                                 (self.b, other.b), (self.a, other.a)):
                arr_d[dst:dst + other.w] = arr_s[src:src + other.w]

    def save_png(self, path):
        rows = bytearray()
        for y in range(self.h):
            rows.append(0)
            for x in range(self.w):
                i = y * self.w + x
                a = self.a[i]
                if a <= 0:
                    rows += b"\0\0\0\0"
                    continue
                rows += bytes((min(255, round(self.r[i] / a * 255)),
                               min(255, round(self.g[i] / a * 255)),
                               min(255, round(self.b[i] / a * 255)),
                               min(255, round(a * 255))))

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data +
                    struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as fh:
            fh.write(png)


# ---------- the puppy ----------

MID = CELL / 2  # 256, center line


def raised_arm(c, s):
    """s = -1 for the paw on the left of the screen, +1 for the right."""
    sx, sy = MID + s * 86, 300
    px, py = MID + s * 158, 118
    c.shape(union(capsule(sx, sy, px, py, 24), circle(px, py, 34)), FUR)
    # paw pads (palm faces us)
    c.paint(ellipse(px, py + 9, 13, 10), PAD)
    for dx, dy in ((-15, -10), (0, -16), (15, -10)):
        c.paint(circle(px + dx, py + dy, 6.5), PAD)


def drum_arm(c, s, pressing):
    sx, sy = MID + s * 80, 300
    if pressing:
        px, py, rx, ry = MID + s * 62, 358, 38, 22  # squashed: hitting the drum
    else:
        px, py, rx, ry = MID + s * 62, 352, 34, 25  # just resting
    c.shape(union(capsule(sx, sy, px, py - 6, 22), ellipse(px, py, rx, ry)), FUR)
    for dx in (-11, 11):
        c.paint(capsule(px + dx, py + 8, px + dx, py + ry - 3, 2.5), OUTLINE)


def draw_cell(pose):
    c = Canvas(CELL, CELL)
    up = {"up": (-1, 1), "hit_left": (1,), "hit_right": (-1,), "sleep": ()}[pose]
    hit = {"up": (), "hit_left": (-1,), "hit_right": (1,), "sleep": ()}[pose]

    # tail, back feet, body
    c.shape(capsule(352, 365, 410, 318, 15), FUR)
    for x in (118, CELL - 118):
        c.shape(ellipse(x, 462, 36, 24), FUR)
    c.shape(ellipse(MID, 330, 120, 110), FUR)
    c.paint(ellipse(MID, 335, 66, 52), CREAM)

    # floppy ears
    c.shape(ellipse(140, 200, 38, 70, 0.35), EAR)
    c.shape(ellipse(CELL - 140, 200, 38, 70, -0.35), EAR)

    # raised paws go behind the head
    for s in up:
        raised_arm(c, s)

    # drum
    c.shape(ellipse(MID, 465, 130, 30), GOLD)
    c.shape(union(box(MID, 406, 130, 46), ellipse(MID, 452, 130, 30)), RED)
    for x in (178, MID, CELL - 178):
        c.shape(box(x, 408, 7, 26, 6), GOLD, outline=4)
    c.shape(ellipse(MID, 360, 130, 30), GOLD)
    c.shape(ellipse(MID, 360, 116, 23), DRUMHEAD, outline=4)

    # paws on the drum
    for s in hit:
        drum_arm(c, s, pressing=True)
    if pose == "sleep":
        drum_arm(c, -1, pressing=False)
        drum_arm(c, 1, pressing=False)

    # head and face
    c.shape(ellipse(MID, 190, 125, 108), FUR)
    c.shape(ellipse(MID, 238, 60, 44), CREAM, outline=5)
    for x in (178, CELL - 178):
        c.paint(ellipse(x, 240, 18, 11), PINK, alpha=0.6)
    c.paint(ellipse(MID, 218, 21, 15), DARK)
    c.paint(ellipse(MID - 6, 213, 6, 4), WHITE, alpha=0.85)
    c.paint(capsule(MID, 230, MID, 240, 3.5), OUTLINE)
    c.paint(arc(MID - 12, 240, 12, 0, math.pi, 3.5), OUTLINE)
    c.paint(arc(MID + 12, 240, 12, 0, math.pi, 3.5), OUTLINE)

    # eyes
    for x in (200, CELL - 200):
        if pose == "sleep":
            c.paint(arc(x, 178, 15, 0.12 * math.pi, 0.88 * math.pi, 4.5), OUTLINE)
        else:
            c.paint(ellipse(x, 180, 15, 19), DARK)
            c.paint(circle(x - 5, 172, 5.5), WHITE)
    return c


def main():
    sheet = Canvas(CELL * 2, CELL * 2)
    layout = [("up", 0, 0), ("hit_left", 1, 0), ("hit_right", 0, 1), ("sleep", 1, 1)]
    for pose, col, row in layout:
        print("drawing", pose)
        sheet.blit(draw_cell(pose), col * CELL, row * CELL)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pet_sheet.png")
    sheet.save_png(out)
    print("saved", out)


if __name__ == "__main__":
    main()
