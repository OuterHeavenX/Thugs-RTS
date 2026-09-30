extends Node
## WORLD COMMAND bootstrap. Owns the screen flow:
## MainMenu -> FactionSelect -> Match (MapRuntime + Camera + Selection +
## Input + Touch + HUD + Minimap + AI) -> Victory/Defeat/Pause overlays.

const Settings := preload("res://scripts/core/settings_store.gd")
const InputCtrl := preload("res://scripts/core/input_controller.gd")

var _menu_layer: CanvasLayer
var _match_root: Node = null

var _human_faction := "us"
var _enemy_faction := "japan"


func _ready() -> void:
	_apply_startup_settings()
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	add_child(_menu_layer)
	_show_menu()


func _apply_startup_settings() -> void:
	var g := int(Settings.get_setting("graphics", 1))
	var vp := get_viewport()
	if vp != null:
		match g:
			0:
				vp.msaa_3d = Viewport.MSAA_DISABLED
			1:
				vp.msaa_3d = Viewport.MSAA_2X
			_:
				vp.msaa_3d = Viewport.MSAA_4X
	VFX.set_quality(g)
	SFX.set_volumes(bool(Settings.get_setting("music", true)),
		bool(Settings.get_setting("sfx", true)))


func _clear_menu() -> void:
	for c in _menu_layer.get_children():
		c.queue_free()


# ------------------------------------------------------------------- menu
func _show_menu() -> void:
	_clear_menu()
	get_tree().paused = false
	var menu := MainMenu.new()
	_menu_layer.add_child(menu)
	menu.start_skirmish.connect(_show_faction_select.bind("select"))
	menu.show_campaign.connect(_show_menu_screens.bind("campaign"))
	menu.show_factions.connect(_show_faction_select.bind("info"))
	menu.show_tech.connect(_show_menu_screens.bind("tech"))
	menu.show_settings.connect(_show_menu_screens.bind("settings"))
	menu.show_credits.connect(_show_menu_screens.bind("credits"))
	menu.exit_game.connect(_on_exit_game)


func _on_exit_game() -> void:
	# Browser-appropriate exit: the engine cannot close the tab, so show a
	# farewell overlay instead. Desktop builds quit outright.
	if OS.has_feature("web"):
		_show_menu_screens("farewell")
	else:
		get_tree().quit()


func _show_menu_screens(which: String) -> void:
	_clear_menu()
	var s := Screens.new()
	_menu_layer.add_child(s)
	# BACK from a menu sub-screen rebuilds the main menu (it was freed).
	s.menu_requested.connect(_show_menu)
	match which:
		"settings":
			s.show_settings()
		"campaign":
			s.show_campaign()
		"tech":
			s.show_tech()
		"farewell":
			s.show_farewell()
		_:
			s.show_credits()
	# Back returns to the menu (Screens handles it via return_to=menu).


func _show_faction_select(mode: String) -> void:
	_clear_menu()
	var fs := FactionSelect.new()
	fs.mode = mode
	_menu_layer.add_child(fs)
	fs.start_battle.connect(_on_start_battle)
	fs.back_pressed.connect(_show_menu)


func _on_start_battle(human_faction: String) -> void:
	_human_faction = human_faction
	_enemy_faction = "japan" if human_faction == "us" else "us"
	_start_match()


# ------------------------------------------------------------------ match
func _start_match() -> void:
	_clear_menu()
	Game.new_match(_human_faction, _enemy_faction)

	_match_root = Node.new()
	_match_root.name = "Match"
	add_child(_match_root)

	var map_runtime := MapRuntime.new()
	map_runtime.name = "MapRuntime"
	_match_root.add_child(map_runtime)
	map_runtime.build(DisplayServer.get_name() == "headless")

	var cam := CameraRig.new()
	cam.name = "CameraRig"
	_match_root.add_child(cam)
	cam.center_on(_home_position(map_runtime))

	var sel := Selection.new()
	sel.name = "Selection"
	_match_root.add_child(sel)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	_match_root.add_child(ui)

	var hud := HUD.new()
	hud.name = "HUD"
	hud.setup(cam, sel, map_runtime, map_runtime)
	var touch := TouchControls.new()
	touch.name = "Touch"
	touch.setup(cam, sel, hud)
	var screens := Screens.new()
	screens.name = "Screens"
	ui.add_child(touch)
	ui.add_child(hud)
	ui.add_child(screens)
	hud.minimap.setup(map_runtime.valley, map_runtime.fog, cam)
	hud.menu_requested.connect(screens.toggle_pause)
	screens.rematch_requested.connect(_on_rematch)
	screens.menu_requested.connect(quit_to_menu)
	screens.apply_graphics()

	var input = InputCtrl.new()
	input.name = "Input"
	input.setup(cam, sel, hud, screens)
	_match_root.add_child(input)

	var ai := AICommander.new()
	ai.name = "AI"
	ai.setup(1, map_runtime.nav_grid, map_runtime.valley)
	_match_root.add_child(ai)

	hud.alert("Command established. Build your base, Commander.", Color(0.5, 0.85, 1.0))


func _home_position(map_runtime: MapRuntime) -> Vector3:
	var v = map_runtime.valley
	if v != null:
		if v.has_method("spawn_pos"):
			var p = v.call("spawn_pos", Game.human_id)
			if p is Vector3:
				return p
		if v.has_method("base_center"):
			var p2 = v.call("base_center", Game.human_id)
			if p2 is Vector3:
				return p2
	return Vector3.ZERO


func _on_rematch() -> void:
	quit_to_menu()
	_start_match()


func quit_to_menu() -> void:
	get_tree().paused = false
	if _match_root != null:
		_match_root.queue_free()
		_match_root = null
	TouchControls.touch_active = false
	Game.to_menu()
	_show_menu()
