# WORLD COMMAND — AI Commander (v0.1.0 slice)

Source: `scripts/ai/ai_commander.gd`. One difficulty, no cheating: the AI
uses the same `Game.spend`, `Building`, and `Unit` APIs as the human.

## Architecture

- `AICommander` extends Node, ticks at **1 Hz** (plus worker reassignment
  every 3s).
- Fully null-guarded; idles with a warning if the building chunk is
  missing. Inert unless a match is playing.

## Economy

- Trains workers from the Command Center until **9 workers**
  (`WORKER_TARGET`), respecting the 60-unit cap.
- Worker assignment (every 3s): prunes dead/depleted assignments, then
  assigns unassigned workers — first 2 to helios once the Lab exists,
  the rest spread across supply nodes **2–3 per node**, nearest first.
- Rebuilds lost workers automatically.

## Build order (match-time triggers, from code)

| Time | Building |
| ---- | -------- |
| 0:40 | Power (near CC) |
| 1:30 | Barracks |
| 4:00 | Factory |
| 4:30 | Power #2 (near CC) |
| 6:00 | Defense tower (near CC) |
| 7:00 | Lab |
| 9:00 | Defense tower #2 (near CC) |

- Buildings already present are skipped; placement probes rings (10–30m)
  around the base/CC for a valid site via `Building.can_place`.
- A per-building 30s attempt cooldown prevents spam when placement or
  funds fail.
- The nearest worker is sent to construct each new building.

> Note: `ARCHITECTURE.md` lists slightly different timings
> (barracks @~1:30, factory @~4:00, lab @~7:00, towers @~6:00). The table
> above is what the code does.

## Army production

- **US:** Barracks mixes Rangers (~2/3) and Guardians (~1/3); Factory
  alternates Abrams-X and Reapers.
- **Japan:** Barracks mixes Raiden (~3/4) and Shinobi (~1/4); Factory picks
  Tora / Ronin / Kitsune in a 2:2:1 ratio.
- First production building sets a rally point 14m toward the enemy base
  so the army masses at home.

## Scouting

- At **3:00**, the AI sends its fastest unit on an attack-move to the
  enemy base. One scout, once.

## Attack waves

- **First wave at 6:30** if it has at least 5 combat units; all combat
  units attack-move toward the enemy base center.
- Repeats every **~3 minutes** while the army threshold holds — each wave
  is bigger as production compounds.
- The AI does not retreat, focus-fire, or micro; it rebuilds and comes
  back.

## Difficulty notes

- Single difficulty in the slice. Challenge comes from build-order timing
  and compounding production, not from reaction speed or cheating.
- Known limitations (see `ROADMAP.md`): no expansion to the 4 expansion
  sites, the AI never researches upgrades (no `queue_research` call in
  this build), no counter-play against the player's composition, no
  defense of its own expansions.
