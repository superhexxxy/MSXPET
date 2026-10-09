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
2. Draw the **front view** first (`overlay.png`): top-center is the head
   (hats live around rows 0–12); neko eyes sit at x12/x18, rows 10–12
   (see the `shades` overlay for reference).
3. **Side views**: front art stretched over a profile looks detached
   (lenses float off the face). Add directional variants as extra files
   in the same folder — `walk_east.png`, `walk_west.png` (mirror of east),
   etc., using the exact state directory names (`walk_north`,
   `walk_southwest`, …). Diagonals automatically borrow their cardinal
   (`walk_northeast` → `walk_east`); everything else uses `overlay.png`.
   Trace the matching pet frame (`pets/neko/walk_east/0.png`) so the
   accessory lands on the right pixels — neko profile eyes sit around
   x21–26, rows 9–14 (see `shades/walk_east.png`).
4. Export PNGs with transparency, drop the folder in, 🐾 → Accessories →
   Reload Assets. Done. Hats come off for naps and wall stunts automatically.
5. Regenerate the bundled set any time: `python3 Tools/make_overlays.py`
   (sources are shapes+rects in that script — fork it freely).

Shipped accessories: `santa_hat`, `witch_hat`, `shades` (+ profile
variants) — all opt-in from the Accessories menu. Walk-cycle bobble is
tracked automatically (per-frame translation vs each state's first frame),
so accessories ride the animation without extra work.

## New poses & states (neko framework)

Adding a behaviour pose (only neko is authored; other pets fall back to
the closest pose of their own art — see `PetState.fallbackState`):

1. Make 2 frames (A/B alternate for life: scramble, shimmy, batting).
   Derive from existing frames when possible — `Tools/make_poses.py`
   shows the pattern (raised paws from `happy`, scramble from `dragged`,
   hang from rotated `dragged`). 32×32 RGBA, same palette.
2. Save as `Resources/pets/neko/<state>/0.png`, `1.png` using the exact
   directory name (`swat`, `cling_side`, `cling_top`, …).
3. Add the case to `PetState` (`assetDirectoryName` + optional
   `fallbackState`), wire transitions in `PetEngine`, and preview with
   `Tools/preview.py <state>` (composites + anchor dots over every frame).

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
