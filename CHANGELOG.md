# Changelog

All notable changes to MSXPET, newest first. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] — First release 🎉

The whole pet, polished and production-ready.

### Alive
- Wandering, chasing, freezing, sleeping, dragging — faithful AppKit port
  of the upstream X11 state machine (`PetEngine`: pure, deterministic,
  headless-tested)
- Mood system (blissful → grumpy, visible in the menu), day/night energy
  rhythm, cursor pouncing, begging for pats (click = sits + purrs),
  unprompted ambient chatter, startle flinches, grooming breaks, zoomies
- Inter-cat life: greetings, chase invitations, scripted dialogues
- Playable physics: fling-to-fall with bounces, wall-cling scrambles with
  rare recoveries, laser pointer with pack formation, separation and
  paw-bat catches (*"gotcha!"*)
- Snacks (`Give snack` — wakes sleepers), hover affection, name tags,
  custom names, launch greeting

### Feel & performance
- 1:1 absolute-position dragging (no drift), hysteresis-filtered walk
  sprites (no 60Hz flicker), modal happy/swat flashes, stall watchdog
  against treadmilling
- Adaptive tick (60Hz → 10Hz → 1Hz), sleep on screen lock, ~1% CPU idle
- Speech bubbles that follow the pet; per-pixel click-through windows

### Dress-up & sound
- Accessory overlays (drop-in PNGs, directional + per-frame variants,
  head-tracked through the walk cycle): santa hat, witch hat, shades
- Synthesized cute sound set + seamless sleep-purr loop, on/off toggle,
  custom uploads from `~/Library/Application Support/MSXPET/Sounds/`
- No Dock icon, menu-bar controls, open-at-login, app icon

### Create
- **Asset Studio** (`/MSXPET/studio.html`): pixel editor for hats AND
  full pets (states, frames, onion skin, mirror, ghost refs), animated
  previews, exact-filename downloads, bundled-art gallery + remix
- `ASSETS.md` guide (variants, poses, sounds), `Tools/` generators
  (sounds, overlays, poses, previews), `CONTRIBUTING.md`

### Ship-shape
- SwiftPM build (no Xcode project), `.app` bundler, CI + Release
  workflows, Homebrew cask, project page + social assets
