# 🐾 MSXPET — your macOS desktop bestie

**A native Apple Silicon desktop pet with actual personality.** She wanders your screen, naps with floating Zzz's, bats at your cursor, begs for pats (and purrs when you deliver), gossips with her sisters, and loses her mind over laser pointers. Zero Electron. Zero XQuartz. Just Swift + AppKit, running at ~1% CPU while she loafs.

> *pawsome. meowsome. oemgi.*

Inspired by [uint23/xpet](https://github.com/uint23/xpet) (suckless X11 pet), rebuilt from whiskers up for macOS 13+ on ARM64.

## ✨ Why she's the best

- **Alive** — wanders, chases, freezes, snoozes, dreams (day/night rhythm!), grooms, gets the zoomies, startles at swooshy cursors
- **Needy (affectionate)** — comes asking for pats (*"pet tax due."*), sits + purrs when you pay up, talks even when unclicked, gets moody when ignored (check the 🐾 → Mood menu, it goes *blissful → grumpy*)
- **Social** — run a clowder of 1–3; they chase each other, stop to say hi (*"sisfur!!"*), and hold full multi-line dialogues (*"i saw the laser first." / "did not." / "did too."*)
- **Playable physics** — drag her, fling her (gravity + bounces + *"whee!"*), watch her grab walls mid-flight, scramble, and occasionally stick the landing with a *"phew."*
- **Dress-up** — santa hats, witch hats, sunglasses (with per-direction fits!), all pixel-perfect and head-tracked through the walk cycle. Make your own in 5 minutes — see **ASSETS.md**
- **Sounds you can hear** — synthesized cute bleeps, chirps, thumps + a seamless sleep-purr loop. Upload your own WAVs, no rebuild needed
- **Polite houseguest** — no Dock icon, click-through transparency, pauses on screen lock, adaptive tick (60Hz playing → 1Hz asleep)

## 🚀 Get her running

**Easiest** — grab `MSXPET.zip` from [Releases](https://github.com/superhexxxy/MSXPET/releases), then on first launch right-click → Open (ad-hoc signed, no paid Apple account involved), or:

```zsh
xattr -d com.apple.quarantine /Applications/MSXPET.app
open /Applications/MSXPET.app
```

**From source** (Command Line Tools are enough — no Xcode required):

```zsh
swift run                # dev run
zsh Scripts/build-app.sh # -> dist/MSXPET.app (signed, bundled)
open dist/MSXPET.app
```

## 🎮 Controls

| Do this | She does this |
|---|---|
| Drag her | Gets carried (*"hey!"*), tracks your cursor 1:1 |
| Fling her | Gravity takes over — bounces, wall-clings, *"whee!"* |
| Click / hover her | Pets + wiggles, phrases, ♥ at high mood |
| Park cursor nearby | She wanders over asking for pats |
| 🐾 → Pet / Clowder | neko, bsd, dog — solo or a pack of 3 |
| 🐾 → Chase / Laser (`L`) | Hunt mode (she *catches* the dot now, with paw-bats + *"gotcha!"*) |
| 🐾 → Give snack (`F`) | *"nom!!"*, +20 mood, wakes sleepers (*"FOOD?!"*) |
| 🐾 → Sound / Accessories / Rename / Mood | Exactly what they say |
| 🐾 → Open at Login | She'll be waiting after every reboot |

## 🧠 Elite engineering bits (for the nerds)

| Upstream X11 | MSXPET AppKit |
|---|---|
| `override_redirect` window | Borderless nonactivating `NSPanel`, `.floating`, all-spaces (`PetWindow.swift`) |
| `XShapeCombineMask` | Per-pixel alpha `hitTest` → true click-through (`PetView.swift`) |
| `xpet.c` game loop | `PetEngine`: pure, deterministic, headless-testable struct — ms accumulators, hysteresis-filtered octants, stall watchdog, drop/cling physics (`PetEngine.swift`) |
| Fixed 200ms tick | Adaptive 60Hz → 10Hz → 1Hz by activity + redundant-composite skipping |
| 120 XPM frames | 120 PNGs + 6 hand-authored poses (`swat`, `cling_side`, `cling_top`) + directional accessory variants |

Porting gotchas solved along the way: Y-axis flip, octant `2x` thresholds, walk-phase preservation, top-down pixel buffers (caught by byte-level PIL cross-checks), timer double-registration. ~45 XCTest cases; `swift test` runs on CI (macos-15, Swift 6.0).

## 🔮 Roadmap

- [ ] **Scriptable nekos** — behavior packs (JSON) → JavaScriptCore hooks → Shortcuts intents. *Your* pet, *your* rules
- [ ] **A tiny soul** — opt-in 1B-class on-device brain (MLX) for fresh lines + memory + dreams, with scripted fallback. 100% local, obviously
- [ ] `v0.1.0`

## 📜 License

Our code: **WTFPL** — do what the fuck you want to (see `LICENSE`).
Upstream art + ported logic: **GPL-3.0** — uint23's sprites ship with this app
(see `LICENSES/GPL-3.0.txt` + `ATTRIBUTION.md`), so the bundled app as a
whole stays GPL-bound. Sorry, lawyers — the cats made us do it. 🐾
