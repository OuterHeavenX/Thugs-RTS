extends SceneTree

## Headless match-logic test. Drives Game.tick() directly with a fixed
## timestep and polls for outcomes (never exact-frame asserts).
## Run: godot --headless --path <project> -s tests/test_match.gd
## Exit code is non-zero on any failure.

var GameScript := load("res://scripts/game.gd")

var _failures := 0
var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	_run()
	print("TEST SUMMARY: %d failure(s)" % _failures)
	quit(_failures)
	return true


func _check(name: String, cond: bool) -> void:
	if cond:
		print("PASS: " + name)
	else:
		_failures += 1
		print("FAIL: " + name)


func _sim(game, seconds: float, until: Callable) -> bool:
	var steps := int(seconds * 60.0)
	for i in steps:
		game.tick(1.0 / 60.0)
		if until.call():
			return true
	return false


func _run() -> void:
	var game = GameScript.new()
	root.add_child(game)
	game.auto_tick = false
	game.setup_match("america")
	game.ai.waves_enabled = false  # test-only: keep enemy waves from raiding the economy buildup

	# 1. A worker ordered to gather increases Supplies.
	var worker = game.player_workers()[0]
	var node = game.nearest_node(worker.tile_pos, "supply")
	_check("supply node exists", node != null)
	var s0: int = game.supplies
	game.order_gather([worker], node)
	var gathered := _sim(game, 200.0, func(): return game.supplies > s0)
	_check("worker gather increases supplies", gathered)

	# 2. Training a worker deducts 50S and the unit appears.
	var c0: int = game.supplies
	var n0: int = game.unit_count(true)
	game.train_unit(game.player_hq, "worker")
	_check("train worker deducts 50 supplies", game.supplies == c0 - Balance.WORKER_COST_S)
	var trained := _sim(game, 30.0, func(): return game.unit_count(true) > n0)
	_check("trained worker appears", trained)

	# 3. A worker builds a Barracks through the real construction path.
	var w2 = game.player_workers()[1]
	var site: Vector2i = game.find_build_site(game.player_hq_tile(), true)
	_check("build site found", site.x >= 0)
	game.start_construction(w2, site, true)
	var built := _sim(game, 60.0, func():
		var r = game.player_barracks()
		return r != null and r.constructed)
	_check("barracks constructed", built)
	var rax = game.player_barracks()
	_check("barracks ref valid", rax != null)

	# 4. Build the economy with all workers, then train a soldier: deducts cost, soldier appears.
	game.order_gather(game.player_workers(), game.nearest_node(game.player_hq_tile(), "supply"))
	var econ := _sim(game, 400.0, func(): return game.supplies >= 150)
	_check("economy built up for soldier", econ)
	var s1: int = game.supplies
	var k1: int = game.cash
	game.train_unit(rax, "soldier")
	_check("train soldier deducts cost", game.supplies == s1 - Balance.SOLDIER_COST_S and game.cash == k1 - Balance.SOLDIER_COST_C)
	var appeared := _sim(game, 40.0, func():
		return not game.player_soldiers().is_empty())
	_check("trained soldier appears", appeared)
	var sols: Array = game.player_soldiers()
	_check("soldier ref valid", not sols.is_empty())

	# 5. An ordered attack kills an adjacent enemy soldier.
	var my_sol = sols[0]
	var enemy = game.debug_spawn_unit("soldier", "asia", false, my_sol.tile_pos + Vector2(1, 0))
	game.order_attack([my_sol], enemy)
	var killed := _sim(game, 60.0, func(): return not is_instance_valid(enemy) or not enemy.is_alive())
	_check("ordered attack kills enemy soldier", killed)

	# 6. Destroying the enemy HQ wins the match.
	game.damage_building(game.enemy_hq, 99999)
	game.tick(1.0 / 60.0)
	_check("destroying enemy HQ wins the match", game.match_state == game.MatchState.VICTORY)
