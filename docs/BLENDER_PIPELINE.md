# WORLD COMMAND — Blender → Godot art pipeline

## Toolchain

- **Blender 4.5.3 LTS**, headless, driven by generator scripts in
  `tools/blender_art/` (`lib.py` + 5 category scripts:
  `buildings_us.py`, `buildings_jp.py`, `units_us.py`, `units_jp.py`,
  `environment.py`).
- All 29 models are **procedurally built** in Blender (no sculpted or
  purchased assets) and exported as **glTF 2.0 binary (.glb)**.
- Godot 4.7 imports the .glb files directly.

## Conventions

- **Units:** meters, Z-up in Blender (Godot converts to Y-up on import),
  origin at **bottom-center** of the model.
- **Materials:** Principled BSDF only — Base Color / Metallic / Roughness /
  Emission. No textures on models.
- **Transforms:** all baked; special nodes keep **translation-only**
  transforms with their origin on the pivot axis.
- **Faction color language:** US = steel gray + navy + white with BLUE
  emissive strips; Japan = white ceramic + dark graphite with RED emissive
  strips.

## Named nodes (the engine reads these)

Optional in every file — the engine null-checks all of them.

| Node | Purpose | Found on |
| ---- | ------- | -------- |
| `Turret` | Yaw node, rotates to face target | Defense towers, Abrams-X, Guardian, Ronin |
| `Muzzle` | Marker3D — projectile/tracer spawn point | Most armed units, both towers |
| `Rotor` / `Rotor_1..4` | Spin animation anchor | Kitsune, Reaper Drone |
| `Dish` | Lab sensor dish | Both research labs |
| `Core` | Generator core | Both power generators |
| `Glow` | Crystal glow | Helios crystal |

## Triangle budgets

| Category | Budget | Actual max |
| -------- | ------ | ---------- |
| Buildings | < 2000 tris | jp_power_generator: 924 |
| Units | < 1500 tris | jp_raiden: 984 |
| Props | < 600 tris | abandoned_facility: 320 |

All 29 assets are within budget. Full per-file tri counts and named-node
lists: `assets/MANIFEST.md`.

## Thumbnails

- `assets/thumbs/<name>.png` — Cycles renders, 192px, one per asset.
- Used by build pickers / faction screens.

## Sources and the `.gdignore` rule

- Blender sources: `assets/blender/source/<name>.blend` (one per asset).
- **Critical:** `assets/blender/source/.gdignore` must exist. If `.blend`
  files live anywhere under `res://` without it, headless `--import`
  tries to import them via Blender, fails ("Cannot configure blender
  path in headless mode"), and the **entire reimport phase silently never
  runs** — `.godot/imported/` stays empty and every `.glb` then fails at
  runtime with "No loader found". This actually happened on 2026-09-29;
  after adding the `.gdignore`, reimport succeeded and all 29 glbs
  imported (116 imported files total).

## Asset list

- Buildings (12): `us/jp_command_center`, `us_power_generator` /
  `jp_power_generator`, `us/jp_barracks`, `us/jp_vehicle_factory`,
  `us/jp_research_lab`, `us/jp_defense_tower` — under
  `assets/models/buildings/`.
- Units (12): `us_worker`, `us_ranger`, `us_guardian_ifv`, `us_abramsx`,
  `us_reaper_drone`, `us_paladin`, `jp_worker`, `jp_raiden`, `jp_shinobi`,
  `jp_tora`, `jp_kitsune`, `jp_ronin` — under `assets/models/units/`.
- Environment (5): `supply_deposit`, `helios_crystal`, `tree`, `rock`,
  `abandoned_facility` — under `assets/models/environment/`.
