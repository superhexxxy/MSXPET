# MSXPET

MSXPET is a native Apple Silicon desktop pet for macOS 13+ on ARM64. It brings the spirit of the classic X11 pet to macOS with a smoother, more opinionated, and more playful interface.

She wanders your desktop, naps in place, reacts to your cursor, asks for pets, purrs when you indulge her, and can be run in small groups for extra chaos. The project is built around a lightweight custom game loop and a transparent, non-intrusive AppKit window.

Inspired by [uint23/xpet](https://github.com/uint23/xpet), rebuilt from the ground up for modern macOS.

## Why it stands out

- Alive behavior: roaming, chasing, freezing, snoozing, dreaming, grooming, zoomies, and cursor-triggered startles
- Affection system: asks for pats, sits and purrs when you comply, and changes mood when ignored
- Social interactions: run one to three pets together, let them greet each other, and watch them talk in multi-line dialogs
- Playful physics: drag, fling, and toss her around with gravity, wall clinging, and bounces
- Customization: hats, sunglasses, accessories, sound packs, and custom asset support
- Audio support: bundled synthesized sounds and support for custom WAV input without rebuilding the app
- Respectful desktop behavior: transparent click-through windows, no Dock icon, and pauses on screen lock

## Running the app

### Download a release

Grab `MSXPET.zip` from the [Releases](https://github.com/superhexxxy/MSXPET/releases) page. On first launch, right-click the app and choose Open to bypass the macOS quarantine gate for an ad hoc signed build.

If needed, you can also remove the quarantine flag manually:

```zsh
xattr -d com.apple.quarantine /Applications/MSXPET.app
open /Applications/MSXPET.app
```

### Build from source

Command Line Tools are sufficient; Xcode is not required for a local build.

```zsh
swift run                # run in development mode
zsh Scripts/build-app.sh # creates dist/MSXPET.app
open dist/MSXPET.app
```

## Controls

| Action | Result |
|---|---|
| Drag her | She follows your cursor and reacts to being carried |
| Fling her | Gravity takes over, causing bounces, wall-clings, and playful motion |
| Click or hover | Triggers petting, wiggles, mood changes, and dialogue |
| Move the cursor nearby | She comes over to ask for attention |
| Pet / Clowder | Choose between different pet types and run a clowder of up to three |
| Chase / Laser (L) | Activates hunt mode, with paw-bats and reaction to the laser dot |
| Give snack (F) | Adds mood, wakes sleepy pets, and triggers a happy reaction |
| Sound / Accessories / Rename / Mood | Adjusts behavior and appearance directly from the menu |
| Open at Login | Starts MSXPET automatically after a reboot |

## Engineering notes

MSXPET keeps the original xpet loop and logic, but ports it into a modern macOS architecture.

| Original concept | Current implementation |
|---|---|
| `override_redirect` window | Borderless, non-activating `NSPanel` with floating behavior and all-spaces support |
| X11 window masking | Per-pixel alpha hit testing for click-through behavior |
| xpet game loop | Deterministic `PetEngine` with timers, state transitions, and physics updates |
| Fixed tick speed | Adaptive frame pacing from active motion to low-power idle behavior |
| Sprite animation | PNG assets plus directional accessory variants and pose variations |

The codebase includes workarounds for typical porting issues such as axis flips, threshold tuning, preserved walk phases, pixel-buffer handling, and timer registration edge cases.

## Roadmap

- [ ] Scriptable pets with JSON behavior packs and JavaScriptCore hooks
- [ ] Lightweight local ML model for personality, memory, and dream states
- [ ] `v0.1.0`

## License

- Source code: WTFPL (`LICENSE`)
- Upstream art and ported logic: GPL-3.0 (`LICENSES/GPL-3.0.txt` and `ATTRIBUTION.md`)

The bundled application remains GPL-licensed as a whole because it includes the upstream art and logic in this distribution.
