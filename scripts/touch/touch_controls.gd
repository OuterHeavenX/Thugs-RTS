class_name TouchControls
extends Control
## Touch input layer: full-rect Control UNDER the HUD buttons (mouse_filter
## PASS) so UI stays tappable. All orders funnel through
## Selection.issue_smart_order — identical behavior to mouse.
##
## Gestures: tap = select / smart-order, single-finger drag = box-select,
## pinch = zoom, two-finger drag = pan, long-press (0.55s) = attack-move.

static var touch_active := false

const TAP_MAX_TIME := 0.25
const TAP_MAX_DIST := 12.0
const LONGPRESS_TIME := 0.55
const DRAG_THRESHOLD := 12.0
const PICK_RADIUS := 28.0

var _cam: CameraRig
var _sel: Selection
var _hud: HUD

var _touches: Dictionary = {}  # index -> {start: Vector2, cur: Vector2, t0: float, moved: bool, lp_fired: bool}
var _box_active := false
var _box_start := Vector2.ZERO
var _box_cur := Vector2.ZERO
var _pinch_d0 := 0.0
var _pan_last := Vector2.ZERO

var _rotate_overlay: CenterContainer


func setup(cam: CameraRig, selection: Selection, hud: HUD) -> void:
	_cam = cam
	_sel = selection
	_hud = hud


func _ready() -> void:
	# Explicit anchors, not set_anchors_preset (see main_menu.gd note).
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	_rotate_overlay = CenterContainer.new()
	_rotate_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = "ROTATE DEVICE FOR BEST EXPERIENCE"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	panel.add_child(lbl)
	_rotate_overlay.add_child(panel)
	_rotate_overlay.visible = false
	add_child(_rotate_overlay)


func _match_live() -> bool:
	return Game.phase == Game.Phase.PLAYING and _cam != null and _sel != null


func _process(_delta: float) -> void:
	# Portrait overlay.
	var vp := get_viewport()
	if vp != null:
		var sz := vp.get_visible_rect().size
		_rotate_overlay.visible = sz.x > 0.0 and sz.y > 0.0 and (sz.x / sz.y) < 1.0
	# Long-press detection for the single active touch.
	if _touches.size() == 1 and _match_live():
		var idx: int = _touches.keys()[0]
		var t: Dictionary = _touches[idx]
		if not t["lp_fired"] and not t["moved"]:
			if Time.get_ticks_msec() / 1000.0 - t["t0"] > LONGPRESS_TIME:
				t["lp_fired"] = true
				_touches[idx] = t
				_on_long_press(t["cur"])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)


func _touch(ev: InputEventScreenTouch) -> void:
	touch_active = true
	if not _match_live():
		return
	if ev.pressed:
		_touches[ev.index] = {
			"start": ev.position, "cur": ev.position,
			"t0": Time.get_ticks_msec() / 1000.0,
			"moved": false, "lp_fired": false,
		}
		if _touches.size() == 2:
			_box_active = false
			queue_redraw()
			var pts := _touch_points()
			_pinch_d0 = pts[0].distance_to(pts[1])
			_pan_last = (pts[0] + pts[1]) * 0.5
	else:
		if not _touches.has(ev.index):
			return
		var t: Dictionary = _touches[ev.index]
		_touches.erase(ev.index)
		if _touches.size() == 2:
			var pts := _touch_points()
			_pinch_d0 = pts[0].distance_to(pts[1])
			_pan_last = (pts[0] + pts[1]) * 0.5
		if _box_active and _touches.is_empty():
			_box_active = false
			queue_redraw()
			_sel.box_select(Rect2(_box_start, Vector2.ZERO).abs().expand(_box_cur), _cam.camera())
			return
		# Single-finger release: tap?
		if _touches.is_empty() and not t["moved"] and not t["lp_fired"]:
			var dt = Time.get_ticks_msec() / 1000.0 - t["t0"]
			if dt < TAP_MAX_TIME:
				_on_tap(ev.position)


func _drag(ev: InputEventScreenDrag) -> void:
	touch_active = true
	if not _match_live():
		return
	if not _touches.has(ev.index):
		return
	var t: Dictionary = _touches[ev.index]
	t["cur"] = ev.position
	if t["start"].distance_to(ev.position) > DRAG_THRESHOLD:
		t["moved"] = true
	_touches[ev.index] = t
	if _touches.size() == 2:
		var pts := _touch_points()
		var d1 = pts[0].distance_to(pts[1])
		if _pinch_d0 > 1.0 and d1 > 1.0:
			_cam.zoom(_pinch_d0 / d1)
		_pinch_d0 = d1
		var mid = (pts[0] + pts[1]) * 0.5
		# Two-finger drag pans the map with the fingers.
		_cam.pan(-(mid - _pan_last) * 1.2)
		_pan_last = mid
	elif _touches.size() == 1 and t["moved"] and not t["lp_fired"]:
		if not _box_active:
			_box_active = true
			_box_start = t["start"]
		_box_cur = ev.position
		queue_redraw()


func _touch_points() -> Array:
	var pts: Array = []
	for k in _touches.keys():
		pts.append((_touches[k] as Dictionary)["cur"])
	return pts


func _pick(screen: Vector2) -> Node3D:
	var cam3d := _cam.camera()
	if cam3d == null:
		return null
	var best: Node3D = null
	var best_d := PICK_RADIUS
	var consider := func(n: Node3D) -> void:
		if n == null or not is_instance_valid(n):
			return
		if n.has_method("alive") and not bool(n.call("alive")):
			return
		if cam3d.is_position_behind(n.global_position):
			return
		var sp := cam3d.unproject_position(n.global_position)
		var d := sp.distance_to(screen)
		if d < best_d:
			best_d = d
			best = n
	for u in Game.units_of(Game.human_id):
		if u is Node3D:
			consider.call(u)
	for b in Game.buildings_of(Game.human_id):
		if b is Node3D:
			consider.call(b)
	for e in Game.enemies_of(Game.human_id):
		if e is Node3D:
			consider.call(e)
	var tree := get_tree()
	if tree != null:
		for rn in tree.get_nodes_in_group("resource_nodes"):
			if rn is Node3D:
				consider.call(rn)
	return best


func _is_own(n: Node3D) -> bool:
	return "player_id" in n and int(n.get("player_id")) == Game.human_id


func _ground(screen: Vector2) -> Vector3:
	return _cam.screen_to_ground(screen)


func _on_tap(screen: Vector2) -> void:
	if _sel.armed == "place_building":
		_hud.try_confirm_placement(_ground(screen))
		return
	if _sel.is_armed():
		var node := _pick(screen)
		_sel.issue_smart_order(node if node != null else _ground(screen))
		return
	var hit := _pick(screen)
	if hit == null:
		if _sel.selected.is_empty():
			return
		# Tap ground with a selection = smart order (move).
		_sel.issue_smart_order(_ground(screen))
		return
	if _is_own(hit):
		_sel.select_single(hit)
	else:
		if _sel.selected.is_empty():
			_sel.select_single(hit)
		else:
			_sel.issue_smart_order(hit)


func _on_long_press(screen: Vector2) -> void:
	# Long-press = attack-move to that point.
	if _sel.selected_units().is_empty():
		return
	_box_active = false
	queue_redraw()
	_sel.arm_attack_move()
	_sel.issue_smart_order(_ground(screen))
	_hud.alert("Attack-move", Color(1, 0.6, 0.3))


func _draw() -> void:
	if _box_active:
		var r := Rect2(_box_start, Vector2.ZERO).abs().expand(_box_cur)
		draw_rect(r, Color(0.3, 0.8, 1.0, 0.15), true)
		draw_rect(r, Color(0.3, 0.8, 1.0, 0.9), false, 2.0)
