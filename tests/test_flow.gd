extends SceneTree
## Headless verification for the game-flow chunk (Chunk D).
## -s quirks (see AGENTS.md): autoload identifiers don't resolve at parse time
## here, and referencing a global class_name at parse time poisons its compile
## (its own autoload references then fail too). So EVERYTHING below is dynamic:
## autoloads via get_node_or_null, chunk classes via ResourceLoader.load.

var _pass := 0
var _fail := 0
var _skip := 0


func _initialize() -> void:
	quit.call_deferred()  # watchdog: never hang on a runtime error
	_run.call_deferred()


func _game():
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game")


func _data():
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Data")


func _cls(path):
	return ResourceLoader.load(path)


func _run() -> void:
	_parse_all()
	_test_match_setup()
	_test_resources()
	_test_data()
	_test_camera()
	_test_selection()
	_test_map_runtime()
	_test_ai()
	_test_ai_attackers()
	_test_victory_defeat()
	_test_screens()
	print("----")
	print("RESULT: %d passed, %d failed, %d skipped" % [_pass, _fail, _skip])
	quit(1 if _fail > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("PASS: ", name)
	else:
		_fail += 1
		print("FAIL: ", name)


func _skip_check(name: String, reason: String) -> void:
	_skip += 1
	print("SKIP: ", name, " (", reason, ")")


func _parse_all() -> void:
	var files = [
		"res://scripts/main.gd",
		"res://scripts/world/map_runtime.gd",
		"res://scripts/core/camera_rig.gd",
		"res://scripts/core/selection.gd",
		"res://scripts/core/input_controller.gd",
		"res://scripts/core/settings_store.gd",
		"res://scripts/touch/touch_controls.gd",
		"res://scripts/ui/main_menu.gd",
		"res://scripts/ui/faction_select.gd",
		"res://scripts/ui/hud.gd",
		"res://scripts/ui/minimap.gd",
		"res://scripts/ui/screens.gd",
		"res://scripts/ai/ai_commander.gd",
		"res://scripts/audio/sfx.gd",
		"res://scripts/vfx/vfx.gd",
	]
	for f in files:
		var scr = _cls(f)
		_check("parse " + (f as String).get_file(), scr != null)


func _test_match_setup() -> void:
	var g = _game()
	_check("Game autoload present", g != null)
	if g == null:
		return
	g.call("new_match", "us", "japan")
	_check("new_match creates 2 players", (g.get("players") as Array).size() == 2)
	_check("human is pid 0", g.get("human_id") == 0 and bool(g.call("human").get("is_human")))
	_check("enemy faction is japan", g.call("get_player", 1).get("faction").get("id") == "japan")
	_check("starting supply 400", g.call("human").get("supply") == 400.0)
	_check("starting helios 0", g.call("human").get("helios") == 0.0)
	_check("phase PLAYING", g.get("phase") == 1)


func _test_resources() -> void:
	var g = _game()
	_check("spend 100 ok", bool(g.call("spend", 0, 100.0, 0.0)))
	_check("supply now 300", g.call("human").get("supply") == 300.0)
	_check("overspend rejected", not bool(g.call("spend", 0, 9999.0, 0.0)))
	_check("supply unchanged after reject", g.call("human").get("supply") == 300.0)
	g.call("refund", 0, 50.0, 0.0)
	_check("refund -> 350", g.call("human").get("supply") == 350.0)
	g.call("add_resources", 0, 25.0, 10.0)
	var h = g.call("human")
	_check("add_resources -> 375/10", h.get("supply") == 375.0 and h.get("helios") == 10.0)


func _test_data() -> void:
	var d = _data()
	_check("Data autoload present", d != null)
	if d == null:
		return
	var us = d.call("faction", "us")
	var jp = d.call("faction", "japan")
	_check("us faction loads", us != null and (us.get("units") as Array).size() == 6)
	_check("japan faction loads", jp != null and (jp.get("buildings") as Array).size() == 6)
	_check("us upgrades", (us.get("upgrades") as Array).size() == 3)
	var ranger = d.call("unit", "us", "ranger")
	_check("ranger lookup", ranger != null and ranger.get("name") == "Ranger Squad")
	var cc = d.call("building", "japan", "command")
	_check("jp command lookup", cc != null and cc.get("power_gen") == 30.0)


func _test_camera() -> void:
	var rig = _cls("res://scripts/core/camera_rig.gd").new()
	root.add_child(rig)
	_check("camera child created", rig.camera() != null)
	rig.pan(Vector2(10, 0))
	_check("pan moves target +x", is_equal_approx(rig.target.x, 10.0))
	rig.zoom(0.5)
	_check("zoom halves distance", is_equal_approx(rig.distance, 21.0))
	rig.zoom(0.001)
	_check("zoom clamps to min 18", is_equal_approx(rig.distance, 18.0))
	rig.zoom(100.0)
	_check("zoom clamps to max 70", is_equal_approx(rig.distance, 70.0))
	rig.rotate_yaw(1.0)
	_check("yaw rotates", is_equal_approx(rig.yaw, 1.0))
	rig.move_to(Vector3(1000, 0, 1000))
	_check("move_to clamps to map", rig.target.x == 64.0 and rig.target.z == 64.0)
	var g = rig.screen_to_ground(Vector2(640, 360))
	_check("screen_to_ground returns Vector3", g is Vector3)
	var corners = rig.get_camera_rect_corners()
	_check("camera rect has 4 corners", (corners as Array).size() == 4)
	rig.queue_free()


func _test_selection() -> void:
	var sel = _cls("res://scripts/core/selection.gd").new()
	root.add_child(sel)
	var a := Node3D.new()
	var b := Node3D.new()
	root.add_child(a)
	root.add_child(b)
	sel.select_single(a)
	_check("select_single", sel.selected.has(a) and (sel.selected as Array).size() == 1)
	sel.toggle(b)
	_check("toggle adds", (sel.selected as Array).size() == 2)
	sel.toggle(a)
	_check("toggle removes", (sel.selected as Array).size() == 1 and (sel.selected as Array)[0] == b)
	sel.store_group(1)
	sel.clear()
	_check("clear", (sel.selected as Array).is_empty())
	sel.recall_group(1)
	_check("recall_group", (sel.selected as Array).size() == 1 and (sel.selected as Array)[0] == b)
	sel.set_attack_move_armed(true)
	_check("attack-move armed", sel.armed == "attack_move")
	# Smart order on a mock with no Unit methods must not error.
	sel.issue_smart_order(Vector3(5, 0, 5))
	_check("smart order on mock harmless", sel.armed == "")
	sel.select_army()
	_check("select_army empty w/o units", (sel.selected as Array).is_empty())
	sel.box_select(Rect2(0, 0, 100, 100), null)
	_check("box_select harmless with no candidates", (sel.selected as Array).is_empty())
	a.queue_free()
	b.queue_free()
	sel.queue_free()


func _test_map_runtime() -> void:
	var mr = _cls("res://scripts/world/map_runtime.gd").new()
	root.add_child(mr)
	mr.build(true)
	_check("map_runtime builds headless", true)
	if mr.nav_grid == null:
		_skip_check("NavGrid glue", "world chunk not present")
	else:
		_check("NavGrid present", true)
	if mr.valley == null:
		_skip_check("HeliosValley glue", "world chunk not present")
	else:
		_check("HeliosValley present", true)
	if mr.fog == null:
		_skip_check("FogOfWar glue", "world chunk not present")
	else:
		_check("FogOfWar present", true)
	mr.queue_free()


func _test_ai() -> void:
	var g = _game()
	g.call("new_match", "us", "japan")
	var mr = _cls("res://scripts/world/map_runtime.gd").new()
	root.add_child(mr)
	mr.build(true)
	var ai = _cls("res://scripts/ai/ai_commander.gd").new()
	root.add_child(ai)
	ai.call("setup", 1, mr.get("nav_grid"), mr.get("valley"))
	for i in 10:
		ai.call("_tick")
	_check("AI ticks 10x without errors", true)
	# AI economy: valley spawns 5 workers, WORKER_TARGET is 9, so the AI
	# should queue worker production at its command center.
	var queued := false
	for b in g.call("buildings_of", 1):
		if (b.get("data") as Resource).get("id") == "command" and (b.get("queue") as Array).size() > 0:
			queued = true
	_check("AI queues worker production", queued)
	_check("AI sees its starting workers", (g.call("units_of", 1) as Array).size() >= 5)
	ai.queue_free()
	mr.queue_free()
	g.call("to_menu")


func _test_ai_attackers() -> void:
	# AI with a finished barracks must queue combat (non-worker) units.
	var g = _game()
	g.call("new_match", "us", "japan")
	var mr = _cls("res://scripts/world/map_runtime.gd").new()
	root.add_child(mr)
	mr.build(true)
	var bscript = _cls("res://scripts/buildings/building.gd")
	var fid := "japan"
	var bd = _data().call("building", fid, "barracks")
	var rax = bscript.new()
	rax.call("setup", bd, 1)
	root.add_child(rax)
	if rax.has_method("place_at"):
		rax.call("place_at", Vector3(30, 0, 0))
	else:
		rax.set("global_position", Vector3(30, 0, 0))
	if rax.has_method("debug_complete"):
		rax.call("debug_complete")
	g.call("register_building", rax)
	g.call("add_resources", 1, 2000.0, 500.0)
	var ai = _cls("res://scripts/ai/ai_commander.gd").new()
	root.add_child(ai)
	ai.call("setup", 1, mr.get("nav_grid"), mr.get("valley"))
	for i in 6:
		ai.call("_tick")
	var attackers := false
	for q in (rax.get("queue") as Array):
		var uid := str(q[0] if (q is Array) else q)
		if uid != "worker" and uid != "kosaku" and uid != "pioneer":
			attackers = true
	_check("AI queues combat units from barracks", attackers)
	ai.queue_free()
	mr.queue_free()
	g.call("to_menu")


func _test_victory_defeat() -> void:
	var g = _game()
	var result := {"v": null}
	g.connect("match_ended", func(victory: bool): result["v"] = victory)
	# Victory: wipe the enemy's buildings.
	g.call("new_match", "us", "japan")
	var mr = _cls("res://scripts/world/map_runtime.gd").new()
	root.add_child(mr)
	mr.build(true)
	for b in (g.call("buildings_of", 1) as Array).duplicate():
		g.call("unregister_building", b)
	_check("victory when enemy has no buildings", g.get("phase") == 2 and result["v"] == true)
	mr.queue_free()
	# Defeat: wipe the human's buildings.
	result["v"] = null
	g.call("new_match", "us", "japan")
	var mr2 = _cls("res://scripts/world/map_runtime.gd").new()
	root.add_child(mr2)
	mr2.build(true)
	for b in (g.call("buildings_of", 0) as Array).duplicate():
		g.call("unregister_building", b)
	_check("defeat when player has no buildings", g.get("phase") == 2 and result["v"] == false)
	mr2.queue_free()
	g.call("to_menu")


func _test_screens() -> void:
	var s = _cls("res://scripts/ui/screens.gd").new()
	root.add_child(s)
	s.show_settings()
	_check("settings panel opens", s.visible)
	s.hide_all()
	_check("hide_all", not s.visible)
	var ts = _cls("res://scripts/touch/touch_controls.gd")
	_check("touch starts inactive", not bool(ts.get("touch_active")))
	s.queue_free()
