class_name AICommander
extends Node
## Enemy commander: 1Hz tick state machine. Single difficulty, no cheating —
## every unit/building goes through Game.spend and the same Unit/Building
## APIs the human uses. Fully null-guarded; inert when chunks are missing.

const UNIT_CAP := 60
const WORKER_TARGET := 9

# build order: [time_sec, building_id, near_cc]
const BUILD_ORDER := [
	[40.0, "power", true],
	[90.0, "barracks", false],
	[240.0, "factory", false],
	[270.0, "power", true],
	[360.0, "tower", true],
	[420.0, "lab", false],
	[540.0, "tower", true],
]

var pid := 1
var _nav = null
var _valley = null
var _parent: Node = null

var _timer := 0.0
var _assign_timer := 0.0
var _ready_logged := false

var _worker_assign: Dictionary = {}   # unit instance id -> ResourceNode
var _attempt_cd: Dictionary = {}      # building_id -> last attempt time
var _scouted := false
var _last_wave := -99999.0
var _rally_set := false
var _building_script: GDScript = null

func _dget(d, key: String, default):
	# Resource.get() takes only one arg; this is get-with-default.
	if d == null:
		return default
	if key in d:
		var v = d.get(key)
		return v if v != null else default
	return default



func setup(p_pid: int, nav, valley) -> void:
	pid = p_pid
	_nav = nav
	_valley = valley
	if valley is Node:
		_parent = valley.get_parent()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		_tick()


func _tick() -> void:
	if Game.phase != Game.Phase.PLAYING:
		return
	if Game.get_player(pid) == null:
		return
	if _building_script == null:
		if ResourceLoader.exists("res://scripts/buildings/building.gd"):
			_building_script = ResourceLoader.load("res://scripts/buildings/building.gd")
		if _building_script == null:
			if not _ready_logged:
				_ready_logged = true
				push_warning("AICommander: Building chunk missing — AI idle.")
			return
	_economy()
	_build_order()
	_assign_timer += 1.0
	if _assign_timer >= 3.0:
		_assign_timer = 0.0
		_assign_workers()
	_army()
	_scout()
	_waves()


# ---------------------------------------------------------------- helpers
func _data(u):
	return u.get("data") if (u != null and "data" in u) else null


func _is_worker(u) -> bool:
	var d = _data(u)
	return d != null and bool(_dget(d, "is_worker", false))


func _workers() -> Array:
	var out: Array = []
	for u in Game.units_of(pid):
		if _is_worker(u):
			out.append(u)
	return out


func _combat_units() -> Array:
	var out: Array = []
	for u in Game.units_of(pid):
		if not _is_worker(u):
			out.append(u)
	return out


func _bdata_id(b) -> String:
	var d = _data(b)
	return str(_dget(d, "id", "")) if d != null else ""


func _is_built(b) -> bool:
	return not ("built" in b) or bool(b.get("built"))


func _find_building(bid: String):
	for b in Game.buildings_of(pid):
		if _bdata_id(b) == bid:
			return b
	return null


func _faction_id() -> String:
	var p: Player = Game.get_player(pid)
	if p == null or p.faction == null:
		return ""
	return p.faction.id


func _enemy_id() -> int:
	return 0 if pid == 1 else 1


func _my_base() -> Vector3:
	if _valley != null and _valley.has_method("base_center"):
		var v = _valley.call("base_center", pid)
		if v is Vector3:
			return v
	return Vector3(44, 0, 0) if pid == 1 else Vector3(-44, 0, 0)


func _enemy_base() -> Vector3:
	if _valley != null and _valley.has_method("base_center"):
		var v = _valley.call("base_center", _enemy_id())
		if v is Vector3:
			return v
	return Vector3(-44, 0, 0) if pid == 1 else Vector3(44, 0, 0)


func _supply_nodes() -> Array:
	return _nodes_of_kind("supply")


func _helios_nodes() -> Array:
	return _nodes_of_kind("helios")


func _nodes_of_kind(kind: String) -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	for rn in tree.get_nodes_in_group("resource_nodes"):
		if rn is Node3D and "kind" in rn and str(rn.get("kind")) == kind:
			if "amount" in rn and float(rn.get("amount")) <= 0.0:
				continue
			out.append(rn)
	out.sort_custom(func(a, b): return a.global_position.distance_squared_to(_my_base()) < b.global_position.distance_squared_to(_my_base()))
	return out


# ---------------------------------------------------------------- economy
func _economy() -> void:
	var cc = _find_building("command")
	if cc == null or not _is_built(cc):
		return
	if Game.units_of(pid).size() >= UNIT_CAP:
		return
	if _workers().size() < WORKER_TARGET and cc.has_method("queue_unit"):
		cc.call("queue_unit", "worker")


func _can_place(bd: BuildingData, pos: Vector3) -> bool:
	if _building_script != null and _building_script.has_method("can_place"):
		var ok = _building_script.call("can_place", _nav, pos, bd.footprint)
		if ok is bool:
			return ok
	return absf(pos.x) < 62.0 and absf(pos.z) < 62.0


func _find_site(bd: BuildingData, near_cc: bool) -> Vector3:
	var center := _my_base()
	if near_cc:
		var cc = _find_building("command")
		if cc is Node3D:
			center = cc.global_position
	for ring in [10.0, 14.0, 18.0, 24.0, 30.0]:
		for i in 12:
			var a := TAU * float(i) / 12.0
			var pos: Vector3 = center + Vector3(cos(a), 0, sin(a)) * ring
			if _can_place(bd, pos):
				return pos
	return Vector3(1.0e9, 0, 1.0e9)


func _try_build(bid: String, near_cc: bool) -> void:
	var last: float = _attempt_cd.get(bid, -9999.0)
	if Game.time - last < 30.0:
		return
	_attempt_cd[bid] = Game.time
	var f: FactionData = Game.get_player(pid).faction
	if f == null:
		return
	var bd: BuildingData = f.building(bid)
	if bd == null:
		return
	var pos := _find_site(bd, near_cc)
	if pos.x > 1.0e8:
		return
	if not Game.spend(pid, bd.cost_supply, bd.cost_helios):
		return
	var b = _building_script.new()
	if not (b is Node3D):
		Game.refund(pid, bd.cost_supply, bd.cost_helios)
		return
	if b.has_method("setup"):
		b.call("setup", bd, pid)
	if _parent != null:
		_parent.add_child(b)
	else:
		b.queue_free()
		Game.refund(pid, bd.cost_supply, bd.cost_helios)
		return
	if b.has_method("place_at"):
		b.call("place_at", pos)
	else:
		b.global_position = pos
	# Send the nearest worker to construct it.
	var best = null
	var best_d := 1.0e18
	for w in _workers():
		if w is Node3D:
			var d: float = w.global_position.distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = w
	if best != null and best.has_method("order_build"):
		best.call("order_build", b)
		_worker_assign.erase(best.get_instance_id())


func _build_order() -> void:
	for item in BUILD_ORDER:
		var t: float = item[0]
		var bid: String = item[1]
		if Game.time < t:
			continue
		if _find_building(bid) != null:
			continue
		_try_build(bid, bool(item[2]))


# --------------------------------------------------------------- workers
func _assign_workers() -> void:
	# Prune dead/depleted assignments.
	var dead: Array = []
	for uid in _worker_assign.keys():
		var node = _worker_assign[uid]
		var u = null
		for w in _workers():
			if w.get_instance_id() == uid:
				u = w
				break
		var node_gone := not is_instance_valid(node)
		if not node_gone and "amount" in node and float(node.get("amount")) <= 0.0:
			node_gone = true
		if u == null or node_gone:
			dead.append(uid)
	for uid in dead:
		_worker_assign.erase(uid)
	var workers := _workers()
	var unassigned: Array = []
	for w in workers:
		if not _worker_assign.has(w.get_instance_id()):
			unassigned.append(w)
	if unassigned.is_empty():
		return
	# Helios crew first (2 workers once the lab stands).
	var helios_want := 0
	if _find_building("lab") != null:
		helios_want = 2
	var helios_nodes := _helios_nodes()
	var hcount := 0
	for uid in _worker_assign.keys():
		var n = _worker_assign[uid]
		if is_instance_valid(n) and "kind" in n and str(n.get("kind")) == "helios":
			hcount += 1
	while hcount < helios_want and not unassigned.is_empty() and not helios_nodes.is_empty():
		var w = unassigned.pop_back()
		_order_gather(w, helios_nodes[0])
		_worker_assign[w.get_instance_id()] = helios_nodes[0]
		hcount += 1
	# Supply: spread 2-3 per node, nearest nodes first.
	var supply := _supply_nodes()
	if supply.is_empty() or unassigned.is_empty():
		return
	var load: Dictionary = {}
	for n in supply:
		load[n.get_instance_id()] = 0
	for uid in _worker_assign.keys():
		var n = _worker_assign[uid]
		if is_instance_valid(n) and load.has(n.get_instance_id()):
			load[n.get_instance_id()] += 1
	supply.sort_custom(func(a, b): return load[a.get_instance_id()] < load[b.get_instance_id()])
	for w in unassigned:
		var target = null
		for n in supply:
			if load[n.get_instance_id()] < 3:
				target = n
				break
		if target == null:
			target = supply[0]
		_order_gather(w, target)
		_worker_assign[w.get_instance_id()] = target
		load[target.get_instance_id()] += 1


func _order_gather(w, node) -> void:
	if w != null and w.has_method("order_gather"):
		w.call("order_gather", node)


# ------------------------------------------------------------------ army
func _army() -> void:
	if Game.units_of(pid).size() >= UNIT_CAP:
		return
	var fid := _faction_id()
	var rax = _find_building("barracks")
	var fac = _find_building("factory")
	if rax != null and _is_built(rax) and rax.has_method("queue_unit"):
		if fid == "us":
			rax.call("queue_unit", "ranger" if randi() % 3 != 0 else "guardian")
		else:
			rax.call("queue_unit", "raiden" if randi() % 4 != 0 else "shinobi")
	if fac != null and _is_built(fac) and fac.has_method("queue_unit"):
		if fid == "us":
			fac.call("queue_unit", "abramsx" if randi() % 2 == 0 else "reaper")
		else:
			var r := randi() % 5
			fac.call("queue_unit", "tora" if r < 2 else ("ronin" if r < 4 else "kitsune"))
	# Rally once so the army masses at home.
	if not _rally_set and rax != null and _is_built(rax) and rax.has_method("set_rally"):
		var rally := _my_base() + (_enemy_base() - _my_base()).normalized() * 14.0
		rax.call("set_rally", rally)
		if fac != null and fac.has_method("set_rally"):
			fac.call("set_rally", rally)
		_rally_set = true


func _fastest_unit(exclude_workers: bool):
	var best = null
	var best_s := -1.0
	for u in Game.units_of(pid):
		if exclude_workers and _is_worker(u):
			continue
		var d = _data(u)
		if d == null:
			continue
		var s: float = float(_dget(d, "speed", 0.0))
		if s > best_s:
			best_s = s
			best = u
	return best


func _scout() -> void:
	if _scouted or Game.time < 180.0:
		return
	_scouted = true
	var s = _fastest_unit(false)
	if s != null and s.has_method("order_attack_move") and s is Node3D:
		s.call("order_attack_move", _enemy_base())


func _waves() -> void:
	var first_at := 390.0
	var interval := 180.0
	if Game.time < first_at:
		return
	if Game.time - _last_wave < interval:
		return
	var army := _combat_units()
	if army.size() < 5:
		return
	_last_wave = Game.time
	var target := _enemy_base()
	for u in army:
		if u.has_method("order_attack_move"):
			u.call("order_attack_move", target)
