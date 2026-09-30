# WORLD COMMAND — Game Design

**Genre:** near-future military real-time strategy (RTS), vertical slice.
**Matchup:** United States vs Japan on the Helios Valley map.
**Engine:** Godot 4.7 (gl_compatibility). **Version:** v0.1.0.

## Vision

A grounded, near-future RTS about two technologically advanced militaries
contesting a resource-rich valley. The fantasy is *combined-arms command*:
infantry, armor, drones, and artillery fighting as one force under a
commander who manages economy, power, and technology on a single 128x128m
battlefield. Everything is original IP — no licensed factions, no borrowed
lore.

## Design pillars

1. **Symmetric-ish combined arms.** Both factions field infantry, vehicles,
   air, artillery, static defense, and a tech lab. Rosters differ in flavor
   and stat profile, not in completeness — a new player can transfer their
   fundamentals between sides.
2. **Doctrine mechanics, not gimmicks.** Each faction has one signature
   positional mechanic that rewards formation play:
   - US **Battlefield Network** — combat units near another friendly US
     combat unit gain +10% damage and +2 sight (+20% damage with Network
     Uplink). Rewards keeping forces together.
   - Japan **Combat Synchronization** — robotic units near another friendly
     robotic unit gain +12% speed and +10% damage (+20% damage, 14m link
     range with Sync Protocol). Rewards tight, elite formations.
3. **Helios as the second resource.** Supply keeps the army fed; Helios —
   a rare crystal found only in contested ground — unlocks the heavy
   hitters. Teching up means fighting for the map center, not turtling.
4. **Power as a live grid.** Every advanced structure and defense tower
   draws power; generators produce it. Run a deficit and production slows
   50% and power-hungry systems go dark. Power is a resource you *route*,
   not a build cost you pay once.
5. **Readable at a glance.** Armor tags, weapon counters, and one-line
   counter notes on every unit. A player should be able to answer "what
   beats this?" without a wiki.

## Win / lose

- **Victory:** destroy all enemy buildings. A player with zero buildings
  loses — workers alone cannot rebuild (`Game.check_victory`).
- **Defeat:** lose all of your own buildings.
- Match end shows stats: match time, units lost, units killed; Rematch and
  Menu buttons.

## Core loop

1. **Expand the economy** — train Pioneers/Kōsaku Units, harvest Supply from
   deposits and Helios from crystals, build generators, barracks, factory,
   lab.
2. **Tech and power** — research faction upgrades; keep power production
   ahead of consumption.
3. **Scout** — fast units and recon drones push into fog to find the enemy
   base and the central Helios field.
4. **Fight for the center** — Helios crystals sit in the middle of the
   valley; controlling them funds the late-game army.
5. **Break the base** — artillery and anti-building units crack defenses;
   destroy every enemy structure.

A skirmish runs on the order of 8–15 minutes against the built-in AI
commander (rough estimate from its wave timings — first wave at 6:30,
then every ~3 minutes; unverified by playtest).

## What makes it original (not a StarCraft clone)

- **No asymmetric weirdness for its own sake.** The asymmetry lives in two
  clean positional auras (Network vs Synchronization), not in three totally
  different economies.
- **Power grid as a combat lever.** Shortages slow production 50% and shut
  down defense towers — raiding a generator is a legitimate strategy.
- **Helios forces map control.** The tech resource is centralized and
  finite; you cannot max out your army from your starting base alone.
- **Stealth is tactical, not magical.** Shinobi are invisible until
  point-blank range (6m) or a detector (Kitsune drone or any defense tower)
  gets within 25m — a scouting and harassment tool with hard counters.
- **No hero units, no micromanagement spells.** The skill expression is
  positioning, composition, economy timing, and power management.

## Scope of the slice

- 1 map (Helios Valley), 2 factions, 6 units + 6 buildings + 3 upgrades
  per faction, 1 AI opponent, skirmish only.
- Desktop (mouse + keyboard) and touch (phone/tablet browser) input.
- No campaign, no multiplayer, no naval/air-transport layers — see
  `ROADMAP.md`.
