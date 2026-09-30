# WORLD COMMAND — Art Manifest

29 original low-poly models built procedurally in Blender 4.5.3 LTS,
exported as glTF 2.0 binary (.glb). Z-up meters in Blender, origin at
bottom-center of each model. Godot converts to Y-up on import.
Materials: Principled BSDF only (Base Color / Metallic / Roughness /
Emission). All transforms baked; special nodes keep translation-only
transforms with their origin on the pivot axis.

Faction color language: US = steel gray + navy + white, BLUE emissive
strips. Japan = white ceramic + dark graphite, RED emissive strips.

## Buildings (12)

| File | Tris | Named nodes |
| ---- | ---: | ----------- |
| `assets/models/buildings/jp_barracks.glb` | 260 | — |
| `assets/models/buildings/jp_command_center.glb` | 524 | — |
| `assets/models/buildings/jp_defense_tower.glb` | 608 | `Turret`, `Muzzle` |
| `assets/models/buildings/jp_power_generator.glb` | 924 | `Core` |
| `assets/models/buildings/jp_research_lab.glb` | 528 | `Dish` |
| `assets/models/buildings/jp_vehicle_factory.glb` | 204 | — |
| `assets/models/buildings/us_barracks.glb` | 280 | — |
| `assets/models/buildings/us_command_center.glb` | 580 | — |
| `assets/models/buildings/us_defense_tower.glb` | 216 | `Turret`, `Muzzle` |
| `assets/models/buildings/us_power_generator.glb` | 496 | `Core` |
| `assets/models/buildings/us_research_lab.glb` | 560 | `Dish` |
| `assets/models/buildings/us_vehicle_factory.glb` | 252 | — |

## Units (12)

| File | Tris | Named nodes |
| ---- | ---: | ----------- |
| `assets/models/units/jp_kitsune.glb` | 512 | `Rotor` |
| `assets/models/units/jp_raiden.glb` | 984 | `Muzzle` |
| `assets/models/units/jp_ronin.glb` | 524 | `Turret`, `Muzzle` |
| `assets/models/units/jp_shinobi.glb` | 632 | — |
| `assets/models/units/jp_tora.glb` | 676 | `Muzzle` |
| `assets/models/units/jp_worker.glb` | 672 | — |
| `assets/models/units/us_abramsx.glb` | 548 | `Turret`, `Muzzle` |
| `assets/models/units/us_guardian_ifv.glb` | 624 | `Turret`, `Muzzle` |
| `assets/models/units/us_paladin.glb` | 860 | `Muzzle` |
| `assets/models/units/us_ranger.glb` | 708 | `Muzzle` |
| `assets/models/units/us_reaper_drone.glb` | 756 | `Rotor_1`, `Rotor_2`, `Rotor_3`, `Rotor_4` |
| `assets/models/units/us_worker.glb` | 672 | — |

## Environment (5)

| File | Tris | Named nodes |
| ---- | ---: | ----------- |
| `assets/models/environment/abandoned_facility.glb` | 320 | — |
| `assets/models/environment/helios_crystal.glb` | 116 | `Glow` |
| `assets/models/environment/rock.glb` | 60 | — |
| `assets/models/environment/supply_deposit.glb` | 256 | — |
| `assets/models/environment/tree.glb` | 70 | — |

## Verification

- All 29 .glb files load in Godot 4.7.2 headless (`ResourceLoader.load`
  returns a valid PackedScene, non-zero mesh instances).
- Triangle counts above confirmed identical in Blender and Godot.
- Named-node check passed for every asset (Turret / Muzzle / Rotor /
  Dish / Core / Glow present where specified).
- Budgets: buildings < 2000 tris, units < 1500 tris, props < 600 tris —
  all assets within budget (max: jp_raiden 984, jp_power_generator 924).

## Sources

- Blender sources: `assets/blender/source/<name>.blend` (one per asset)
- Generator scripts: `tools/blender_art/` (`lib.py` + 5 category scripts)
- Thumbnails: `assets/thumbs/<name>.png` (Cycles, 192px)
