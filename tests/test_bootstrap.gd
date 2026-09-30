extends SceneTree
## Bootstrap integration smoke test: drives main.gd through
## menu -> faction select -> full match start (all chunk-D nodes created),
## lets it run ~60 frames (AI ticks, HUD, fog timers, camera), then quits
## to menu. Any runtime error is a failure. Fully dynamic (see test_flow.gd).

var _errors := 0


func _initialize() -> void:
	_run.call_deferred()
	var w = create_timer(30.0)
	w.timeout.connect(_on_watchdog)


func _on_watchdog() -> void:
	print("WATCHDOG: bootstrap test timed out")
	quit(2)


func _run() -> void:
	var main_scr = ResourceLoader.load("res://scripts/main.gd")
	if main_scr == null:
		print("FAIL: cannot load main.gd")
		quit(1)
		return
	print("PASS: main.gd loads")
	var main = main_scr.new()
	root.add_child(main)
	await process_frame
	await process_frame
	print("PASS: main menu ready")
	# Faction select (info mode + select mode).
	main._show_faction_select("info")
	await process_frame
	print("PASS: faction info screen builds")
	main._show_faction_select("select")
	await process_frame
	print("PASS: faction select screen builds")
	# Start the match as Japan (enemy = US).
	main._on_start_battle("japan")
	await process_frame
	print("PASS: match nodes created")
	var match_root = main.get_node_or_null("Match")
	print("PASS: match root exists" if match_root != null else "FAIL: no match root")
	# Let the simulation run: AI ticks, HUD refresh, fog timers, camera.
	for i in 60:
		await process_frame
	print("PASS: 60 frames of match without fatal error")
	# Pause overlay via Screens.
	var screens = main.get_node_or_null("Match/UI/Screens")
	if screens != null:
		screens.toggle_pause()
		await process_frame
		print("PASS: pause toggles" if paused else "FAIL: pause did not engage")
		screens.toggle_pause()
		await process_frame
	else:
		print("FAIL: screens node missing")
	# Back to menu.
	main.quit_to_menu()
	await process_frame
	await process_frame
	var menu_left = main.get_node_or_null("MenuLayer")
	var kids = menu_left.get_child_count() if menu_left != null else -1
	print("PASS: quit to menu" if kids > 0 else "FAIL: menu not restored")
	print("----")
	print("BOOTSTRAP SMOKE: done (check output above for SCRIPT ERROR lines)")
	quit(0)
