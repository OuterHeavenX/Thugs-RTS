class_name InputController
extends Node2D

## Tap/drag/pinch routing. Lives on the HUD canvas layer so the
## box-select rectangle draws in screen space.
## Touch: tap = select/command, drag = pan camera, pinch = zoom.
## Desktop: left-click = select/command, left-drag = box select,
## right-click = context command, wheel = zoom, WASD/arrows = pan.

const TAP_SLOP := 14.0

var game = null

var _press_pos := Vector2.ZERO
var _pressing := false
var _is_touch := false
var _boxing := false
var _box_rect := Rect2()
var _touches := {}
var _pinch_dist := 0.0


func _input(event: InputEvent) -> void:
	if game == null or not game.is_playing():
		_reset_gesture()
		return
	if event is InputEventMouseButton:
		_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		game.camera.zoom_at(mg.factor)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			game.cancel_command()


func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressing = true
			_is_touch = false
			_press_pos = mb.position
			_boxing = false
		elif _pressing and not _is_touch:
			_pressing = false
			if _boxing:
				_boxing = false
				queue_redraw()
				game.box_select(_box_rect)
			elif _press_pos.distance_to(mb.position) <= TAP_SLOP:
				game.handle_tap(mb.position, false)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		game.handle_context_command(mb.position)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		game.camera.zoom_at(1.12)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		game.camera.zoom_at(1.0 / 1.12)


func _mouse_motion(mm: InputEventMouseMotion) -> void:
	if _pressing and not _is_touch:
		if _press_pos.distance_to(mm.position) > TAP_SLOP:
			_boxing = true
			_box_rect = Rect2(_press_pos, mm.position - _press_pos).abs()
			queue_redraw()


func _touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		_touches[st.index] = st.position
		if _touches.size() == 1:
			_pressing = true
			_is_touch = true
			_press_pos = st.position
			_boxing = false
		elif _touches.size() == 2:
			_pressing = false
			_pinch_dist = _touch_distance()
	else:
		var was_pressing := _pressing and _touches.size() == 1
		_touches.erase(st.index)
		if was_pressing and _press_pos.distance_to(st.position) <= TAP_SLOP:
			_pressing = false
			game.handle_tap(st.position, true)
		elif _touches.is_empty():
			_pressing = false
		if _touches.size() < 2:
			_pinch_dist = 0.0


func _drag(sd: InputEventScreenDrag) -> void:
	_touches[sd.index] = sd.position
	if _touches.size() == 2:
		var nd := _touch_distance()
		if _pinch_dist > 0.0 and nd > 0.0:
			game.camera.zoom_at(nd / _pinch_dist)
		_pinch_dist = nd
		game.camera.pan_by(-sd.relative * 0.5)
	elif _touches.size() == 1 and _pressing and _is_touch:
		if _press_pos.distance_to(sd.position) > TAP_SLOP:
			game.camera.pan_by(-sd.relative)


func _touch_distance() -> float:
	var keys := _touches.keys()
	if keys.size() < 2:
		return 0.0
	return (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)


func _reset_gesture() -> void:
	_pressing = false
	_boxing = false
	_touches.clear()
	_pinch_dist = 0.0
	queue_redraw()


func _draw() -> void:
	if _boxing:
		draw_rect(_box_rect, Color(1, 1, 1, 0.18), true)
		draw_rect(_box_rect, Color(1, 1, 1, 0.8), false, 2.0)
