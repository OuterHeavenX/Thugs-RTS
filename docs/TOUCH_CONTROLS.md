# WORLD COMMAND — Touch controls (v0.1.0 slice)

Sources: `scripts/touch/touch_controls.gd`, `scripts/core/input_controller.gd`,
`scripts/core/camera_rig.gd`, `scripts/ui/hud.gd`. Touch and mouse share
the same order API (`Selection.issue_smart_order`), so behavior is
identical across inputs.

**Landscape-first design.** The game is tuned for landscape; portrait
shows a full-screen **ROTATE DEVICE / Landscape recommended** overlay
while keeping the menu usable.

## Touch gestures

| Gesture | Action |
| ------- | ------ |
| Tap (own unit/building) | Select |
| Tap (enemy, with selection) | Smart order: attack |
| Tap (ground, with selection) | Smart order: move (workers: gather if a resource node was tapped, build if own building tapped) |
| Tap (ground, building-placement armed) | Confirm placement |
| Single-finger drag | Box-select (rubber-band rectangle) |
| Pinch | Zoom (camera distance 18–70m) |
| Two-finger drag | Pan the map |
| Long-press (0.55s) | Attack-move to that point |

- Tap detection: < 0.25s, < 12px movement. Pick radius 28px.
- No two-finger rotate gesture in the slice; camera rotate is keyboard
  Q/E only.

## HUD (touch-sized)

- **Top bar:** Supply, Helios, Power (produced/consumed — flashes red in
  shortage), Units x/60, menu button.
- **Command bar (bottom):** contextual, buttons ≥ 64px:
  - Worker: Move / Gather / Build (opens the building picker) / Stop
  - Combat units: Attack / Move / Stop / Hold
  - Buildings: Train list / Research list / Rally
- **Minimap (bottom-right, ~220px):** terrain, friendly/enemy dots (enemy
  only if visible in fog), resources, camera rect; tap/drag to jump the
  camera.
- Building picker lists all player-buildable structures with costs; the
  Command Center is excluded (unique).
- Pause menu: resume, settings (graphics, music/sfx, edge-pan), quit to
  menu.

## Desktop controls (for reference)

Left-click select (Shift toggles), drag box-select, right-click smart
order, **A**+click attack-move, **S** stop, **H** hold, WASD/arrows pan,
mouse wheel zoom, **Q/E** rotate, **Ctrl+1..9** control groups,
**Esc** deselect/pause, **P** pause, **F1** help.

## Portrait behavior

- Aspect < 1.0 → overlay panel: "ROTATE DEVICE — Landscape recommended".
- Menus remain usable in portrait; gameplay input layer stays active but
  the layout is designed for landscape widths.
