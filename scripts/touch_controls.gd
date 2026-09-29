class_name TouchControls
extends Control

## On-screen command buttons + zoom buttons. Every target is at
## least 64px so it works with thumbs on mobile.

signal cmd_pressed(cmd: String)
signal zoom_pressed(factor: float)

var _cmd_buttons := {}
var _zoom_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -340
	bar.offset_right = 340
	bar.offset_top = -92
	bar.offset_bottom = -16
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	for cmd in ["move", "gather", "attack", "stop", "build"]:
		var b := _make_button(cmd.capitalize(), Vector2(124, 68))
		b.pressed.connect(_on_cmd.bind(cmd))
		bar.add_child(b)
		_cmd_buttons[cmd] = b

	_zoom_box = VBoxContainer.new()
	_zoom_box.add_theme_constant_override("separation", 10)
	_zoom_box.anchor_left = 1.0
	_zoom_box.anchor_right = 1.0
	_zoom_box.anchor_top = 0.0
	_zoom_box.anchor_bottom = 0.0
	_zoom_box.offset_left = -92
	_zoom_box.offset_right = -16
	_zoom_box.offset_top = 60
	_zoom_box.offset_bottom = 220
	add_child(_zoom_box)
	var zin := _make_button("+", Vector2(68, 68))
	zin.add_theme_font_size_override("font_size", 34)
	zin.pressed.connect(_on_zoom.bind(1.18))
	_zoom_box.add_child(zin)
	var zout := _make_button("-", Vector2(68, 68))
	zout.add_theme_font_size_override("font_size", 34)
	zout.pressed.connect(_on_zoom.bind(1.0 / 1.18))
	_zoom_box.add_child(zout)


func _make_button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	return b


func set_context(has_units: bool, show_build: bool) -> void:
	for cmd in _cmd_buttons:
		_cmd_buttons[cmd].visible = has_units
	_cmd_buttons["build"].visible = has_units and show_build


func _on_cmd(cmd: String) -> void:
	cmd_pressed.emit(cmd)


func _on_zoom(factor: float) -> void:
	zoom_pressed.emit(factor)
