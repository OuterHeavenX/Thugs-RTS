class_name Projectile
extends Node3D

## Unguided projectile: flies toward the target's last known position,
## impacts on arrival (or when the target dies) via Combat + VFX.
## Visual: small emissive sphere + short tracer segments. No lights.

const IMPACT_DIST := 0.5
const TRAIL_PERIOD := 0.12

var _target: Node3D = null
var _target_pos: Vector3 = Vector3.ZERO
var _weapon: WeaponData = null
var _attacker: Unit = null
var _speed: float = 30.0
var _dead: bool = false
var _trail_t: float = 0.0
var _prev_pos: Vector3 = Vector3.ZERO


func setup(from: Vector3, target: Node3D, target_pos: Vector3, weapon: WeaponData, attacker: Unit) -> void:
	global_position = from
	_prev_pos = from
	_target = target
	_target_pos = target_pos
	_weapon = weapon
	_attacker = attacker
	if weapon != null and weapon.projectile_speed > 0.0:
		_speed = weapon.projectile_speed
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	var col := Color(1.0, 0.8, 0.4)
	if weapon != null:
		col = weapon.tracer_color
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mi.set_surface_override_material(0, mat)
	add_child(mi)


func _process(delta: float) -> void:
	if _dead:
		return
	if _target != null and is_instance_valid(_target) and _target.has_method("alive") and _target.alive():
		_target_pos = (_target as Node3D).global_position + Vector3(0, 1.0, 0)
	var to := _target_pos - global_position
	var dist := to.length()
	if dist <= IMPACT_DIST:
		_impact()
		return
	var step: float = _speed * delta
	if dist <= step:
		global_position = _target_pos
		_impact()
		return
	global_position += to / dist * step
	# Trail: short emissive segments, throttled.
	_trail_t += delta
	if _trail_t >= TRAIL_PERIOD:
		_trail_t = 0.0
		var col := Color(1.0, 0.8, 0.4)
		if _weapon != null:
			col = _weapon.tracer_color
		VFX.tracer(_prev_pos, global_position, col)
	_prev_pos = global_position


func _impact() -> void:
	if _dead:
		return
	_dead = true
	var pos := _target_pos
	if _weapon != null:
		VFX.explosion(pos, maxf(_weapon.splash, 1.0))
		if _weapon.splash > 0.0:
			SFX.play("explosion")
			Combat.apply_splash(pos, _weapon.splash, _weapon.damage, _weapon, _attacker)
		elif _target != null and is_instance_valid(_target):
			Combat.apply_damage(_target, _weapon.damage, _weapon, _attacker)
	queue_free()
