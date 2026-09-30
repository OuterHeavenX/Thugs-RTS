class_name MainMenu
extends Control
## Title screen: procedural animated backdrop (drifting starfield + tactical
## grid), big title, menu buttons. No engine branding.

signal start_skirmish
signal show_campaign
signal show_factions
signal show_tech
signal show_settings
signal show_credits
signal exit_game

var _stars: Array = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Explicit anchors, not set_anchors_preset: called after entering the tree
	# at size 0, the preset "preserves" the zero size via negative offsets and
	# the menu renders off-screen.
	anchor_right = 1.0
	anchor_bottom = 1.0
	_rng.seed = 1337
	for i in 140:
		_stars.append({
			"p": Vector2(_rng.randf(), _rng.randf()),
			"s": _rng.randf_range(0.6, 2.2),
			"v": _rng.randf_range(2.0, 10.0),
		})
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "WORLD COMMAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.5, 0.8, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(0.25, 0.6, 0.9, 0.7)
	rule.custom_minimum_size = Vector2(420, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(rule)

	var sub := Label.new()
	sub.text = "NEAR-FUTURE THEATER COMMAND  •  v0.1.0"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 26)
	vbox.add_child(spacer)

	for def in [
		["SKIRMISH", "start_skirmish"],
		["CAMPAIGN", "show_campaign"],
		["FACTIONS", "show_factions"],
		["TECH DATABASE", "show_tech"],
		["SETTINGS", "show_settings"],
		["CREDITS", "show_credits"],
		["EXIT", "exit_game"],
	]:
		var b := _menu_button(def[0])
		b.pressed.connect(_on_button.bind(def[1]))
		vbox.add_child(b)

	var foot := Label.new()
	foot.text = "A Venom Works production"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 16)
	foot.add_theme_color_override("font_color", Color(0.4, 0.48, 0.58))
	vbox.add_child(foot)


func _on_button(which: String) -> void:
	SFX.play("ui")
	match which:
		"start_skirmish":
			start_skirmish.emit()
		"show_campaign":
			show_campaign.emit()
		"show_factions":
			show_factions.emit()
		"show_tech":
			show_tech.emit()
		"show_settings":
			show_settings.emit()
		"show_credits":
			show_credits.emit()
		"exit_game":
			exit_game.emit()


func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.12, 0.17, 0.92)
	normal.border_color = Color(0.25, 0.45, 0.65, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 24
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.2, 0.28, 0.95)
	hover.border_color = Color(0.4, 0.75, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.16, 0.28, 0.38, 0.98)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := get_rect()
	# Deep-space gradient backdrop.
	for i in 24:
		var f := float(i) / 23.0
		var c := Color(0.03 + 0.02 * f, 0.045 + 0.02 * f, 0.08 + 0.03 * f)
		draw_rect(Rect2(0, r.size.y * i / 24.0, r.size.x, r.size.y / 24.0 + 1), c)
	# Drifting starfield.
	for s in _stars:
		var d: Dictionary = s
		var px := fmod((d["p"] as Vector2).x * r.size.x - _t * float(d["v"]), r.size.x)
		if px < 0.0:
			px += r.size.x
		var py := (d["p"] as Vector2).y * r.size.y
		var tw := 0.55 + 0.45 * sin(_t * 2.0 + (d["p"] as Vector2).x * 40.0)
		draw_circle(Vector2(px, py), float(d["s"]), Color(0.7, 0.85, 1.0, 0.5 * tw))
	# Slow-panning tactical grid.
	var grid := 72.0
	var ox := fmod(_t * 6.0, grid)
	var gc := Color(0.2, 0.45, 0.65, 0.10)
	var x := -ox
	while x < r.size.x:
		draw_line(Vector2(x, 0), Vector2(x, r.size.y), gc, 1.0)
		x += grid
	var oy := fmod(_t * 4.0, grid)
	var y := -oy
	while y < r.size.y:
		draw_line(Vector2(0, y), Vector2(r.size.x, y), gc, 1.0)
		y += grid
