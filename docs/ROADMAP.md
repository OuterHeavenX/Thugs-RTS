# WORLD COMMAND — Roadmap

## In the v0.1.0 slice (done)

- 1 map: Helios Valley (128x128m, single-mesh terrain, nav grid, fog of war)
- 2 playable factions: United States, Japan — 6 units, 6 buildings,
  3 upgrades each
- Full loop: harvest → build → power → research → scout → attack waves →
  victory/defeat
- AI commander (single difficulty, no cheating)
- Desktop (mouse/keyboard) + touch controls, landscape-first
- 29 procedural Blender 4.5.3 models (.glb), thumbnails, named-node rigging
- Web export preset (single-threaded), victory/defeat/pause/settings
  screens, control groups, minimap

## Planned

- **More factions:** China, Germany, India, Brazil, Russia — grayed-out
  "COMING SOON" cards already in the faction select with one-line
  doctrines (see `FACTIONS.md`). Data-driven via `FactionData`; new
  faction = new data file + models.
- **Campaign:** scripted missions. Not started.
- **Multiplayer:** not started; the `Player`/`Game` API is per-match and
  would need a networking layer.
- **More maps and units:** the data files are built for extension
  (`Data.unit/building/upgrade` lookups, no hardcoded stats in systems).
- **AI difficulties:** the commander is one fixed build order/timing set.

## Honest gaps in the slice

- **Stealth is targeting-only.** Shinobi can't be targeted per the
  stealth rules, but there is no decloak-on-attack, no stealth shimmer,
  and no separate UI treatment — unverified how readable it is in actual
  fogged play.
- **No naval layer.** No water combat, no transports.
- **No air transports or drops.** Air units are combat/scout only.
- **AI never researches** and never expands to the 4 expansion sites; it
  follows one fixed build order with no counter-play.
- **Defense towers fire during power shortages** in the current build,
  against the design intent ("shuts down in a power shortage") — known
  deviation, see `CHANGELOG.md`.
- **Projectile setup arg mismatch:** `Building._fire` passes 6 arguments
  to `Projectile.setup`, which takes 5 — tower-fired projectiles will
  error at runtime. Known bug, see `CHANGELOG.md`.
- **Tech HP bonuses apply only at spawn** — researching Composite Armor /
  Ceramic Plating mid-game does not buff already-fielded units
  (unverified whether this is intended).
- **No rally queue / waypoint system** beyond single queued orders.
- Unit/building stat balance is first-pass; no playtest tuning data yet.
