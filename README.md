# MSXPET — Super Pawsome Desktop Pet

[![Release](https://img.shields.io/github/v/release/superhexxxy/MSXPET?label=release)](https://github.com/superhexxxy/MSXPET/releases) [![License](https://img.shields.io/github/license/superhexxxy/MSXPET)](LICENSE) [![Stars](https://img.shields.io/github/stars/superhexxxy/MSXPET?style=social)](https://github.com/superhexxxy/MSXPET/stargazers) [![Issues](https://img.shields.io/github/issues/superhexxxy/MSXPET)](https://github.com/superhexxxy/MSXPET/issues) [![Downloads](https://img.shields.io/github/downloads/superhexxxy/MSXPET/total)](https://github.com/superhexxxy/MSXPET/releases)

MSXPET is a native Apple Silicon desktop pet for macOS 13+ (ARM64). Cute, clever, and a little chaotic — your screen will never be the same. Run one or a clowder of 1–3 pets and watch them roam, nap, purr, and argue over the laser dot.

This project is a modern macOS reimagining of the classic X11 xpet experience, rewritten for AppKit and Apple Silicon. Inspired by [uint23/xpet](https://github.com/uint23/xpet).




## Quick highlights — why MSXPET is delightfully elite

- Playful behavior: roaming, chasing, freezing, snoozing, dreaming, grooming, zoomies, and cursor-triggered surprises
- Affection system: asks for pats, sits and purrs when you comply, and shifts mood when neglected
- Social: run 1–3 pets together; they chase, greet, and exchange multi-line dialogue
- Physics-forward: drag, fling, wall-cling, bounce — and sometimes stick the landing
- Customizable: hats, sunglasses, accessories, and user-supplied assets (PNG/WAV) without rebuilding
- Audio: built-in synthesized sounds plus support for custom WAV files
- Desktop-friendly: transparent click-through window, no Dock icon, pauses on screen lock

## Badges, swag, and screenshots

Want to show off MSXPET in your README? Grab a GIF or screenshot and drop it here. Example (replace with a real GIF):

![example-screenshot](https://raw.githubusercontent.com/superhexxxy/MSXPET/main/Resources/demo.gif)

## Install — the easiest ways

### Download a release

Get `MSXPET.zip` from the [Releases](https://github.com/superhexxxy/MSXPET/releases) page. On first launch, right-click the app and choose Open to allow an ad-hoc signed build.

If you prefer the command line, remove the quarantine flag and open the app:

```zsh
xattr -d com.apple.quarantine /Applications/MSXPET.app
open /Applications/MSXPET.app
```

### Build from source

Command Line Tools are enough; Xcode is optional.

```zsh
swift run                # run in development mode
zsh Scripts/build-app.sh # creates dist/MSXPET.app
open dist/MSXPET.app
```

## Controls (pawsome shortcuts)

| Action | What happens |
|---|---|
| Drag | She rides along and reacts to being carried |
| Fling | Gravity and physics take over (bounces, wall-clings) |
| Click / hover | Petting, wiggles, phrases, mood boosts |
| Park cursor nearby | She wanders over asking for attention |
| Pet / Clowder menu | Choose pet type (neko, bsd, dog) and clowder size (1–3) |
| Chase / Laser (L) | Hunt mode: paw-bats, catch attempts, chase dialogue |
| Give snack (F) | +20 mood, wakes sleepy pets, happy snack reaction |
| Accessories / Rename / Mood | Tweak appearance and behavior from the menu |
| Open at Login | Start MSXPET automatically on reboot |

## For contributors and modders

- Assets live under `Sources/MSXPET/Resources/pets/<pet>/<state>/<n>.png` (see `ASSETS.md` for design notes and templates).
- Use the included conversion script if you want to pull sprites from upstream xpet assets (Pillow required).
- Sounds are WAV files and can be dropped into the assets folder; no rebuild required for runtime loading.

## Engineering notes (elite mode)

MSXPET ports the classic xpet loop into a deterministic, testable engine with an AppKit frontend:

| Concept from X11 xpet | MSXPET implementation |
|---|---|
| override_redirect windows | Borderless non-activating `NSPanel` with floating + all-spaces support (`PetWindow.swift`) |
| per-pixel masking | Alpha-based `hitTest` for true click-through behavior (`PetView.swift`) |
| xpet game loop | `PetEngine`: deterministic, headless-testable, hysteresis-filtered octants (`PetEngine.swift`) |
| frame pacing | Adaptive tick: 60Hz → 10Hz → 1Hz depending on activity |
| sprite pipeline | 120 PNG frames + direction/accessory variants, plus a few hand-authored poses |

Porting notes: handled Y-axis flips, walk-phase preservation, top-down pixel buffers, and timer double-registration.

## Roadmap (wish list)

- [ ] Scriptable pets: JSON behavior packs plus JavaScriptCore hooks for user-defined personalities
- [ ] On-device personality model: optional local ML for richer dialogue and memory
- [ ] v0.1.0 release

## License & attribution

- Source code: WTFPL (`LICENSE`) — use as you please.
- Upstream art and ported logic: GPL-3.0 (`LICENSES/GPL-3.0.txt` and `ATTRIBUTION.md`) — the bundled app remains GPL due to included upstream assets.

## Thanks & credits

- Original inspiration and sprite assets: [uint23/xpet](https://github.com/uint23/xpet)

Enjoy MSXPET — may your desktop be ever pawsome. ฅ^•ﻌ•^ฅ
