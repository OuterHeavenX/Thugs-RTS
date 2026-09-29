# THUGS RTS — slice v1

A tiny 2.5D isometric browser RTS built with Godot 4.7. One map, two
factions (America vs Asia), gather-build-fight loop, and a win/lose
ending. All code and art are original; no paid assets.

## Factions

- **America** (blue) vs **Asia** (red) — data-driven in
  `scripts/data/faction_data.gd`, ready for Africa, Europe, Australia,
  and South America later.

## Play

- Title screen → pick a country → START.
- Tap your units/buildings to select; tap the ground to move.
- Command buttons: Move, Gather, Attack, Stop, Build (Barracks).
- Harvest Supplies and Cash, train Workers and Soldiers, destroy the
  enemy HQ to win.
- Desktop: right-click = smart order, left-drag = box-select, wheel =
  zoom, WASD/arrows = pan. Mobile: full touch buttons + pinch zoom.

## Layout

- `scripts/game.gd` — match manager (map, resources, orders, win/lose)
- `scripts/health.gd` — HP component
- `scripts/units/` — unit, worker, soldier
- `scripts/buildings/` — building, hq, barracks
- `scripts/ai/` — enemy commander
- `scripts/ui/` — title screen, HUD
- `scripts/art/` — procedural unit sprites + Blender-baked structure sprites
- `scripts/data/` — balance constants, faction data
- `assets/blender/` — original `.blend` sources for the structures
- `assets/structures/` — Blender-rendered PNGs (baked to base64 by
  `tools/bake_structure_sprites.py`; the game never reads the PNGs at
  runtime, so no texture-import pipeline is involved)
- `tests/test_match.gd` — headless match-logic test

## Build & test

Requires Godot 4.7.2 (`--headless` works):

```
# import + class cache
godot --headless --path . --import
# headless test (exit code 0 = all pass)
godot --headless --path . -s tests/test_match.gd
# web export (needs export templates installed)
godot --headless --path . --export-release "Web" web_staging/index.html
```

Web export notes: `variant/thread_support=false` (no COOP/COEP headers on
static hosts), `input_devices/pointing/emulate_mouse_from_touch=false`,
and the exported `index.pck` must start with the `GDPC` magic bytes.

## Re-render structures

```
blender -b --python tools/render_structures.py
python3 tools/bake_structure_sprites.py
```
