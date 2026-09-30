# WORLD COMMAND — Architecture & Chunk Contracts

Vertical slice: US vs Japan on Helios Valley. Godot 4.7, gl_compatibility, Y-up 3D.
Autoloads: `Game` (match state), `Data` (faction registry), `SFX`, `VFX`.
World scale: meters. Map 128x128m. Ground plane y=0. Camera: perspective, elevated.

## Already built (do not rewrite)
- `scripts/data/`: `FactionData`, `UnitData`, `BuildingData`, `WeaponData`, `UpgradeData` (Resource subclasses with `static make(...)`).
- `scripts/factions/us_data.gd`, `japan_data.gd`: full faction definitions.
- `scripts/autoload/data.gd`: `faction(id)`, `unit(f,i)`, `building(f,i)`, `upgrade(f,i)`.
- `scripts/autoload/game.gd`: match lifecycle + resource/power/registry API (see below).
- `scripts/core/player.gd`: `Player` (RefCounted).

### Game API (authoritative)
```
Game.new_match(human_faction: String, enemy_faction: String)
Game.end_match(victory: bool)
Game.to_menu()
Game.get_player(pid) -> Player ; Game.human() -> Player
Game.spend(pid, supply, helios) -> bool
Game.refund(pid, supply, helios)
Game.add_resources(pid, supply, helios)
Game.recompute_power(pid)
Game.register_unit(u) / unregister_unit(u) / register_building(b) / unregister_building(b)
Game.units_of(pid, alive_only=true) -> Array
Game.buildings_of(pid, alive_only=true) -> Array
Game.enemies_of(pid) -> Array
Game.check_victory()            # called automatically on building death
Game.phase, Game.time, Game.players, Game.human_id
signals: match_started, match_ended(victory), resources_changed(pid),
         unit_spawned, unit_died, building_placed, building_died,
         building_constructed, tech_researched(pid, upgrade_id)
```
### Player API
`id, faction: FactionData, is_human, supply, helios, techs: Dictionary`,
`has_tech(id) -> bool`, `power_shortage() -> bool`, `power_ratio() -> float`

### Data conventions
- Faction ids: `"us"`, `"japan"`. Unit/building/upgrade ids are per-faction
  (`"worker"`, `"ranger"`, `"command"`, `"power"`, `"barracks"`, `"factory"`,
  `"lab"`, `"tower"`, `"network_uplink"` ...). Always look up via
  `Data.unit(faction_id, unit_id)` — never hardcode stats.
- Model paths: `res://assets/models/<buildings|units|environment>/<file>.glb`.
  Load with `ResourceLoader.load(path)` + null-check (never `FileAccess.file_exists`).
  Named nodes the engine may use: `Turret` (yaw node), `Muzzle` (Marker3D/Node3D),
  `Rotor`, `Glow`, `Dish`, `Core`, `Door`. All optional — null-check.
- Armor tags: `infantry`, `light`, `vehicle`, `tank`, `air`, `building`,
  `artillery`, `stealth`, `elite`. `WeaponData.bonus_vs: Dictionary` tag->mult.
- Stealth (Shinobi): invisible to enemies unless within 6m or a detector
  (Kitsune, or any tower) is within 25m. Implement in unit visibility helper.

## Chunk A — WORLD (map, navigation, fog of war)
Files: `scripts/world/helios_valley.gd`, `scripts/world/resource_node.gd`,
`scripts/navigation/nav_grid.gd`, `scripts/core/fog_of_war.gd`,
`scripts/world/terrain.gd` (+ `assets/shaders/fow.gdshader` if wanted), map props.
- `NavGrid` (class_name): cell 2m over 128m => 64x64. API:
  `setup()`, `world_to_cell(pos: Vector3) -> Vector2i`, `cell_to_world(c) -> Vector3`,
  `set_blocked_rect(center: Vector3, size_cells: Vector2i, blocked: bool)`,
  `find_path(from: Vector3, to: Vector3) -> PackedVector3Array` (A*, 8-dir,
  returns y=0 waypoints; empty array if unreachable),
  `clamp_to_map(pos) -> Vector3`, `is_cell_walkable(c) -> bool`.
- `ResourceNode` (class_name extends Node3D): `kind` `"supply"|"helios"`,
  `amount: float`, `harvest(requested: float) -> float` (returns actual, frees
  itself at 0 via `depleted` signal), model from
  `assets/models/environment/supply_deposit.glb` / `helios_crystal.glb`.
  Supply node: 1500; Helios crystal: 800.
- `HeliosValley` (class_name extends Node3D): `build(nav: NavGrid, fow) -> void`.
  Layout: US base west (x≈-44), Japan base east (x≈+44), each with Command Center
  + 5 workers + starting buildings area; central Helios field (7 crystals around
  x=0); 5 supply deposits near each base; 2 expansion sites per side
  (each: 3 supply + 2 helios, marked with a subtle ring decal); tree clusters
  N/S; rock formations; 1 abandoned_facility prop near center-north.
  Exposes: `spawn_pos(pid) -> Vector3`, `resource_nodes: Array[ResourceNode]`,
  `base_center(pid) -> Vector3`. Spawns starting CC + 5 workers for both players
  (use `Building`/`Unit` APIs from Chunk B/C — instantiate via their `setup`).
  Terrain: one big ground mesh (128x128, vertex-colored or textured: grass base
  with dirt patches, roads between bases, cliff-ish darker rock areas at edges).
  Keep draw calls low (single terrain mesh + props).
- `FogOfWar` (class_name extends Node3D): 64x64 byte grid over the map.
  `reveal(units: Array)` called at 10Hz by game chunk; per human player only
  (slice is 1 human). API: `is_visible(pos: Vector3) -> bool`,
  `is_explored(pos) -> bool`, `get_texture() -> Texture2D` (R8: 0 unexplored,
  128 explored, 255 visible) for the terrain shader. Terrain shader darkens
  unexplored (near-black) and tints explored-but-not-visible darker/desaturated.
  Enemy units/buildings render normally but game chunk hides them when not
  visible (scale 0 / visible=false) — provide `FogOfWar` only; hiding is game chunk.

## Chunk B — UNITS & COMBAT
Files: `scripts/units/unit.gd`, `scripts/units/worker.gd`,
`scripts/combat/combat.gd`, `scripts/combat/projectile.gd`,
`scripts/factions/mechanics.gd`, `scripts/vfx/vfx.gd`, `scripts/audio/sfx.gd`.
- `Unit` (class_name extends Node3D): the workhorse.
  `signal died(unit)`; `var data: UnitData`, `player_id: int`, `hp`, `max_hp: float`.
  `setup(data: UnitData, pid: int) -> void` — builds model child from
  `data.model`, selection ring (hidden), health bar (billboard quad, hidden at
  full), registers with Game.
  Orders (all interrupt current, support `queued: bool` appending to `_queue`):
  `order_move(pos)`, `order_attack(target: Node3D)`, `order_attack_move(pos)`,
  `order_gather(node: ResourceNode)`, `order_build(bld: Building)`,
  `order_stop()`, `order_hold()`.
  `take_damage(amount: float, source) -> void` (dies -> explosion VFX, Game.unregister_unit).
  `alive() -> bool`, `is_air()`, `is_detector()` (Kitsune/towers),
  `faction_bonus_damage() -> float` (from Mechanics), `sight_range() -> float`.
  Movement: follows nav path (NavGrid passed via `Unit.nav: NavGrid` static or
  injected), speed from data * bonuses, simple separation from nearby allies
  (cap neighbor checks), air units fly at y=6 ignoring blockers.
  Combat: acquires nearest visible enemy (via FogOfWar + Game.enemies_of) within
  sight; if weapon targets allow; chases into `weapon.range`, fires on cooldown:
  instant if projectile_speed==0 else spawn Projectile. Turret node yaws to target.
  Stealth: Shinobi (`"stealth"` tag) only targetable per stealth rules.
  `_process(delta)`: state machine IDLE/MOVE/ATTACK/ATTACKMOVE/GATHER/BUILD/HOLD.
  Worker gathering: move to node, harvest 8 per 2s, return to nearest CC
  (Game.add_resources), repeat until node depleted then find nearest same-kind node.
  Worker building: move to site, channel until `bld.construction >= 1`.
- `Combat` (class_name, static): `apply_damage(target: Node3D, base: float, weapon: WeaponData, attacker) -> void`
  → `dmg = base * attacker.faction_bonus_damage() * tech_mult * Π bonus_vs[tag]`;
  round to int; splash: damage all enemy units/buildings within `weapon.splash`.
  `can_target(weapon, target) -> bool` (air/ground/stealth rules).
- `Projectile` (class_name extends Node3D): `setup(from, target_pos: Vector3, target: Node3D, weapon, attacker, speed)`;
  flies, on arrive → Combat splash/single + `VFX.explosion`. Pooled if easy.
- `Mechanics` (class_name, static): `damage_mult(unit) -> float`,
  `speed_mult(unit) -> float`, `sight_bonus(unit) -> float` implementing
  Battlefield Network (US: ≥1 other friendly US combat unit within 12m →
  +10% dmg, +2 sight; 20% with `network_uplink`) and Combat Synchronization
  (Japan robotic: ≥1 other friendly JP robotic within 10m → +12% speed, +10% dmg;
  20%/14m with `sync_protocol`). Tech effects also: `composite_armor`
  (vehicle_hp_mult), `drone_ai` (reaper mults), `ceramic_plating` (unit_hp_mult),
  `rail_amplifiers` (unit_dmg_mult) — apply in `Unit.setup` (hp) and
  `Mechanics.damage_mult`.
- `VFX` (autoload): pooled: `muzzle(pos, color)`, `tracer(from, to, color)`,
  `explosion(pos, scale)`, `sparks(pos)` (construction), `harvest_glint(pos)`,
  `smoke(pos)` (damaged buildings, when hp<50%), `helios_glow` handled by model.
  Keep counts small; no per-frame allocations in hot paths.
- `SFX` (autoload): procedural AudioStreamWAV: `play(name)` for
  `shoot, cannon, explosion, build, harvest, select, order, error, research,
  train, warning, victory, defeat, ui`. Lazy-init players; master/music/sfx
  volumes from Settings (see game chunk for settings keys).

## Chunk C — BUILDINGS & ECONOMY
Files: `scripts/buildings/building.gd`, `scripts/economy/economy.gd`
(may fold into Game calls), construction visuals.
- `Building` (class_name extends Node3D): `signal constructed(bld)`.
  `var data: BuildingData`, `player_id`, `hp`, `max_hp`, `built: bool`,
  `construction: float` (0..1).
  `setup(data, pid) -> void`: model child, blocks nav rect (footprint),
  hp=1 while constructing? Use hp=max_hp but `built=false`; takes no damage
  orders? Simpler: damageable always, but destroyed while constructing refunds 0.
  `add_build_power(amount)` called by workers each tick; at >=1 → `built=true`,
  Game.building_constructed.emit, Game.recompute_power.
  Construction visual: model scale y from 0.15→1 + scaffold color overlay
  (use a second material tint or scale-only + VFX.sparks from workers).
  Placement: `static can_place(nav, pos, footprint, pid) -> bool` (in-bounds,
  not blocked, min distance from other buildings).
  Production: `queue_unit(unit_id) -> bool` (Game.spend; up to 5 queued),
  `queue_research(upgrade_id) -> bool`; `_process`: if built and
  `power_ok()` → advance queue by `data.build_time` (slowed 50% on power
  shortage); spawn unit at rally point (free cell near building) via `Unit`;
  research → `player.techs[id]=true`, Game.tech_researched.emit.
  `power_ok() -> bool`: `data.power_use == 0 or not player.power_shortage()`.
  Defense towers: acquire/fire like units (reuse Combat + Projectile), but
  silent when power shortage.
  `alive() -> bool`, `take_damage(amount, source)`.
  Rally point: `set_rally(pos)`; default in front of building.
- Power/economy rules live in `Game` (recompute_power) + `Player`; chunk C
  just calls them. Construction costs are spent up-front on placement.

## Chunk D — GAME FLOW, INPUT, UI, AI, TOUCH
Files: `scripts/core/camera_rig.gd`, `scripts/core/selection.gd`,
`scripts/core/input_controller.gd`, `scripts/touch/touch_controls.gd`,
`scripts/ui/main_menu.gd`, `faction_select.gd`, `hud.gd`, `minimap.gd`,
`command_bar.gd`, `screens.gd` (victory/defeat/pause), `settings.gd`,
`scripts/ai/ai_commander.gd`, `scenes/main.tscn` (+ `scripts/main.gd` bootstrap),
`scripts/world/map_runtime.gd` (glue: builds HeliosValley, NavGrid, FogOfWar,
spawns gameplay nodes under a `World3D` root).
Bootstrap flow: main.tscn → main.gd → shows MainMenu; Skirmish → FactionSelect
(human picks US/Japan; enemy = the other); Start → Game.new_match →
MapRuntime.build() → HUD. Menu buttons: WORLD COMMAND title, Skirmish, Factions
(info screen reusing faction select cards), Settings, Credits, version v0.1.0.
Faction select: two playable cards (emblem drawn procedurally: US star /
Japan rising-sun disc via Control _draw), doctrine, strengths, weaknesses,
mechanic, unit list; five "COMING SOON" grayed cards (China, Germany, India,
Brazil, Russia — neutral one-line doctrine each, no power ranking).
- `CameraRig` (extends Node3D, class_name): child Camera3D, pitch ~50°.
  `pan(d)`, `zoom(factor)` (dist 18..70), `rotate(dyaw)` (Q/E),
  `move_to(pos)`, `screen_to_ground(screen_pos) -> Vector3`,
  `center_on(pos)`. Edge pan optional (settings).
- `Selection` (class_name extends Node): `selected: Array[Node3D]`,
  `select(a)`, `toggle(a)`, `clear()`, `box_select(rect) -> Array` (project
  unit positions via camera), groups: `set_group(i)`, `recall_group(i)`.
- `InputController` (extends Node): mouse+keyboard, feeds Selection/Unit orders:
  left-click select (shift toggles), drag box-select, right-click: smart order
  (enemy→attack, resource→gather if worker selected, own building→(worker)build/
  else move; ground→move), A+click attack-move, S stop, H hold, WASD/arrows pan,
  wheel zoom, Q/E rotate, Ctrl+1..9 groups, Esc deselect/menu.
- `TouchControls` (extends Control, full-rect, mouse_filter pass): tap=select,
  tap ground with selection=smart order (same as right-click), drag on empty
  = box-select, pinch=zoom, two-finger drag=pan, long-press (0.5s)=attack-move
  to point. Emits through the same order API as InputController (share a helper:
  put smart-order logic in `Selection.issue_smart_order(target_pos_or_node)`).
  Command bar (bottom, big buttons ≥64px): contextual — worker: Move/Gather/Build
  (build opens building picker)/Stop; combat: Attack/Move/Stop/Hold;
  building: Train list / Research list / Rally. Top bar: Supply, Helios,
  Power (prod/used, red when shortage), Units x/y, menu button.
  Portrait (<1.0 aspect): show ROTATE DEVICE overlay, keep menu usable.
- `Minimap` (Control, bottom-right ~220px): draws terrain (from a pre-baked
  ImageTexture the world chunk provides via `HeliosValley.get_minimap_image()`),
  dots: friendly green/blue, enemy red (only if FogOfWar.is_visible), resources
  yellow/cyan, camera rect white; click/drag → CameraRig.move_to.
- `AICommander` (extends Node): runs enemy pid. Tick 1Hz state machine:
  1) keep 8-10 workers (train from CC), 2) build order: power, barracks @~1:30,
  factory @~4:00, lab @~7:00, 2nd power @~5:00, towers @~6:00 near CC,
  3) assign workers to nearest supply (2-3 per node), 2 to helios after lab,
  4) train army mix per faction (US: rangers+guardians→abramsx+reapers;
  JP: raiden+shinobi→tora+ronin), 5) scout with 1 fast unit @~3:00,
  6) attack waves: first @~6:30 (4-6 units) at nearest enemy building, then
  every ~3 min bigger. Rebuilds lost workers/buildings basics. Uses the same
  Unit/Building APIs (no cheating resources — spends via Game.spend).
- HUD updates via Game signals. Victory/defeat screens with stats (time, units
  lost/killed) + Rematch / Menu buttons. Pause (Esc/P): resume, settings,
  quit-to-menu. Settings: graphics Low/Med/High (shadows, MSAA, vfx density),
  music/sfx mute, edge-pan toggle; persisted via ConfigFile to user://settings.cfg.

## Cross-chunk rules
- No chunk reaches into another chunk's scenes; only the APIs above.
- Null-check every `ResourceLoader.load` and every `get_node_or_null`.
- Never `FileAccess.file_exists("res://...")`.
- Headless-safe: no `@onready` dependency on autoload order beyond
  Game/Data/SFX/VFX (registered in project.godot).
- Keep per-frame work O(n) small; no allocations in _process hot loops.
- `class_name` collisions are fatal: each chunk owns its file list; shared
  names: Unit, Building, ResourceNode, NavGrid, FogOfWar, Combat, Projectile,
  Mechanics, Player, FactionData, UnitData, BuildingData, WeaponData, UpgradeData.
