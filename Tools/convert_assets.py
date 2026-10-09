"""XPM folder -> PNG converter for MSXPET (macOS AppKit needs PNG w/ alpha).
Upstream xpet ships pets/*/*.xpm ; AppKit wants PNGs.
Usage:
  pip install Pillow
  python3 Tools/convert_assets.py /path/to/xpet/pets Sources/MSXPET/Resources/pets
"""
import os
import sys

def convert_tree(input_dir: str, output_dir: str) -> int:
    from PIL import Image
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
                img = Image.open(src).convert("RGBA")
                dst = os.path.join(dst_dir, f.replace(".xpm", ".png"))
                img.save(dst)
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
