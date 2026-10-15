# MSXPET — Super Pawsome Desktop Pet

[![Release](https://img.shields.io/github/v/release/superhexxxy/MSXPET?label=release)](https://github.com/superhexxxy/MSXPET/releases) [![License](https://img.shields.io/github/license/superhexxxy/MSXPET)](LICENSE) [![Stars](https://img.shields.io/github/stars/superhexxxy/MSXPET?style=social)](https://github.com/superhexxxy/MSXPET/stargazers) [![Issues](https://img.shields.io/github/issues/superhexxxy/MSXPET)](https://github.com/superhexxxy/MSXPET/issues) [![Downloads](https://img.shields.io/github/downloads/superhexxxy/MSXPET/total)](https://github.com/superhexxxy/MSXPET/releases)

[![macOS](https://img.shields.io/badge/platform-macOS%20%7C%20macOS%2013%2B-4B8BBE)](https://www.apple.com/macos/) [![Apple Silicon](https://img.shields.io/badge/arch-Apple%20Silicon-0A84FF)](https://developer.apple.com/apple-silicon/) [![Swift](https://img.shields.io/badge/made%20with-Swift-FA7343)](https://swift.org)

MSXPET is a native macOS desktop pet for Apple Silicon (ARM64) — lightweight, responsive, and designed to be an unobtrusive little companion on your screen. Run a single pet or a clowder of up to three; they roam, nap, purr, and interact with each other and your cursor.

Inspired by [uint23/xpet](https://github.com/uint23/xpet), MSXPET reimagines the experience for modern AppKit on macOS 13+.

## What it does (high level)

- Roams the desktop, chases the cursor, and reacts to environment changes
- Affection system: pets respond to attention, purr, and change mood when neglected
- Social behaviors for groups of pets: greetings, chasing, and short dialog exchanges
- Physics-driven movement: drag, fling, wall cling, bounce, and recover
- Customizable appearance and sound: accessories, hat variants, and user-supplied PNG/WAV assets
- Desktop-friendly by design: per-pixel click-through, no Dock icon, and pauses on screen lock

## Showcase

Add a GIF or screenshot to this section to highlight MSXPET in action. Example placeholder:

![demo-placeholder](https://raw.githubusercontent.com/superhexxxy/MSXPET/main/Resources/demo.gif)

## Install

### Download a release

Grab `MSXPET.zip` from the [Releases](https://github.com/superhexxxy/MSXPET/releases). On first launch, right-click the app and choose Open to bypass Gatekeeper for ad-hoc signed builds.

Command-line alternative:

```zsh
xattr -d com.apple.quarantine /Applications/MSXPET.app
open /Applications/MSXPET.app
```

### Build from source

Command Line Tools are sufficient; Xcode is optional.

```zsh
swift run                # run in development mode
zsh Scripts/build-app.sh # creates dist/MSXPET.app
open dist/MSXPET.app
```

## Controls

| Action | Result |
|---|---|
| Drag | Pet follows and reacts to being carried |
| Fling | Physics take over: gravity, bounces, wall-cling |
| Click / Hover | Petting actions, small phrases, mood adjustments |
| Leave cursor nearby | Pet approaches asking for attention |
| Pet / Clowder menu | Select pet type and clowder size (1–3) |
| Chase / Laser (L) | Toggle hunt mode: chase the dot and paw-bat |
| Give snack (F) | Boost mood, wakes sleeping pets |
| Accessories / Rename / Mood | Tweak appearance and behavior from the menu |
| Open at Login | Start MSXPET on system login |

## Customization & assets

- Sprite assets: Sources/MSXPET/Resources/pets/<pet>/<state>/<n>.png
- Convert upstream xpet assets using the included script (Pillow required): see ASSETS.md
- Sounds: drop WAV files into the assets folder; MSXPET can load them at runtime without rebuilding

## Engineering notes

MSXPET retains the essence of the original xpet engine while modernizing it for macOS and AppKit.

| Original xpet concept | MSXPET implementation |
|---|---|
| `override_redirect` windows | Borderless, non-activating `NSPanel` with floating + all-spaces support (`PetWindow.swift`) |
| Per-pixel window masking | Alpha-aware `hitTest` for click-through behavior (`PetView.swift`) |
| xpet game loop | `PetEngine`: deterministic, headless-testable, with hysteresis-filtered octants (`PetEngine.swift`) |
| Fixed tick | Adaptive frame pacing: active (60Hz) → reduced (10Hz) → idle (1Hz) |
| Sprite pipeline | ~120 PNG frames + accessory/direction variants and a few hand-authored poses |

Porting challenges addressed: Y-axis flips, walk-phase preservation, top-down pixel buffer conversions, and timer registration edge cases.

## Roadmap

- [ ] Scriptable pets: JSON-based behavior packs with JavaScriptCore hooks
- [ ] Optional local personality model for richer, on-device dialogue and memory
- [ ] v0.1.0 release

## Contributing

Contributions are welcome. If you plan to add features, assets, or fixes:

1. Open an issue describing the change.
2. Create a branch and submit a pull request with tests or screenshots when appropriate.

See CONTRIBUTING.md for more details (if present).

## License & attribution

- Source code: WTFPL (`LICENSE`) — use freely.
- Upstream art and ported logic: GPL-3.0 (`LICENSES/GPL-3.0.txt` and `ATTRIBUTION.md`) — because upstream sprites and logic are included, the bundled app remains GPL-licensed.

Thanks to the original project for inspiration: [uint23/xpet](https://github.com/uint23/xpet).
