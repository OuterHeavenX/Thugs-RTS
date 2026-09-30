class_name Worker
extends Unit

## Engineer unit: harvests Supply/Helios from ResourceNodes and constructs
## buildings. Implements the GATHER and BUILD state ticks.
##
## CROSS-CHUNK CONTRACT: the world chunk must add every ResourceNode to the
## "resource_nodes" group so Worker can find them.

const HARVEST_PER_TICK := 8.0
const HARVEST_PERIOD := 2.0
const CARRY_CAP := 40.0
const GATHER_REACH := 2.5
const BUILD_REACH := 3.0

var carried: float = 0.0
var carried_kind: String = ""

var _harvest_t: float = 0.0
var _returning: bool = false
var _spark_t: float = 0.0


func _tick_gather(delta: float) -> void:
	var node: Node3D = _gather_node
	if not _node_usable(node):
		node = _nearest_node(carried_kind)
		_gather_node = node
		if node == null:
			state = State.IDLE
			return
	if not _returning:
		var dest: Vector3 = node.global_position
		if _at(dest, GATHER_REACH):
			_harvest_t += delta
			if _harvest_t >= HARVEST_PERIOD:
				_harvest_t = 0.0
				_harvest_tick(node)
		else:
			_ensure_path(dest)
			_move_along_path(delta)
	else:
		# Returning to a Command Center to deposit.
		if _move_along_path(delta):
			_deposit()


func _harvest_tick(node: Node3D) -> void:
	var got: float = node.harvest(HARVEST_PER_TICK)
	carried += got
	carried_kind = str(node.get("kind"))
	VFX.harvest_glint(node.global_position + Vector3(0, 1.5, 0))
	SFX.play("harvest")
	if carried >= CARRY_CAP or not _node_usable(node):
		_returning = true
		_go_to_dropoff()


func _go_to_dropoff() -> void:
	var cc := _nearest_command()
	if cc == null:
		# Nowhere to deposit; hold position with the load.
		_returning = false
		state = State.IDLE
		return
	_compute_path(_sanitize_dest(cc.global_position))


func _deposit() -> void:
	if carried_kind == "helios":
		Game.add_resources(player_id, 0.0, carried)
	else:
		Game.add_resources(player_id, carried, 0.0)
	carried = 0.0
	_returning = false
	# Resume the nearest node of the same kind.
	_gather_node = _nearest_node(carried_kind)


func _tick_build(delta: float) -> void:
	var bld: Node3D = _build_target
	if bld == null or not is_instance_valid(bld):
		state = State.IDLE
		_next_queued()
		return
	if bld.get("built") == true:
		SFX.play("build")
		state = State.IDLE
		_next_queued()
		return
	var dest: Vector3 = bld.global_position
	if _at(dest, BUILD_REACH):
		var bd = bld.get("data")
		if bd != null and float(bd.build_time) > 0.0:
			# Each worker contributes 1/build_time of progress per second;
			# multiple workers stack linearly.
			bld.add_build_power(delta / float(bd.build_time))
		_spark_t += delta
		if _spark_t >= 0.5:
			_spark_t = 0.0
			VFX.sparks(dest + Vector3(0, 2.0, 0))
	else:
		_ensure_path(dest)
		_move_along_path(delta)


# ------------------------------------------------------------------ helpers
func _node_usable(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var amount = node.get("amount")
	if amount != null and float(amount) <= 0.0:
		return false
	return true


func _nearest_node(kind: String) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if not (n is Node3D) or not _node_usable(n):
			continue
		if kind != "" and str(n.get("kind")) != kind:
			continue
		var d: float = global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best = n
			best_d = d
	return best


func _nearest_command() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for b in Game.buildings_of(player_id):
		if not (b is Node3D):
			continue
		if not b.alive():
			continue
		if b.get("built") != true:
			continue
		var bd = b.get("data")
		if bd == null or str(bd.id) != "command":
			continue
		var d: float = global_position.distance_to((b as Node3D).global_position)
		if d < best_d:
			best = b
			best_d = d
	return best
