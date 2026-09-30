# WORLD COMMAND — Changelog

## v0.1.0 — Vertical slice (2026-09-29)

### Hotfix — independent verification findings (2026-09-29)
Independent live-match verification (217/217 unit tests passing) found four
defects the isolated tests could not see; all fixed and re-verified:
- **Workers now spawn as `Worker`** (`helios_valley.gd`, `building.gd`):
  starting workers and trained workers were instantiated from base
  `unit.gd`, whose gather/build ticks just idle — the entire economy was
  dead (supply 400→400 over 200s). Live-match probe now shows supply
  400→1160 with workers ordered to gather, and the AI training units 5→11.
- **Freed attack targets no longer spam errors** (`unit.gd`): `_target_ok`
  took a typed `Node3D` parameter, so every call with a killed target threw
  "previously freed" errors every frame and stuck the attacker in ATTACK.
  The parameter is now untyped (guarded by `is_instance_valid`), and
  `_set_attack_target()` watches the target's `died` signal to clear the
  reference promptly.
- **UI anchor fix** (`main_menu.gd`, `faction_select.gd`, `hud.gd`,
  `screens.gd`, `touch_controls.gd`): `set_anchors_preset(FULL_RECT)` in
  `_ready()` preserved the zero pre-layout size off-screen (title clipped,
  faction cards invisible). Replaced with explicit
  `anchor_right/bottom = 1.0`.
- **Menu now complete**: added CAMPAIGN (Coming Soon screen), TECH DATABASE
  (data-driven tech list for US/Japan), and EXIT (browser shows a farewell
  overlay; desktop quits). Also fixed BACK from menu sub-screens leaving a
  blank screen — it now rebuilds the main menu via `menu_requested`.
- Re-exported Web build (`thread_support=false`, GDPC-verified).

## v0.1.0 — Vertical slice (2026-09-29)

First playable slice: US vs Japan skirmish on Helios Valley.

**World chunk**
- Helios Valley map: single-mesh 128x128m terrain, US base west / Japan
  base east (faction-resolved, so the human's side follows their pick),
  central 7-crystal Helios field, 5 supply deposits per base, 2 expansion
  sites per side, trees/rocks/abandoned facility props, minimap bake.
- NavGrid: 64x64 cells, 2m, A* 8-directional pathfinding.
- FogOfWar: 64x64 byte grid, 10Hz reveal / 4Hz enemy hiding, R8 texture
  for the terrain shader.

**Units & combat chunk**
- `Unit` state machine (idle/move/attack/attack-move/gather/build/hold),
  target acquisition with staggered scans, separation steering with
  tangential slide, queued orders, air units at y=6.
- `Combat`: damage formula (base × mechanic/tech × per-tag counters, min
  1), splash, air/ground gating, stealth rules (6m reveal / 25m
  detectors).
- `Mechanics`: Battlefield Network (US) and Combat Synchronization
  (Japan) auras, plus all six tech effects.
- Worker: harvest 8/2s, carry 40, deposit at Command Center, auto-retarget
  depleted nodes; construction channeling stacks linearly.
- Pooled VFX (muzzle, tracer, explosion, sparks, harvest glint, smoke);
  procedural SFX.

**Buildings & economy chunk**
- Construction (up-front cost, worker channeling, scaffold visual),
  production/research queues (5 max, 50% speed in power shortage),
  rally points, cancel-with-refund, defense towers with turret yaw.
- Power grid: shortage = consumed > produced; queueing blocked and
  production halved during shortage.
- Supply (1500/node) / Helios (800/node) economy, 400/0 starting
  stockpile, 60-unit cap.

**Game flow, input, UI, AI, touch chunk**
- Main menu → faction select (2 playable + 5 COMING SOON cards) →
  skirmish; victory/defeat/pause/settings screens; settings persisted to
  `user://settings.cfg`.
- Desktop: click/drag/right-click smart orders, A attack-move, S/H
  stop/hold, WASD/arrows pan, wheel zoom, Q/E rotate, Ctrl+1..9 groups.
- Touch: tap select/smart-order, drag box-select, pinch zoom, two-finger
  pan, 0.55s long-press attack-move, portrait ROTATE DEVICE overlay,
  ≥64px command bar buttons.
- AICommander: 1Hz tick, 9-worker economy, timed build order, army mix
  per faction, 3:00 scout, 6:30 first wave then every ~3 min. No
  cheating — same APIs as the player.

**Art**
- 29 original procedural Blender 4.5.3 models (.glb): 12 buildings, 12
  units, 5 environment props; named nodes (Turret/Muzzle/Rotor/Dish/Core/
  Glow); all within tri budgets; 192px Cycles thumbnails.

**Integration fixes during the slice**
- FogOfWar API renamed `is_visible` → `is_visible_at` (Node3D already
  owns the no-arg name; the original broke GDScript parsing).
- `Unit.nav_grid`/`Unit.fog` and `Building.nav_grid` left deliberately
  untyped — the world chunk's `nav_grid.gd` had parse errors and typed
  references broke compilation of every consumer.
- `building.gd` uses dynamic autoload accessors (`_game()`/`_data()`) so
  headless `-s` test scripts parse before autoload names register.
- `helios_valley.gd` instantiates Building/Unit via script paths instead
  of `class_name` references for the same parse-order reason.
- `.gdignore` added to `assets/blender/source/` — headless `--import` was
  trying to import `.blend` files via Blender, failing, and silently
  skipping the *entire* reimport (all glbs failed at runtime).

**Known issues (open)**
- `Building._fire` calls `Projectile.setup` with 6 arguments; the method
  takes 5 — defense towers firing projectile weapons will error at
  runtime.
- Defense towers are not yet gated on power shortage (they fire during
  shortages, against the design intent).
- The AI's build-order timings in code (power 0:40, barracks 1:30,
  factory 4:00, 2nd power 4:30, tower 6:00, lab 7:00, tower 9:00) differ
  from the timings listed in `ARCHITECTURE.md`.
