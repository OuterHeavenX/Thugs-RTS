# WORLD COMMAND — Units (v0.1.0 slice)

Generated from `scripts/factions/us_data.gd` and
`scripts/factions/japan_data.gd`. Costs are paid up-front when training.
`S` = Supply, `H` = Helios, `t` = build time (seconds). Weapon columns:
damage / range (m) / cooldown (s). "Counter" is the unit's own
`counter_note` from the data files.

## United States

| Unit | Role | Cost | HP | Spd | Sight | Armor tags | Weapon | Counter |
| ---- | ---- | ---- | --: | --: | ----: | ---------- | ------ | ------- |
| Pioneer | Worker: gathers Supply/Helios, constructs buildings | 50S, 10t | 45 | 4.5 | 14 | infantry, light | — | Fragile. Keep away from combat. |
| Ranger Squad | Versatile infantry, assault rifles | 50S, 12t | 60 | 4.2 | 18 | infantry, light | Assault rifle 8 / 14 / 1.0 — bonus vs light x1.5 | Strong vs light units. Weak vs vehicles. |
| Guardian IFV | Fast infantry fighting vehicle, autocannon | 110S, 18t | 220 | 7.0 | 20 | vehicle | Autocannon 10 / 15 / 0.8 — bonus vs infantry x1.6, projectile 60 m/s | Strong vs infantry. Vulnerable to anti-armor. |
| Abrams-X Tank | Main battle tank, heavy cannon | 160S+40H, 25t | 450 | 6.0 | 18 | vehicle, tank | 120mm cannon 35 / 18 / 2.5 — bonus vs vehicle x1.5, building x1.5, splash 1.5m, projectile 45 m/s | Strong vs vehicles and buildings. Counter with anti-armor. |
| Reaper Drone | Armed drone, anti-vehicle from above | 140S+50H, 22t | 140 | 10.0 | 24 | air (robotic) | Hellfire missiles 18 / 20 / 2.0 — bonus vs vehicle x1.6, tank x1.6, splash 2.0m, projectile 55 m/s, targets air | Strong vs vehicles. Vulnerable to anti-air. |
| Paladin Carrier | Long-range missile artillery | 170S+60H, 28t | 160 | 5.5 | 22 | vehicle, artillery | MLRS barrage 40 / 26 / 4.0 — bonus vs building x2.0, splash 3.0m, projectile 40 m/s | Strong vs buildings and clusters. Fragile — protect it. |

Notes:
- Reaper is the only US air unit; it flies at y=6 and ignores terrain
  blockers.
- Paladin's 26m range is the longest US weapon; its splash (3.0m) punishes
  clumped armies and buildings alike.
- US has no stealth units and no dedicated detector unit (defense towers
  detect stealth).

## Japan

| Unit | Role | Cost | HP | Spd | Sight | Armor tags | Weapon | Counter |
| ---- | ---- | ---- | --: | --: | ----: | ---------- | ------ | ------- |
| Kōsaku Unit | Worker frame: gathers, constructs | 50S, 10t | 45 | 4.8 | 14 | infantry, light (robotic) | — | Fragile. Keep away from combat. |
| Raiden Infantry | Elite infantry, rail rifles | 75S, 14t | 80 | 4.6 | 20 | infantry | Rail rifle 14 / 16 / 1.4 — bonus vs light x1.4, vehicle x1.25, projectile 80 m/s | Strong all-rounder infantry. Costly. |
| Shinobi | Stealth infiltrator, plasma blade, anti-armor | 100S+25H, 16t | 70 | 5.5 | 16 | infantry, stealth | Plasma blade 20 / 2.5 / 1.2 — bonus vs vehicle x1.75, tank x1.75, melee (instant) | Invisible until very close or detected. Deadly vs tanks. |
| Tora Hover Tank | Fast hover tank, strike-and-fade | 175S+50H, 26t | 400 | 8.0 | 19 | vehicle, tank (robotic) | Hover cannon 30 / 17 / 2.2 — bonus vs vehicle x1.5, splash 1.5m, projectile 50 m/s | Fast raider. Counter with anti-armor. |
| Kitsune Drone | Recon drone, huge sight, detects stealth | 90S+25H, 16t | 120 | 11.0 | 34 | air (robotic) | — (unarmed) | Unarmed scout. Detects Shinobi. |
| Ronin Mech | Elite combat mech | 280S+140H, 40t | 700 | 5.0 | 20 | vehicle, tank, elite (robotic) | Rail cannon 45 / 20 / 2.8 — bonus vs vehicle x1.5, building x1.25, splash 2.0m, projectile 60 m/s | Elite and expensive. Focus fire to bring down. |

Notes:
- Shinobi is the slice's only stealth unit: untargetable beyond 6m unless
  a Kitsune or a defense tower is within 25m of it.
- Kitsune (sight 34) is the longest vision in the slice; fast (11.0) but
  fragile and unarmed.
- Tora (speed 8.0) is the fastest ground combat unit in the slice.
- The Kōsaku Unit is robotic, so it also gains the +12% sync speed bonus
  when near another friendly robotic unit (damage bonus is moot — it has
  no weapon). The US Battlefield Network explicitly excludes workers from
  both its damage and sight bonuses.

## Global rules

- **Unit cap:** 60 units per player (`UNIT_CAP`), shown in the HUD as
  `x/60`.
- Workers harvest 8 resource per 2s tick, carry up to 40, and deposit at a
  Command Center.
- Tech HP bonuses apply at spawn: US Composite Armor (+25% vehicle HP),
  Japan Ceramic Plating (+25% all-unit HP). See `COMBAT.md`.
