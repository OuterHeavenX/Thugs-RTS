class_name TitleScreen
extends Control

## THUGS title, faction select cards (America blue / Asia red),
## START button, how-to-play. All touch-sized.

signal start_game(faction: String)

var _selected := "america"
var _group := ButtonGroup.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "THUGS"
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "tiny RTS — slice v1"
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.65, 0.68, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var pick := Label.new()
	pick.text = "Choose your country"
	pick.add_theme_font_size_override("font_size", 24)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pick)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards)
	for f in ["america", "asia"]:
		cards.add_child(_make_card(f))

	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(340, 76)
	start.add_theme_font_size_override("font_size", 34)
	start.focus_mode = Control.FOCUS_NONE
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_on_start)
	vbox.add_child(start)

	var how := Label.new()
	how.text = "HOW TO PLAY\nTap one of your units or buildings to select it. Tap the ground to move.\nButtons: Gather sends workers to a node, Attack hits a target, Build raises a Barracks.\nDesktop: right-click gives a smart order, left-drag box-selects, wheel zooms, WASD pans.\nHarvest supplies and cash, train an army, and destroy the enemy HQ to win."
	how.add_theme_font_size_override("font_size", 19)
	how.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(700, 0)
	vbox.add_child(how)


func _make_card(faction: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	var swatch := ColorRect.new()
	swatch.color = FactionData.color_of(faction)
	swatch.custom_minimum_size = Vector2(280, 64)
	card.add_child(swatch)
	var b := Button.new()
	b.text = FactionData.display_name(faction)
	b.custom_minimum_size = Vector2(280, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_group = _group
	b.pressed.connect(_on_pick.bind(faction))
	card.add_child(b)
	if faction == _selected:
		b.button_pressed = true
	return card


func _on_pick(faction: String) -> void:
	_selected = faction


func _on_start() -> void:
	start_game.emit(_selected)
