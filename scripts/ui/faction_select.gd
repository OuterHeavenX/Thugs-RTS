class_name FactionSelect
extends Control
## Skirmish setup: pick a playable faction (enemy = the other). Five future
## factions shown as neutral "COMING SOON" cards — no power ranking, no
## good/evil framing.

signal start_battle(human_faction: String)
signal back_pressed

const COMING_SOON := [
	["China", "Mass-mobilization doctrine: overwhelming numbers and resilient industry."],
	["Germany", "Precision engineering doctrine: disciplined armor and methodical advances."],
	["India", "Adaptive combined-arms doctrine: flexible formations for any terrain."],
	["Brazil", "Expeditionary doctrine: rapid deployment and jungle-honed mobility."],
	["Russia", "Deep-battle doctrine: layered artillery and armored spearheads."],
]

var mode := "select"  # or "info"
var _selected_id := "us"
var _cards: Dictionary = {}
var _start_btn: Button


class Emblem:
	extends Control
	var kind := "star"
	var accent := Color.CYAN

	func _ready() -> void:
		custom_minimum_size = Vector2(120, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.44
		if kind == "star":
			# US: white star on deep blue roundel.
			draw_circle(c, r, Color(0.10, 0.16, 0.34))
			draw_arc(c, r, 0, TAU, 48, accent, 3.0)
			var pts := PackedVector2Array()
			for i in 10:
				var rr := r * (0.42 if i % 2 == 1 else 0.85)
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(0.93, 0.95, 1.0))
		else:
			# Japan: red disc on white roundel.
			draw_circle(c, r, Color(0.92, 0.92, 0.94))
			draw_arc(c, r, 0, TAU, 48, Color(0.75, 0.2, 0.2), 3.0)
			draw_circle(c, r * 0.55, Color(0.78, 0.12, 0.14))


func _ready() -> void:
	# Explicit anchors, not set_anchors_preset (see main_menu.gd note):
	# the preset called in _ready() preserves the zero size off-screen.
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build()


func _bg() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.05, 0.085)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg


func _build() -> void:
	add_child(_bg())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "SELECT FACTION" if mode == "select" else "FACTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Your opponent fields the other faction." if mode == "select" else "Two commanders ready. Five more in training."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
	vbox.add_child(sub)

	var cards_scroll := ScrollContainer.new()
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(cards_scroll)
	var scroll_vb := VBoxContainer.new()
	scroll_vb.add_theme_constant_override("separation", 12)
	scroll_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_scroll.add_child(scroll_vb)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_vb.add_child(cards)
	for fid in ["us", "japan"]:
		var f: FactionData = Data.faction(fid)
		if f == null:
			continue
		var card := _playable_card(f)
		_cards[fid] = card
		cards.add_child(card)
	_refresh_highlights()

	var soon_title := Label.new()
	soon_title.text = "COMING SOON"
	soon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon_title.add_theme_font_size_override("font_size", 20)
	soon_title.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
	scroll_vb.add_child(soon_title)

	var soon := HBoxContainer.new()
	soon.add_theme_constant_override("separation", 10)
	soon.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_vb.add_child(soon)
	for entry in COMING_SOON:
		soon.add_child(_soon_card(entry[0], entry[1]))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom)
	var back := _button("BACK", Color(0.5, 0.55, 0.6))
	back.pressed.connect(func(): back_pressed.emit())
	bottom.add_child(back)
	if mode == "select":
		_start_btn = _button("START BATTLE", Color(0.35, 0.85, 0.45))
		_start_btn.pressed.connect(_on_start)
		bottom.add_child(_start_btn)


func _panel_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.15, 0.96)
	sb.border_color = accent if selected else Color(0.22, 0.3, 0.4)
	sb.set_border_width_all(3 if selected else 1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


func _playable_card(f: FactionData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(f.accent, false))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	var emb := Emblem.new()
	emb.kind = f.emblem
	emb.accent = f.accent
	top.add_child(emb)
	var namebox := VBoxContainer.new()
	namebox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(namebox)
	var nm := Label.new()
	nm.text = f.name
	nm.add_theme_font_size_override("font_size", 30)
	nm.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namebox.add_child(nm)
	var mech := Label.new()
	mech.text = f.mechanic_name.to_upper()
	mech.add_theme_font_size_override("font_size", 16)
	mech.add_theme_color_override("font_color", f.accent)
	mech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namebox.add_child(mech)
	vb.add_child(_section("DOCTRINE", f.doctrine, 15))
	vb.add_child(_section("STRENGTHS", "\n".join(f.strengths), 14))
	vb.add_child(_section("WEAKNESSES", "\n".join(f.weaknesses), 14))
	vb.add_child(_section("FIELD MANUAL", f.mechanic_desc, 14))
	var units_txt := ""
	for u in f.units:
		var ud: UnitData = u
		units_txt += "• %s — %s\n" % [ud.name, ud.counter_note]
	vb.add_child(_section("ARSENAL", units_txt.strip_edges(), 13))
	card.gui_input.connect(_on_card_input.bind(f.id))
	return card


func _section(head: String, body: String, fsize: int) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var h := Label.new()
	h.text = head
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color(0.45, 0.62, 0.78))
	vb.add_child(h)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color(0.82, 0.87, 0.93))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(b)
	return vb


func _soon_card(card_name: String, doctrine: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.9)
	sb.border_color = Color(0.25, 0.27, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var nm := Label.new()
	nm.text = card_name
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	vb.add_child(nm)
	var tag := Label.new()
	tag.text = "COMING SOON"
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color(0.4, 0.42, 0.46))
	vb.add_child(tag)
	var d := Label.new()
	d.text = doctrine
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", Color(0.48, 0.51, 0.55))
	vb.add_child(d)
	return card


func _on_card_input(event: InputEvent, fid: String) -> void:
	if mode != "select":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_selected_id = fid
			SFX.play("select")
			_refresh_highlights()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_selected_id = fid
			SFX.play("select")
			_refresh_highlights()


func _refresh_highlights() -> void:
	for fid in _cards.keys():
		var card: PanelContainer = _cards[fid]
		var f: FactionData = Data.faction(fid)
		card.add_theme_stylebox_override("panel", _panel_style(f.accent, fid == _selected_id))


func _on_start() -> void:
	SFX.play("ui")
	start_battle.emit(_selected_id)


func _button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 60)
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
