class_name CameraRig
extends Node3D
## RTS camera: yaw pivot -> pitch pivot -> Camera3D.
## Owns target (ground point), distance (zoom), yaw. Edge-pan optional.

const Settings := preload("res://scripts/core/settings_store.gd")

const MIN_DIST := 18.0
const MAX_DIST := 70.0
const PITCH_DEG := 50.0
const PAN_SPEED := 34.0
const EDGE_MARGIN := 14.0
const MAP_HALF := 64.0

var target := Vector3.ZERO
var distance := 42.0
var yaw := 0.0

var _pitch: Node3D
var _cam: Camera3D


func _ready() -> void:
	_pitch = Node3D.new()
	_pitch.rotation.x = deg_to_rad(-PITCH_DEG)
	add_child(_pitch)
	_cam = Camera3D.new()
	_cam.far = 400.0
	_cam.fov = 55.0
	_cam.current = true
	_pitch.add_child(_cam)
	_apply()


func _process(delta: float) -> void:
	if not bool(Settings.get_setting("edge_pan", true)):
		return
	if TouchControls.touch_active:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var mp := vp.get_mouse_position()
	var size := vp.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Only edge-pan when the pointer is inside the window.
	if mp.x < 0.0 or mp.y < 0.0 or mp.x > size.x or mp.y > size.y:
		return
	var d := Vector2.ZERO
	if mp.x < EDGE_MARGIN:
		d.x -= 1.0
	elif mp.x > size.x - EDGE_MARGIN:
		d.x += 1.0
	if mp.y < EDGE_MARGIN:
		d.y -= 1.0
	elif mp.y > size.y - EDGE_MARGIN:
		d.y += 1.0
	if d != Vector2.ZERO:
		pan(d.normalized() * PAN_SPEED * delta)


func _apply() -> void:
	position = target
	rotation.y = yaw
	if _cam:
		_cam.position = Vector3(0, 0, distance)


func pan(d: Vector2) -> void:
	# d is in screen space; convert to world XZ relative to yaw.
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	target += right * d.x + fwd * -d.y
	target.x = clampf(target.x, -MAP_HALF, MAP_HALF)
	target.z = clampf(target.z, -MAP_HALF, MAP_HALF)
	target.y = 0.0
	_apply()


func zoom(f: float) -> void:
	distance = clampf(distance * f, MIN_DIST, MAX_DIST)
	_apply()


func rotate_yaw(d: float) -> void:
	yaw += d
	_apply()


func move_to(pos: Vector3) -> void:
	target = Vector3(clampf(pos.x, -MAP_HALF, MAP_HALF), 0.0, clampf(pos.z, -MAP_HALF, MAP_HALF))
	_apply()


func center_on(pos: Vector3) -> void:
	move_to(pos)


func camera() -> Camera3D:
	return _cam


func screen_to_ground(screen: Vector2) -> Vector3:
	if _cam == null:
		return Vector3(1.0e9, 0, 1.0e9)
	var origin := _cam.project_ray_origin(screen)
	var dir := _cam.project_ray_normal(screen)
	if dir.y > -0.0001:
		return Vector3(1.0e9, 0, 1.0e9)
	var t := -origin.y / dir.y
	var p := origin + dir * t
	p.x = clampf(p.x, -MAP_HALF, MAP_HALF)
	p.z = clampf(p.z, -MAP_HALF, MAP_HALF)
	p.y = 0.0
	return p


func ground_to_screen(world: Vector3) -> Vector2:
	if _cam == null:
		return Vector2(-10000, -10000)
	if _cam.is_position_behind(world):
		return Vector2(-10000, -10000)
	return _cam.unproject_position(world)


func get_camera_rect_corners() -> Array:
	# 4 ground-space corners of the visible rect, for the minimap.
	var vp := get_viewport()
	var out: Array = []
	if _cam == null or vp == null:
		return out
	var size := vp.get_visible_rect().size
	var corners := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	for c in corners:
		out.append(screen_to_ground(c))
	return out
