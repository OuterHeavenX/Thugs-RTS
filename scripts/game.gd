class_name Game
extends Node2D

## Match manager: map setup, resources, selection, commands, win/lose.
## Owns the isometric world (y-sorted), camera, HUD, input, AI, and sfx.

signal exit_to_title

enum MatchState { PLAYING, VICTORY, DEFEAT }


class ResNode extends Node2D:
	var tile := Vector2.ZERO
	var kind := "supply"
	var amount := 0


class Poof extends Node2D:
	var life := 0.35

	func _process(delta: float) -> void:
		life -= delta
		queue_redraw()
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		var f := 1.0 - life / 0.35
		draw_circle(Vector2(0, -10), 6.0 + f * 14.0, Color(1, 1, 1, 0.6 * (1.0 - f)))


var player_faction := "america"
var enemy_faction := "asia"
var match_state: int = MatchState.PLAYING
var match_started := false
var auto_tick := true
var match_time := 0.0
var supplies := 0
var cash := 0
var enemy_supplies := 0
var enemy_cash := 0
var units: Array = []
var buildings: Array = []
var nodes: Array = []
var selected: Array = []
var pending_command := ""
var ghost_tile := Vector2i(-1, -1)
var player_hq = null
var enemy_hq = null
var units_lost := 0
var enemy_lost := 0

var camera: CameraRig
var hud: Hud
var input: InputController
var sfx: Sfx
var ai: AICmdr


func _ready() -> void:
	y_sort_enabled = true
	camera = CameraRig.new()
	add_child(camera)
	sfx = Sfx.new()
	add_child(sfx)
	ai = AICmdr.new()
	ai.game = self
	add_child(ai)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	input = InputController.new()
	input.game = self
	hud.add_child(input)


func _physics_process(delta: float) -> void:
	if match_started and auto_tick:
		tick(delta)


func is_playing() -> bool:
	return match_state == MatchState.PLAYING


# ---------------------------------------------------------------- setup

func setup_match(faction: String) -> void:
	player_faction = faction
	enemy_faction = "asia" if faction == "america" else "america"
	match_state = MatchState.PLAYING
	match_started = true
	match_time = 0.0
	supplies = Balance.START_SUPPLIES
	cash = Balance.START_CASH
	enemy_supplies = Balance.START_SUPPLIES
	enemy_cash = Balance.START_CASH
	units_lost = 0
	enemy_lost = 0
	pending_command = ""
	ghost_tile = Vector2i(-1, -1)
	_scatter_nodes()
	player_hq = _place_hq(Vector2i(3, 3), player_faction, true)
	enemy_hq = _place_hq(Vector2i(19, 19), enemy_faction, false)
	for i in Balance.START_WORKERS:
		spawn_unit("worker", player_faction, true, Vector2(2 + i, 6))
		spawn_unit("worker", enemy_faction, false, Vector2(21 - i, 17))
	camera.position = Iso.tile_to_screen(Vector2(5, 5))
	camera.zoom = Vector2(0.85, 0.85)
	clear_selection()
	hud.hide_end()
	hud.show_hint("")
	hud.update_hud()
	queue_redraw()


func reset_match() -> void:
	for u in units:
		if is_instance_valid(u):
			u.queue_free()
	for b in buildings:
		if is_instance_valid(b):
			b.queue_free()
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	units.clear()
	buildings.clear()
	nodes.clear()
	selected.clear()
	player_hq = null
	enemy_hq = null
	setup_match(player_faction)


func _place_hq(origin: Vector2i, faction: String, is_player: bool):
	var hq = HQ.new()
	hq.game = self
	hq.faction = faction
	hq.is_player = is_player
	hq.origin = origin
	add_child(hq)
	buildings.append(hq)
	return hq


func _scatter_nodes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	var placed: Array = []
	var specs := []
	for i in Balance.SUPPLY_NODES:
		specs.append("supply")
	for i in Balance.CASH_NODES:
		specs.append("cash")
	for kind in specs:
		var tile := Vector2.ZERO
		var tries := 0
		while tries < 60:
			tries += 1
			tile = Vector2(rng.randi_range(1, Balance.MAP_W - 2), rng.randi_range(1, Balance.MAP_H - 2))
			if _node_spot_free(tile, placed):
				break
		placed.append(tile)
		var n := ResNode.new()
		n.tile = tile
		n.kind = kind
		n.amount = Balance.NODE_SUPPLY_AMOUNT if kind == "supply" else Balance.NODE_CASH_AMOUNT
		var spr := Sprite2D.new()
		spr.texture = SpriteFactory.node_texture(kind)
		n.add_child(spr)
		n.position = Iso.tile_to_screen(tile)
		add_child(n)
		nodes.append(n)


func _node_spot_free(tile: Vector2, placed: Array) -> bool:
	if tile.x < 2.0 or tile.y < 2.0 or tile.x > 21.0 or tile.y > 21.0:
		return false
	if tile.x < 7.0 and tile.y < 7.0:
		return false
	if tile.x > 16.0 and tile.y > 16.0:
		return false
	for p in placed:
		if (p as Vector2).distance_to(tile) < 2.0:
			return false
	return true


func spawn_unit(kind: String, faction: String, is_player: bool, tile: Vector2):
	var u = Worker.new() if kind == "worker" else Soldier.new()
	u.game = self
	u.kind = kind
	u.faction = faction
	u.is_player = is_player
	u.tile_pos = tile
	u.move_target = tile
	if kind == "worker":
		u.max_hp = Balance.WORKER_HP
		u.speed = Balance.WORKER_SPEED
		u.damage = Balance.WORKER_DMG
		u.attack_cd = Balance.WORKER_ATTACK_CD
	else:
		u.max_hp = Balance.SOLDIER_HP
		u.speed = Balance.SOLDIER_SPEED
		u.damage = Balance.SOLDIER_DMG
		u.attack_cd = Balance.ATTACK_CD
	u.attack_range = Balance.ATTACK_RANGE
	add_child(u)
	u.position = Iso.tile_to_screen(tile)
	units.append(u)
	return u


func debug_spawn_unit(kind: String, faction: String, is_player: bool, tile: Vector2):
	return spawn_unit(kind, faction, is_player, tile)


func spawn_unit_at_building(b, kind: String) -> void:
	var center: Vector2 = b.aim_tile()
	var spot := center
	var found := false
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var t := Vector2(center.x + dx, center.y + dy)
				if t.x >= 0.0 and t.y >= 0.0 and t.x < Balance.MAP_W and t.y < Balance.MAP_H:
					if not _tile_blocked(t):
						spot = t
						found = true
						break
			if found:
				break
		if found:
			break
	spawn_unit(kind, b.faction, b.is_player, spot)


func _tile_blocked(t: Vector2) -> bool:
	for b in buildings:
		if not is_instance_valid(b):
			continue
		var o: Vector2i = b.origin
		var s: Vector2i = b.size
		if t.x >= o.x - 0.5 and t.y >= o.y - 0.5 and t.x < o.x + s.x + 0.5 and t.y < o.y + s.y + 0.5:
			return true
	return false


# ---------------------------------------------------------------- tick

func tick(delta: float) -> void:
	if match_state != MatchState.PLAYING:
		return
	match_time += delta
	ai.tick(delta)
	for b in buildings.duplicate():
		if is_instance_valid(b):
			b.tick(delta)
	for u in units.duplicate():
		if is_instance_valid(u):
			u.tick(delta)
	_separation(delta)
	_check_end()
	hud.update_hud()


func _separation(delta: float) -> void:
	var n := units.size()
	for i in n:
		var a = units[i]
		if not is_instance_valid(a):
			continue
		for j in range(i + 1, n):
			var b = units[j]
			if not is_instance_valid(b):
				continue
			var d: Vector2 = b.tile_pos - a.tile_pos
			var dist := d.length()
			if dist < 0.45 and dist > 0.001:
				var push := (0.45 - dist) * 0.5 * minf(delta * 8.0, 1.0)
				var dir := d / dist
				a.tile_pos -= dir * push
				b.tile_pos += dir * push


func _check_end() -> void:
	if match_state != MatchState.PLAYING:
		return
	if enemy_hq == null or not is_instance_valid(enemy_hq):
		match_state = MatchState.VICTORY
		hud.show_end(true, _stats_text())
	elif player_hq == null or not is_instance_valid(player_hq):
		match_state = MatchState.DEFEAT
		hud.show_end(false, _stats_text())


func _stats_text() -> String:
	var mins := int(match_time) / 60
	var secs := int(match_time) % 60
	return "Time  %02d:%02d\nYour units lost: %d\nEnemy units lost: %d" % [mins, secs, units_lost, enemy_lost]


# ---------------------------------------------------------------- queries

func units_of(is_player: bool, kind := "") -> Array:
	var out := []
	for u in units:
		if not is_instance_valid(u):
			continue
		if u.is_player == is_player and (kind == "" or u.kind == kind):
			out.append(u)
	return out


func unit_count(is_player: bool) -> int:
	return units_of(is_player).size()


func player_workers() -> Array:
	return units_of(true, "worker")


func player_soldiers() -> Array:
	return units_of(true, "soldier")


func enemy_workers() -> Array:
	return units_of(false, "worker")


func enemy_soldiers() -> Array:
	return units_of(false, "soldier")


func player_barracks():
	return _find_barracks(true)


func enemy_barracks():
	return _find_barracks(false)


func _find_barracks(is_player: bool):
	for b in buildings:
		if is_instance_valid(b) and b.is_player == is_player and b.kind == "barracks":
			return b
	return null


func player_hq_tile() -> Vector2:
	if player_hq != null and is_instance_valid(player_hq):
		return player_hq.aim_tile()
	return Vector2(4, 4)


func enemy_hq_tile() -> Vector2:
	if enemy_hq != null and is_instance_valid(enemy_hq):
		return enemy_hq.aim_tile()
	return Vector2(20, 20)


func nearest_node(tile: Vector2, kind: String):
	var best = null
	var best_d := 1e9
	for n in nodes:
		if not is_instance_valid(n) or n.amount <= 0:
			continue
		if kind != "" and n.kind != kind:
			continue
		var d: float = tile.distance_to(n.tile)
		if d < best_d:
			best_d = d
			best = n
	return best


func find_enemy_in_range(tile: Vector2, radius: float, is_player: bool):
	var best = null
	var best_d := radius
	for u in units:
		if not is_instance_valid(u) or u.is_player == is_player:
			continue
		var d: float = tile.distance_to(u.tile_pos)
		if d <= best_d:
			best_d = d
			best = u
	for b in buildings:
		if not is_instance_valid(b) or b.is_player == is_player:
			continue
		var d2: float = tile.distance_to(b.aim_tile())
		if d2 <= best_d:
			best_d = d2
			best = b
	return best


func find_unit_at(world: Vector2):
	for u in units:
		if not is_instance_valid(u):
			continue
		if u.position.distance_to(world) < 24.0:
			return u
	return null


func find_building_at(world: Vector2):
	var t := Iso.screen_to_tile(world)
	for b in buildings:
		if not is_instance_valid(b):
			continue
		var o: Vector2i = b.origin
		var s: Vector2i = b.size
		if t.x >= o.x and t.y >= o.y and t.x < o.x + s.x and t.y < o.y + s.y:
			return b
	return null


func find_node_at(world: Vector2):
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if n.position.distance_to(world) < 30.0:
			return n
	return null


func selected_units() -> Array:
	var out := []
	for s in selected:
		if is_instance_valid(s) and s is Unit:
			out.append(s)
	return out


func selected_building():
	for s in selected:
		if is_instance_valid(s) and s is Building:
			return s
	return null


func can_afford(is_player: bool, s: int, c: int) -> bool:
	if is_player:
		return supplies >= s and cash >= c
	return enemy_supplies >= s and enemy_cash >= c


func try_spend(is_player: bool, s: int, c: int) -> bool:
	if not can_afford(is_player, s, c):
		return false
	if is_player:
		supplies -= s
		cash -= c
	else:
		enemy_supplies -= s
		enemy_cash -= c
	return true


func add_resource(is_player: bool, kind: String, amount: int) -> void:
	if kind == "supply":
		if is_player:
			supplies += amount
		else:
			enemy_supplies += amount
	else:
		if is_player:
			cash += amount
		else:
			enemy_cash += amount


func can_place(t: Vector2i) -> bool:
	if t.x < 1 or t.y < 1 or t.x > Balance.MAP_W - 3 or t.y > Balance.MAP_H - 3:
		return false
	var r := Rect2i(t, Vector2i(2, 2))
	for b in buildings:
		if not is_instance_valid(b):
			continue
		if r.intersects(Rect2i(b.origin, b.size)):
			return false
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var nt := Vector2i(int(n.tile.x), int(n.tile.y))
		if r.has_point(nt):
			return false
	return true


func find_build_site(near: Vector2, _is_player: bool) -> Vector2i:
	var base := Vector2i(int(near.x), int(near.y))
	for rad in range(0, 9):
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
				var t := Vector2i(base.x + dx, base.y + dy)
				if can_place(t):
					return t
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- input handling

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func handle_tap(screen_pos: Vector2, _is_touch: bool) -> void:
	if match_state != MatchState.PLAYING:
		return
	var world := _screen_to_world(screen_pos)
	if pending_command != "":
		_resolve_pending(world)
		return
	var u = find_unit_at(world)
	if u == null:
		u = find_building_at(world)
	if u != null and u.is_player:
		select_only(u)
		return
	if u != null and not u.is_player:
		var su := selected_units()
		if not su.is_empty():
			order_attack(su, u)
		return
	var su2 := selected_units()
	if not su2.is_empty():
		order_move(su2, Iso.screen_to_tile(world))
	else:
		clear_selection()


func handle_context_command(screen_pos: Vector2) -> void:
	if match_state != MatchState.PLAYING:
		return
	var su := selected_units()
	if su.is_empty():
		return
	var world := _screen_to_world(screen_pos)
	var foe = find_unit_at(world)
	if foe == null:
		foe = find_building_at(world)
	if foe != null and not foe.is_player:
		order_attack(su, foe)
		return
	var n = find_node_at(world)
	if n != null:
		var workers := []
		for w in su:
			if w.kind == "worker":
				workers.append(w)
		if not workers.is_empty():
			order_gather(workers, n)
		return
	order_move(su, Iso.screen_to_tile(world))


func box_select(rect: Rect2) -> void:
	clear_selection()
	var xf := get_viewport().get_canvas_transform()
	for u in units_of(true):
		var sp: Vector2 = xf * u.position
		if rect.has_point(sp):
			selected.append(u)
			u.set_selected(true)
	if not selected.is_empty():
		sfx.play("select")
	hud.update_hud()


func select_only(ent) -> void:
	clear_selection()
	selected.append(ent)
	ent.set_selected(true)
	sfx.play("select")
	hud.update_hud()


func clear_selection() -> void:
	for s in selected:
		if is_instance_valid(s):
			s.set_selected(false)
	selected.clear()
	cancel_command()


func cancel_command() -> void:
	pending_command = ""
	ghost_tile = Vector2i(-1, -1)
	hud.show_hint("")
	queue_redraw()


func arm(cmd: String) -> void:
	if pending_command == cmd:
		cancel_command()
		return
	if cmd == "build":
		var has_worker := false
		for u in selected_units():
			if u.kind == "worker":
				has_worker = true
		if not has_worker:
			hud.show_hint("Select a worker first")
			sfx.play("error")
			return
	pending_command = cmd
	ghost_tile = Vector2i(-1, -1)
	var hints := {
		"move": "Tap the map to move",
		"gather": "Tap a supply or cash node",
		"attack": "Tap an enemy (or the ground for attack-move)",
		"build": "Tap a tile to place the Barracks, tap again to confirm",
	}
	hud.show_hint(String(hints.get(cmd, "")))
	queue_redraw()


func _resolve_pending(world: Vector2) -> void:
	var su := selected_units()
	var cmd := pending_command
	if cmd == "move":
		order_move(su, Iso.screen_to_tile(world))
		cancel_command()
	elif cmd == "gather":
		var n = find_node_at(world)
		if n == null:
			hud.show_hint("Tap a glowing resource node")
			sfx.play("error")
			return
		order_gather(su, n)
		cancel_command()
	elif cmd == "attack":
		var foe = find_unit_at(world)
		if foe == null:
			foe = find_building_at(world)
		if foe != null and not foe.is_player:
			order_attack(su, foe)
		else:
			order_attack_move(su, Iso.screen_to_tile(world))
		cancel_command()
	elif cmd == "build":
		var t := Vector2i(int(floor(Iso.screen_to_tile(world).x)), int(floor(Iso.screen_to_tile(world).y)))
		if t == ghost_tile:
			var worker = null
			for u in su:
				if u.kind == "worker":
					worker = u
					break
			if worker != null and can_place(t):
				start_construction(worker, t, true)
			else:
				hud.show_hint("Can't build there")
				sfx.play("error")
		else:
			ghost_tile = t
			if can_place(t):
				hud.show_hint("Tap again to confirm Barracks (150S 50C)")
			else:
				hud.show_hint("Can't build there")
			queue_redraw()


# ---------------------------------------------------------------- orders

func _clamp_tile(t: Vector2) -> Vector2:
	return Vector2(clampf(t.x, 0.0, Balance.MAP_W - 1), clampf(t.y, 0.0, Balance.MAP_H - 1))


func _formation_offset(units_: Array, u) -> Vector2:
	var idx := units_.find(u)
	return Vector2((idx % 3) - 1, (idx / 3) - 1) * 0.6


func order_move(units_: Array, tile: Vector2) -> void:
	var t := _clamp_tile(tile)
	for u in units_:
		if not is_instance_valid(u):
			continue
		u.stop()
		u.move_target = t + _formation_offset(units_, u)
		u.has_move = true
		u.state = Unit.UState.MOVE
	sfx.play("move")


func order_attack_move(units_: Array, tile: Vector2) -> void:
	var t := _clamp_tile(tile)
	for u in units_:
		if not is_instance_valid(u):
			continue
		u.stop()
		u.attack_move = true
		u.move_target = t + _formation_offset(units_, u)
		u.has_move = true
		u.state = Unit.UState.MOVE
	sfx.play("move")


func order_gather(units_: Array, node) -> void:
	var ordered := false
	for u in units_:
		if not is_instance_valid(u) or u.kind != "worker":
			continue
		u.stop()
		u.gather_node = node
		u.state = Unit.UState.GATHER_MOVE
		ordered = true
	if ordered:
		sfx.play("move")


func order_attack(units_: Array, target) -> void:
	for u in units_:
		if not is_instance_valid(u):
			continue
		u.stop()
		u.attack_target = target
		u.state = Unit.UState.IDLE
	sfx.play("attack")


func order_stop(units_: Array) -> void:
	for u in units_:
		if is_instance_valid(u):
			u.stop()


func train_unit(building, kind: String) -> void:
	if building == null or not is_instance_valid(building):
		return
	if not building.constructed or building.trains != kind:
		return
	if building.train_queue.size() >= 3:
		return
	if unit_count(building.is_player) >= Balance.UNIT_CAP:
		hud.show_hint("Unit cap reached")
		return
	if kind == "worker":
		if not try_spend(building.is_player, Balance.WORKER_COST_S, Balance.WORKER_COST_C):
			hud.show_hint("Not enough supplies")
			sfx.play("error")
			return
		building.train_queue.append({"kind": "worker", "t": Balance.WORKER_TRAIN_TIME})
	else:
		if not try_spend(building.is_player, Balance.SOLDIER_COST_S, Balance.SOLDIER_COST_C):
			hud.show_hint("Not enough resources")
			sfx.play("error")
			return
		building.train_queue.append({"kind": "soldier", "t": Balance.SOLDIER_TRAIN_TIME})
	sfx.play("select")


func start_construction(worker, tile: Vector2i, is_player: bool) -> void:
	if not try_spend(is_player, Balance.BARRACKS_COST_S, Balance.BARRACKS_COST_C):
		hud.show_hint("Not enough resources")
		sfx.play("error")
		return
	var b = Barracks.new()
	b.game = self
	b.faction = player_faction if is_player else enemy_faction
	b.is_player = is_player
	b.origin = tile
	b.constructed = false
	b.build_progress = 0.0
	add_child(b)
	buildings.append(b)
	worker.stop()
	worker.build_site = b
	b.build_worker = worker
	worker.state = Unit.UState.BUILD_MOVE
	pending_command = ""
	ghost_tile = Vector2i(-1, -1)
	hud.show_hint("")
	sfx.play("select")
	queue_redraw()


func damage_building(b, amount: int) -> void:
	if b != null and is_instance_valid(b):
		b.take_damage(amount)


# ---------------------------------------------------------------- deaths

func on_unit_died(u) -> void:
	_spawn_poof(u.position)
	units.erase(u)
	selected.erase(u)
	if u.is_player:
		units_lost += 1
	else:
		enemy_lost += 1
	u.queue_free()


func on_building_died(b) -> void:
	_spawn_poof(b.position)
	_spawn_poof(b.position + Vector2(30, -40))
	_spawn_poof(b.position + Vector2(-30, -40))
	buildings.erase(b)
	selected.erase(b)
	if b == player_hq:
		player_hq = null
	elif b == enemy_hq:
		enemy_hq = null
	b.queue_free()


func on_building_completed(_b) -> void:
	pass


func remove_node(n) -> void:
	nodes.erase(n)
	n.queue_free()


func _spawn_poof(world_pos: Vector2) -> void:
	var p := Poof.new()
	p.position = world_pos
	add_child(p)


# ---------------------------------------------------------------- draw

func _draw() -> void:
	for x in Balance.MAP_W:
		for y in Balance.MAP_H:
			var c := Iso.tile_to_screen(Vector2(x, y))
			var v := float((x * 73 + y * 149) % 100) / 100.0
			var col := Color(0.24 + v * 0.05, 0.44 + v * 0.06, 0.22 + v * 0.04)
			var pts := PackedVector2Array([
				c + Vector2(0, -16), c + Vector2(32, 0),
				c + Vector2(0, 16), c + Vector2(-32, 0)])
			draw_colored_polygon(pts, col)
	var edge := PackedVector2Array([
		Vector2(0, -16), Vector2(768, 368), Vector2(0, 752),
		Vector2(-768, 368), Vector2(0, -16)])
	draw_polyline(edge, Color(0.1, 0.2, 0.1, 0.8), 3.0)
	if ghost_tile.x >= 0:
		var ok := can_place(ghost_tile)
		var gcol := Color(0.2, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.2, 0.2, 0.35)
		for dx in 2:
			for dy in 2:
				var cc := Iso.tile_to_screen(Vector2(ghost_tile) + Vector2(dx, dy))
				var gp := PackedVector2Array([
					cc + Vector2(0, -16), cc + Vector2(32, 0),
					cc + Vector2(0, 16), cc + Vector2(-32, 0)])
				draw_colored_polygon(gp, gcol)
