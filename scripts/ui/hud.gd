class_name Hud
extends CanvasLayer

## Resource bar, selection panel, command buttons, win/lose panels.

var game = null

var _res_label: Label
var _sel_label: Label
var _hint_label: Label
var _controls: TouchControls
var _train_btn: Button
var _train_kind := ""
var _train_building = null
var _end_panel: CenterContainer
var _end_title: Label
var _end_stats: Label

const BUILDING_NAMES := {"hq": "HQ", "barracks": "Barracks"}


func _ready() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 46
	add_child(top)
	_res_label = Label.new()
	_res_label.add_theme_font_size_override("font_size", 22)
	top.add_child(_res_label)

	var sel_panel := PanelContainer.new()
	sel_panel.anchor_left = 0.0
	sel_panel.anchor_right = 0.0
	sel_panel.anchor_top = 1.0
	sel_panel.anchor_bottom = 1.0
	sel_panel.offset_left = 16
	sel_panel.offset_top = -162
	sel_panel.offset_right = 372
	sel_panel.offset_bottom = -104
	add_child(sel_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sel_panel.add_child(sv)
	_sel_label = Label.new()
	_sel_label.add_theme_font_size_override("font_size", 20)
	sv.add_child(_sel_label)
	_train_btn = Button.new()
	_train_btn.custom_minimum_size = Vector2(320, 56)
	_train_btn.add_theme_font_size_override("font_size", 20)
	_train_btn.focus_mode = Control.FOCUS_NONE
	_train_btn.pressed.connect(_on_train_pressed)
	_train_btn.visible = false
	sv.add_child(_train_btn)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.offset_left = -500
	_hint_label.offset_right = 500
	_hint_label.offset_top = -140
	_hint_label.offset_bottom = -104
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 20)
	add_child(_hint_label)

	_controls = TouchControls.new()
	add_child(_controls)
	_controls.cmd_pressed.connect(_on_cmd)
	_controls.zoom_pressed.connect(_on_zoom)

	_end_panel = CenterContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_panel.visible = false
	add_child(_end_panel)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(500, 340)
	_end_panel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	_end_title = Label.new()
	_end_title.add_theme_font_size_override("font_size", 48)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)
	_end_stats = Label.new()
	_end_stats.add_theme_font_size_override("font_size", 22)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_stats)
	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(320, 64)
	again.add_theme_font_size_override("font_size", 24)
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(_on_play_again)
	v.add_child(again)
	var to_title := Button.new()
	to_title.text = "Back to Title"
	to_title.custom_minimum_size = Vector2(320, 64)
	to_title.add_theme_font_size_override("font_size", 24)
	to_title.focus_mode = Control.FOCUS_NONE
	to_title.pressed.connect(_on_back_to_title)
	v.add_child(to_title)


func update_hud() -> void:
	if game == null:
		return
	var mins := int(game.match_time) / 60
	var secs := int(game.match_time) % 60
	_res_label.text = "Supplies: %d   Cash: %d   Units: %d/%d   %02d:%02d" % [
		game.supplies, game.cash, game.unit_count(true), Balance.UNIT_CAP, mins, secs]

	var su: Array = game.selected_units()
	var sb = game.selected_building()
	if sb != null:
		var bname: String = BUILDING_NAMES.get(sb.kind, sb.kind)
		_sel_label.text = "%s  %d/%d HP" % [bname, sb.health.hp, sb.health.max_hp]
		_train_btn.visible = sb.constructed and sb.trains != ""
		if sb.constructed and sb.trains == "worker":
			_train_btn.text = "Train Worker (50S)"
			_train_kind = "worker"
			_train_building = sb
		elif sb.constructed and sb.trains == "soldier":
			_train_btn.text = "Train Soldier (75S 25C)"
			_train_kind = "soldier"
			_train_building = sb
		else:
			_train_kind = ""
			_train_building = null
	elif not su.is_empty():
		var workers := 0
		var soldiers := 0
		for u in su:
			if u.kind == "worker":
				workers += 1
			else:
				soldiers += 1
		var parts := []
		if workers > 0:
			parts.append("%dx Worker" % workers)
		if soldiers > 0:
			parts.append("%dx Soldier" % soldiers)
		_sel_label.text = "  ".join(parts)
		_train_btn.visible = false
	else:
		_sel_label.text = "Tap a unit or building"
		_train_btn.visible = false

	var has_worker := false
	for u in su:
		if u.kind == "worker":
			has_worker = true
	_controls.set_context(not su.is_empty(), has_worker)


func show_hint(t: String) -> void:
	_hint_label.text = t


func show_end(victory: bool, stats: String) -> void:
	_end_title.text = "VICTORY" if victory else "DEFEAT"
	_end_title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if victory else Color(0.95, 0.35, 0.3))
	_end_stats.text = stats
	_end_panel.visible = true


func hide_end() -> void:
	_end_panel.visible = false


func _on_cmd(cmd: String) -> void:
	if game == null:
		return
	if cmd == "stop":
		game.order_stop(game.selected_units())
		game.cancel_command()
	else:
		game.arm(cmd)


func _on_zoom(factor: float) -> void:
	if game != null and game.camera != null:
		game.camera.zoom_at(factor)


func _on_train_pressed() -> void:
	if game != null and _train_building != null and is_instance_valid(_train_building):
		game.train_unit(_train_building, _train_kind)


func _on_play_again() -> void:
	hide_end()
	if game != null:
		game.reset_match()


func _on_back_to_title() -> void:
	if game != null:
		game.exit_to_title.emit()
