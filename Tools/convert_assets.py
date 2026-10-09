"""XPM folder -> PNG converter for MSXPET (macOS AppKit needs PNG w/ alpha).
Upstream xpet ships pets/*/*.xpm ; AppKit wants PNGs.
Usage:
  pip install Pillow
  python3 Tools/convert_assets.py /path/to/xpet/pets Sources/MSXPET/Resources/pets

NOTE: Pillow's XpmImagePlugin fails on upstream files (palette.index bug),
so this uses a small purpose-built XPM parser (upstream uses only
hex colours + None, 1 char-per-pixel). Pillow is used only for PNG writing.
"""
import os
import re
import sys


def parse_xpm(path: str):
    """Return (width, height, colormap, rows). Colormap: symbol -> (r,g,b,a)."""
    with open(path, "r") as f:
        text = f.read()
    strings = re.findall(r'"(.*)"', text)
    if not strings:
        raise ValueError("no quoted strings found")
    w, h, ncolors, cpp = map(int, strings[0].split())
    color_lines = strings[1:1 + ncolors]
    pixel_rows = strings[1 + ncolors:1 + ncolors + h]
    if len(pixel_rows) < h:
        raise ValueError(f"expected {h} rows, got {len(pixel_rows)}")

    cmap = {}
    for line in color_lines:
        sym = line[:cpp]
        rest = line[cpp:].strip()
        # format: "c <spec>" (upstream never uses multi-key "m"/"s" entries)
        m = re.search(r"c\s+(\S+)", rest)
        spec = m.group(1) if m else "None"
        if spec.lower() == "none":
            cmap[sym] = (0, 0, 0, 0)
        elif spec.startswith("#"):
            hexv = spec[1:]
            if len(hexv) == 3:  # #rgb shorthand
                hexv = "".join(c * 2 for c in hexv)
            r, g, b = int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16)
            cmap[sym] = (r, g, b, 255)
        else:
            raise ValueError(f"unsupported colour spec: {spec!r} in {path}")
    return w, h, cmap, pixel_rows


def xpm_to_png(src: str, dst: str) -> None:
    from PIL import Image
    w, h, cmap, rows = parse_xpm(src)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y, row in enumerate(rows):
        for x in range(w):
            sym = row[x * 1:(x + 1) * 1]  # cpp is always 1 upstream
            try:
                px[x, y] = cmap[sym]
            except KeyError:
                raise ValueError(f"unknown symbol {sym!r} in {src}")
    img.save(dst)


def convert_tree(input_dir: str, output_dir: str) -> int:
    count = 0
    for root, _, files in os.walk(input_dir):
        for f in files:
            if not f.endswith(".xpm"):
                continue
            src = os.path.join(root, f)
            rel = os.path.relpath(root, input_dir)
            dst_dir = os.path.join(output_dir, rel)
            os.makedirs(dst_dir, exist_ok=True)
            try:
                dst = os.path.join(dst_dir, f.replace(".xpm", ".png"))
                xpm_to_png(src, dst)
                print(f"OK {src} -> {dst}")
                count += 1
            except Exception as e:  # noqa: BLE001
                print(f"FAIL {src}: {e}", file=sys.stderr)
    return count

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    n = convert_tree(sys.argv[1], sys.argv[2])
    print(f"converted {n} files")
    sys.exit(0 if n > 0 else 1)
