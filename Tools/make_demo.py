"""Scripted showcase demo: walk-in, bubble, santa hat, laser chase, gotcha.
Regenerable showreel for the README (transparent GIF, monochrome).
Usage: python3 Tools/make_demo.py  ->  docs/assets/demo.gif
"""
import glob
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "assets",
                   "demo.gif")
RES = os.path.join(os.path.dirname(__file__), "..", "Sources", "MSXPET",
                   "Resources")

W, H, S = 480, 160, 3
CAT = 32 * S  # 96

# 5x7 pixel font, only what the script says (hewwo :3 / gotcha!)
FONT = {
    'h': ["#...#", "#...#", "####.", "#...#", "#...#", "#...#", "#...#"],
    'e': [".####", "#....", "#....", ".###.", "#....", "#....", ".####"],
    'w': ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#.", ".#.#."],
    'o': [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    ' ': [".....", ".....", ".....", ".....", ".....", ".....", "....."],
    ':': [".....", "..#..", ".....", ".....", "..#..", ".....", "....."],
    '3': [".####", "....#", "....#", ".###.", "....#", "....#", ".####"],
    'g': [".####", "#....", "#....", ".####", "....#", "#...#", ".###."],
    't': ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    'c': [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
    'a': [".###.", "....#", "....#", ".####", "#...#", "#...#", ".####"],
    '!': ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
}
BLACK = (17, 17, 17, 255)
WHITE = (255, 255, 255, 255)
RED = (230, 40, 40, 255)


def load(pet, state):
    fs = sorted(glob.glob(os.path.join(RES, "pets", pet, state, "*.png")))
    return [Image.open(f).convert("RGBA").resize((CAT, CAT), Image.NEAREST)
            for f in fs]


def text_w(s, sc=2):
    return len(s) * 6 * sc - sc


def bubble(base, cx, top_y, text):
    """White rounded bubble with pixel text, centered at cx."""
    sc = 2
    tw, th = text_w(text, sc), 7 * sc
    pad, w, h = 8, 0, 0
    w, h = tw + pad * 2, th + pad * 2
    b = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=8, fill=WHITE,
                        outline=BLACK, width=2)
    x = pad
    for ch in text:
        for r, row in enumerate(FONT[ch]):
            for c, v in enumerate(row):
                if v == "#":
                    d.rectangle([x + c * sc, pad + r * sc,
                                 x + (c + 1) * sc - 1, pad + (r + 1) * sc - 1],
                                fill=BLACK)
        x += 6 * sc
    base.alpha_composite(b, (int(cx - w / 2), int(top_y - h)))


def main():
    idle = load("neko", "idle")
    east = load("neko", "walk_east")
    happy = load("neko", "happy")
    hat = Image.open(os.path.join(RES, "overlays", "santa_hat",
                                  "overlay.png")).convert("RGBA")
    hat = hat.resize((CAT, CAT), Image.NEAREST)
    ground = H - 8  # feet line (sprite bottom)

    frames = []

    def cat_frame(sprites, k, x, hat_on=False):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sp = sprites[k % len(sprites)]
        img.paste(sp, (int(x), ground - CAT), sp)
        if hat_on:
            img.paste(hat, (int(x), ground - CAT), hat)
        return img, int(x)

    # Act 1: walk in from the left (24 ticks)
    x = -CAT
    for t in range(24):
        img, _ = cat_frame(east, t // 2, x)
        frames.append(img)
        x += 12
    # Act 2: settle + hewwo (16 ticks), hat pops on halfway
    for t in range(16):
        img, cx = cat_frame(idle, t // 4, x)
        if t >= 6:
            img.paste(hat, (cx, ground - CAT), hat)
        if t >= 2:
            bubble(img, cx + CAT / 2, ground - CAT + 6, "hewwo :3")
        frames.append(img)
    # Act 3: laser dot zips in, chase right — staged to stop mid-stage
    dot_x, cat_x = W + 10, x
    for t in range(30):
        dot_x = max(min(cat_x + 130, 380), dot_x - 14)
        cat_x = min(dot_x - 60, cat_x + 9, 300)
        img, cx = cat_frame(east, t // 2, cat_x, hat_on=True)
        d = ImageDraw.Draw(img)
        d.ellipse([dot_x - 5, ground - 40, dot_x + 5, ground - 30], fill=RED)
        d.ellipse([dot_x - 2, ground - 37, dot_x + 2, ground - 33], fill=WHITE)
        frames.append(img)
    # Act 4: GOTCHA — hold the catch so it reads, then exit together
    for t in range(10):
        img, cx = cat_frame(happy, t // 3, cat_x, hat_on=True)
        bubble(img, cx + CAT / 2, ground - CAT + 6, "gotcha!")
        d = ImageDraw.Draw(img)
        d.ellipse([dot_x - 5, ground - 40, dot_x + 5, ground - 30], fill=RED)
        d.ellipse([dot_x - 2, ground - 37, dot_x + 2, ground - 33], fill=WHITE)
        frames.append(img)
    for t in range(12):
        img, cx = cat_frame(east, t // 2, cat_x, hat_on=True)
        cat_x += 14
        dot_x += 14
        d = ImageDraw.Draw(img)
        d.ellipse([dot_x - 5, ground - 40, dot_x + 5, ground - 30], fill=RED)
        d.ellipse([dot_x - 2, ground - 37, dot_x + 2, ground - 33], fill=WHITE)
        frames.append(img)

    # trim dead tail so the loop restarts snappily
    while len(frames) > 2 and sum(
            1 for px in frames[-1].getdata() if px[3] > 20) < 300:
        frames.pop()
    frames[0].save(OUT, save_all=True, append_images=frames[1:],
                   duration=100, loop=0, transparency=0, disposal=2)
    print(f"{len(frames)} frames -> {OUT} "
          f"({os.path.getsize(OUT) // 1024}KB)")


if __name__ == "__main__":
    main()
