extends SceneTree

## Headless verification for the WORLD chunk:
## NavGrid, ResourceNode, FogOfWar, HeliosValley (+ terrain + minimap).
## Run: godot --headless --path ~/workspace/world-command -s tests/test_world.gd
##
## NOTE: in `-s` mode the main script is compiled before autoload globals and
## global class_names are usable, so EVERYTHING here is loaded dynamically
## (ResourceLoader + untyped vars + dynamic dispatch). Library code itself is
## untouched and uses the normal Game/Data autoload identifiers.

class FakeUnit extends Node3D:
	var player_id := 0
	var _alive := true
	var _sight := 14.0

	func alive() -> bool:
		return _alive

	func sight_range() -> float:
		return _sight


var _passes := 0
var _failures := 0
var _game = null
var _data = null
var _scripts := {}


func _init() -> void:
	# Watchdog: a runtime error aborts the current function, which would skip
	# the trailing quit() and hang the process forever. This fires first.
	quit.call_deferred()
	process_frame.connect(_run_once)


func _load_scripts() -> void:
	_scripts["nav"] = ResourceLoader.load("res://scripts/navigation/nav_grid.gd")
	_scripts["res"] = ResourceLoader.load("res://scripts/world/resource_node.gd")
	_scripts["fow"] = ResourceLoader.load("res://scripts/core/fog_of_war.gd")
	_scripts["valley"] = ResourceLoader.load("res://scripts/world/helios_valley.gd")


func _ensure_autoloads() -> void:
	var ml := Engine.get_main_loop() as SceneTree
	for spec in [["res://scripts/autoload/game.gd", "Game"], ["res://scripts/autoload/data.gd", "Data"]]:
		if ml.root.get_node_or_null(spec[1]) == null:
			var s = ResourceLoader.load(spec[0]) as GDScript
			if s != null:
				var n = s.new()
				n.name = spec[1]
				ml.root.add_child(n)
	_game = ml.root.get_node_or_null("Game")
	_data = ml.root.get_node_or_null("Data")


func _run_once() -> void:
	process_frame.disconnect(_run_once)
	_load_scripts()
	_ensure_autoloads()
	_check(_scripts["nav"] != null and _scripts["res"] != null and _scripts["fow"] != null and _scripts["valley"] != null,
		"all WORLD scripts load")
	_check(_data != null and _data.faction("us") != null and _data.faction("japan") != null,
		"Data autoload factions built")
	print("== NavGrid ==")
	_test_nav()
	print("== ResourceNode ==")
	_test_resource_node()
	print("== FogOfWar ==")
	_test_fog()
	print("== HeliosValley ==")
	_test_valley()
	print("world tests: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if cond:
		_passes += 1
		print("  PASS ", name)
	else:
		_failures += 1
		print("  FAIL ", name)


# ------------------------------------------------------------------ NavGrid
func _test_nav() -> void:
	var nav = _scripts["nav"].new()
	nav.setup()
	_check(nav.world_to_cell(Vector3(-64, 0, -64)) == Vector2i(0, 0), "world_to_cell corner")
	_check(nav.world_to_cell(Vector3(0, 0, 0)) == Vector2i(32, 32), "world_to_cell origin")
	_check(nav.world_to_cell(Vector3(63.9, 0, 63.9)) == Vector2i(63, 63), "world_to_cell max clamps")
	var c := Vector2i(17, 42)
	_check(nav.world_to_cell(nav.cell_to_world(c)) == c, "cell roundtrip")
	var cw = nav.cell_to_world(c)
	_check(absf(cw.y) < 0.001, "cell_to_world y=0")
	_check(nav.clamp_to_map(Vector3(500, 0, -500)) == Vector3(63.5, 0, -63.5), "clamp_to_map")
	_check(nav.is_cell_walkable(Vector2i(32, 32)), "default walkable")
	_check(not nav.is_cell_walkable(Vector2i(-1, 0)), "out of bounds not walkable")

	# Wall with a forced detour: 10x2 blocked rect across z~=10.
	nav.set_blocked_rect(Vector3(0, 0, 10), Vector2i(10, 2), true)
	_check(not nav.is_cell_walkable(nav.world_to_cell(Vector3(0, 0, 10))), "blocked rect blocks")
	var path = nav.find_path(Vector3(0, 0, -6), Vector3(0, 0, 26))
	_check(not path.is_empty(), "path around wall non-empty")
	var all_walkable := true
	for wp in path:
		if not nav.is_cell_walkable(nav.world_to_cell(wp)):
			all_walkable = false
		if absf(wp.y) > 0.001:
			all_walkable = false
	_check(all_walkable, "path waypoints walkable, y=0")
	_check(path.size() > 2, "detour needs >2 waypoints (got %d)" % path.size())
	_check(path[path.size() - 1].distance_to(Vector3(0, 0, 26)) < 6.0, "path ends near goal")

	# Unblock and go straight through.
	nav.set_blocked_rect(Vector3(0, 0, 10), Vector2i(10, 2), false)
	_check(nav.is_cell_walkable(nav.world_to_cell(Vector3(0, 0, 10))), "unblock works")
	var straight = nav.find_path(Vector3(0, 0, -6), Vector3(0, 0, 26))
	_check(not straight.is_empty() and straight.size() <= 3, "straight path is short (got %d)" % straight.size())

	# Blocked endpoint falls back to nearest walkable cell.
	nav.set_blocked_rect(Vector3(30, 0, 30), Vector2i(3, 3), true)
	var fb = nav.find_path(Vector3(0, 0, 0), Vector3(30, 0, 30))
	_check(not fb.is_empty(), "blocked endpoint falls back, path non-empty")
	_check(nav.is_cell_walkable(nav.world_to_cell(fb[fb.size() - 1])), "fallback endpoint is walkable")
	_check(fb[fb.size() - 1].distance_to(Vector3(30, 0, 30)) < 10.0, "fallback endpoint near goal")

	# Same cell -> empty (already there).
	_check(nav.find_path(Vector3(5, 0, 5), Vector3(5.5, 0, 5.5)).is_empty(), "same-cell path empty")

	# Fully blocked map -> unreachable -> empty.
	nav.set_blocked_rect(Vector3(0, 0, 0), Vector2i(64, 64), true)
	_check(nav.find_path(Vector3(-60, 0, -60), Vector3(60, 0, 60)).is_empty(), "unreachable returns empty")


# ------------------------------------------------------------------ ResourceNode
func _test_resource_node() -> void:
	var ml := Engine.get_main_loop() as SceneTree
	var n = _scripts["res"].new()
	ml.root.add_child(n)
	n.setup("supply")
	_check(n.kind == "supply" and n.amount == 1500.0, "supply node 1500")
	_check(n.get_child_count() > 0, "fallback model built (glb missing)")
	var got = n.harvest(100.0)
	_check(got == 100.0 and n.amount == 1400.0, "harvest deducts partial")
	var fired := []
	n.depleted.connect(func(node): fired.append(node))
	got = n.harvest(5000.0)
	_check(got == 1400.0, "over-harvest returns remainder")
	_check(fired.size() == 1 and fired[0] == n, "depleted emitted")
	_check(n.is_queued_for_deletion(), "node queued free at 0")
	_check(n.harvest(10.0) == 0.0, "harvest on empty returns 0")

	var h = _scripts["res"].new()
	ml.root.add_child(h)
	h.setup("helios")
	_check(h.kind == "helios" and h.amount == 800.0, "helios node 800")
	_check(h.get_child_count() > 0, "helios fallback model built")


# ------------------------------------------------------------------ FogOfWar
func _test_fog() -> void:
	var ml := Engine.get_main_loop() as SceneTree
	var nav = _scripts["nav"].new()
	nav.setup()
	var fog = _scripts["fow"].new()
	ml.root.add_child(fog)
	fog.setup(nav)
	_check(not fog.is_visible_at(Vector3.ZERO), "initially not visible")
	_check(not fog.is_explored_at(Vector3.ZERO), "initially not explored")

	var u := FakeUnit.new()
	u.player_id = 0
	u._sight = 14.0
	ml.root.add_child(u)
	u.global_position = Vector3.ZERO
	var enemy := FakeUnit.new()
	enemy.player_id = 1
	ml.root.add_child(enemy)
	enemy.global_position = Vector3(40, 0, 40)

	fog.reveal([u, enemy])
	_check(fog.is_visible_at(Vector3.ZERO), "human unit reveals origin")
	_check(fog.is_explored_at(Vector3.ZERO), "revealed cell explored")
	_check(not fog.is_visible_at(Vector3(40, 0, 40)), "enemy unit does not reveal")
	_check(not fog.is_visible_at(Vector3(60, 0, 60)), "far cell stays hidden")
	_check(fog.is_visible_at(Vector3(10, 0, 0)), "inside 14m sight visible")
	_check(not fog.is_visible_at(Vector3(20, 0, 0)), "outside 14m sight hidden")

	fog.reveal([])
	_check(not fog.is_visible_at(Vector3.ZERO), "visible decays when unit leaves")
	_check(fog.is_explored_at(Vector3.ZERO), "explored persists after decay")

	var tex = fog.get_texture()
	_check(tex != null and tex.get_size() == Vector2(64, 64), "R8 texture 64x64")


# ------------------------------------------------------------------ HeliosValley
func _test_valley() -> void:
	var ml := Engine.get_main_loop() as SceneTree
	var bscript = ResourceLoader.load("res://scripts/buildings/building.gd")
	var uscript = ResourceLoader.load("res://scripts/units/unit.gd")
	var have_actors := bscript != null and uscript != null
	if not have_actors:
		print("  SKIP building/unit placement: Building/Unit scripts not loadable yet (Chunk B/C).")

	var nav = _scripts["nav"].new()
	nav.setup()
	var fog = _scripts["fow"].new()
	ml.root.add_child(fog)
	fog.setup(nav)
	var valley = _scripts["valley"].new()
	ml.root.add_child(valley)
	valley.build(nav, fog)

	# Resource census: 7 central helios + 5 supply x2 bases + 4 expansions x(3+2).
	var nodes = valley.resource_nodes
	_check(nodes.size() == 37, "37 resource nodes (got %d)" % nodes.size())
	var helios := 0
	var supply := 0
	var nodes_ok := true
	for rn in nodes:
		if rn.kind == "helios":
			helios += 1
			if rn.amount != 800.0:
				nodes_ok = false
		elif rn.kind == "supply":
			supply += 1
			if rn.amount != 1500.0:
				nodes_ok = false
		else:
			nodes_ok = false
		var p = rn.global_position
		if absf(p.x) > 64.0 or absf(p.z) > 64.0 or absf(p.y) > 0.001:
			nodes_ok = false
		if not nav.is_cell_walkable(nav.world_to_cell(p)):
			nodes_ok = false
	_check(helios == 15 and supply == 22, "15 helios + 22 supply (got %d/%d)" % [helios, supply])
	_check(nodes_ok, "node amounts, bounds, walkable cells")

	# Bases.
	_check(valley.base_center(0) == Vector3(-44, 0, 0), "base_center(0) west")
	_check(valley.base_center(1) == Vector3(44, 0, 0), "base_center(1) east")
	_check(valley.spawn_pos(0) == Vector3(-44, 0, 12), "spawn_pos(0)")

	# Terrain mesh.
	var terrain = valley.get_node_or_null("Terrain")
	_check(terrain != null and terrain.mesh != null, "terrain mesh built")
	var terrain_mat = terrain.material_override if terrain != null else null
	_check(terrain_mat != null and terrain_mat.shader != null, "terrain uses fow.gdshader")
	var vert_count := 0
	if terrain != null and terrain.mesh != null:
		vert_count = (terrain.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	_check(vert_count == 129 * 129, "terrain 129x129 verts (got %d)" % vert_count)

	# Minimap.
	var mini = valley.get_minimap_image()
	_check(mini != null and mini.get_size() == Vector2(128, 128), "minimap 128x128")

	# Landmark blocks 6x4, expansions stay walkable, trees/rocks block cells.
	_check(not nav.is_cell_walkable(nav.world_to_cell(Vector3(0, 0, -25))), "facility blocks nav")
	_check(nav.is_cell_walkable(nav.world_to_cell(Vector3(-20, 0, -35))), "expansion site walkable")
	var blocked_cells := 0
	for y in range(64):
		for x in range(64):
			if not nav.is_cell_walkable(Vector2i(x, y)):
				blocked_cells += 1
	_check(blocked_cells > 60, "props block a sane number of cells (got %d)" % blocked_cells)

	# Base -> center path exists (road not blocked).
	var p2 = nav.find_path(valley.spawn_pos(0), Vector3(0, 0, 0))
	_check(not p2.is_empty(), "path from base to center exists")

	if have_actors:
		_check(not nav.is_cell_walkable(nav.world_to_cell(Vector3(-44, 0, 0))), "CC footprint blocks nav")
		_check(_game.buildings_of(0).size() >= 1, "CC registered for pid 0")
		_check(_game.buildings_of(1).size() >= 1, "CC registered for pid 1")
		_check(_game.units_of(0).size() == 5, "5 workers pid 0 (got %d)" % _game.units_of(0).size())
		_check(_game.units_of(1).size() == 5, "5 workers pid 1 (got %d)" % _game.units_of(1).size())
	else:
		print("  SKIP Game registry checks: actors not placed.")

	# Depleted-signal integration on a live valley node.
	var rn0 = nodes[0]
	var fired2 := []
	rn0.depleted.connect(func(node): fired2.append(node))
	var total = rn0.amount
	var got2 = rn0.harvest(total + 100.0)
	_check(got2 == total and fired2.size() == 1, "valley node depletes via harvest")
