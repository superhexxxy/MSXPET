# MSXPET — native macOS desktop pet (Apple Silicon)

Native AppKit port of [uint23/xpet](https://github.com/uint23/xpet) (suckless X11 pet) for macOS 13+ on ARM64. No XQuartz. No Electron. `swift build` only — no Xcode required.

GPL-3.0 (upstream derivative — see `LICENSE` + `ATTRIBUTION.md`).

## Install (no paid Apple account — ad-hoc signed, not notarized)

Download `MSXPET.zip` or `MSXPET.dmg` from GitHub Releases, then on first launch either right-click → Open, or:

```zsh
xattr -d com.apple.quarantine /Applications/MSXPET.app
open /Applications/MSXPET.app
```

## Quickstart (from source)

```zsh
cd /Users/shadow/Projects/MSXPET
swift run                # dev run (placeholder art until PNGs installed)
zsh Scripts/build-app.sh # -> dist/MSXPET.app
open dist/MSXPET.app
```
Tests: `swift test` on CI (requires full Xcode; CLT-only Macs run engine checks via `swift build` — see CI badge). Local CLT verified: `swift build` + standalone `PetEngine` harness pass.

## Import real pet art

```zsh
git clone https://github.com/uint23/xpet /tmp/xpet
pip install Pillow
python3 Tools/convert_assets.py /tmp/xpet/pets Sources/MSXPET/Resources/pets
zsh Scripts/build-app.sh
```

Expected layout: `Sources/MSXPET/Resources/pets/neko/idle/0.png …`

## Architecture

| Upstream X11 | MSXPET AppKit |
|---|---|
| `override_redirect` window | `PetWindow` (`Sources/MSXPET/PetWindow.swift`): borderless nonactivating `NSPanel`, `.floating`, `canJoinAllSpaces` |
| `XShapeCombineMask` | `PetView` (`Sources/MSXPET/PetView.swift`): per-pixel alpha `hitTest` → click-through |
| bubble `Window` | `SpeechBubble` (`Sources/MSXPET/SpeechBubble.swift`): dedicated panel (not a subview) |
| `xpet.c` wander/chase/freeze | `PetEngine` (`Sources/MSXPET/PetEngine.swift`): pure struct, ms accumulators, fully unit-tested |
| `config.h` | `Config` (`Sources/MSXPET/Config.swift`) |
| `XGrabKey` Alt+F/S/Q | Menu-bar menu (no Accessibility prompt in M0) |

Critical porting fixes vs naive brainstorm (`chat.json`):
- Y-axis flipped: X11 Y-down → AppKit Y-up (`PetEngine.findOctant`, drag delta sign).
- `find_octant` uses upstream `2x` thresholds, not `/2`.
- Timing preserved in ms (`PET_REFRESH`-style accumulators) on a 60Hz `Timer`; speed = 100 pt/s.
- Walk→walk keeps animation phase like upstream `set_pet_state`.
- `hitTest` maps view points → image pixels with Retina scaling + flipped-row correction.

## Production checklist

- [x] SwiftPM (no `.xcodeproj` in git), `swift build/test` on arm64
- [x] `.app` bundler (`Scripts/build-app.sh`) with `LSUIElement` (no Dock)
- [x] CI (`.github/workflows/ci.yml`, macos-15, Swift 6.0)
- [x] `PetEngine` unit tests (`Tests/MSXPETTests`)
- [x] GPL-3.0 + attribution
- [x] Real PNG assets vendored (120 frames: neko/bsd/dog × 12 states, via `Tools/convert_assets.py`)
- [ ] App icon (`.icns`), `README` screenshot
- [ ] Notarization + `dmg` release workflow
- [ ] Settings UI (pet picker, speed), launch-at-login
- [ ] Optional global hotkeys (requires Accessibility entitlement + docs)

## Controls

- Drag pet to move · fling it and it falls with a *"whee!"* · Click = pets + phrases (happy pets get ♥)
- She notices you: bats at lingering cursors, **comes asking for pats** (click = sits + purrs), talks unprompted, sleeps with floating Zzz's, day/night rhythm
- Menu bar 🐾 → Pet (neko/bsd/dog) / Clowder (1–3 pets, they play together) / Chase / Freeze / Laser Pointer / Sound / Accessories / Rename / Open at Login / Quit
- Dress-up + custom sounds: see **ASSETS.md** (drop-in PNG overlays, uploadable WAVs, no rebuild needed)

## Do I need full Xcode?

No. Command Line Tools are enough to `swift build` and run `Scripts/build-app.sh` (that's how this was built). Full Xcode only adds: local `swift test`, Instruments, and — with a paid $99/yr account — Developer-ID signing + notarization. CI (free macos runners) already runs `swift test` + bundles the `.app`, and the Release workflow ships ad-hoc signed zips/dmgs without any paid account.
