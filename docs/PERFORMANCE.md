# WORLD COMMAND — Performance (v0.1.0 slice)

Engine: Godot 4.7, **gl_compatibility** renderer. World scale in meters;
map 128x128m.

## Budgets and caps

| Item | Value | Source |
| ---- | ----- | ------ |
| Unit cap per player | **60** | `UNIT_CAP` (`ai_commander.gd`, HUD) |
| Fog reveal | **10 Hz** (0.1s) | `map_runtime.gd` |
| Enemy hide-under-fog | **4 Hz** (0.25s) | `map_runtime.gd` |
| Unit target scan | 0.25s, staggered across 8 slots | `unit.gd` |
| Tower target scan | 0.3s | `building.gd` |
| Separation neighbor checks | capped at 8 per unit | `unit.gd` |
| Nav grid | 64x64 cells, 2m, A* 8-dir | `nav_grid.gd` |
| Fog grid | 64x64 bytes | `fog_of_war.gd` |
| VFX puffs pool | 40 | `vfx.gd` |
| VFX tracers pool | 40 | `vfx.gd` |
| Production queue | 5 per building | `building.gd` |

## Draw calls

- Terrain is a **single mesh** (128x128 vertex-colored grid); fog is
  applied in the terrain shader from the fog texture (R8: 0 unexplored /
  128 explored / 255 visible).
- Props are individual `.glb` instances (trees, rocks, facility) — kept
  low-poly (≤ 320 tris each).
- Units/buildings are single `.glb` instances plus a selection ring and
  billboard health bar (hidden when not needed).
- VFX are pooled billboard quads — no per-frame allocations in hot paths
  (fixed pools, index reuse).
- Projectile visuals: one emissive sphere + short tracer segments; no
  lights.

## Graphics quality tiers

Settings → graphics (persisted in `user://settings.cfg`):

| Tier | MSAA | Shadows |
| ---- | ---- | ------- |
| Low (0) | disabled | off |
| Medium (1, default) | 2x | on |
| High (2) | 4x | on |

Applied at startup (`main.gd`) and when changed in settings
(`screens.gd`); VFX density also scales via `VFX.set_quality`.

## What keeps the frame rate safe

- Fog texture updates only when the grid changes; reveal work is a
  circle-stamp over a byte array.
- Enemy hiding under fog flips `visible` at 4Hz instead of per frame.
- Unit scans and separation are staggered/capped, not all-units-every-frame.
- Air units skip pathfinding (straight-line flight at y=6).
- Headless-safe: no autoload-order dependencies beyond
  Game/Data/SFX/VFX; null-guarded cross-chunk resolution.

## Unverified

- No measured draw-call or frame-time numbers exist for the slice yet;
  the budgets above are design caps, not profiled results.
