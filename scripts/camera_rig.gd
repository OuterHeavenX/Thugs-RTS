class_name CameraRig
extends Camera2D

## Drag-pan, pinch/wheel zoom, clamped to the map. Keyboard pan (WASD/arrows).

var min_zoom := 0.5
var max_zoom := 2.2
var pan_bounds := Rect2(-820, -120, 1680, 1080)
var input_enabled := true


func _ready() -> void:
	make_current()


func _process(delta: float) -> void:
	if not input_enabled:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * 650.0 * delta / zoom.x
		_clamp()


func zoom_at(factor: float) -> void:
	var z := clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(z, z)


func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	_clamp()


func _clamp() -> void:
	position.x = clampf(position.x, pan_bounds.position.x, pan_bounds.position.x + pan_bounds.size.x)
	position.y = clampf(position.y, pan_bounds.position.y, pan_bounds.position.y + pan_bounds.size.y)
