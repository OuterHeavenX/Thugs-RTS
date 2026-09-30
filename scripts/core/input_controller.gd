extends Node
## Mouse + keyboard input. Left: select / box-select. Right: smart order.
## All orders funnel through Selection.issue_smart_order (shared with touch).

const PICK_RADIUS := 24.0
const DRAG_THRESHOLD := 8.0

var _cam: CameraRig
var _sel: Selection
var _hud: HUD
var _screens: Screens

var _l_down := false
var _l_start := Vector2.ZERO
var _l_cur := Vector2.ZERO
var _dragging := false


func setup(cam: CameraRig, selection: Selection, hud: HUD, screens: Screens) -> void:
	_cam = cam
	_sel = selection
	_hud = hud
	_screens = screens


func _ready() -> void:
	set_process_unhandled_input(true)


func _match_live() -> bool:
	return Game.phase == Game.Phase.PLAYING and _cam != null and _sel != null


func _process(delta: float) -> void:
	if not _match_live():
		return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	# NOTE: A is attack-move (see _on_key), so it does NOT pan. D still pans.
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if d != Vector2.ZERO:
		_cam.pan(d.normalized() * CameraRig.PAN_SPEED * delta)
	if Input.is_key_pressed(KEY_Q):
		_cam.rotate_yaw(1.6 * delta)
	if Input.is_key_pressed(KEY_E):
		_cam.rotate_yaw(-1.6 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _match_live():
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


func _mouse_gated() -> bool:
	# Once touch has been used this session, the touch layer owns gestures.
	return TouchControls.touch_active


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_cam.zoom(0.9)
			return
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_cam.zoom(1.0 / 0.9)
			return
		MOUSE_BUTTON_LEFT:
			if _mouse_gated():
				return
			if mb.pressed:
				_l_down = true
				_l_start = mb.position
				_l_cur = mb.position
				_dragging = false
			else:
				if _l_down:
					_l_down = false
					if _dragging:
						_finish_box_select()
					else:
						_on_left_click(mb)
					_dragging = false
			return
		MOUSE_BUTTON_RIGHT:
			if _mouse_gated():
				return
			if mb.pressed:
				_on_right_click(mb.position)
			return


func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	if _mouse_gated():
		return
	if _l_down:
		_l_cur = mm.position
		if not _dragging and _l_start.distance_to(_l_cur) > DRAG_THRESHOLD:
			_dragging = true


func _on_key(k: InputEventKey) -> void:
	if not k.pressed or k.echo:
		return
	var code := k.keycode
	# Number keys: groups (Ctrl+ stores, plain recalls).
	if code >= KEY_1 and code <= KEY_9:
		var idx := int(code - KEY_1) + 1
		if k.ctrl_pressed:
			_sel.store_group(idx)
		else:
			_sel.recall_group(idx)
		get_viewport().set_input_as_handled()
		return
	match code:
		KEY_A:
			if not k.ctrl_pressed:
				_sel.arm_attack_move()
				_hud.alert("Attack-move armed — click a target", Color(1, 0.6, 0.3))
		KEY_S:
			_stop_selected()
		KEY_H:
			_hold_selected()
		KEY_ESCAPE:
			_on_escape()
		KEY_P:
			_screens.toggle_pause()
		KEY_F1:
			_sel.select_army()


func _on_escape() -> void:
	if _sel.is_armed():
		_sel.disarm()
		_sel.changed.emit()
	elif not _sel.selected.is_empty():
		_sel.clear()
	else:
		_screens.toggle_pause()


func _stop_selected() -> void:
	for n in _sel.selected_units():
		if is_instance_valid(n) and n.has_method("order_stop"):
			n.call("order_stop")
	SFX.play("order")


func _hold_selected() -> void:
	for n in _sel.selected_units():
		if is_instance_valid(n) and n.has_method("order_hold"):
			n.call("order_hold")
	SFX.play("order")


# ------------------------------------------------------------------ mouse
func _pick(screen: Vector2) -> Node3D:
	# Picking without physics: project candidates, nearest within PICK_RADIUS.
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


func _on_left_click(mb: InputEventMouseButton) -> void:
	if _sel.armed == "place_building":
		# Placement ghost confirms on click; right-click cancels.
		_hud.try_confirm_placement(_cam.screen_to_ground(mb.position))
		return
	if _sel.is_armed():
		var node := _pick(mb.position)
		if node != null:
			_sel.issue_smart_order(node)
		else:
			_sel.issue_smart_order(_cam.screen_to_ground(mb.position))
		return
	var hit := _pick(mb.position)
	if hit == null:
		_sel.clear()
		return
	if mb.double_click:
		_select_type_on_screen(hit)
	elif mb.shift_pressed:
		_sel.toggle(hit)
	else:
		_sel.select_single(hit)


func _select_type_on_screen(hit: Node3D) -> void:
	# Double-click: select all human units of the same type currently visible.
	var cam3d := _cam.camera()
	if cam3d == null:
		return
	var hid = "data" in hit and hit.get("data") != null and (hit.get("data") as Resource).get("id")
	if hid == null:
		_sel.select_single(hit)
		return
	var vp_size := get_viewport().get_visible_rect().size
	_sel.clear_silent()
	for u in Game.units_of(Game.human_id):
		if not (u is Node3D):
			continue
		var d = u.get("data") if "data" in u else null
		if d == null or (d as Resource).get("id") != hid:
			continue
		if cam3d.is_position_behind(u.global_position):
			continue
		var sp := cam3d.unproject_position(u.global_position)
		if Rect2(Vector2.ZERO, vp_size).has_point(sp):
			_sel.add_silent(u)
	SFX.play("select")
	_sel.changed.emit()


func _finish_box_select() -> void:
	var r := Rect2(_l_start, Vector2.ZERO).abs()
	# Expand tiny rects slightly so near-clicks still feel good.
	if r.size.x < 4.0:
		r.size.x = 4.0
	if r.size.y < 4.0:
		r.size.y = 4.0
	_sel.box_select(r, _cam.camera())


func _on_right_click(screen: Vector2) -> void:
	if _sel.armed == "place_building":
		_sel.disarm()
		_sel.changed.emit()
		return
	var node := _pick(screen)
	if node != null:
		_sel.issue_smart_order(node)
	else:
		_sel.issue_smart_order(_cam.screen_to_ground(screen))
