# WORLD COMMAND — Economy (v0.1.0 slice)

Sources: `scripts/autoload/game.gd`, `scripts/core/player.gd`,
`scripts/units/worker.gd`, `scripts/world/resource_node.gd`,
`scripts/world/helios_valley.gd`, `scripts/buildings/building.gd`.

## Resources

| Resource | What it's for | Sources |
| -------- | ------------- | ------- |
| **Supply** | Workers, buildings, most units — the everyday economy | Supply deposits (1500 each) |
| **Helios** | Advanced units (tanks, drones, artillery), Factory, Lab, towers, all upgrades | Helios crystals (800 each) |

- **Starting stockpile:** 400 Supply, 0 Helios.
- **Map layout (Helios Valley):** 5 supply deposits ring each base
  (~12–20m out); 7 helios crystals form a contested central field (~8–14m
  around map center); 2 expansion sites per side (each: 3 supply + 2
  helios).
- Nodes are finite: a Supply deposit holds 1500, a Helios crystal 800.
  Empty nodes emit `depleted` and remove themselves; workers automatically
  move to the nearest node of the same kind.

## Harvesting (as coded)

- Workers harvest **8 resource per 2-second tick** while within 2.5m of a
  node.
- **Carry capacity 40** per trip; the worker then returns to the nearest
  built Command Center to deposit (`Game.add_resources`), then resumes the
  nearest same-kind node.
- Effective rate per worker: ~20 resource/minute before travel time; a
  full 40-carry takes 5 ticks = 10s of harvesting plus two trips.
- AI assigns 2–3 workers per supply node and 2 workers to helios once its
  Lab is built; players manage this manually.

## Power grid

- Each player tracks **power produced** vs **power consumed**, recomputed
  whenever a building is placed, constructed, or destroyed
  (`Game.recompute_power`). Only *built* buildings count.
- **Shortage** = consumed > produced (`Player.power_shortage()`).
- During a shortage (`Building.power_factor`):
  - production and research advance at **50% speed**;
  - queueing new units/research is blocked until power is OK.
- Defense towers and research require power OK; towers counter "shuts down
  in a power shortage" — though the current build's defense scan is not
  yet gated on power (see `CHANGELOG.md`, known deviation).
- Typical budget: Command Center (+30) + one Generator (+120) = 150 power,
  enough for Barracks (10) + Factory (20) + Lab (25) + one Tower (15) = 70
  with headroom for a second tower or expansion.

## Construction

- Costs are spent **up-front** on placement (`Game.spend`).
- Each worker channels `1 / build_time` progress per second; multiple
  workers stack linearly (2 workers ≈ half the build time).
- Construction visual: model scales from 0.12 to full height with a
  translucent scaffold ghost and spark VFX.
- Destroyed buildings (even unbuilt ones) refund nothing.

## Victory economy

There is no "destroy the workers" win condition — a player with **zero
buildings** loses immediately, checked automatically on every building
death (`Game.check_victory`). Denying expansions and sniping generators
wins games.
