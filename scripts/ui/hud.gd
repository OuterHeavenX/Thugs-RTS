class_name HUD
extends Control
## In-match UI: top resource bar, contextual command bar, selection info,
## build picker + placement ghost, alerts, minimap. All buttons touch-sized.

signal menu_requested

const UNIT_CAP := 60

var _cam: CameraRig
var _sel: Selection
var _map: MapRuntime
var _world: Node3D

var minimap: Minimap

var _supply_lbl: Label
var _helios_lbl: Label
var _power_lbl: Label
var _units_lbl: Label
var _timer_lbl: Label
var _alerts_box: VBoxContainer
var _info_panel: PanelContainer
var _portrait: ColorRect
var _info_name: Label
var _info_hp: ProgressBar
var _info_sub: Label
var _cmd_panel: PanelContainer
var _cmd_box: VBoxContainer
var _picker: PanelContainer
var _picker_list: VBoxContainer
var _ghost: Node3D = null
var _ghost_mat: StandardMaterial3D = null
var _ghost_ok := false

var _hp_watch: Dictionary = {}
var _attack_cd := 0.0
var _ui_timer := 0.0
var _power_flash := 0.0
var _building_script: GDScript = null

func _dget(d, key: String, default):
	# Resource.get() takes only one arg; this is get-with-default.
	if d == null:
		return default
	if key in d:
		var v = d.get(key)
		return v if v != null else default
	return default



func setup(cam: CameraRig, sel: Selection, map_runtime: MapRuntime, world: Node3D) -> void:
	_cam = cam
	_sel = sel
	_map = map_runtime
	_world = world


func _ready() -> void:
	# Explicit anchors, not set_anchors_preset (see main_menu.gd note).
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_alerts()
	_build_info_panel()
	_build_command_bar()
	_build_picker()
	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.position = Vector2(-232, -232)
	minimap.custom_minimum_size = Vector2(220, 220)
	minimap.size = Vector2(220, 220)
	add_child(minimap)
	_sel.changed.connect(_refresh_panels)
	Game.resources_changed.connect(_on_resources_changed)
	Game.tech_researched.connect(_on_tech_researched)
	_refresh_panels()


# ------------------------------------------------------------- top bar
func _bar_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	sb.border_color = Color(0.2, 0.32, 0.45)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build_top_bar() -> void:
	var bar := _bar_panel()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hb)
	_supply_lbl = _res_label(hb, Color(1.0, 0.75, 0.25), "SUP")
	_helios_lbl = _res_label(hb, Color(0.35, 0.9, 1.0), "HEL")
	_power_lbl = _bar_text(hb, "120/85")
	_units_lbl = _bar_text(hb, "0/60")
	_timer_lbl = _bar_text(hb, "00:00")
	var menu := _cmd_button("MENU", "Pause menu (Esc)", Color(0.55, 0.65, 0.8))
	menu.custom_minimum_size = Vector2(96, 48)
	menu.pressed.connect(func(): menu_requested.emit())
	hb.add_child(menu)


func _res_label(parent: Control, color: Color, tag: String) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	hb.add_child(dot)
	var tagl := Label.new()
	tagl.text = tag
	tagl.add_theme_font_size_override("font_size", 14)
	tagl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.72))
	hb.add_child(tagl)
	var num := Label.new()
	num.text = "0"
	num.add_theme_font_size_override("font_size", 20)
	num.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	hb.add_child(num)
	return num


func _bar_text(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- alerts
func _build_alerts() -> void:
	var top := CenterContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 64
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_alerts_box = VBoxContainer.new()
	_alerts_box.add_theme_constant_override("separation", 6)
	_alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_alerts_box)


func alert(text: String, color: Color = Color(1, 0.9, 0.6)) -> void:
	while _alerts_box.get_child_count() >= 4:
		_alerts_box.get_child(0).queue_free()
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.88)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	_alerts_box.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------- selection info
func _build_info_panel() -> void:
	_info_panel = _bar_panel()
	_info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_panel.position = Vector2(12, -12)
	_info_panel.custom_minimum_size = Vector2(250, 0)
	add_child(_info_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_info_panel.add_child(hb)
	_portrait = ColorRect.new()
	_portrait.color = Color(0.3, 0.5, 0.8)
	_portrait.custom_minimum_size = Vector2(52, 52)
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 17)
	_info_name.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	vb.add_child(_info_name)
	_info_hp = ProgressBar.new()
	_info_hp.custom_minimum_size = Vector2(0, 10)
	_info_hp.max_value = 1.0
	_info_hp.show_percentage = false
	vb.add_child(_info_hp)
	_info_sub = Label.new()
	_info_sub.add_theme_font_size_override("font_size", 13)
	_info_sub.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
	vb.add_child(_info_sub)


# ----------------------------------------------------------- command bar
func _build_command_bar() -> void:
	_cmd_panel = _bar_panel()
	_cmd_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cmd_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cmd_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cmd_panel.position = Vector2(0, -12)
	add_child(_cmd_panel)
	_cmd_box = VBoxContainer.new()
	_cmd_box.add_theme_constant_override("separation", 8)
	_cmd_panel.add_child(_cmd_box)


func _cmd_button(text: String, tip: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(104, 64)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.13, 0.18, 0.95)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.22, 0.30, 0.97)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.32, 0.42, 0.98)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.07, 0.09, 0.9)
	disabled.border_color = Color(0.25, 0.27, 0.3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _refresh_panels() -> void:
	_refresh_info()
	_refresh_commands()
	_refresh_picker_visibility()


func _refresh_info() -> void:
	var sel := _sel.selected.filter(func(n): return is_instance_valid(n))
	if sel.is_empty():
		_info_panel.visible = false
		return
	_info_panel.visible = true
	var f: FactionData = Game.human().faction if Game.human() != null else null
	_portrait.color = f.color if f != null else Color(0.4, 0.5, 0.6)
	var first = sel[0]
	var d = first.get("data") if "data" in first else null
	_info_name.text = str(_dget(d, "name", "Unknown"))
	if sel.size() > 1:
		_info_sub.text = "x%d selected" % sel.size()
	else:
		_info_sub.text = ""
	var hp := 1.0
	if "hp" in first and "max_hp" in first:
		var m := float(first.get("max_hp"))
		hp = clampf(float(first.get("hp")) / m, 0.0, 1.0) if m > 0.0 else 1.0
	if "built" in first and not bool(first.get("built")) and "construction" in first:
		hp = clampf(float(first.get("construction")), 0.0, 1.0)
		_info_sub.text = "Constructing %d%%" % int(hp * 100.0)
	_info_hp.value = hp


func _clear_box(box: Container) -> void:
	for c in box.get_children():
		c.queue_free()


func _refresh_commands() -> void:
	_clear_box(_cmd_box)
	var sel := _sel.selected.filter(func(n): return is_instance_valid(n))
	if sel.is_empty():
		var hint := Label.new()
		hint.text = "Select units — left-click / tap, drag to box-select"
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.72))
		_cmd_box.add_child(hint)
		return
	var units := _sel.selected_units()
	var blds := _sel.selected_buildings()
	if blds.size() == 1 and units.is_empty():
		_building_commands(blds[0])
	else:
		_unit_commands(units)


func _cmd_row() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_cmd_box.add_child(hb)
	return hb


func _unit_commands(units: Array) -> void:
	var row := _cmd_row()
	var has_worker := false
	for u in units:
		var d = u.get("data") if "data" in u else null
		if d != null and bool(_dget(d, "is_worker", false)):
			has_worker = true
	var atk := _cmd_button("ATTACK", "Arm attack-move (A)", Color(0.9, 0.35, 0.3))
	atk.pressed.connect(func():
		_sel.arm_attack_move()
		alert("Attack-move armed — click a target", Color(1, 0.6, 0.3)))
	row.add_child(atk)
	var mv := _cmd_button("MOVE", "Next click issues a move order", Color(0.35, 0.7, 1.0))
	mv.pressed.connect(func():
		_sel.armed = "move_click"
		_sel.changed.emit()
		alert("Move — click destination", Color(0.5, 0.8, 1.0)))
	row.add_child(mv)
	var st := _cmd_button("STOP", "Stop (S)", Color(0.7, 0.7, 0.75))
	st.pressed.connect(_stop_selected)
	row.add_child(st)
	var hd := _cmd_button("HOLD", "Hold position (H)", Color(0.65, 0.55, 0.85))
	hd.pressed.connect(_hold_selected)
	row.add_child(hd)
	if has_worker:
		var row2 := _cmd_row()
		var ga := _cmd_button("GATHER", "Next click on a resource gathers", Color(0.45, 0.9, 0.5))
		ga.pressed.connect(func():
			_sel.arm_gather()
			alert("Gather — click a supply deposit or helios crystal", Color(0.5, 0.95, 0.55)))
		row2.add_child(ga)
		var bd := _cmd_button("BUILD", "Open construction", Color(1.0, 0.75, 0.3))
		bd.pressed.connect(_open_picker)
		row2.add_child(bd)


func _stop_selected() -> void:
	for n in _sel.selected_units():
		if n.has_method("order_stop"):
			n.call("order_stop")
	SFX.play("order")


func _hold_selected() -> void:
	for n in _sel.selected_units():
		if n.has_method("order_hold"):
			n.call("order_hold")
	SFX.play("order")


func _building_commands(bld) -> void:
	var d: BuildingData = bld.get("data") if "data" in bld else null
	var f: FactionData = Game.human().faction if Game.human() != null else null
	if d == null or f == null:
		return
	var built: bool = not ("built" in bld) or bool(bld.get("built"))
	var head := Label.new()
	head.text = "%s%s" % [d.name, "" if built else " (UNDER CONSTRUCTION)"]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	_cmd_box.add_child(head)
	if not built:
		return
	# Train list.
	var row := _cmd_row()
	for uid in d.trains:
		var ud: UnitData = Data.unit(f.id, uid)
		if ud == null:
			continue
		var b := _cmd_button("TRAIN\n%s" % ud.name, ud.desc, Color(0.35, 0.7, 1.0))
		b.text = "Train %s\n%ds %dT" % [ud.name, int(ud.cost_supply), int(ud.cost_helios)]
		b.pressed.connect(_on_train.bind(bld, uid))
		row.add_child(b)
	# Queue display (5 slots).
	var q := _queue_info(bld)
	if not q.is_empty() or true:
		var qrow := _cmd_row()
		var ql := Label.new()
		ql.text = "Queue:"
		ql.add_theme_font_size_override("font_size", 14)
		ql.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
		qrow.add_child(ql)
		for i in 5:
			var slot := Label.new()
			if i < q.size():
				var item: Dictionary = q[i]
				slot.text = "[%s %d%%]" % [item.get("label", "?"), int(float(item.get("progress", 0.0)) * 100.0)]
				slot.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
			else:
				slot.text = "[ — ]"
				slot.add_theme_color_override("font_color", Color(0.35, 0.4, 0.48))
			slot.add_theme_font_size_override("font_size", 14)
			qrow.add_child(slot)
			if i < q.size():
				var x := _cmd_button("X", "Cancel queued item", Color(0.8, 0.4, 0.35))
				x.custom_minimum_size = Vector2(48, 40)
				x.pressed.connect(_on_cancel_queue.bind(bld, i))
				qrow.add_child(x)
	# Research list.
	if not d.researches.is_empty():
		var rrow := _cmd_row()
		for upid in d.researches:
			var up: UpgradeData = Data.upgrade(f.id, upid)
			if up == null:
				continue
			var p: Player = Game.human()
			if p != null and p.has_tech(upid):
				continue
			var rb := _cmd_button("Research\n%s" % up.name, up.desc, Color(0.7, 0.55, 0.95))
			rb.text = "%s\n%ds %dT" % [up.name, int(up.cost_supply), int(up.cost_helios)]
			rb.pressed.connect(_on_research.bind(bld, upid))
			rrow.add_child(rb)
	var brow := _cmd_row()
	var rally := _cmd_button("SET RALLY", "Next click sets the rally point", Color(0.5, 0.85, 0.6))
	rally.pressed.connect(func():
		_sel.arm_rally(bld)
		alert("Rally — click destination", Color(0.5, 0.9, 0.6)))
	brow.add_child(rally)


func _queue_info(bld) -> Array:
	if bld.has_method("get_queue_info"):
		var q = bld.call("get_queue_info")
		if q is Array:
			return q
	return []


func _on_train(bld, uid: String) -> void:
	if bld.has_method("queue_unit"):
		if bool(bld.call("queue_unit", uid)):
			SFX.play("train")
		else:
			alert("Not enough supply", Color(1, 0.45, 0.4))
			SFX.play("error")
	_refresh_panels()


func _on_cancel_queue(bld, i: int) -> void:
	if bld.has_method("cancel_queue_index"):
		bld.call("cancel_queue_index", i)
	_refresh_panels()


func _on_research(bld, upid: String) -> void:
	if bld.has_method("queue_research"):
		if bool(bld.call("queue_research", upid)):
			SFX.play("research")
		else:
			alert("Not enough supply", Color(1, 0.45, 0.4))
			SFX.play("error")
	_refresh_panels()


# ------------------------------------------------------------- build picker
func _build_picker() -> void:
	_picker = _bar_panel()
	_picker.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_picker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_picker.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_picker.position = Vector2(0, -320)
	_picker.custom_minimum_size = Vector2(420, 0)
	_picker.visible = false
	add_child(_picker)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_picker.add_child(vb)
	var head := Label.new()
	head.text = "CONSTRUCT"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	vb.add_child(head)
	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 6)
	vb.add_child(_picker_list)
	var close := _cmd_button("CLOSE", "Close", Color(0.5, 0.55, 0.6))
	close.custom_minimum_size = Vector2(120, 48)
	close.pressed.connect(func(): _picker.visible = false)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_child(close)
	vb.add_child(crow)


func _open_picker() -> void:
	_clear_box(_picker_list)
	var f: FactionData = Game.human().faction if Game.human() != null else null
	if f == null:
		return
	for bd in f.buildings:
		var data: BuildingData = bd
		if data.id == "command":
			continue  # CC is unique.
		var b := _cmd_button("%s\n%ds %dT" % [data.name, int(data.cost_supply), int(data.cost_helios)], data.desc, Color(1.0, 0.75, 0.3))
		b.custom_minimum_size = Vector2(360, 56)
		b.pressed.connect(_on_pick_building.bind(data))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(b)
		_picker_list.add_child(row)
	_picker.visible = true


func _on_pick_building(data: BuildingData) -> void:
	_picker.visible = false
	_sel.arm_place(data)
	alert("Placement — click a valid site (right-click cancels)", Color(1.0, 0.85, 0.4))
	_ensure_ghost(data)


func _refresh_picker_visibility() -> void:
	if _sel.armed != "place_building" and _ghost != null:
		_ghost.queue_free()
		_ghost = null


func _ensure_ghost(data: BuildingData) -> void:
	if _world == null:
		return
	if _ghost != null:
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.top_level = false
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(data.footprint.x * 2.0, 0.6, data.footprint.y * 2.0)
	mi.mesh = bm
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
	_ghost_mat.no_depth_test = false
	mi.material_override = _ghost_mat
	mi.position.y = 0.3
	_ghost.add_child(mi)
	_world.add_child(_ghost)


func try_confirm_placement(pos: Vector3) -> void:
	var data: Resource = _sel.armed_data
	if data == null or not (data is BuildingData):
		_sel.disarm()
		return
	var bd := data as BuildingData
	if not _placement_valid(bd, pos):
		alert("Cannot build here", Color(1, 0.45, 0.4))
		SFX.play("error")
		return
	var pid := Game.human_id
	if not Game.spend(pid, bd.cost_supply, bd.cost_helios):
		alert("Not enough supply", Color(1, 0.45, 0.4))
		SFX.play("error")
		return
	var b = _spawn_building(bd, pid, pos)
	if b == null:
		Game.refund(pid, bd.cost_supply, bd.cost_helios)
		alert("Construction failed", Color(1, 0.45, 0.4))
		return
	SFX.play("build")
	_sel.disarm()
	_sel.changed.emit()
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	# Auto-select a worker to send it to the site? Leave selection as-is.


func _spawn_building(bd: BuildingData, pid: int, pos: Vector3):
	var scr := _building_script_cached()
	if scr == null:
		return null
	var b = scr.new()
	if not (b is Node3D):
		return null
	if b.has_method("setup"):
		b.call("setup", bd, pid)
	_world.add_child(b)
	if b.has_method("place_at"):
		b.call("place_at", pos)
	else:
		b.global_position = pos
	return b


func _building_script_cached() -> GDScript:
	if _building_script != null:
		return _building_script
	if not ResourceLoader.exists("res://scripts/buildings/building.gd"):
		return null
	_building_script = ResourceLoader.load("res://scripts/buildings/building.gd")
	return _building_script


func _placement_valid(bd: BuildingData, pos: Vector3) -> bool:
	var scr := _building_script_cached()
	var nav = _map.nav_grid if _map != null else null
	if scr != null:
		# Static can_place on the Building script (duck-typed via has_method).
		var ok = null
		if scr.has_method("can_place"):
			ok = scr.call("can_place", nav, pos, bd.footprint, Game.human_id)
		if ok is bool:
			return ok
	# Fallback: bounds only.
	return absf(pos.x) < 62.0 and absf(pos.z) < 62.0


# ------------------------------------------------------------------ tick
func _on_resources_changed(_pid: int) -> void:
	pass  # polled below


func _on_tech_researched(pid: int, upgrade_id: String) -> void:
	if pid != Game.human_id:
		return
	var f: FactionData = Game.human().faction
	var up: UpgradeData = Data.upgrade(f.id, upgrade_id) if f != null else null
	alert("Research complete: %s" % (up.name if up != null else upgrade_id), Color(0.7, 0.6, 1.0))
	SFX.play("research")
	_refresh_panels()


func _process(delta: float) -> void:
	if Game.phase != Game.Phase.PLAYING:
		return
	_ui_timer += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_update_ghost()
	if _ui_timer < 0.25:
		return
	_ui_timer = 0.0
	_update_top_bar()
	_watch_under_attack()
	_refresh_info()


func _update_top_bar() -> void:
	var p: Player = Game.human()
	if p == null:
		return
	_supply_lbl.text = "%d" % int(p.supply)
	_helios_lbl.text = "%d" % int(p.helios)
	var shortage := p.power_shortage()
	_power_lbl.text = "%d/%d" % [int(p.power_produced), int(p.power_consumed)]
	if shortage:
		_power_flash += 0.25
		var on := fmod(_power_flash, 1.0) < 0.5
		_power_lbl.add_theme_color_override("font_color",
			Color(1, 0.25, 0.2) if on else Color(1, 0.6, 0.5))
	else:
		_power_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_units_lbl.text = "%d/%d" % [Game.units_of(Game.human_id).size(), UNIT_CAP]
	var t := int(Game.time)
	_timer_lbl.text = "%02d:%02d" % [t / 60, t % 60]


func _watch_under_attack() -> void:
	var dead_keys: Array = []
	for b in _hp_watch.keys():
		if not is_instance_valid(b):
			dead_keys.append(b)
	for k in dead_keys:
		_hp_watch.erase(k)
	for b in Game.buildings_of(Game.human_id):
		if not (b is Node3D):
			continue
		var hp := float(b.get("hp")) if "hp" in b else 0.0
		var m := float(b.get("max_hp")) if "max_hp" in b else 1.0
		var frac := hp / m if m > 0.0 else 1.0
		var prev: float = _hp_watch.get(b, 1.0)
		if prev - frac > 0.02 and _attack_cd <= 0.0:
			var nm := "Base"
			var d = b.get("data") if "data" in b else null
			if d != null:
				nm = str(_dget(d, "name", "Base"))
			alert("%s under attack!" % nm, Color(1, 0.3, 0.25))
			SFX.play("warning")
			_attack_cd = 8.0
		_hp_watch[b] = frac


func _update_ghost() -> void:
	if _ghost == null or _ghost_mat == null:
		return
	if _sel.armed != "place_building" or not (_sel.armed_data is BuildingData):
		_ghost.queue_free()
		_ghost = null
		_ghost_mat = null
		return
	var vp := get_viewport()
	if vp == null:
		return
	var pos: Vector3 = _cam.screen_to_ground(vp.get_mouse_position())
	_ghost.global_position = Vector3(pos.x, 0, pos.z)
	_ghost_ok = _placement_valid(_sel.armed_data as BuildingData, pos)
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if _ghost_ok else Color(1.0, 0.3, 0.3, 0.45)
