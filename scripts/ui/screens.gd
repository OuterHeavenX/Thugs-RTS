class_name Screens
extends Control
## Full-screen overlays: victory/defeat, pause, settings, credits.
## Tracks match stats (kills/losses) from Game signals.

signal rematch_requested
signal menu_requested

const Settings := preload("res://scripts/core/settings_store.gd")

var _overlay: ColorRect
var _panel: PanelContainer
var _panel_box: VBoxContainer

var _kills := 0
var _losses := 0
var _end_shown := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Explicit anchors, not set_anchors_preset (see main_menu.gd note).
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.72)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.98)
	sb.border_color = Color(0.3, 0.55, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_panel_box)
	Game.match_started.connect(_on_match_started)
	Game.unit_died.connect(_on_unit_died)
	Game.match_ended.connect(_on_match_ended)


func _on_match_started() -> void:
	_kills = 0
	_losses = 0
	_end_shown = false
	hide_all()


func _on_unit_died(unit) -> void:
	if Game.phase != Game.Phase.PLAYING:
		return
	if unit == null:
		return
	var pid := -1
	if "player_id" in unit:
		pid = int(unit.get("player_id"))
	if pid == Game.human_id:
		_losses += 1
	elif pid >= 0:
		_kills += 1


func _on_match_ended(victory: bool) -> void:
	if _end_shown:
		return
	_end_shown = true
	get_tree().paused = true
	var stats := {
		"time": Game.time,
		"kills": _kills,
		"losses": _losses,
	}
	if victory:
		SFX.play("victory")
		show_victory(stats)
	else:
		SFX.play("defeat")
		show_defeat(stats)


# ------------------------------------------------------------------ show
func _show_base() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = true
	_panel.visible = true
	for c in _panel_box.get_children():
		c.queue_free()


func hide_all() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_panel.visible = false
	if Game.phase == Game.Phase.PLAYING and not _end_shown:
		get_tree().paused = false


func _title(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.12, 0.17, 0.95)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.2, 0.28, 0.97)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _stats_lines(stats: Dictionary) -> Label:
	var t := int(stats.get("time", 0.0))
	var l := Label.new()
	l.text = "Time  %02d:%02d\nEnemy units destroyed  %d\nUnits lost  %d" % [
		t / 60, t % 60, int(stats.get("kills", 0)), int(stats.get("losses", 0))]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	return l


func show_victory(stats: Dictionary) -> void:
	_show_base()
	_panel_box.add_child(_title("VICTORY", Color(0.45, 0.95, 0.55)))
	_panel_box.add_child(_stats_lines(stats))
	var rm := _button("REMATCH", Color(0.4, 0.85, 0.5))
	rm.pressed.connect(func(): rematch_requested.emit())
	_panel_box.add_child(rm)
	var mm := _button("MAIN MENU", Color(0.5, 0.65, 0.85))
	mm.pressed.connect(func(): menu_requested.emit())
	_panel_box.add_child(mm)


func show_defeat(stats: Dictionary) -> void:
	_show_base()
	_panel_box.add_child(_title("DEFEAT", Color(0.95, 0.4, 0.35)))
	_panel_box.add_child(_stats_lines(stats))
	var rm := _button("REMATCH", Color(0.4, 0.85, 0.5))
	rm.pressed.connect(func(): rematch_requested.emit())
	_panel_box.add_child(rm)
	var mm := _button("MAIN MENU", Color(0.5, 0.65, 0.85))
	mm.pressed.connect(func(): menu_requested.emit())
	_panel_box.add_child(mm)


func toggle_pause() -> void:
	if Game.phase != Game.Phase.PLAYING or _end_shown:
		return
	if get_tree().paused:
		hide_all()
	else:
		show_pause()


func show_pause() -> void:
	_show_base()
	get_tree().paused = true
	_panel_box.add_child(_title("PAUSED", Color(0.85, 0.9, 1.0)))
	var rs := _button("RESUME", Color(0.4, 0.85, 0.5))
	rs.pressed.connect(hide_all)
	_panel_box.add_child(rs)
	var st := _button("SETTINGS", Color(0.5, 0.65, 0.85))
	st.pressed.connect(show_settings)
	_panel_box.add_child(st)
	var qt := _button("QUIT TO MENU", Color(0.9, 0.45, 0.4))
	qt.pressed.connect(func(): menu_requested.emit())
	_panel_box.add_child(qt)


# --------------------------------------------------------------- settings
func show_settings() -> void:
	_show_base()
	_panel_box.add_child(_title("SETTINGS", Color(0.85, 0.9, 1.0)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	_panel_box.add_child(grid)

	grid.add_child(_slabel("Graphics"))
	var gfx := OptionButton.new()
	gfx.add_item("Low", 0)
	gfx.add_item("Medium", 1)
	gfx.add_item("High", 2)
	gfx.selected = int(Settings.get_setting("graphics", 1))
	gfx.custom_minimum_size = Vector2(220, 48)
	gfx.item_selected.connect(func(i): Settings.set_setting("graphics", i); apply_graphics())
	grid.add_child(gfx)

	grid.add_child(_slabel("Music"))
	var mus := CheckButton.new()
	mus.button_pressed = bool(Settings.get_setting("music", true))
	mus.toggled.connect(func(on): SFX.set_volumes(on, SFX.sfx_enabled()))
	grid.add_child(mus)

	grid.add_child(_slabel("Sound FX"))
	var sfxb := CheckButton.new()
	sfxb.button_pressed = bool(Settings.get_setting("sfx", true))
	sfxb.toggled.connect(func(on): SFX.set_volumes(SFX.music_enabled(), on))
	grid.add_child(sfxb)

	grid.add_child(_slabel("Edge pan"))
	var edge := CheckButton.new()
	edge.button_pressed = bool(Settings.get_setting("edge_pan", true))
	edge.toggled.connect(func(on): Settings.set_setting("edge_pan", on))
	grid.add_child(edge)

	var back := _button("BACK", Color(0.5, 0.65, 0.85))
	back.pressed.connect(_back_from_sub)
	_panel_box.add_child(back)
	_panel_box.set_meta("return_to", "pause" if Game.phase == Game.Phase.PLAYING else "menu")


func _back_from_sub() -> void:
	if _panel_box.get_meta("return_to", "menu") == "pause" and Game.phase == Game.Phase.PLAYING:
		show_pause()
	else:
		# From the main menu the menu itself was freed when this screen
		# opened — ask the host to rebuild it instead of blanking out.
		menu_requested.emit()


func _slabel(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	return l


func apply_graphics() -> void:
	var g := int(Settings.get_setting("graphics", 1))
	var tree := get_tree()
	if tree != null:
		match g:
			0:
				tree.root.msaa_3d = Viewport.MSAA_DISABLED
			1:
				tree.root.msaa_3d = Viewport.MSAA_2X
			_:
				tree.root.msaa_3d = Viewport.MSAA_4X
		for sun in tree.get_nodes_in_group("sun_light"):
			if sun is DirectionalLight3D:
				sun.shadow_enabled = g >= 1
	VFX.set_quality(g)


# ---------------------------------------------------------------- credits
func show_credits() -> void:
	_show_base()
	_panel_box.add_child(_title("CREDITS", Color(0.85, 0.9, 1.0)))
	var l := Label.new()
	l.text = "WORLD COMMAND v0.1.0\n\nA Venom Works production.\n\nDesign, code, art, and audio\ncreated original in-house\nfor this game.\n\nNo third-party assets.\nNo engine branding.\n\nThanks for playing, Commander."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	_panel_box.add_child(l)
	var back := _button("BACK", Color(0.5, 0.65, 0.85))
	back.pressed.connect(_back_from_sub)
	_panel_box.add_child(back)
	_panel_box.set_meta("return_to", "menu")


func show_campaign() -> void:
	_show_base()
	_panel_box.add_child(_title("CAMPAIGN", Color(0.85, 0.9, 1.0)))
	var soon := Label.new()
	soon.text = "COMING SOON"
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.add_theme_font_size_override("font_size", 30)
	soon.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	_panel_box.add_child(soon)
	var l := Label.new()
	l.text = "The single-player campaign is still in development.\nSkirmish against the AI is fully playable right now."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	_panel_box.add_child(l)
	var back := _button("BACK", Color(0.5, 0.65, 0.85))
	back.pressed.connect(_back_from_sub)
	_panel_box.add_child(back)
	_panel_box.set_meta("return_to", "menu")


func show_tech() -> void:
	_show_base()
	_panel_box.add_child(_title("TECH DATABASE", Color(0.85, 0.9, 1.0)))
	for fid in ["us", "japan"]:
		var f: FactionData = Data.faction(fid)
		if f == null:
			continue
		var fh := Label.new()
		fh.text = f.name.to_upper()
		fh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fh.add_theme_font_size_override("font_size", 26)
		fh.add_theme_color_override("font_color", f.accent)
		_panel_box.add_child(fh)
		for u in f.upgrades:
			var uh := Label.new()
			uh.text = "%s  (%d SUP / %d HEL)" % [u.name, int(u.cost_supply), int(u.cost_helios)]
			uh.add_theme_font_size_override("font_size", 20)
			uh.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
			_panel_box.add_child(uh)
			var ud := Label.new()
			ud.text = u.desc
			ud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ud.custom_minimum_size = Vector2(560, 0)
			ud.add_theme_font_size_override("font_size", 17)
			ud.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
			_panel_box.add_child(ud)
	var back := _button("BACK", Color(0.5, 0.65, 0.85))
	back.pressed.connect(_back_from_sub)
	_panel_box.add_child(back)
	_panel_box.set_meta("return_to", "menu")


func show_farewell() -> void:
	_show_base()
	_panel_box.add_child(_title("WORLD COMMAND", Color(0.85, 0.9, 1.0)))
	var l := Label.new()
	l.text = "Thanks for playing, Commander.\nYou can close this tab whenever you're ready."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	_panel_box.add_child(l)
	var back := _button("BACK TO TITLE", Color(0.5, 0.65, 0.85))
	back.pressed.connect(_back_from_sub)
	_panel_box.add_child(back)
	_panel_box.set_meta("return_to", "menu")
