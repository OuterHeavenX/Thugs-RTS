class_name Minimap
extends Control
## 220x220 tactical minimap, bottom-right. Terrain from HeliosValley,
## dots for resources/units/buildings, white camera rect. Click/drag to move.

const MAP_HALF := 64.0

var _valley = null
var _fog = null
var _cam: CameraRig = null

var _terrain_tex: Texture2D = null
var _timer := 0.0
var _dragging := false


func setup(valley, fog, cam: CameraRig) -> void:
	_valley = valley
	_fog = fog
	_cam = cam
	_terrain_tex = null
	if _valley != null and _valley.has_method("get_minimap_image"):
		var img = _valley.call("get_minimap_image")
		if img is Image:
			_terrain_tex = ImageTexture.create_from_image(img)
		elif img is Texture2D:
			_terrain_tex = img
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.25:
		_timer = 0.0
		queue_redraw()


func _w2m(world: Vector3) -> Vector2:
	var s := size
	return Vector2((world.x + MAP_HALF) / (MAP_HALF * 2.0) * s.x,
		(world.z + MAP_HALF) / (MAP_HALF * 2.0) * s.y)


func _m2w(mp: Vector2) -> Vector3:
	var s := size
	return Vector3(mp.x / s.x * MAP_HALF * 2.0 - MAP_HALF, 0,
		mp.y / s.y * MAP_HALF * 2.0 - MAP_HALF)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# Frame.
	draw_rect(r.grow(2), Color(0.03, 0.04, 0.06, 0.95))
	if _terrain_tex != null:
		draw_texture_rect(_terrain_tex, r, false)
	else:
		draw_rect(r, Color(0.08, 0.10, 0.09))
	# Unexplored darkening: cheap — skip per-pixel, fog of war handles 3D.
	# Resource dots.
	var tree := get_tree()
	if tree != null:
		for rn in tree.get_nodes_in_group("resource_nodes"):
			if rn is Node3D:
				var kind := ""
				if "kind" in rn:
					kind = str(rn.get("kind"))
				var c := Color(1.0, 0.8, 0.25) if kind == "supply" else Color(0.35, 0.9, 1.0)
				draw_circle(_w2m(rn.global_position), 2.5, c)
	# Friendly buildings (blue squares), units (green dots).
	var hid := Game.human_id
	for b in Game.buildings_of(hid):
		if b is Node3D:
			draw_rect(Rect2(_w2m(b.global_position) - Vector2(3, 3), Vector2(6, 6)),
				Color(0.3, 0.55, 1.0))
	for u in Game.units_of(hid):
		if u is Node3D:
			draw_circle(_w2m(u.global_position), 2.0, Color(0.35, 1.0, 0.45))
	# Enemy red — only where visible (FogOfWar.is_visible_at; Node3D owns is_visible).
	for e in Game.enemies_of(hid):
		if e is Node3D:
			var vis := true
			if _fog != null and _fog.has_method("is_visible_at"):
				vis = bool(_fog.call("is_visible_at", e.global_position))
			if vis:
				var is_b: bool = "footprint" in e or (e.get("data") is BuildingData if "data" in e else false)
				if is_b:
					draw_rect(Rect2(_w2m(e.global_position) - Vector2(3, 3), Vector2(6, 6)),
						Color(1.0, 0.3, 0.25))
				else:
					draw_circle(_w2m(e.global_position), 2.0, Color(1.0, 0.35, 0.3))
	# Camera rect.
	if _cam != null:
		var corners: Array = _cam.get_camera_rect_corners()
		if corners.size() == 4:
			var pts := PackedVector2Array()
			for c in corners:
				pts.append(_w2m(c))
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 1, 1, 0.85), 1.5)
	draw_rect(r, Color(0.25, 0.45, 0.65, 0.9), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if _cam == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_cam.move_to(_m2w(mb.position))
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_cam.move_to(_m2w((event as InputEventMouseMotion).position))
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_cam.move_to(_m2w(st.position))
		accept_event()
	elif event is InputEventScreenDrag:
		_cam.move_to(_m2w((event as InputEventScreenDrag).position))
		accept_event()
