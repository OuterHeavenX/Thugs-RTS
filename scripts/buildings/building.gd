class_name Building
extends Node3D

## WORLD COMMAND — Building (chunk: buildings).
##
## A placed structure: construction -> production/research -> defense, plus
## power-grid integration. 100% original code.
##
## PLACEMENT CONVENTION (for the world chunk):
##   var b := Building.new()
##   b.setup(data, pid)      # loads model, ring, health bar, registers with Game
##   parent.add_child(b)
##   b.place_at(pos)         # sets position AND blocks nav via Building.nav_grid
## Do NOT set position directly: nav blocking only happens in place_at().
## Before any placement, the world chunk must set:
##   Building.nav_grid = <NavGrid instance>
## (left untyped so this file parses before navigation/nav_grid.gd lands).
##
## CROSS-CHUNK CALLS (units/combat/mechanics/vfx/sfx chunks may land later):
## Unit, Projectile, Mechanics, Combat are resolved dynamically via
## ClassDB / the global class list with res:// fallback paths, then cached.
## Missing classes degrade gracefully (warn + skip) instead of parse errors.
## VFX/SFX autoloads are looked up via get_node_or_null("/root/...") so this
## file is headless-safe even before those scripts exist.
##
## Production queue entries: Dictionaries
##   {"kind": "unit"|"research", "id": String, "progress": float, "total": float}
## Only the front entry advances. Research needs power_ok(); production runs
## at 50% speed during a power shortage.

signal selected_changed(selected: bool)

const CELL_METERS := 2.0
const MAP_HALF := 64.0          # map is 128x128 m
const PLACE_MARGIN := 4.0       # placement must stay this far inside the edge
const MAX_QUEUE := 5
const SCAN_INTERVAL := 0.3       # defense target-scan stagger (seconds)
const SMOKE_FRAC := 0.5         # smoke VFX below this hp fraction
const SPARK_INTERVAL := 0.25     # construction spark throttle (seconds)

static var nav_grid = null
static var _script_cache: Dictionary = {}


## Autoload access without parse-time singleton identifiers.
## Headless `-s` test scripts compile before autoload names are registered
## with the script language, so `Game` / `Data` as bare identifiers fail to
## parse there. These Variant-returning accessors use dynamic dispatch and
## work identically in normal game runs and headless tests. They resolve via
## the main loop (not get_tree()) so setup() works before add_child().
func _game():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Game")
	return null


func _data():
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Data")
	return null

var data: BuildingData = null
var player_id: int = 0
var hp: float = 1.0
var max_hp: float = 1.0
var built: bool = false
var construction: float = 0.0
var queue: Array = []
var rally_point: Vector3 = Vector3.ZERO

var _rally_set: bool = false
var _setup_done: bool = false
var _model_root: Node3D = null
var _model_offset: Node3D = null
var _scaffold: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _bar: Node3D = null
var _bar_fg: MeshInstance3D = null
var _turret: Node3D = null
var _muzzle: Node3D = null
var _top_y: float = 3.0
var _select_radius: float = 4.0
var _scan_t: float = 0.0
var _cooldown: float = 0.0
var _smoke_t: float = 0.0
var _last_spark_msec: int = -100000
var _target = null
var _faction_color: Color = Color(0.5, 0.5, 0.5)


# ---------------------------------------------------------- static helpers
## Resolve another chunk's script class without a parse-time reference.
## Falls back to the conventional res:// path from ARCHITECTURE.md, then null.
static func _resolve_script(class_name_str: String, fallback_path: String) -> Script:
	if _script_cache.has(class_name_str):
		return _script_cache[class_name_str] as Script
	var scr: Script = null
	if ClassDB.class_exists(class_name_str):
		for info in ProjectSettings.get_global_class_list():
			if String(info.get("class", "")) == class_name_str:
				var p := String(info.get("path", ""))
				if p != "":
					scr = ResourceLoader.load(p) as Script
				break
	if scr == null and fallback_path != "":
		scr = ResourceLoader.load(fallback_path) as Script
	_script_cache[class_name_str] = scr
	return scr


static func _static_call(class_name_str: String, fallback_path: String,
		method: String, args: Array):
	var scr := _resolve_script(class_name_str, fallback_path)
	if scr == null:
		return null
	return scr.callv(method, args)


## Placement validity: inside map bounds (margin 4 m) and every covered cell
## walkable. `nav` is the world's NavGrid; null nav -> false.
static func can_place(nav, pos: Vector3, footprint: Vector2i) -> bool:
	if nav == null:
		return false
	var half := Vector2(footprint) * (CELL_METERS * 0.5)
	var limit := MAP_HALF - PLACE_MARGIN
	if absf(pos.x) + half.x > limit:
		return false
	if absf(pos.z) + half.y > limit:
		return false
	var c0: Vector2i = nav.world_to_cell(pos - Vector3(half.x, 0.0, half.y))
	var c1: Vector2i = nav.world_to_cell(pos + Vector3(half.x, 0.0, half.y))
	for cx in range(mini(c0.x, c1.x), maxi(c0.x, c1.x) + 1):
		for cz in range(mini(c0.y, c1.y), maxi(c0.y, c1.y) + 1):
			if not nav.is_cell_walkable(Vector2i(cx, cz)):
				return false
	return true


# ------------------------------------------------------------------- setup
func setup(p_data: BuildingData, pid: int) -> void:
	if _setup_done:
		return
	_setup_done = true
	data = p_data
	player_id = pid
	max_hp = data.hp
	hp = max_hp
	built = false
	construction = 0.0
	var p = _game().get_player(pid)
	if p != null and p.faction != null:
		_faction_color = p.faction.color
	_build_model()
	_build_ring()
	_build_healthbar()
	_apply_construction_visual()
	_game().register_building(self)


## Sets world position AND blocks nav cells. Call this instead of assigning
## position/global_position directly.
func place_at(pos: Vector3) -> void:
	global_position = pos
	_block_nav(true)


func _block_nav(blocked: bool) -> void:
	if nav_grid == null or data == null:
		return
	nav_grid.set_blocked_rect(global_position, data.footprint, blocked)


func _build_model() -> void:
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)
	_model_offset = Node3D.new()
	_model_offset.name = "ModelOffset"
	_model_root.add_child(_model_offset)
	var inst: Node3D = null
	if data.model != "":
		var res := ResourceLoader.load(data.model)
		if res is PackedScene:
			inst = (res as PackedScene).instantiate() as Node3D
	var fp_m := Vector2(data.footprint) * CELL_METERS
	if inst == null:
		inst = _make_fallback_box(fp_m)
	_model_offset.add_child(inst)
	# Shift the model so its lowest point sits at y=0: scale-y then grows
	# from the ground instead of sinking through it.
	var aabb := _measure_aabb(inst)
	_model_offset.position.y = -aabb.position.y
	_top_y = maxf(aabb.size.y, 2.0)
	_select_radius = maxf(fp_m.x, fp_m.y) * 0.5 + 0.75
	_turret = inst.find_child("Turret", true, false) as Node3D
	if _turret != null:
		_muzzle = _turret.get_node_or_null("Muzzle") as Node3D
	if _muzzle == null:
		_muzzle = inst.find_child("Muzzle", true, false) as Node3D
	# Translucent scaffold ghost, visible only while under construction.
	_scaffold = MeshInstance3D.new()
	_scaffold.name = "Scaffold"
	var bm := BoxMesh.new()
	bm.size = Vector3(fp_m.x, maxf(_top_y, 2.0), fp_m.y)
	_scaffold.mesh = bm
	_scaffold.position.y = bm.size.y * 0.5
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(_faction_color.r, _faction_color.g, _faction_color.b, 0.25)
	_scaffold.material_override = sm
	add_child(_scaffold)


func _make_fallback_box(fp_m: Vector2) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "FallbackBox"
	var bm := BoxMesh.new()
	var h := 3.0
	bm.size = Vector3(fp_m.x, h, fp_m.y)
	mi.mesh = bm
	mi.position.y = h * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _faction_color
	mat.roughness = 0.9
	mi.material_override = mat
	return mi


func _measure_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var mb: AABB = _relative_xf(mi, root) * mi.mesh.get_aabb()
				if first:
					box = mb
					first = false
				else:
					box = box.merge(mb)
		for c in n.get_children():
			stack.push_back(c)
	if first:
		box = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.0, 2.0))
	return box


func _relative_xf(n: Node3D, root: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = c
	m.no_depth_test = true
	return m


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "SelectionRing"
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(_select_radius - 0.18, 0.05)
	tm.outer_radius = _select_radius + 0.18
	tm.rings = 48
	tm.ring_segments = 8
	_ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _faction_color
	mat.no_depth_test = true
	_ring.material_override = mat
	_ring.position.y = 0.15
	_ring.visible = false
	add_child(_ring)


func set_selected(selected: bool) -> void:
	if _ring != null:
		_ring.visible = selected
	selected_changed.emit(selected)


func _build_healthbar() -> void:
	_bar = Node3D.new()
	_bar.name = "HealthBar"
	_bar.position = Vector3(0.0, _top_y + 1.2, 0.0)
	add_child(_bar)
	var w := 3.0
	var bg := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, 0.32)
	bg.mesh = qm
	bg.material_override = _flat_mat(Color(0.0, 0.0, 0.0, 0.75))
	_bar.add_child(bg)
	_bar_fg = MeshInstance3D.new()
	var qm2 := QuadMesh.new()
	qm2.size = Vector2(w, 0.22)
	_bar_fg.mesh = qm2
	_bar_fg.material_override = _flat_mat(Color(0.2, 0.9, 0.25))
	_bar_fg.position.z = 0.01
	_bar.add_child(_bar_fg)
	_bar.visible = false


func _update_bar() -> void:
	if _bar == null or _bar_fg == null:
		return
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_bar.visible = frac < 1.0
	if _bar.visible:
		_bar_fg.scale.x = maxf(frac, 0.001)
		_bar_fg.position.x = -3.0 * (1.0 - frac) * 0.5
		var c := Color(0.9, 0.2, 0.15).lerp(Color(0.2, 0.9, 0.25), frac)
		(_bar_fg.material_override as StandardMaterial3D).albedo_color = c


# ------------------------------------------------------------ construction
func add_build_power(amount: float) -> void:
	if built or data == null:
		return
	construction = minf(1.0, construction + amount)
	_apply_construction_visual()
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_spark_msec >= int(SPARK_INTERVAL * 1000.0):
		_last_spark_msec = now_msec
		_fx("sparks", [_spark_pos()])
	if construction >= 1.0:
		built = true
		construction = 1.0
		_apply_construction_visual()
		_game().building_constructed.emit(self)
		_game().recompute_power(player_id)


func _apply_construction_visual() -> void:
	if _model_root == null:
		return
	var s := lerpf(0.12, 1.0, construction)
	_model_root.scale = Vector3(1.0, s, 1.0)
	if _scaffold != null:
		_scaffold.visible = not built


func get_construction_progress() -> float:
	return construction


## Instantly finish (map setup). No cost, no build power needed.
func debug_complete() -> void:
	if data == null:
		return
	built = true
	construction = 1.0
	_apply_construction_visual()
	_game().building_constructed.emit(self)
	_game().recompute_power(player_id)


# ------------------------------------------------------------------- power
func power_ok() -> bool:
	if data == null:
		return true
	if data.power_use <= 0.0:
		return true
	var p = _game().get_player(player_id)
	return p != null and not p.power_shortage()


## Production speed multiplier: 0.5 during a power shortage, else 1.0.
func power_factor() -> float:
	var p = _game().get_player(player_id)
	if p != null and p.power_shortage():
		return 0.5
	return 1.0


# ------------------------------------------------------ production/research
func queue_unit(unit_id: String) -> bool:
	if not built or data == null:
		return false
	if not power_ok():
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	var p = _game().get_player(player_id)
	if p == null or p.faction == null:
		return false
	if not data.trains.has(unit_id):
		return false
	var ud = _data().unit(p.faction.id, unit_id)
	if ud == null:
		return false
	if not _game().spend(player_id, ud.cost_supply, ud.cost_helios):
		return false
	queue.append({
		"kind": "unit", "id": unit_id,
		"progress": 0.0, "total": maxf(ud.build_time, 0.1),
	})
	return true


func queue_research(upgrade_id: String) -> bool:
	if not built or data == null:
		return false
	if not power_ok():
		return false
	var p = _game().get_player(player_id)
	if p == null or p.faction == null:
		return false
	if not data.researches.has(upgrade_id):
		return false
	if p.has_tech(upgrade_id):
		return false
	for e in queue:
		if String((e as Dictionary).get("kind", "")) == "research":
			return false  # one research at a time
	var up = _data().upgrade(p.faction.id, upgrade_id)
	if up == null:
		return false
	if not _game().spend(player_id, up.cost_supply, up.cost_helios):
		return false
	queue.append({
		"kind": "research", "id": upgrade_id,
		"progress": 0.0, "total": maxf(up.research_time, 0.1),
	})
	return true


## Cancel a queued entry and refund its full cost.
func cancel_queue_index(i: int) -> void:
	if i < 0 or i >= queue.size():
		return
	var e: Dictionary = queue[i]
	var p = _game().get_player(player_id)
	var fid := ""
	if p != null and p.faction != null:
		fid = p.faction.id
	if fid != "":
		if String(e.get("kind", "")) == "unit":
			var ud = _data().unit(fid, String(e.get("id", "")))
			if ud != null:
				_game().refund(player_id, ud.cost_supply, ud.cost_helios)
		elif String(e.get("kind", "")) == "research":
			var up = _data().upgrade(fid, String(e.get("id", "")))
			if up != null:
				_game().refund(player_id, up.cost_supply, up.cost_helios)
	queue.remove_at(i)


func set_rally(pos: Vector3) -> void:
	rally_point = pos
	_rally_set = true


func rally_pos() -> Vector3:
	if _rally_set:
		return rally_point
	var d := 4.0
	if data != null:
		d = float(data.footprint.y) * CELL_METERS * 0.5 + 2.0
	return global_position + Vector3(0.0, 0.0, d)


func _complete_entry(e: Dictionary) -> void:
	var kind := String(e.get("kind", ""))
	var eid := String(e.get("id", ""))
	var p = _game().get_player(player_id)
	var fid := ""
	if p != null and p.faction != null:
		fid = p.faction.id
	if kind == "unit":
		var ud = _data().unit(fid, eid) if fid != "" else null
		# Workers need the Worker subclass (gather/build ticks live there;
		# base Unit just idles in GATHER/BUILD states).
		var scr: Script = null
		if ud != null and ud.is_worker:
			scr = _resolve_script("Worker", "res://scripts/units/worker.gd")
		else:
			scr = _resolve_script("Unit", "res://scripts/units/unit.gd")
		if ud != null and scr != null:
			var u = scr.new()
			u.setup(ud, player_id)
			var par := get_parent()
			if par != null:
				par.add_child(u)
				u.global_position = rally_pos()
				_game().register_unit(u)
				_sfx_play("train")
			else:
				push_warning("Building: no parent to spawn unit '%s' into." % eid)
		else:
			push_warning("Building: cannot spawn unit '%s' (Unit class or data missing)." % eid)
	elif kind == "research":
		if p != null:
			p.techs[eid] = true
		_game().tech_researched.emit(player_id, eid)
		_sfx_play("research")


# ------------------------------------------------------------------- process
func _process(delta: float) -> void:
	if data == null:
		return
	if not built or hp <= 0.0:
		return
	_smoke_t -= delta
	if hp < max_hp * SMOKE_FRAC and _smoke_t <= 0.0:
		_smoke_t = 1.5
		_fx("smoke", [_smoke_pos()])
	if not queue.is_empty() and power_ok():
		var e: Dictionary = queue[0]
		e["progress"] = float(e["progress"]) + delta * power_factor()
		if float(e["progress"]) >= float(e["total"]):
			queue.pop_front()
			_complete_entry(e)
	_defense(delta)


# ------------------------------------------------------------------- defense
func _defense(delta: float) -> void:
	if data.weapon == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_INTERVAL
		_target = _acquire_target()
	if _target != null:
		if not is_instance_valid(_target):
			_target = null
		elif not bool(_target.alive()):
			_target = null
	if _target != null and _cooldown <= 0.0:
		_fire(_target)


func _acquire_target():
	var w: WeaponData = data.weapon
	var combat := _resolve_script("Combat", "res://scripts/combat/combat.gd")
	var best = null
	var best_d := w.range
	for e in _game().enemies_of(player_id):
		if e == null:
			continue
		var ep: Vector3 = e.global_position
		var d := _flat_distance(global_position, ep)
		if d > w.range or d >= best_d:
			continue
		if not _can_see(ep):
			continue
		if not _can_target(w, e, combat):
			continue
		best = e
		best_d = d
	return best


func _can_target(w: WeaponData, target, combat: Script) -> bool:
	if combat != null:
		var r = combat.callv("can_target", [w, target])
		if r != null:
			return bool(r)
	var air := bool(target.is_air())
	if air and not w.targets_air:
		return false
	if not air and not w.targets_ground:
		return false
	return true


func _can_see(pos: Vector3) -> bool:
	var r = _static_call("Mechanics", "res://scripts/factions/mechanics.gd",
		"can_see", [player_id, pos])
	if r == null:
		return true  # mechanics chunk not present yet: assume visible
	return bool(r)


func _fire(target) -> void:
	var w: WeaponData = data.weapon
	_cooldown = w.cooldown
	if _turret != null:
		var d: Vector3 = target.global_position - _turret.global_position
		if Vector2(d.x, d.z).length() > 0.01:
			_turret.rotation.y = atan2(-d.x, -d.z)
	var from := _muzzle_pos()
	var to: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	_fx("muzzle", [from])
	_fx("tracer", [from, to, w.tracer_color])
	_sfx_play("shoot")
	if w.projectile_speed > 0.0:
		var pscr := _resolve_script("Projectile", "res://scripts/combat/projectile.gd")
		if pscr != null:
			var pr = pscr.new()
			pr.setup(from, to, target, w, self)
			var par := get_parent()
			if par != null:
				par.add_child(pr)
				return
	_deal_damage(target, w)


func _deal_damage(target, w: WeaponData) -> void:
	var combat := _resolve_script("Combat", "res://scripts/combat/combat.gd")
	if combat != null:
		combat.callv("apply_damage", [target, w.damage, w, self])
	else:
		target.take_damage(w.damage, self)


# -------------------------------------------------------------------- damage
func take_damage(amount: float, source) -> void:
	if hp <= 0.0 or data == null:
		return
	hp = maxf(0.0, hp - amount)
	_update_bar()
	if hp <= 0.0:
		_die()


func _die() -> void:
	_fx("explosion", [global_position + Vector3(0.0, 1.0, 0.0), 3.0])
	_sfx_play("explosion")
	_block_nav(false)
	_game().unregister_building(self)  # triggers _game().check_victory()
	queue_free()  # no refund for a destroyed building, even if unbuilt


func alive() -> bool:
	return hp > 0.0 and not is_queued_for_deletion()


func armor_tags() -> PackedStringArray:
	return PackedStringArray(["building"])


func is_air() -> bool:
	return false


## Armed, constructed buildings act as stealth detectors (duck-typed by units).
func is_detector() -> bool:
	return built and data != null and data.weapon != null


## Damage multiplier hooks used by Combat.apply_damage(..., attacker=self).
func faction_bonus_damage() -> float:
	return 1.0


# ------------------------------------------------------------------ fx/audio
func _vfx_node() -> Node:
	var t := get_tree()
	if t == null:
		return null
	return t.root.get_node_or_null("VFX")


func _fx(method: String, args: Array) -> void:
	var v := _vfx_node()
	if v == null or not v.has_method(method):
		return
	v.callv(method, args)


func _sfx_play(sound_name: String) -> void:
	var t := get_tree()
	if t == null:
		return
	var s := t.root.get_node_or_null("SFX")
	if s == null or not s.has_method("play"):
		return
	s.call("play", sound_name)


func _muzzle_pos() -> Vector3:
	if _muzzle != null and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position + Vector3(0.0, _top_y * 0.8, 0.0)


func _smoke_pos() -> Vector3:
	return global_position + Vector3(
		randf_range(-1.0, 1.0), _top_y * 0.6, randf_range(-1.0, 1.0))


func _spark_pos() -> Vector3:
	var r := _select_radius * 0.7
	return global_position + Vector3(
		randf_range(-r, r), randf_range(0.3, _top_y), randf_range(-r, r))


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return sqrt(dx * dx + dz * dz)
