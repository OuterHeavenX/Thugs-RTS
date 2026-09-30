# WORLD COMMAND — Buildings (v0.1.0 slice)

Generated from `scripts/factions/us_data.gd` and
`scripts/factions/japan_data.gd`. Construction costs are spent up-front on
placement; workers then channel construction (each worker contributes
1/build_time of progress per second; multiple workers stack linearly).
Destroyed buildings refund nothing. `S` = Supply, `H` = Helios,
`t` = base build time (seconds), footprint in nav cells (2m each).

Both factions share the same six building roles with faction-specific
names, stats identical except where noted.

| Building (US / Japan) | Purpose | Cost | HP | Power | Footprint | Trains / Researches |
| --------------------- | ------- | ---- | --: | ----- | --------- | ------------------- |
| Command Center | Trains workers. Heart of the base. Pre-built at match start for both players. | — (starts built; excluded from the build picker — "CC is unique") | 1500 | +30 | 5x5 | worker |
| Fusion Generator / Helios Reactor | Power generation. | 100S, 20t | 500 | **+120** | 3x3 | — |
| Barracks / Dojo Barracks | Trains infantry. | 150S, 30t | 800 | -10 | 4x4 | US: ranger · JP: raiden, shinobi |
| Vehicle Factory / Mech Foundry | Builds vehicles, drones, mechs. | 200S+25H, 40t | 900 | -20 | 5x4 | US: guardian, abramsx, reaper, paladin · JP: tora, kitsune, ronin |
| Research Lab / Tech Shrine | Researches upgrades. Requires power. | 200S+50H, 40t | 700 | -25 | 4x4 | US: network_uplink, composite_armor, drone_ai · JP: sync_protocol, ceramic_plating, rail_amplifiers |
| Sentry Tower / Pulse Tower | Automated defense. | 125S+25H, 25t | 600 | -15 | 2x2 | — (armed) |

## Defense towers

| Tower | Weapon | Dmg / Range / CD | Bonuses | Projectile |
| ----- | ------ | ---------------- | ------- | ---------- |
| Sentry Tower (US) | Sentry guns | 12 / 18m / 0.9s | infantry x1.5, air x1.5 | 70 m/s, targets air + ground |
| Pulse Tower (JP) | Pulse cannon | 16 / 18m / 1.2s | vehicle x1.5, tank x1.5 | 75 m/s, targets air + ground |

- Towers acquire the nearest visible enemy in range (scan every 0.3s) and
  fire on cooldown.
- Towers **detect stealth**: a stealth unit within 25m of a tower is
  targetable (`Combat._stealth_visible`).
- Design intent is that towers go silent during a power shortage; per the
  current code the defense scan is *not* gated on power — see
  `CHANGELOG.md` (known deviation, unverified against design intent).
- Turret models yaw to the target (`Turret` / `Muzzle` named nodes).
- Damaged buildings (hp < 50%) emit smoke VFX.

## Upgrades (researched at the Lab / Tech Shrine)

One research at a time per building; costs paid up-front; queue entry is
cancelable with a full refund.

| Upgrade (US) | Effect | Cost | Time |
| ------------ | ------ | ---- | ---- |
| Network Uplink | Battlefield Network damage bonus 10% → 20% | 150S+50H | 45s |
| Composite Armor | +25% max HP for all vehicles (applies at spawn) | 150S+50H | 45s |
| Drone AI | +20% damage and +20% speed for Reaper drones | 125S+75H | 40s |

| Upgrade (Japan) | Effect | Cost | Time |
| --------------- | ------ | ---- | ---- |
| Sync Protocol | Combat Sync damage bonus 10% → 20%, link range 10m → 14m | 150S+50H | 45s |
| Ceramic Plating | +25% max HP for all units (applies at spawn) | 150S+50H | 45s |
| Rail Amplifiers | +20% weapon damage for all units | 150S+75H | 45s |

## Placement & production rules

- Placement must be in-bounds (4m margin), on walkable cells; buildings
  block their nav rect on placement (`place_at`) and unblock on death.
- Production queue: up to 5 entries; only the front entry advances.
- Queueing a unit or research requires power OK (no shortage). Production
  advances at 50% speed during a power shortage.
- Canceling a queued entry refunds its full cost.
- New units spawn at the rally point (default: in front of the building;
  settable via `set_rally`).
