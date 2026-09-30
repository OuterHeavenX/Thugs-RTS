class_name Unit
extends Node3D

## Base RTS unit: model, selection ring, health bar, orders, movement,
## target acquisition and firing. State machine driven in _process.
## Worker (worker.gd) extends this and implements GATHER/BUILD ticks.

signal died(unit: Unit)

enum State { IDLE, MOVE, ATTACK, ATTACKMOVE, GATHER, BUILD, HOLD }

# Set externally by the map glue (world chunk). Null-guarded: if null,
# units move straight and ignore fog.
# Deliberately untyped: the world chunk's nav_grid.gd has parse errors as
# of 2026-09-28, and typed references would break compilation of this file.
# Re-type as (NavGrid / FogOfWar) once their chunk compiles cleanly.
static var nav_grid = null
static var fog = null
static var _scan_slot: int = 0

const AIR_HEIGHT := 6.0
const CHASE_REPATH_DIST := 4.0

var data: UnitData = null
var player_id: int = 0
var faction_id: String = ""
var hp: float = 1.0
var max_hp: float = 1.0
var state: int = State.IDLE

var _queue: Array = [] # Array[Dictionary] of pending orders
var _attack_target: Node3D = null
var _gather_node: Node3D = null
var _build_target: Node3D = null
var _move_goal: Vector3 = Vector3.ZERO
var _path: PackedVector3Array = []
var _path_i: int = 0
var _path_dest: Vector3 = Vector3.ZERO
var _chase_pos: Vector3 = Vector3.ZERO
var _repath_t: float = 0.0
var _cooldown: float = 0.0
var _scan_t: float = 0.0
var _dead: bool = false

var _holder: Node3D = null      # model holder (raised to AIR_HEIGHT for air)
var _turret: Node3D = null      # optional "Turret" child node, yaws to target
var _muzzle: Node3D = null      # optional "Muzzle" child node
var _ring: MeshInstance3D = null
var _bar_root: Node3D = null
var _bar_fg: MeshInstance3D = null
var _selected: bool = false


func _ready() -> void:
	# All construction happens in setup(); _ready is a no-op so add_child
	# ordering never matters.
	pass


## Build visuals, stats and registration. Call once after add_child.
func setup(p_data: UnitData, pid: int) -> void:
	data = p_data
	player_id = pid
	var pl := Game.get_player(pid)
	if pl != null and pl.faction != null:
		faction_id = pl.faction.id
	max_hp = Mechanics.max_hp_for(data, pid)
	hp = max_hp
	_scan_t = 0.03125 * float(_scan_slot % 8)
	_scan_slot += 1
	_build_model()
	_build_ring()
	_build_health_bar()
	Game.register_unit(self)
	_update_hp_bar()


# ------------------------------------------------------------------ orders
func order_move(pos: Vector3, queued: bool = false) -> void:
	_issue({"op": "move", "pos": pos}, queued)


func order_attack(target: Node3D, queued: bool = false) -> void:
	_issue({"op": "attack", "target": target}, queued)


func order_attack_move(pos: Vector3, queued: bool = false) -> void:
	_issue({"op": "attackmove", "pos": pos}, queued)


func order_gather(node: Node3D, queued: bool = false) -> void:
	_issue({"op": "gather", "node": node}, queued)


func order_build(bld: Node3D, queued: bool = false) -> void:
	_issue({"op": "build", "bld": bld}, queued)


func order_stop() -> void:
	_queue.clear()
	_set_attack_target(null)
	_gather_node = null
	_build_target = null
	_path = PackedVector3Array()
	_path_i = 0
	state = State.IDLE


func order_hold() -> void:
	_queue.clear()
	_set_attack_target(null)
	_path = PackedVector3Array()
	_path_i = 0
	state = State.HOLD


func _issue(order: Dictionary, queued: bool) -> void:
	if queued and state != State.IDLE:
		_queue.append(order)
		return
	_queue.clear()
	_execute(order)


func _execute(order: Dictionary) -> void:
	_set_attack_target(null)
	_gather_node = null
	_build_target = null
	_path = PackedVector3Array()
	_path_i = 0
	var op: String = str(order.get("op", ""))
	match op:
		"move":
			_move_goal = _sanitize_dest(order["pos"])
			_compute_path(_move_goal)
			state = State.MOVE
		"attack":
			var t: Node3D = order["target"]
			if t != null and is_instance_valid(t):
				_set_attack_target(t)
				state = State.ATTACK
			else:
				state = State.IDLE
		"attackmove":
			_move_goal = _sanitize_dest(order["pos"])
			_compute_path(_move_goal)
			state = State.ATTACKMOVE
		"gather":
			var n: Node3D = order["node"]
			if n != null and is_instance_valid(n):
				_gather_node = n
				state = State.GATHER
			else:
				state = State.IDLE
		"build":
			var b: Node3D = order["bld"]
			if b != null and is_instance_valid(b):
				_build_target = b
				state = State.BUILD
			else:
				state = State.IDLE
		"hold":
			state = State.HOLD
		_:
			state = State.IDLE


func _next_queued() -> void:
	if _queue.is_empty():
		state = State.IDLE
		return
	var order: Dictionary = _queue.pop_front()
	_execute(order)


# ------------------------------------------------------------------ queries
func alive() -> bool:
	return not _dead


func is_air() -> bool:
	return data != null and data.is_air


func is_detector() -> bool:
	return data != null and data.id == "kitsune"


func armor_tags() -> PackedStringArray:
	if data == null:
		return PackedStringArray()
	return data.armor_tags


func sight_range() -> float:
	if data == null:
		return 0.0
	return data.sight + Mechanics.sight_bonus(self)


func faction_bonus_damage() -> float:
	return Mechanics.damage_mult(self)


func set_selected(b: bool) -> void:
	_selected = b
	if _ring != null:
		_ring.visible = b


func take_damage(amount: float, _source) -> void:
	if _dead or data == null:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_die()
	else:
		_update_hp_bar()


func _die() -> void:
	if _dead:
		return
	_dead = true
	VFX.explosion(global_position + Vector3(0, 1.0, 0), 1.6 if not is_air() else 2.2)
	SFX.play("explosion")
	Game.unregister_unit(self)
	died.emit(self)
	queue_free()


# --------------------------------------------------------------- visuals
func _faction_color() -> Color:
	var pl := Game.get_player(player_id)
	if pl != null and pl.faction != null:
		return pl.faction.color
	return Color(0.6, 0.6, 0.6)


func _build_model() -> void:
	_holder = Node3D.new()
	_holder.name = "Model"
	add_child(_holder)
	if is_air():
		_holder.position.y = AIR_HEIGHT
	var loaded := false
	if data.model != "":
		var res = ResourceLoader.load(data.model)
		if res is PackedScene:
			var inst: Node3D = (res as PackedScene).instantiate()
			_holder.add_child(inst)
			loaded = true
	if not loaded:
		_holder.add_child(_fallback_model())
	_turret = _holder.find_child("Turret")
	_muzzle = _holder.find_child("Muzzle")
	if is_air():
		_build_shadow_blob()


func _fallback_model() -> Node3D:
	# Tinted primitive used when the .glb is missing (models are optional).
	var col := _faction_color()
	var mi := MeshInstance3D.new()
	if "vehicle" in data.armor_tags or "tank" in data.armor_tags:
		var box := BoxMesh.new()
		box.size = Vector3(1.6 * data.radius, 1.0, 2.2 * data.radius)
		mi.mesh = box
		mi.position.y = 0.6
	else:
		var cap := CapsuleMesh.new()
		cap.radius = 0.38 * data.radius
		cap.height = 1.7
		mi.mesh = cap
		mi.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mi.set_surface_override_material(0, mat)
	return mi


func _build_shadow_blob() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = data.radius * 0.9
	cyl.bottom_radius = data.radius * 0.9
	cyl.height = 0.02
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.position.y = 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	add_child(mi)


func _build_ring() -> void:
	var tor := TorusMesh.new()
	var r := data.radius + 0.35
	tor.inner_radius = r - 0.09
	tor.outer_radius = r + 0.09
	tor.rings = 32
	tor.ring_segments = 8
	_ring = MeshInstance3D.new()
	_ring.mesh = tor
	_ring.position.y = 0.08
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 1.0, 0.45)
	_ring.set_surface_override_material(0, mat)
	_ring.visible = false
	add_child(_ring)


func _build_health_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position.y = (AIR_HEIGHT + 1.8) if is_air() else 2.4
	add_child(_bar_root)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 0.16)
	var bg := MeshInstance3D.new()
	bg.mesh = quad
	var bgm := StandardMaterial3D.new()
	bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bgm.albedo_color = Color(0.05, 0.05, 0.08, 0.85)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg.set_surface_override_material(0, bgm)
	_bar_root.add_child(bg)
	_bar_fg = MeshInstance3D.new()
	_bar_fg.mesh = quad
	var fgm := StandardMaterial3D.new()
	fgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fgm.albedo_color = Color(0.2, 0.9, 0.25)
	_bar_fg.set_surface_override_material(0, fgm)
	_bar_fg.position.z = 0.01
	_bar_root.add_child(_bar_fg)
	_bar_root.visible = false


func _update_hp_bar() -> void:
	if _bar_root == null or _bar_fg == null:
		return
	if _dead or max_hp <= 0.0:
		_bar_root.visible = false
		return
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_bar_root.visible = frac < 1.0
	_bar_fg.scale.x = maxf(frac, 0.001)
	_bar_fg.position.x = -(1.0 - frac) * 0.8
	var mat := _bar_fg.get_surface_override_material(0) as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(1.0 - frac * 0.85, 0.15 + frac * 0.75, 0.2)


# ------------------------------------------------------------ state machine
func _process(delta: float) -> void:
	if _dead or data == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_repath_t = maxf(0.0, _repath_t - delta)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_do_scan()
	match state:
		State.IDLE, State.HOLD:
			_combat_tick(delta, false)
		State.MOVE:
			if _move_along_path(delta):
				_next_queued()
		State.ATTACK:
			_attack_tick(delta)
		State.ATTACKMOVE:
			_attackmove_tick(delta)
		State.GATHER:
			_tick_gather(delta)
		State.BUILD:
			_tick_build(delta)


## Overridden by Worker. Base units sent here by mistake just stop.
func _tick_gather(_delta: float) -> void:
	state = State.IDLE


## Overridden by Worker. Base units sent here by mistake just stop.
func _tick_build(_delta: float) -> void:
	state = State.IDLE


# ------------------------------------------------------------------ combat
func _do_scan() -> void:
	if data.weapon == null:
		return
	if not (state == State.IDLE or state == State.HOLD or state == State.ATTACK or state == State.ATTACKMOVE):
		return
	if state == State.ATTACK and _target_ok(_attack_target):
		return # keep the explicitly ordered target
	var best: Node3D = null
	var best_d := sight_range()
	for e in Game.enemies_of(player_id):
		var d: float = global_position.distance_to(e.global_position)
		if d > best_d:
			continue
		if not Mechanics.can_see(player_id, e.global_position):
			continue
		if not Combat.can_target(data.weapon, self, e):
			continue
		best = e
		best_d = d
	_set_attack_target(best)


func _target_ok(t) -> bool:
	# NOTE: parameter is deliberately UNTYPED. A typed (Node3D) parameter
	# re-validates the type at every call boundary, so passing a *freed*
	# target throws "previously freed" errors every frame forever. Untyped
	# lets is_instance_valid do its job.
	return t != null and is_instance_valid(t) and t.has_method("alive") and t.alive()


## Assigns the attack target, watching the target's `died` signal (units)
## so the reference clears promptly instead of lingering until the next scan.
func _set_attack_target(t) -> void:
	if _target_ok(_attack_target) and _attack_target == t:
		return  # already watching this live target
	if _attack_target != null and is_instance_valid(_attack_target) \
			and _attack_target.has_signal("died"):
		if _attack_target.is_connected("died", _on_attack_target_died):
			_attack_target.disconnect("died", _on_attack_target_died)
	_attack_target = t
	if t != null and is_instance_valid(t) and t.has_signal("died"):
		if not t.is_connected("died", _on_attack_target_died):
			t.connect("died", _on_attack_target_died)


func _on_attack_target_died(_t: Node) -> void:
	_attack_target = null


func _combat_tick(delta: float, chase: bool) -> void:
	if data.weapon == null:
		return
	if not _target_ok(_attack_target):
		return
	var w := data.weapon
	var tp: Vector3 = _attack_target.global_position
	var dist: float = global_position.distance_to(tp)
	if dist <= w.range:
		_face_toward(tp, delta)
		if _cooldown <= 0.0:
			_fire()
	elif chase:
		_chase_tick(delta, tp)


func _attack_tick(delta: float) -> void:
	if not _target_ok(_attack_target):
		_do_scan()
		if not _target_ok(_attack_target):
			_next_queued()
			return
	_combat_tick(delta, true)


func _attackmove_tick(delta: float) -> void:
	if data.weapon != null and _target_ok(_attack_target):
		var tp: Vector3 = _attack_target.global_position
		if global_position.distance_to(tp) <= data.weapon.range:
			_face_toward(tp, delta)
			if _cooldown <= 0.0:
				_fire()
			return # hold position while a target is in range
	if _move_along_path(delta):
		_next_queued()


func _chase_tick(delta: float, tp: Vector3) -> void:
	if _repath_t <= 0.0 or _chase_pos.distance_to(tp) > CHASE_REPATH_DIST:
		_chase_pos = tp
		_repath_t = 0.5
		_compute_path(tp)
	_move_along_path(delta)


func _fire() -> void:
	var w := data.weapon
	if w == null or not _target_ok(_attack_target):
		return
	_cooldown = w.cooldown
	var tp: Vector3 = _attack_target.global_position
	_face_toward(tp, 1.0)
	if _turret != null:
		_turret.global_rotation.y = atan2(-(tp.x - global_position.x), -(tp.z - global_position.z))
	var mzl := _muzzle_point()
	VFX.muzzle(mzl, w.tracer_color)
	if w.damage >= 30.0 or w.splash > 0.0:
		SFX.play("cannon")
	else:
		SFX.play("shoot")
	if w.projectile_speed <= 0.0:
		VFX.tracer(mzl, tp + Vector3(0, 1.0, 0), w.tracer_color)
		Combat.apply_damage(_attack_target, w.damage, w, self)
	else:
		var pr := Projectile.new()
		get_parent().add_child(pr)
		pr.setup(mzl, _attack_target, tp, w, self)


func _muzzle_point() -> Vector3:
	if _muzzle != null:
		return _muzzle.global_position
	return global_position + Vector3(0, 1.2, 0)


# ---------------------------------------------------------------- movement
func _sanitize_dest(pos: Vector3) -> Vector3:
	var p := pos
	p.y = 0.0
	if nav_grid != null:
		p = nav_grid.clamp_to_map(p)
	return p


func _compute_path(to: Vector3) -> void:
	_path_dest = to
	_path_i = 0
	if is_air() or nav_grid == null:
		# Air units fly straight; no grid means straight lines for everyone.
		_path = PackedVector3Array([to])
		return
	_path = nav_grid.find_path(global_position, to)
	if _path.is_empty():
		_path = PackedVector3Array([to])


func _ensure_path(to: Vector3) -> void:
	if _path_i >= _path.size() or _path_dest.distance_to(to) > 1.0:
		_compute_path(to)


## Returns true when the destination is reached.
func _move_along_path(delta: float) -> bool:
	if _path_i >= _path.size():
		return true
	var base_y := AIR_HEIGHT if is_air() else 0.0
	var speed: float = data.speed * Mechanics.speed_mult(self)
	var wp: Vector3 = _path[_path_i]
	var goal := Vector3(wp.x, base_y, wp.z)
	var pos := global_position
	var to := goal - pos
	var dist := to.length()
	var step := speed * delta
	if dist <= maxf(step, 0.25):
		_path_i += 1
		if _path_i >= _path.size():
			global_position = Vector3(goal.x, base_y, goal.z)
			return true
	else:
		var dir := to / dist
		pos += dir * step
		_face_dir(dir, delta)
		pos += _separation(dir) * delta * 4.0
	pos.y = base_y
	global_position = pos
	return false


func _at(pos: Vector3, radius: float) -> bool:
	var d := global_position - pos
	d.y = 0.0
	return d.length() <= radius


## Separation push from nearby allies, capped at ~8 neighbors.
## Includes a tangential slide (biased toward the current move direction) so
## a head-on approach slips around the blocker instead of stalling forever.
func _separation(move_dir: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var found := 0
	for u in Game.units_of(player_id):
		if u == self or found >= 8:
			continue
		if not (u is Unit) or not u.alive():
			continue
		var d: Vector3 = u.global_position - global_position
		d.y = 0.0
		var dist := d.length()
		var min_d: float = data.radius + (u as Unit).data.radius * 0.5 + 0.4
		if dist < min_d and dist > 0.001:
			var n := d / dist
			var overlap := min_d - dist
			push -= n * overlap
			var tangent := Vector3(-n.z, 0.0, n.x)
			if tangent.dot(move_dir) < 0.0:
				tangent = -tangent
			push += tangent * overlap * 1.2
			found += 1
	return push


func _face_dir(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.000001:
		return
	_face_toward(global_position + dir, delta)


func _face_toward(point: Vector3, delta: float) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length_squared() < 0.000001:
		return
	var yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(10.0 * delta, 0.0, 1.0))
