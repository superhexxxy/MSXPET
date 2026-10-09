"""Author MSXPET overlay accessories (pixel art via code — regenerable).
Writes full-canvas 32x32 RGBA PNGs + meta.json to Resources/overlays/.
Usage:
  python3 Tools/make_overlays.py            # build bundled overlays
  python3 Tools/make_overlays.py --template # blank template for custom art
Overlays draw OVER the sprite, pixel-aligned. See ASSETS.md.
"""
import json
import os
import sys

from PIL import Image

SIZE = 32
OUT = os.path.join(os.path.dirname(__file__), "..", "Sources", "MSXPET",
                   "Resources", "overlays")

T = None  # transparent
WHITE = (255, 255, 255, 255)
GRAY = (217, 217, 217, 255)
RED = (212, 42, 42, 255)
DRED = (165, 31, 31, 255)
DARK = (20, 20, 26, 255)
PURP = (43, 36, 64, 255)
ORANGE = (232, 130, 30, 255)


def blank():
    return [[T] * SIZE for _ in range(SIZE)]


def rect(px, x0, y0, x1, y1, color):
    for y in range(max(0, y0), min(SIZE, y1 + 1)):
        for x in range(max(0, x0), min(SIZE, x1 + 1)):
            px[y][x] = color


def save(name, px, meta):
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pix = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if px[y][x] is not None:
                pix[x, y] = px[y][x]
    img.save(os.path.join(d, "overlay.png"))
    with open(os.path.join(d, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print(f"{name}/overlay.png + meta.json  {meta}")


def santa_hat():
    px = blank()
    # cone (red, dark right edge), widening downward
    rows = {7: (9, 22), 6: (10, 21), 5: (11, 20), 4: (12, 20)}
    for y, (a, b) in rows.items():
        rect(px, a, y, b, y, RED)
        px[y][b] = DRED
    # flop to the right
    rect(px, 14, 3, 20, 3, RED)
    rect(px, 16, 2, 22, 2, RED)
    px[2][22] = DRED
    # pom blob
    rect(px, 22, 0, 24, 0, WHITE)
    rect(px, 21, 1, 25, 2, WHITE)
    rect(px, 22, 3, 24, 3, WHITE)
    px[2][25] = GRAY
    px[3][24] = GRAY
    # brim
    rect(px, 8, 8, 23, 10, WHITE)
    rect(px, 8, 11, 23, 11, GRAY)
    rect(px, 8, 8, 8, 11, GRAY)
    return px


def witch_hat():
    px = blank()
    # cone (dark purple-black), tip leaning right
    rows = {9: (9, 22), 8: (10, 21), 7: (11, 20), 6: (12, 19),
            5: (12, 18), 4: (13, 18), 3: (13, 17), 2: (14, 16),
            1: (14, 17), 0: (15, 17)}
    for y, (a, b) in rows.items():
        rect(px, a, y, b, y, PURP)
    # orange band
    rect(px, 10, 8, 21, 8, ORANGE)
    # wide brim
    rect(px, 6, 10, 25, 10, DARK)
    rect(px, 5, 11, 26, 12, DARK)
    rect(px, 5, 12, 26, 12, DARK)
    return px


def shades():
    # Fitted to neko eyes (bars at x12/x18, rows 10-12). Species-gated.
    px = blank()
    for y in (9, 10, 11, 12):
        rect(px, 10, y, 15, y, DARK)
        rect(px, 17, y, 22, y, DARK)
    rect(px, 11, 13, 14, 13, DARK)  # taper
    rect(px, 18, 13, 21, 13, DARK)
    rect(px, 15, 10, 17, 11, DARK)  # bridge
    rect(px, 9, 11, 9, 11, DARK)    # temples
    rect(px, 23, 11, 23, 11, DARK)
    px[10][11] = WHITE  # glints
    px[10][18] = WHITE
    return px


def shades_band(x0, y0, x1, y1, glint):
    """Sunglasses band variant for a given face rect + glint point."""
    px = blank()
    B = (20, 20, 26, 255)
    W = (255, 255, 255, 255)
    rect(px, x0, y0, x1, y1, B)
    gx, gy = glint
    rect(px, gx, gy, gx + 1, gy + 1, W)
    return px


def save_img(name, img):
    img.save(os.path.join(OUT, "shades", name))
    print(f"shades/{name}")


def shades_variants():
    from PIL import Image as I
    def put(px):
        img = I.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        pix = img.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if px[y][x]:
                    pix[x, y] = px[y][x]
        return img
    # measured face bands (both stride frames covered)
    specs = {
        "walk_south.png": ((8, 12, 23, 17), (9, 13)),
        "walk_east_1.png": ((16, 10, 28, 15), (17, 11)),
        "walk_northeast.png": ((14, 7, 28, 12), (15, 8)),
        "walk_southeast.png": ((14, 9, 28, 14), (15, 10)),
        # leap frames throw the head far out: exact-frame variants
        "walk_northeast_1.png": ((19, 7, 29, 12), (20, 8)),
        "walk_southeast_1.png": ((19, 10, 29, 15), (20, 11)),
    }
    for name, (band, glint) in specs.items():
        east = put(shades_band(*band, glint))
        save_img(name, east)
        west = ("walk_northwest.png" if "northeast" in name else
                "walk_southwest.png" if "southeast" in name else None)
        if name.endswith("_1.png"):
            west = west.replace(".png", "_1.png") if west else None
        if name == "walk_east_1.png":
            west = "walk_west_1.png"
        if west:
            save_img(west, east.transpose(I.FLIP_LEFT_RIGHT))


def template():
    px = blank()
    # anchor guides: top-center cross + canvas border (deleted by artist)
    guide = (0, 255, 0, 255)
    for x in range(SIZE):
        px[0][x] = guide
        px[SIZE - 1][x] = guide
    for y in range(SIZE):
        px[y][0] = guide
        px[y][SIZE - 1] = guide
    px[2][16] = (255, 0, 0, 255)
    return px


if __name__ == "__main__":
    if "--template" in sys.argv:
        save("template", template(), {"note": "delete guides, draw 32x32 RGBA"})
    else:
        save("santa_hat", santa_hat(), {})
        save("witch_hat", witch_hat(), {})
        save("shades", shades(), {})
        shades_variants()
    print("done ->", os.path.abspath(OUT))
