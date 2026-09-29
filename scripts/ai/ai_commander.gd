class_name AICmdr
extends Node

## Enemy brain, ticked every ~2s: keeps workers gathering, builds a
## barracks when it can afford one, trains soldiers, and sends an
## attack wave at the player HQ once it has enough soldiers.

var game = null
var waves_enabled := true
var _timer := 0.0
var _wave_active := false


func tick(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = Balance.AI_TICK
	if game == null or not game.is_playing():
		return

	var workers: Array = game.enemy_workers()
	var soldiers: Array = game.enemy_soldiers()

	# Keep idle workers harvesting.
	for w in workers:
		if w.state == Unit.UState.IDLE:
			var n = game.nearest_node(w.tile_pos, "")
			if n != null:
				game.order_gather([w], n)

	# Build a barracks when affordable and we have none.
	var rax = game.enemy_barracks()
	if rax == null and not workers.is_empty():
		if game.can_afford(false, Balance.BARRACKS_COST_S, Balance.BARRACKS_COST_C):
			var site: Vector2i = game.find_build_site(game.enemy_hq_tile(), false)
			if site.x >= 0:
				game.start_construction(workers[0], site, false)

	# Train soldiers once the barracks is up; keep workers topped up.
	if rax != null and rax.constructed:
		if soldiers.size() < Balance.AI_SOLDIERS and rax.train_queue.size() < 2:
			game.train_unit(rax, "soldier")
	if game.enemy_hq != null and workers.size() < Balance.AI_WORKERS:
		if game.enemy_hq.train_queue.size() < 2:
			game.train_unit(game.enemy_hq, "worker")

	# Attack wave at the player HQ.
	if not waves_enabled:
		return
	if soldiers.size() >= Balance.AI_WAVE_SIZE and not _wave_active:
		_wave_active = true
		game.order_attack_move(soldiers, game.player_hq_tile())
	if _wave_active and soldiers.size() < 3:
		_wave_active = false
