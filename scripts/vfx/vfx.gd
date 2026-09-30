extends Node

## Pooled one-shot VFX. Two pool kinds: billboarded "puffs" (quads with
## unshaded emissive materials) and stretched "tracer" boxes.
## Zero per-frame allocation in steady state: fixed pools, index lists,
## parallel PackedFloat32Arrays. Headless-safe (plain MeshInstance3D only,
## no particles, no lights).

const PUFF_N := 40
const TRACER_N := 40

var _quality: int = 2
var _puffs: Array[MeshInstance3D] = []
var _tracers: Array[MeshInstance3D] = []
var _puff_mesh: QuadMesh
var _tracer_mesh: BoxMesh

# Per-index effect state.
var _p_t := PackedFloat32Array()
var _p_dur := PackedFloat32Array()
var _p_size := PackedFloat32Array()
var _p_grow := PackedFloat32Array()
var _p_active: Array[int] = []
var _t_t := PackedFloat32Array()
var _t_dur := PackedFloat32Array()
var _t_active: Array[int] = []
var _lowq_skip := 0


func _ready() -> void:
	# Pick up the graphics setting if the game chunk exposes it (default 2).
	for prop in Game.get_property_list():
		if prop.name == "settings_vfx":
			set_quality(int(Game.get("settings_vfx")))
			break
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2(1.0, 1.0)
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(1.0, 1.0, 1.0)
	var puff_n := PUFF_N
	var tracer_n := TRACER_N
	if _quality <= 1:
		puff_n = PUFF_N / 2
		tracer_n = TRACER_N / 2
	for i in puff_n:
		_puffs.append(_make_puff())
	for i in tracer_n:
		_tracers.append(_make_tracer())
	_p_t.resize(_puffs.size())
	_p_dur.resize(_puffs.size())
	_p_size.resize(_puffs.size())
	_p_grow.resize(_puffs.size())
	_t_t.resize(_tracers.size())
	_t_dur.resize(_tracers.size())


func set_quality(q: int) -> void:
	_quality = clampi(q, 0, 2)


func _make_puff() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _puff_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mi.set_surface_override_material(0, mat)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _make_tracer() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _tracer_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mi.set_surface_override_material(0, mat)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ------------------------------------------------------------------ API
func muzzle(pos: Vector3, color: Color) -> void:
	_spawn_puff(pos, color.lightened(0.4), 0.55, 0.18, 1.6)


func tracer(from: Vector3, to: Vector3, color: Color) -> void:
	if _quality == 0:
		_lowq_skip += 1
		if _lowq_skip % 2 == 0:
			return
	var idx := _free_tracer()
	if idx < 0:
		return
	var mi := _tracers[idx]
	var length := maxf(from.distance_to(to), 0.1)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to)
	mi.scale = Vector3(0.16, 0.16, length)
	_set_mat_color(mi, color, 1.0)
	mi.visible = true
	_t_t[idx] = 0.0
	_t_dur[idx] = 0.3
	_t_active.append(idx)


func explosion(pos: Vector3, explosion_scale: float = 1.0) -> void:
	var s := maxf(explosion_scale, 0.6)
	_spawn_puff(pos + Vector3(0, 0.5, 0), Color(1.0, 0.55, 0.15), 1.6 * s, 0.55, 2.2)
	_spawn_puff(pos + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.4), 1.0 * s, 0.35, 1.6)
	_spawn_puff(pos + Vector3(0, 0.3, 0), Color(0.25, 0.22, 0.2), 1.2 * s, 0.8, 2.6)


func sparks(pos: Vector3) -> void:
	_spawn_puff(pos, Color(1.0, 0.75, 0.25), 0.35, 0.4, 1.2)
	_spawn_puff(pos + Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.5), 0.25, 0.3, 1.0)


func harvest_glint(pos: Vector3) -> void:
	_spawn_puff(pos, Color(0.4, 1.0, 0.6), 0.6, 0.5, 0.6)


func smoke(pos: Vector3) -> void:
	_spawn_puff(pos, Color(0.16, 0.16, 0.18), 1.1, 0.9, 2.4)


# ------------------------------------------------------------------ internals
func _spawn_puff(pos: Vector3, color: Color, size: float, dur: float, grow: float) -> void:
	if _quality == 0:
		_lowq_skip += 1
		if _lowq_skip % 2 == 0:
			return
	for i in _puffs.size():
		if _puffs[i].visible:
			continue
		var mi := _puffs[i]
		mi.global_position = pos
		mi.scale = Vector3.ONE * size
		_set_mat_color(mi, color, 0.9)
		mi.visible = true
		_p_t[i] = 0.0
		_p_dur[i] = dur
		_p_size[i] = size
		_p_grow[i] = grow
		_p_active.append(i)
		return


func _free_tracer() -> int:
	for i in _tracers.size():
		if not _tracers[i].visible:
			return i
	return -1


func _set_mat_color(mi: MeshInstance3D, color: Color, alpha: float) -> void:
	var mat := mi.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission = Color(color.r, color.g, color.b)


func _process(delta: float) -> void:
	# Puffs: grow + fade.
	for k in range(_p_active.size() - 1, -1, -1):
		var i: int = _p_active[k]
		_p_t[i] += delta
		var dur := _p_dur[i]
		if _p_t[i] >= dur:
			_puffs[i].visible = false
			_p_active.remove_at(k)
			continue
		var f := _p_t[i] / dur
		var s := _p_size[i] * (1.0 + _p_grow[i] * f)
		_puffs[i].scale = Vector3(s, s, s)
		var mat := _puffs[i].get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			var c := mat.albedo_color
			c.a = 0.9 * (1.0 - f)
			mat.albedo_color = c
	# Tracers: fade only.
	for k in range(_t_active.size() - 1, -1, -1):
		var i: int = _t_active[k]
		_t_t[i] += delta
		var dur := _t_dur[i]
		if _t_t[i] >= dur:
			_tracers[i].visible = false
			_t_active.remove_at(k)
			continue
		var mat := _tracers[i].get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			var c := mat.albedo_color
			c.a = 1.0 - _t_t[i] / dur
			mat.albedo_color = c
