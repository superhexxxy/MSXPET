# Attribution

This project is a macOS AppKit port derived from:

- **xpet** by uint23 — https://github.com/uint23/xpet — GPL-3.0
  - `xpet.c`, `xpet.h`, `config.h`, `Makefile` (ported game logic),
    `pets/*/*.xpm` (converted to the PNGs in `Resources/pets/`).

## License split

- **Our original code** (`Sources/MSXPET/*.swift`, `Tools/`, docs):
  WTFPL — do what the fuck you want to (see `LICENSE`).
- **Upstream-derived parts** (pet sprites, ported algorithms):
  GPL-3.0 (see `LICENSES/GPL-3.0.txt`) — do not relicense separately.

Net effect: hack on the code however you like, but the app **bundle**
ships uint23's art, so distributing the bundle stays GPL-bound.
Credit the cats. 🐾
