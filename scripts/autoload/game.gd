extends Node

## Game autoload: match lifecycle, players, resources, power grid, registries.
## Systems talk to each other through this API, never through scene paths.

signal match_started
signal match_ended(victory: bool)
signal resources_changed(player_id: int)
signal unit_spawned(unit)
signal unit_died(unit)
signal building_placed(bld)
signal building_died(bld)
signal building_constructed(bld)
signal tech_researched(player_id: int, upgrade_id: String)

enum Phase { MENU, PLAYING, OVER }

const START_SUPPLY := 400.0
const START_HELIOS := 0.0

var phase: int = Phase.MENU
var players: Array[Player] = []
var time: float = 0.0
var human_id: int = 0

var _units: Array = []
var _buildings: Array = []


func _process(delta: float) -> void:
	if phase == Phase.PLAYING:
		time += delta


# ------------------------------------------------------------- match setup
func new_match(human_faction: String, enemy_faction: String) -> void:
	players.clear()
	_units.clear()
	_buildings.clear()
	time = 0.0
	var hp := Player.new()
	hp.id = 0
	hp.faction = Data.faction(human_faction)
	hp.is_human = true
	hp.supply = START_SUPPLY
	hp.helios = START_HELIOS
	var ep := Player.new()
	ep.id = 1
	ep.faction = Data.faction(enemy_faction)
	ep.is_human = false
	ep.supply = START_SUPPLY
	ep.helios = START_HELIOS
	players = [hp, ep]
	human_id = 0
	phase = Phase.PLAYING
	match_started.emit()


func end_match(victory: bool) -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.OVER
	match_ended.emit(victory)


func to_menu() -> void:
	phase = Phase.MENU
	players.clear()
	_units.clear()
	_buildings.clear()


func get_player(pid: int) -> Player:
	if pid >= 0 and pid < players.size():
		return players[pid]
	return null


func human() -> Player:
	return get_player(human_id)


# -------------------------------------------------------------- resources
func spend(pid: int, supply: float, helios: float) -> bool:
	var p := get_player(pid)
	if p == null:
		return false
	if p.supply < supply or p.helios < helios:
		return false
	p.supply -= supply
	p.helios -= helios
	resources_changed.emit(pid)
	return true


func refund(pid: int, supply: float, helios: float) -> void:
	var p := get_player(pid)
	if p == null:
		return
	p.supply += supply
	p.helios += helios
	resources_changed.emit(pid)


func add_resources(pid: int, supply: float, helios: float) -> void:
	var p := get_player(pid)
	if p == null:
		return
	p.supply += supply
	p.helios += helios
	resources_changed.emit(pid)


# ------------------------------------------------------------------ power
func recompute_power(pid: int) -> void:
	var p := get_player(pid)
	if p == null:
		return
	var prod := 0.0
	var use := 0.0
	for b in _buildings:
		if b.player_id != pid or not b.built:
			continue
		prod += b.data.power_gen
		use += b.data.power_use
	p.power_produced = prod
	p.power_consumed = use


# -------------------------------------------------------------- registries
func register_unit(u) -> void:
	if not _units.has(u):
		_units.append(u)
		unit_spawned.emit(u)


func unregister_unit(u) -> void:
	_units.erase(u)
	unit_died.emit(u)


func register_building(b) -> void:
	if not _buildings.has(b):
		_buildings.append(b)
		building_placed.emit(b)
		recompute_power(b.player_id)


func unregister_building(b) -> void:
	_buildings.erase(b)
	building_died.emit(b)
	recompute_power(b.player_id)
	check_victory()


func units_of(pid: int, alive_only: bool = true) -> Array:
	var out: Array = []
	for u in _units:
		if u.player_id != pid:
			continue
		if alive_only and not u.alive():
			continue
		out.append(u)
	return out


func buildings_of(pid: int, alive_only: bool = true) -> Array:
	var out: Array = []
	for b in _buildings:
		if b.player_id != pid:
			continue
		if alive_only and not b.alive():
			continue
		out.append(b)
	return out


func enemies_of(pid: int) -> Array:
	var out: Array = []
	for u in _units:
		if u.player_id != pid and u.alive():
			out.append(u)
	for b in _buildings:
		if b.player_id != pid and b.alive():
			out.append(b)
	return out


# ---------------------------------------------------------------- victory
func check_victory() -> void:
	if phase != Phase.PLAYING or players.size() < 2:
		return
	for p in players:
		if buildings_of(p.id).is_empty():
			# A player with no buildings left loses (workers alone can't rebuild).
			end_match(p.id != human_id)
			return
