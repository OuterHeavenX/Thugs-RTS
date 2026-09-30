# WORLD COMMAND — Factions (v0.1.0 slice)

Two playable nations in the slice. Both are presented neutrally as
professional near-future militaries with distinct doctrines. Data source:
`scripts/factions/us_data.gd`, `scripts/factions/japan_data.gd`.

---

## United States

- **Doctrine:** "Networked combined arms. Flexible forces that grow
  stronger fighting together — drones, armor, and infantry sharing one
  battlefield picture."
- **Signature mechanic — Battlefield Network:** US combat units within
  **12m** of at least one other friendly US combat unit (workers excluded)
  gain **+10% damage** and **+2 sight range**.
  (`Mechanics.damage_mult`, `Mechanics.sight_bonus`)
- **Strengths (per faction data):** network damage/sight aura; strong air
  and drone options; flexible, well-rounded roster.
- **Weaknesses (per faction data):** individual units rarely dominate
  specialists; no stealth options.
- **Playstyle:** keep the army in mutually supporting groups, mix infantry,
  armor, drones, and artillery, and let the network aura compound. Punishes
  stragglers, rewards battle lines.
- **Tech structure:** Research Lab → **Network Uplink** (network damage
  bonus 10% → 20%), **Composite Armor** (+25% max HP for all vehicles),
  **Drone AI** (+20% damage and speed for Reaper drones).
- **Roster (6 units):** Pioneer (worker), Ranger Squad, Guardian IFV,
  Abrams-X Tank, Reaper Drone, Paladin Carrier. See `UNITS.md`.
- **Buildings (6):** Command Center, Fusion Generator, Barracks, Vehicle
  Factory, Research Lab, Sentry Tower. See `BUILDINGS.md`.
- **Color language:** steel gray + navy + white, blue emissive strips.

---

## Japan

- **Doctrine:** "Elite robotic warfare. Small, fast, precise forces —
  expensive units that win through synchronization and superior
  technology."
- **Signature mechanic — Combat Synchronization:** Japanese **robotic**
  units within **10m** of at least one other friendly Japanese robotic
  unit gain **+12% move speed** and **+10% damage**.
  (`Mechanics.speed_mult`, `Mechanics.damage_mult`)
- **Strengths (per faction data):** synchronization speed/damage aura;
  fast, elite units with excellent sensors; stealth options (Shinobi).
- **Weaknesses (per faction data):** units are expensive — losses hurt;
  small armies can be overwhelmed.
- **Playstyle:** small, fast, high-quality strike groups. Sync-linked
  robotic units outmaneuver and out-trade; Shinobi infiltrators harass
  armor; Kitsune drones provide unmatched vision and stealth detection.
- **Tech structure:** Tech Shrine → **Sync Protocol** (sync damage bonus
  10% → 20%, link range 10m → 14m), **Ceramic Plating** (+25% max HP for
  all units), **Rail Amplifiers** (+20% weapon damage for all units).
- **Roster (6 units):** Kōsaku Unit (worker), Raiden Infantry, Shinobi,
  Tora Hover Tank, Kitsune Drone (unarmed scout/detector), Ronin Mech.
  See `UNITS.md`.
- **Buildings (6):** Command Center, Helios Reactor, Dojo Barracks, Mech
  Foundry, Tech Shrine, Pulse Tower. See `BUILDINGS.md`.
- **Color language:** white ceramic + dark graphite, red emissive strips.

---

## Planned factions (not in the slice)

One-line doctrines from the in-game faction select screen; no stats, no
power ranking.

| Faction | Doctrine (planned) |
| ------- | ------------------ |
| China   | Mass-mobilization doctrine: overwhelming numbers and resilient industry. |
| Germany | Precision engineering doctrine: disciplined armor and methodical advances. |
| India   | Adaptive combined-arms doctrine: flexible formations for any terrain. |
| Brazil  | Expeditionary doctrine: rapid deployment and jungle-honed mobility. |
| Russia  | Deep-battle doctrine: layered artillery and armored spearheads. |

All five are **PLANNED** — grayed-out "COMING SOON" cards in the UI.
