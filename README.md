# WORLD COMMAND

An original near-future real-time strategy game built in **Godot 4.7**.
Command US or Japanese forces on Helios Valley — harvest Supply and Helios
crystals, raise a base, research battlefield tech, and break the enemy
Command Center.

## Play

The web build is served from this repo's root via GitHub Pages:

**https://outerheavenx.github.io/Thugs-RTS/**

Desktop and touch (landscape-first) supported.

## Status — v0.1.0 vertical slice

- US vs Japan skirmish on Helios Valley (128×128 m single-mesh terrain)
- Full RTS loop: gathering, construction, power, research, fog of war,
  minimap, combat, victory/defeat
- Faction mechanics: US Battlefield Network, Japan Combat Synchronization
- 6 buildings and ~5 combat units per faction; tech database in-game
- Seven-nation architecture (China, Germany, India, Brazil, Russia
  stubbed as Coming Soon)

## Build from source

Requires Godot 4.7.2.

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Web" ../world-command-web/index.html
```

Headless tests (scene-based):

```bash
godot --headless --path . res://tests/test_combat.tscn
```

## Layout

- `scripts/` — game code (units, buildings, world, AI, UI, data)
- `scenes/` — Godot scenes
- `assets/` — GLB models (Blender sources under `assets/blender/source/`,
  excluded from import via `.gdignore`)
- `docs/` — architecture, balance, test plan, changelog
- `tests/` — headless test scenes
- `index.*` — exported web build (served by Pages)

## Notes

- Original work: no paid or copied assets, code, or audio.
- Real nations are never framed as superior, evil, or inferior —
  factions differ in doctrine and mechanics, not moral worth.
