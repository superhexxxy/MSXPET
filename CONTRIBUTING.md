# Contributing to MSXPET

Thanks for stopping by! Small, focused PRs beat grand redesigns.

## How to contribute

1. **Open an issue first** describing the change (behavior, art, or fix).
2. **Branch** from `main`, keep it focused — one thing per PR.
3. **Match the patterns**: pure logic goes in testable structs (see
   `PetEngine.swift`), UI stays in `Pet*`/`AppDelegate`, drop-in content
   goes in data folders (`pets/`, `overlays/`, `sounds/`) — no rebuild needed.
4. **Tests**: add XCTest cases for logic changes (`Tests/MSXPETTests/`).
   They run on CI (macos-15, Swift 6.0). Screenshots help for art changes.
5. **Docs**: update `README.md` / `ASSETS.md` if behavior or formats change.

## Ground rules

- Keep her lightweight: no new dependencies without discussion, mind the
  adaptive tick (idle must stay near-free CPU-wise).
- Upstream art (`Resources/pets/`, converted from uint23/xpet) stays
  GPL-3.0 — see `ATTRIBUTION.md`. Your own art/code is WTFPL.
- Be kind. She's a cat.
