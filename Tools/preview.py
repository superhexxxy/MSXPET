"""Preview pet frames with overlays + anchor dots (the asset-creation loop).
Usage:
  python3 Tools/preview.py neko walk_east [shades]   # frames + overlay + anchors
  python3 Tools/preview.py neko swat                 # new pose check
Saves /tmp/msxpet_preview.png
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

RES = os.path.join(os.path.dirname(__file__), "..", "Sources", "MSXPET",
                   "Resources")


def top(path):
    px = Image.open(path).convert("RGBA").load()
    miny = min((y for y in range(32) for x in range(32) if px[x, y][3] > 20),
               default=0)
    xs = [x for y in range(miny, min(32, miny + 3))
          for x in range(32) if px[x, y][3] > 20]
    return (sum(xs) / len(xs), miny) if xs else (16, 0)


def main(pet, state, overlay=None):
    fs = sorted(glob.glob(os.path.join(RES, "pets", pet, state, "*.png")))
    if not fs:
        print(f"no frames: {pet}/{state}")
        sys.exit(1)
    ov = None
    if overlay:
        opath = os.path.join(RES, "overlays", overlay, f"{state}.png")
        if not os.path.exists(opath):
            opath = os.path.join(RES, "overlays", overlay, "overlay.png")
        ov = Image.open(opath).convert("RGBA") if os.path.exists(opath) else None
    a0 = top(fs[0])
    cells = []
    for f in fs:
        base = Image.open(f).convert("RGBA")
        a = top(f)
        comp = base.copy()
        if ov:
            big = ov.resize((64, 64), Image.NEAREST)
            comp.paste(big, (round((a[0] - a0[0]) * 2), round((a[1] - a0[1]) * 2)), big)
        cell = comp.resize((128, 128), Image.NEAREST)
        d = ImageDraw.Draw(cell)
        ax, ay = round(a[0] * 4), round(a[1] * 4)  # anchor dot (red)
        d.ellipse([ax - 3, ay - 3, ax + 3, ay + 3], fill=(255, 0, 0, 255))
        cells.append(cell)
    sheet = Image.new("RGBA", (128 * len(cells), 148), (30, 30, 30, 255))
    d = ImageDraw.Draw(sheet)
    d.text((4, 2), f"{pet}/{state}" + (f" + {overlay}" if overlay else ""),
           fill=(255, 255, 0, 255))
    for i, c in enumerate(cells):
        sheet.paste(c, (i * 128, 20), c)
    sheet.save("/tmp/msxpet_preview.png")
    print(f"{len(cells)} frames, anchor0={a0} -> /tmp/msxpet_preview.png")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
