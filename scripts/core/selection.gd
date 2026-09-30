class_name Selection
extends Node
## Owns the human player's current selection and ALL order issuance.
## Both mouse (InputController) and touch (TouchControls) route through
## issue_smart_order() so behavior is identical on every device.

signal changed

const MAX_GROUPS := 9

var selected: Array[Node3D] = []
# Armed one-shot order modes: "", "attack_move", "rally", "place_building", "gather"
var armed: String = ""
var armed_ref: Node3D = null      # building for rally
var armed_data: Resource = null   # BuildingData for placement

var _groups: Dictionary = {}  # int -> Array[Node3D]


func _prop(obj: Object, prop: String, default = null):
	if obj == null:
		return default
	if prop in obj:
		return obj.get(prop)
	return default


func _alive_node(n: Node3D) -> bool:
	if not is_instance_valid(n):
		return false
	if n.has_method("alive"):
		return bool(n.call("alive"))
	return true



func _dget(d, key: String, default):
	# Resource.get() takes only one arg; this is get-with-default.
	if d == null:
		return default
	if key in d:
		var v = d.get(key)
		return v if v != null else default
	return default

func human_id() -> int:
	return Game.human_id


func _set_ring(n: Node3D, on: bool) -> void:
	if is_instance_valid(n) and n.has_method("set_selected"):
		n.call("set_selected", on)


func select_single(n: Node3D) -> void:
	clear_silent()
	if _alive_node(n):
		selected.append(n)
		_set_ring(n, true)
	SFX.play("select")
	changed.emit()


## Arch alias.
func select(a: Node3D) -> void:
	select_single(a)


func toggle(n: Node3D) -> void:
	if n == null or not _alive_node(n):
		return
	if selected.has(n):
		selected.erase(n)
		_set_ring(n, false)
	else:
		selected.append(n)
		_set_ring(n, true)
	SFX.play("select")
	changed.emit()


func add_silent(n: Node3D) -> void:
	if _alive_node(n) and not selected.has(n):
		selected.append(n)
		_set_ring(n, true)


func clear_silent() -> void:
	for n in selected:
		_set_ring(n, false)
	selected.clear()


func clear() -> void:
	if selected.is_empty() and armed == "":
		return
	clear_silent()
	disarm()
	changed.emit()


func select_army() -> void:
	clear_silent()
	for u in Game.units_of(human_id()):
		var d = _prop(u, "data", null)
		if d != null and not bool(_dget(d, "is_worker", false)):
			add_silent(u)
	SFX.play("select")
	changed.emit()


func box_select(world_rect: Rect2, cam: Camera3D) -> void:
	# world_rect is screen-space. Candidates: human units + buildings.
	var hits: Array[Node3D] = []
	var bld_hits: Array[Node3D] = []
	for u in Game.units_of(human_id()):
		if u is Node3D and not cam.is_position_behind(u.global_position):
			var sp := cam.unproject_position(u.global_position)
			if world_rect.has_point(sp):
				hits.append(u)
	if hits.is_empty():
		for b in Game.buildings_of(human_id()):
			if b is Node3D and not cam.is_position_behind(b.global_position):
				var sp2 := cam.unproject_position(b.global_position)
				if world_rect.has_point(sp2):
					bld_hits.append(b)
	clear_silent()
	for n in hits:
		add_silent(n)
	for n in bld_hits:
		add_silent(n)
	if not selected.is_empty():
		SFX.play("select")
	changed.emit()


func selected_units() -> Array:
	var out: Array = []
	for n in selected:
		if not _alive_node(n):
			continue
		var d = _prop(n, "data", null)
		if d is UnitData:
			out.append(n)
	return out


func selected_buildings() -> Array:
	var out: Array = []
	for n in selected:
		if not _alive_node(n):
			continue
		var d = _prop(n, "data", null)
		if d is BuildingData:
			out.append(n)
	return out


func selected_workers() -> Array:
	var out: Array = []
	for n in selected_units():
		var d = _prop(n, "data", null)
		if d != null and bool(_dget(d, "is_worker", false)):
			out.append(n)
	return out


func selected_combat_units() -> Array:
	var out: Array = []
	for n in selected_units():
		var d = _prop(n, "data", null)
		if d != null and not bool(_dget(d, "is_worker", false)):
			out.append(n)
	return out


# ------------------------------------------------------------- armed modes
func disarm() -> void:
	armed = ""
	armed_ref = null
	armed_data = null


func set_attack_move_armed(b: bool) -> void:
	if b:
		armed = "attack_move"
		armed_ref = null
		armed_data = null
	elif armed == "attack_move":
		disarm()
	changed.emit()


func arm_attack_move() -> void:
	set_attack_move_armed(true)


func arm_rally(bld: Node3D) -> void:
	armed = "rally"
	armed_ref = bld
	armed_data = null
	changed.emit()


func arm_place(data: Resource) -> void:
	armed = "place_building"
	armed_data = data
	armed_ref = null
	changed.emit()


func arm_gather() -> void:
	armed = "gather"
	armed_ref = null
	armed_data = null
	changed.emit()


func is_armed() -> bool:
	return armed != ""


# ----------------------------------------------------------------- orders
func _order_one(u, method: String, arg = null) -> void:
	if u == null or not _alive_node(u):
		return
	if not u.has_method(method):
		return
	if arg == null:
		u.call(method)
	else:
		u.call(method, arg)


func _is_enemy(n: Node3D) -> bool:
	var pid = _prop(n, "player_id", -999)
	return pid != -999 and int(pid) != human_id()


func _is_resource(n: Node3D) -> bool:
	if n == null:
		return false
	if n.is_in_group("resource_nodes"):
		return true
	return n.has_method("harvest")


func _is_own_building(n: Node3D) -> bool:
	var d = _prop(n, "data", null)
	return d is BuildingData and not _is_enemy(n)


func issue_smart_order(target) -> void:
	# target: Node3D (enemy unit/building, resource node, own building)
	# or Vector3 (ground).
	if selected.is_empty():
		return
	# Prune dead first.
	selected = selected.filter(func(n): return _alive_node(n))
	if selected.is_empty():
		changed.emit()
		return
	var did := false
	if armed == "attack_move":
		did = _issue_attack_move(target)
	elif armed == "rally":
		did = _issue_rally(target)
	elif armed == "place_building":
		# Placement is confirmed by the HUD ghost / input layer calling
		# confirm_placement(); a smart order click cancels it.
		disarm()
		changed.emit()
		return
	elif armed == "gather":
		did = _issue_gather(target)
	else:
		did = _issue_smart(target)
	if did:
		SFX.play("order")
	disarm()
	changed.emit()


func _issue_smart(target) -> bool:
	var workers := selected_workers()
	var combat := selected_combat_units()
	if target is Node3D:
		var n := target as Node3D
		if not _alive_node(n):
			return false
		if _is_enemy(n):
			for u in combat:
				_order_one(u, "order_attack", n)
			for u in workers:
				_order_one(u, "order_move", n.global_position)
			return not combat.is_empty() or not workers.is_empty()
		if _is_resource(n):
			if not workers.is_empty():
				for u in workers:
					_order_one(u, "order_gather", n)
				for u in combat:
					_order_one(u, "order_move", n.global_position)
				return true
			# No workers: move everyone near it.
			for u in selected_combat_units():
				_order_one(u, "order_move", n.global_position)
			return true
		if _is_own_building(n):
			var built := bool(_prop(n, "built", true))
			if not workers.is_empty() and not built:
				for u in workers:
					_order_one(u, "order_build", n)
				return true
			for u in selected_units():
				_order_one(u, "order_move", n.global_position)
			return true
		# Neutral / unknown node: move.
		for u in selected_units():
			_order_one(u, "order_move", n.global_position)
		return true
	elif target is Vector3:
		var pos := target as Vector3
		for u in selected_units():
			_order_one(u, "order_move", pos)
		return not selected_units().is_empty()
	return false


func _issue_attack_move(target) -> bool:
	var pos := Vector3.ZERO
	if target is Vector3:
		pos = target
	elif target is Node3D:
		pos = (target as Node3D).global_position
	else:
		return false
	var any := false
	for u in selected_combat_units():
		_order_one(u, "order_attack_move", pos)
		any = true
	for u in selected_workers():
		_order_one(u, "order_move", pos)
		any = true
	return any


func _issue_gather(target) -> bool:
	if not (target is Node3D):
		return false
	var n := target as Node3D
	if not _is_resource(n):
		return false
	var workers := selected_workers()
	if workers.is_empty():
		return false
	for u in workers:
		_order_one(u, "order_gather", n)
	return true


func _issue_rally(target) -> bool:
	if armed_ref == null or not _alive_node(armed_ref):
		return false
	var pos := Vector3.ZERO
	if target is Vector3:
		pos = target
	elif target is Node3D:
		pos = (target as Node3D).global_position
	else:
		return false
	if armed_ref.has_method("set_rally"):
		armed_ref.call("set_rally", pos)
		return true
	return false


# ----------------------------------------------------------------- groups
func store_group(i: int) -> void:
	if i < 1 or i > MAX_GROUPS:
		return
	_groups[i] = selected.duplicate()
	SFX.play("select")


func recall_group(i: int) -> void:
	if i < 1 or i > MAX_GROUPS:
		return
	var g: Array = _groups.get(i, [])
	clear_silent()
	for n in g:
		add_silent(n)
	if not selected.is_empty():
		SFX.play("select")
	changed.emit()


func group_exists(i: int) -> bool:
	return _groups.has(i) and not (_groups[i] as Array).is_empty()
