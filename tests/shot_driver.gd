extends SceneTree
## Screenshot driver: boots the real main scene, then
## title -> faction select -> live match.
## Run under xvfb: godot --path . -s res://tests/shot_driver.gd


func _initialize() -> void:
	_run.call_deferred()


func _rt():
	return (Engine.get_main_loop() as SceneTree).root


func _snap(path: String) -> void:
	await process_frame
	await process_frame
	var img := _rt().get_texture().get_image()
	var err := img.save_png(path)
	print("SHOT ", path, " err=", err)


func _find_by_script(node: Node, fname: String) -> Node:
	if node == null:
		return null
	var s = node.get_script()
	if s != null and str(s.resource_path).ends_with(fname):
		return node
	for c in node.get_children():
		var f = _find_by_script(c, fname)
		if f != null:
			return f
	return null


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 60:
		await process_frame
	await _snap("/tmp/wc_title.png")
	var main = current_scene
	var menu = _find_by_script(main, "main_menu.gd")
	print("menu found: ", menu != null)
	if menu != null:
		menu.emit_signal("start_skirmish")
	for i in 40:
		await process_frame
	await _snap("/tmp/wc_factions.png")
	main = current_scene
	var fs = _find_by_script(main, "faction_select.gd")
	print("faction select found: ", fs != null)
	if fs != null:
		fs.emit_signal("start_battle", "us")
	for i in 240:
		await process_frame
	await _snap("/tmp/wc_game.png")
	print("SHOTS DONE")
	quit()
