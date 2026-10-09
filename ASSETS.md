# MSXPET Custom Assets & Sounds

No rebuild needed for any of this: drop files in, hit reload in the 🐾 menu.

## Accessories (overlays)

An accessory is a folder with a full-canvas **32×32 RGBA PNG** drawn over
the sprite, pixel-aligned (same canvas as the pets, so anything you draw
lines up with the cat exactly). Simple rule: **ticked on = displayed** —
no seasons, no per-pet gating, no surprises:

```
MyHat/
  overlay.png   # 32x32, transparent everywhere except the accessory
  meta.json     # optional, currently just {} (reserved for later)
```

Two homes (user folder wins on name clashes):

- Bundled: `Sources/MSXPET/Resources/overlays/<name>/` (ships with the app)
- Yours: `~/Library/Application Support/MSXPET/Overlays/<name>/`

Then 🐾 → Accessories → tick it on. **Reload Assets** rescans without
restarting. **Reveal Overlays Folder** opens yours in Finder.

Making one (5 minutes, free):

1. `python3 Tools/make_overlays.py --template` gives you a 32×32 guide, or
   just open any pet frame (`Resources/pets/neko/idle/0.png`) as tracing
   reference in **Piskel** (piskelapp.com), Aseprite, or GIMP.
2. Draw on a 32×32 canvas. Top-center is the head (hats live around
   rows 0–12); neko eyes sit at x12/x18, rows 10–12 (see the `shades`
   overlay for reference).
3. Export PNG with transparency, add `meta.json`, drop in, reload. Done.
4. Regenerate the bundled set any time: `python3 Tools/make_overlays.py`
   (sources are shapes+rects in that script — fork it freely).

Shipped accessories: `santa_hat`, `witch_hat`, `shades` — all opt-in
from the Accessories menu. Overlays track the head: each frame's anchor
is measured at load, so hats ride the walk-cycle bobble automatically.

## Sounds

Events and their files (`<event>.wav`, 8 total):

| event    | when                    |
|----------|-------------------------|
| `grab`   | picked up               |
| `happy`  | petted (clicked)        |
| `land`   | fling landing           |
| `pounce` | cursor pounce (`!`)     |
| `laserOn` / `laserOff` | laser toggle |
| `wake`   | woken from sleep        |
| `purr`   | looped while ANY pet sleeps (seamless 1.2s loop) |

Custom uploads: drop `<event>.wav` (or `.mp3`/`.m4a`/`.aiff`) into
`~/Library/Application Support/MSXPET/Sounds/` — 🐾 → Custom Sounds →
Reveal Sounds Folder. Lookup is live per play (no reload step needed);
user files always beat bundled ones. Keep replacements short (<0.5s) and
gentle — this pet lives on your desktop all day.

The bundled set is synthesized, not recorded: `python3 Tools/make_sounds.py`
(stdlib only) regenerates all 8 from sine sweeps + envelopes — tweak
frequencies and re-run to taste.

Toggle: 🐾 → Sound on/off (persisted; also silences the purr).
