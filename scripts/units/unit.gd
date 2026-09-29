class_name Unit
extends Node2D

## Base unit: tile-space movement, separation-friendly steering, combat,
## and the worker gather/build state machine hooks.

enum UState { IDLE, MOVE, GATHER_MOVE, GATHER_HARVEST, GATHER_RETURN, BUILD_MOVE, BUILDING }

var game = null
var faction := "america"
var is_player := true
var kind := "worker"
var tile_pos := Vector2.ZERO
var move_target := Vector2.ZERO
var has_move := false
var attack_target = null
var attack_move := false
var state: int = UState.IDLE
var speed := 4.0
var damage := 4
var attack_range := 1.0
var attack_cd := 1.2
var cooldown := 0.0
var max_hp := 60
var selected := false
# worker fields
var gather_node = null
var carry := 0
var carry_kind := ""
var harvest_timer := 0.0
var build_site = null

var health: Health


func _ready() -> void:
	health = Health.new()
	health.setup(max_hp)
	health.died.connect(_on_died)
	health.changed.connect(_on_hp_changed)
	add_child(health)
	var sprite := Sprite2D.new()
	sprite.texture = SpriteFactory.unit_texture(kind, faction)
	sprite.position = Vector2(0, -28)
	add_child(sprite)
	position = Iso.tile_to_screen(tile_pos)


func is_alive() -> bool:
	return health != null and health.is_alive()


func take_damage(amount: int) -> void:
	if health != null:
		health.take_damage(amount)


func aim_tile() -> Vector2:
	return tile_pos


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func stop() -> void:
	state = UState.IDLE
	has_move = false
	attack_target = null
	attack_move = false
	gather_node = null
	build_site = null


func tick(delta: float) -> void:
	if not is_alive():
		return
	if cooldown > 0.0:
		cooldown -= delta
	_validate_targets()
	var engaging := attack_target != null
	match state:
		UState.MOVE:
			if not engaging and _step_toward(move_target, delta):
				has_move = false
				state = UState.IDLE
		UState.GATHER_MOVE:
			if gather_node == null:
				state = UState.IDLE
			elif _step_toward(gather_node.tile, delta, 0.6):
				state = UState.GATHER_HARVEST
				harvest_timer = Balance.HARVEST_TIME
		UState.GATHER_HARVEST:
			harvest_timer -= delta
			if harvest_timer <= 0.0:
				_finish_harvest()
		UState.GATHER_RETURN:
			var hq = game.player_hq if is_player else game.enemy_hq
			if hq == null or not is_instance_valid(hq):
				state = UState.IDLE
			elif _step_toward(hq.aim_tile(), delta, 1.4):
				_deposit()
		UState.BUILD_MOVE:
			if build_site == null or not is_instance_valid(build_site):
				state = UState.IDLE
			elif _step_toward(build_site.aim_tile(), delta, 1.6):
				state = UState.BUILDING
		UState.BUILDING:
			if build_site == null or not is_instance_valid(build_site) or build_site.constructed:
				build_site = null
				state = UState.IDLE
	if engaging:
		_engage(delta)
	extra_tick(delta)
	position = Iso.tile_to_screen(tile_pos)


func extra_tick(_delta: float) -> void:
	pass


func _step_toward(t: Vector2, delta: float, arrive_dist := 0.05) -> bool:
	var to := t - tile_pos
	var dist := to.length()
	if dist <= arrive_dist:
		return true
	var step := speed * delta
	if step >= dist:
		tile_pos = t
		return true
	tile_pos += to / dist * step
	return false


func _engage(delta: float) -> void:
	var tp: Vector2 = attack_target.aim_tile()
	var d := tile_pos.distance_to(tp)
	if d <= attack_range:
		if cooldown <= 0.0:
			cooldown = attack_cd
			attack_target.take_damage(damage)
			if game != null:
				game.sfx.play("attack")
	else:
		_step_toward(tp, delta)


func _validate_targets() -> void:
	if attack_target != null:
		if not is_instance_valid(attack_target) or not attack_target.is_alive():
			attack_target = null
	if gather_node != null:
		if not is_instance_valid(gather_node) or gather_node.amount <= 0:
			gather_node = null
			if state == UState.GATHER_MOVE or state == UState.GATHER_HARVEST:
				state = UState.IDLE


func _finish_harvest() -> void:
	if gather_node == null:
		state = UState.IDLE
		return
	carry = mini(Balance.CARRY_AMOUNT, gather_node.amount)
	carry_kind = gather_node.kind
	gather_node.amount -= carry
	if gather_node.amount <= 0:
		game.remove_node(gather_node)
		gather_node = null
	state = UState.GATHER_RETURN


func _deposit() -> void:
	if carry > 0 and carry_kind != "":
		game.add_resource(is_player, carry_kind, carry)
		game.sfx.play("coin")
	carry = 0
	carry_kind = ""
	if gather_node != null and is_instance_valid(gather_node) and gather_node.amount > 0:
		state = UState.GATHER_MOVE
	else:
		gather_node = null
		state = UState.IDLE


func _on_died() -> void:
	if game != null:
		game.on_unit_died(self)


func _on_hp_changed(_hp: int, _max_hp: int) -> void:
	queue_redraw()


func _draw() -> void:
	if selected:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if health != null and health.hp < health.max_hp:
		var w := 30.0
		var f := health.fraction()
		draw_rect(Rect2(-w * 0.5, -54, w, 5), Color(0, 0, 0, 0.7))
		var bar_col := Color(0.25, 0.9, 0.25) if is_player else Color(0.9, 0.25, 0.25)
		draw_rect(Rect2(-w * 0.5, -54, w * f, 5), bar_col)
