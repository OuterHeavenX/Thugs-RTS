# WORLD COMMAND — Combat model (v0.1.0 slice)

Sources: `scripts/combat/combat.gd`, `scripts/units/unit.gd`,
`scripts/combat/projectile.gd`, `scripts/factions/mechanics.gd`,
`scripts/buildings/building.gd`.

## Damage formula

```
final = max(1, round(base_damage
                     × faction/mechanic/tech multipliers
                     × Π bonus_vs[armor_tag]))
```

- `base_damage`: the weapon's `damage` stat.
- Mechanic/tech multipliers come from `Mechanics.damage_mult`: US
  Battlefield Network (+10% / +20% with Network Uplink), Japan Combat
  Synchronization (+10% / +20% with Sync Protocol), Drone AI (+20% for
  Reapers), Rail Amplifiers (+20% all Japan weapons).
- `bonus_vs` multiplies per armor tag on the target (e.g. a weapon with
  `{"vehicle": 1.5}` hitting a `["vehicle", "tank"]` target applies 1.5x
  once per matching tag — tags multiply, they don't double-apply unless
  both are listed).
- Minimum 1 damage per hit; damage is rounded to int.

Example: an Abrams-X (35 dmg, vehicle x1.5) firing at a Tora
(`vehicle`, `tank` tags) with its network aura active:
`round(35 × 1.10 × 1.5)` = 58 per shot.

## Weapons: hitscan vs projectiles

- `projectile_speed == 0` → **instant** (melee, beams): damage applies
  immediately with a tracer visual (`VFX.tracer`).
- `projectile_speed > 0` → **projectile**: a homing-ish projectile flies
  from the muzzle toward the target's position at that speed (m/s) and
  impacts on arrival (or when the target dies), applying splash/single
  damage via `Combat`.
- Units and towers with damage ≥ 30 (or any splash) play the "cannon"
  sound; lighter weapons play "shoot".

## Armor tags and counters

Tags: `infantry`, `light`, `vehicle`, `tank`, `air`, `building`,
`artillery`, `stealth`, `elite`. Every unit lists its counter matchups in
its `counter_note` (see `UNITS.md`). The designed counter triangle:

- **Anti-infantry:** Guardian IFV (infantry x1.6), Sentry Tower
  (infantry x1.5)
- **Anti-armor:** Shinobi (vehicle/tank x1.75), Abrams-X (vehicle x1.5),
  Tora (vehicle x1.5), Pulse Tower (vehicle/tank x1.5), Reaper (vehicle/tank
  x1.6)
- **Anti-air:** Sentry Tower (air x1.5); Reaper targets air too
- **Anti-building:** Paladin (building x2.0), Abrams-X (building x1.5),
  Ronin (building x1.25)
- **Anti-cluster:** splash weapons — Paladin 3.0m, Ronin 2.0m, Reaper 2.0m,
  Abrams-X/Tora 1.5m. Splash hits *all* enemies in radius, buildings
  included.

## Air / ground targeting

- `weapon.targets_air` / `weapon.targets_ground` gate engagement.
  Air units fly at y=6 and ignore nav blockers.
- Both defense towers target air **and** ground.
- Kitsune is unarmed; workers are unarmed.

## Stealth and detection

- The Shinobi carries the `stealth` tag. It is **untargetable** unless:
  1. the attacker is within **6m** (point-blank reveal), or
  2. a friendly **detector** is within **25m** of the Shinobi.
- Detectors: the Kitsune drone (`is_detector()`), and any built defense
  tower (tower buildings count as detectors).
- Stealth is **targeting-only**: it lives entirely in
  `Combat.can_target`. There is no decloak-on-attack, no stealth shimmer,
  and no separate UI treatment for stealthed units in the slice.

## Target acquisition

- Units scan for targets every 0.25s (staggered across 8 slots so not all
  units scan the same frame), acquiring the nearest visible enemy within
  sight range that the weapon can target.
- Orders: move, attack (explicit target, chases), attack-move (advances,
  stops to engage targets in range), stop, hold position, plus queued
  orders (`queued: true` appends).
- Separation steering pushes units apart (capped at ~8 neighbors) with a
  tangential slide so head-on approaches slip around blockers instead of
  stalling.

## Tech HP bonuses

Applied once at spawn via `Mechanics.max_hp_for`:

- US **Composite Armor**: +25% max HP for all vehicles.
- Japan **Ceramic Plating**: +25% max HP for all units.

Researching the tech does not retroactively buff existing units —
**unverified** in the current slice whether mid-game research updates
already-fielded units; the code applies it only in `Unit.setup`.
