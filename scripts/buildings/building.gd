class_name Building
extends Node2D

## Base building: construction progress, training queue, placement helpers.

var game = null
var faction := "america"
var is_player := true
var kind := "hq"
var origin := Vector2i.ZERO
var size := Vector2i(2, 2)
var max_hp := 800
var constructed := true
var build_progress := 0.0
var build_worker = null
var train_queue: Array = []
var selected := false
var trains := ""

var health: Health
var _sprite: Sprite2D


func _ready() -> void:
	health = Health.new()
	health.setup(max_hp)
	health.died.connect(_on_died)
	health.changed.connect(_on_hp_changed)
	add_child(health)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = StructureSprites.get_texture(kind + "_" + faction)
	var sc := 0.55 if kind == "hq" else 0.5
	_sprite.scale = Vector2(sc, sc)
	# Baked PNGs are 256x256 with the building base at image y=232,
	# centered horizontally: anchor base bottom-center on the tile anchor.
	_sprite.position = Vector2(-128.0 * sc, -232.0 * sc)
	if not constructed:
		_sprite.modulate.a = 0.6
	add_child(_sprite)
	position = Iso.tile_to_screen(aim_tile())


func is_alive() -> bool:
	return health != null and health.is_alive()


func take_damage(amount: int) -> void:
	if health != null:
		health.take_damage(amount)


func aim_tile() -> Vector2:
	return Vector2(origin) + Vector2(size) * 0.5


func footprint_tiles() -> Array:
	var out := []
	for dx in size.x:
		for dy in size.y:
			out.append(Vector2i(origin.x + dx, origin.y + dy))
	return out


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func tick(delta: float) -> void:
	if not constructed:
		if build_worker != null and is_instance_valid(build_worker) and build_worker.build_site == self:
			var d: float = aim_tile().distance_to(build_worker.tile_pos)
			if d <= 3.0:
				build_progress += delta / Balance.BUILD_TIME
				if build_progress >= 1.0:
					build_progress = 1.0
					constructed = true
					_sprite.modulate.a = 1.0
					queue_redraw()
					if game != null:
						game.sfx.play("build")
						game.on_building_completed(self)
		return
	if not train_queue.is_empty():
		var job: Dictionary = train_queue[0]
		job["t"] = float(job["t"]) - delta
		if float(job["t"]) <= 0.0:
			train_queue.pop_front()
			if game != null:
				game.spawn_unit_at_building(self, String(job["kind"]))


func _on_died() -> void:
	if game != null:
		game.on_building_died(self)


func _on_hp_changed(_hp: int, _max_hp: int) -> void:
	queue_redraw()


func _draw() -> void:
	if selected:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 52.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not constructed:
		var w := 64.0
		draw_rect(Rect2(-w * 0.5, -150, w, 7), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, -150, w * build_progress, 7), Color(0.3, 0.7, 1.0))
	elif health != null and health.hp < health.max_hp:
		var w2 := 64.0
		var f := health.fraction()
		draw_rect(Rect2(-w2 * 0.5, -150, w2, 7), Color(0, 0, 0, 0.7))
		var bar_col := Color(0.25, 0.9, 0.25) if is_player else Color(0.9, 0.25, 0.25)
		draw_rect(Rect2(-w2 * 0.5, -150, w2 * f, 7), bar_col)
