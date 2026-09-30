class_name FogOfWar
extends Node3D

## 64x64 fog-of-war grid over the 128x128m map.
## reveal(units) is called externally at ~10Hz. Cells stay "explored" once seen.
## Texture channels: R8, 0 = unexplored, 128 = explored, 255 = visible.
##
## API DEVIATION (engine constraint): the contract's `is_visible(pos)` /
## `is_explored(pos)` are impossible — Godot 4.7's Node3D already defines a
## native no-arg `is_visible()`, and overriding it with a Vector3 parameter
## breaks GDScript static member resolution for EVERY caller (parse error).
## Use `is_visible_at(pos)` / `is_explored_at(pos)` instead.

const GRID := 64
const STATE_UNEXPLORED := 0
const STATE_EXPLORED := 1
const STATE_VISIBLE := 2

var _nav: NavGrid
var _state := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _dirty := true


func setup(nav: NavGrid) -> void:
	_nav = nav
	_state.resize(GRID * GRID)
	_state.fill(STATE_UNEXPLORED)
	_img = Image.create(GRID, GRID, false, Image.FORMAT_R8)
	_img.fill(Color(0, 0, 0))
	_dirty = true


func reveal(units: Array) -> void:
	if _nav == null or _state.size() != GRID * GRID:
		return
	# Decay: visible -> explored (explored never decays).
	for i in range(_state.size()):
		if _state[i] == STATE_VISIBLE:
			_state[i] = STATE_EXPLORED
	var human_id: int = Game.human_id
	for u in units:
		if u == null or not (u is Node3D):
			continue
		var pid := 0
		var raw_pid = u.get("player_id")
		if raw_pid != null:
			pid = int(raw_pid)
		if pid != human_id:
			continue
		var alive := true
		if u.has_method("alive"):
			alive = bool(u.alive())
		if not alive:
			continue
		var sight := 14.0
		if u.has_method("sight_range"):
			sight = maxf(float(u.sight_range()), 2.0)
		_mark_circle((u as Node3D).global_position, sight)
	_redraw_image()
	# Push to the GPU texture now: the terrain material holds the Texture2D
	# from get_texture() and nothing re-calls it, so without this the
	# rendered fog stays black forever even though the state array updates.
	if _tex != null and _dirty:
		_tex.update(_img)
		_dirty = false


func is_visible_at(pos: Vector3) -> bool:
	return _cell_state(pos) == STATE_VISIBLE


func is_explored_at(pos: Vector3) -> bool:
	return _cell_state(pos) >= STATE_EXPLORED


func get_texture() -> Texture2D:
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	elif _dirty:
		_tex.update(_img)
		_dirty = false
	return _tex


# ------------------------------------------------------------------ internals
func _cell_state(pos: Vector3) -> int:
	if _nav == null:
		return STATE_UNEXPLORED
	var c := _nav.world_to_cell(pos)
	return _state[c.y * GRID + c.x]


func _mark_circle(pos: Vector3, radius_m: float) -> void:
	var center := _nav.world_to_cell(pos)
	var r := int(ceil(radius_m / NavGrid.CELL_SIZE))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			# Circle test in meters from the true position, not the cell.
			var wx := pos.x + float(dx) * NavGrid.CELL_SIZE
			var wz := pos.z + float(dz) * NavGrid.CELL_SIZE
			var ox := wx - pos.x
			var oz := wz - pos.z
			if ox * ox + oz * oz > radius_m * radius_m:
				continue
			var c := Vector2i(center.x + dx, center.y + dz)
			if c.x < 0 or c.y < 0 or c.x >= GRID or c.y >= GRID:
				continue
			var i := c.y * GRID + c.x
			_state[i] = STATE_VISIBLE


func _redraw_image() -> void:
	for y in range(GRID):
		for x in range(GRID):
			var s := _state[y * GRID + x]
			var v := 0.0
			if s == STATE_EXPLORED:
				v = 128.0 / 255.0
			elif s == STATE_VISIBLE:
				v = 1.0
			_img.set_pixel(x, y, Color(v, v, v))
	_dirty = true
