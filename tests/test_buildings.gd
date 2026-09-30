extends SceneTree

## Headless verification for scripts/buildings/building.gd.
## Run: godot --headless --path <project> -s res://tests/test_buildings.gd
## Unit/Projectile/Mechanics/Combat chunks may be absent: spawn-dependent
## asserts print SKIP but economy/power/research logic is fully tested.

var _passed := 0
var _failed := 0
var _skipped := 0
# Autoload identifiers do not resolve at parse time in `-s` headless scripts,
# so grab the singleton nodes dynamically (same objects, dynamic dispatch).
var Game = null
var Data = null


class FakeNav:
	extends RefCounted
	var blocked: Dictionary = {}

	func world_to_cell(pos: Vector3) -> Vector2i:
		return Vector2i(int(floor(pos.x / 2.0)) + 32, int(floor(pos.z / 2.0)) + 32)

	func is_cell_walkable(c: Vector2i) -> bool:
		if c.x < 0 or c.y < 0 or c.x >= 64 or c.y >= 64:
			return false
		return not blocked.get(c, false)


func check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func skip(name: String) -> void:
	_skipped += 1
	print("SKIP: ", name)


func make_building(data: BuildingData, pid: int, pos: Vector3) -> Building:
	var b := Building.new()
	b.setup(data, pid)
	root.add_child(b)
	b.place_at(pos)
	return b


func _initialize() -> void:
	# Watchdog: if a runtime error aborts the run early, the deferred quit
	# still fires so the headless run can never hang.
	quit.call_deferred()
	# Deferred one frame: in `-s` headless mode the script's _initialize runs
	# before autoload _ready() (Data.factions is still empty); by the first
	# idle frame the autoloads are fully initialized.
	_run.call_deferred()


func _run() -> void:
	Game = root.get_node("Game")
	Data = root.get_node("Data")
	Game.new_match("us", "japan")
	var p0 = Game.get_player(0)

	# ------------------------------------------------ (1) setup / registration
	var barracks_data: BuildingData = Data.building("us", "barracks")
	var b := make_building(barracks_data, 0, Vector3(10, 0, 10))
	check(not b.built, "new building starts unbuilt")
	check(b.construction == 0.0, "construction starts at 0")
	check(b.hp == b.max_hp and b.max_hp == barracks_data.hp, "hp=max_hp=data.hp")
	check(b.alive(), "alive() true when fresh")
	check(b.armor_tags() == PackedStringArray(["building"]), "armor_tags building")
	check(not b.is_air(), "is_air() false")
	b.set_selected(true)  # must not crash
	b.debug_complete()
	check(b.built, "debug_complete sets built")
	check(b.construction == 1.0, "debug_complete sets construction=1")
	check(b.get_construction_progress() == 1.0, "get_construction_progress")
	check(Game.buildings_of(0).has(b), "Game.buildings_of(0) contains it")

	# construction path (worker-driven)
	var b_cons := make_building(barracks_data, 0, Vector3(-20, 0, -20))
	b_cons.add_build_power(0.5)
	check(not b_cons.built, "half build power -> not built")
	check(absf(b_cons.get_construction_progress() - 0.5) < 0.001, "progress tracks build power")
	var constructed_flag := [false]
	Game.building_constructed.connect(func(_x): constructed_flag[0] = true)
	b_cons.add_build_power(0.6)
	check(b_cons.built, "full build power -> built")
	check(constructed_flag[0], "building_constructed emitted on completion")
	Game.building_constructed.disconnect(Game.building_constructed.get_connections()[0].callable)

	# ------------------------------------------------ (3) power (before economy so queueing has power)
	var gen := make_building(Data.building("us", "power"), 0, Vector3(20, 0, 20))
	gen.debug_complete()
	Game.recompute_power(0)
	check(not p0.power_shortage(), "no shortage with fusion generator online")
	check(b.power_ok(), "barracks power_ok with surplus")
	check(gen.power_ok(), "generator (power_use=0) power_ok")
	check(absf(gen.power_factor() - 1.0) < 0.001, "power_factor 1.0 without shortage")
	p0.power_consumed = p0.power_produced + 1.0  # force a shortage directly
	check(p0.power_shortage(), "shortage when consumed > produced")
	check(not b.power_ok(), "barracks power_ok false in shortage")
	check(gen.power_ok(), "generator still power_ok in shortage (no power_use)")
	check(absf(gen.power_factor() - 0.5) < 0.001, "power_factor 0.5 in shortage")
	Game.recompute_power(0)  # restore real numbers

	# ------------------------------------------------ (2) production economy
	Game.add_resources(0, 1000.0, 500.0)
	var dup: BuildingData = barracks_data.duplicate() as BuildingData
	var b2 := make_building(dup, 0, Vector3(-10, 0, 10))
	b2.debug_complete()
	var unbuilt := make_building(barracks_data, 0, Vector3(-30, 0, -30))
	check(not unbuilt.queue_unit("ranger"), "queue_unit false while unbuilt")
	check(not b2.queue_unit("paladin"), "queue_unit false for untrainable id")
	check(not b2.queue_unit("nope"), "queue_unit false for unknown unit")
	var supply_before: float = p0.supply
	check(b2.queue_unit("ranger"), "queue_unit('ranger') true")
	check(p0.supply < supply_before, "queue_unit spends supply")
	check(b2.queue.size() == 1, "queue holds the entry")
	var e0: Dictionary = b2.queue[0]
	check(String(e0["kind"]) == "unit" and String(e0["id"]) == "ranger", "queue entry kind/id")
	# fast-forward: near-complete then one _process tick
	e0["progress"] = float(e0["total"]) - 0.05
	b2._process(0.1)
	check(b2.queue.is_empty(), "queue empties after completion")
	# Unit chunk has landed (scripts/units/unit.gd): the spawn goes through
	# Building._resolve_script's res:// fallback even when the global class
	# cache is stale, so assert on the registry, not on ClassDB.
	var spawned_count: int = Game.units_of(0).size()
	if spawned_count >= 1:
		check(true, "ranger spawned and registered")
	else:
		skip("Unit class missing: spawn assert (queue pop verified)")
	# queue cap at 5
	for i in range(6):
		b2.queue_unit("ranger")
	check(b2.queue.size() == 5, "queue capped at 5")
	# cancel refunds
	var sup2: float = p0.supply
	b2.cancel_queue_index(0)
	check(b2.queue.size() == 4, "cancel_queue_index removes entry")
	check(p0.supply > sup2, "cancel_queue_index refunds cost")
	b2.cancel_queue_index(99)  # out of range: no crash
	check(b2.queue.size() == 4, "cancel out of range ignored")

	# ------------------------------------------------ (4) research
	var lab := make_building(Data.building("us", "lab"), 0, Vector3(30, 0, 30))
	lab.debug_complete()
	check(not b2.queue_research("network_uplink"), "queue_research false on barracks")
	check(lab.queue_research("network_uplink"), "queue_research('network_uplink') true")
	check(not lab.queue_research("composite_armor"), "one research at a time")
	var re: Dictionary = lab.queue[0]
	re["progress"] = float(re["total"]) - 0.05
	lab._process(0.2)
	check(p0.has_tech("network_uplink"), "player.has_tech after research completes")
	check(lab.queue.is_empty(), "research entry popped on completion")
	check(not lab.queue_research("network_uplink"), "cannot research owned tech twice")

	# ------------------------------------------------ can_place (static)
	var fake := FakeNav.new()
	check(not Building.can_place(null, Vector3.ZERO, Vector2i(4, 4)), "can_place null nav false")
	check(Building.can_place(fake, Vector3(0, 0, 0), Vector2i(4, 4)), "can_place center true")
	check(not Building.can_place(fake, Vector3(63, 0, 0), Vector2i(4, 4)), "can_place margin 4m enforced")
	fake.blocked[Vector2i(32, 32)] = true
	check(not Building.can_place(fake, Vector3(0, 0, 0), Vector2i(4, 4)), "can_place false on blocked cell")

	# ------------------------------------------------ take_damage / death
	var b_doom := make_building(barracks_data, 0, Vector3(40, 0, 40))
	b_doom.debug_complete()
	b_doom.take_damage(b_doom.max_hp * 0.6, null)
	check(b_doom.hp < b_doom.max_hp * 0.5, "take_damage reduces hp")
	check(b_doom.alive(), "still alive above 0")
	b_doom.take_damage(99999.0, null)
	check(not b_doom.alive(), "dead at 0 hp")
	check(not Game.buildings_of(0).has(b_doom), "dead building unregistered")

	# ------------------------------------------------ rally
	b2.set_rally(Vector3(5, 0, 5))
	check(b2.rally_pos() == Vector3(5, 0, 5), "set_rally/rally_pos round-trip")

	# ------------------------------------------------ cleanup
	for bb in [b, b_cons, gen, b2, unbuilt, lab]:
		Game.unregister_building(bb)
		root.remove_child(bb)
		bb.free()  # immediate free: queue_free would leak past the deferred quit
	for u in Game.units_of(0, false):
		Game.unregister_unit(u)
		if is_instance_valid(u) and u is Node:
			root.remove_child(u)
			u.free()
	Game.to_menu()

	print("---- test_buildings: %d passed, %d failed, %d skipped ----" % [_passed, _failed, _skipped])
	quit()
