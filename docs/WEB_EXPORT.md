# WORLD COMMAND — Web export (v0.1.0 slice)

Target: browser play (desktop + mobile), hosted on GitHub Pages.

## Export preset requirements

From `export_presets.cfg` (`[preset.0]` "Web"):

- **Platform:** Web, runnable.
- **`variant/thread_support=false`** — required. GitHub Pages does not
  send COOP/COEP headers, so a threaded build fails with the
  "Cross-Origin Isolation / SharedArrayBuffer missing" error.
  Single-threaded wasm runs fine.
- **Export path must end in `.html`** (e.g.
  `../world-command-web/index.html`). Passing a `.pck` path writes the
  HTML shell into the `.pck` name and leaves the real pack in an
  unrenamed temp file.
- `vram_texture_compression/for_desktop=true`, `for_mobile=false`.
- `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true`.
- PWA disabled; no custom HTML shell.

## Export steps

1. Open the project in Godot 4.7 (or headless) and make sure the import
   cache is fresh (`--import`), especially after adding new `.glb` files
   or classes.
2. Export release: `--export-release "Web" --output <path ending .html>`
   (or via the editor: Project → Export → Web → Export Release).
3. Verify the output `.pck` starts with the `GDPC` magic bytes and is a
   sane size before deploying.
4. Copy the fresh export into the web directory served by Pages and
   commit; verify the served `Content-Length` matches before announcing
   the build live (Pages can lag a minute or two).

## Known web constraints

- **Never use `FileAccess` on `res://` packed files.** On Godot 4.7 Web
  exports, `FileAccess.file_exists("res://...")` returns FALSE and
  `FileAccess.open("res://...")` returns null for files inside the pck,
  even though they are present. Call `ResourceLoader.load("res://...")`
  and **null-check** instead. (Verified: no `FileAccess` usage exists in
  `scripts/` — all model loads go through `ResourceLoader.load` with
  null-checks and procedural fallbacks.)
- **No engine branding on player-facing surfaces:** the project uses a
  custom boot splash background color; no Godot logo appears in-game.
- Web audio: SFX are procedural `AudioStreamWAV` generated at runtime
  (no audio asset downloads); volumes persist via `user://settings.cfg`.
- Portrait phones get the ROTATE DEVICE overlay (see
  `TOUCH_CONTROLS.md`); the game is landscape-first.
