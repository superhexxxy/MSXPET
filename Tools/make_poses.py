"""Author new neko poses by editing existing frames (guaranteed style match).
Writes Resources/pets/neko/{swat,cling_side,cling_top}/*.png (2 frames each).
Usage: python3 Tools/make_poses.py
Poses:
  swat       A/B alternating raised paws (laser catch) from happy/0
  cling_side A/B scrambling arms (wall cling) from dragged frames
  cling_top  A/B hanging shimmy (top cling) from rotated dragged frames
"""
import os

from PIL import Image

PETS = os.path.join(os.path.dirname(__file__), "..", "Sources", "MSXPET",
                    "Resources", "pets", "neko")
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)


def load(state, i):
    return Image.open(os.path.join(PETS, state, f"{i}.png")).convert("RGBA")


def save(state, i, img):
    d = os.path.join(PETS, state)
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, f"{i}.png"))
    print(f"{state}/{i}.png")


def paw(img, x0, x1):
    """Raised paw: black outline bar with white inset, rows 2..9."""
    px = img.load()
    for y in range(2, 10):
        for x in range(x0, x1 + 1):
            px[x, y] = BLACK
    for y in range(3, 9):
        for x in range(x0 + 1, x1):
            px[x, y] = WHITE


def make_swat():
    base = load("happy", 0)
    a = base.copy()
    paw(a, 3, 6)    # left paw up
    b = base.copy()
    paw(b, 25, 28)  # right paw up
    save("swat", 0, a)
    save("swat", 1, b)


def scramble(img, up_left=True):
    """Shift arm bands vertically, opposite sides opposite ways."""
    px = img.load()
    out = img.copy()
    po = out.load()
    bands = [(range(8, 15), range(0, 11), -1 if up_left else 1),
             (range(8, 15), range(20, 32), 1 if up_left else -1)]
    for ys, xs, dy in bands:
        for y in ys:
            for x in xs:
                if px[x, y][3] > 20:
                    po[x, y] = (0, 0, 0, 0)
                    if 0 <= y + dy < 32:
                        po[x, y + dy] = px[x, y]
    return out


def make_cling_side():
    save("cling_side", 0, scramble(load("dragged", 0), True))
    save("cling_side", 1, scramble(load("dragged", 1), False))


def make_cling_top():
    a = load("dragged", 0).transpose(Image.ROTATE_180)
    b = load("dragged", 1).transpose(Image.ROTATE_180)
    # shimmy: B shifted 1px (alternate grip)
    shim = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    shim.paste(b, (1, 0), b)
    save("cling_top", 0, a)
    save("cling_top", 1, shim)


if __name__ == "__main__":
    make_swat()
    make_cling_side()
    make_cling_top()
    print("done")
