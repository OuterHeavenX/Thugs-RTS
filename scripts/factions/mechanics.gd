class_name Mechanics
extends RefCounted

## Faction mechanics + tech stat modifiers. All static; every stat flows
## through here so balance lives in one place.

const US_NETWORK_RANGE := 12.0
const JP_SYNC_RANGE := 10.0
const JP_SYNC_RANGE_TECH := 14.0


static func damage_mult(unit: Unit) -> float:
	var m := 1.0
	if unit == null or unit.data == null:
		return m
	var p := Game.get_player(unit.player_id)
	var fid := unit.faction_id
	# US Battlefield Network: +10% damage near another friendly US combat
	# unit (+20% with Network Uplink).
	if fid == "us" and not unit.data.is_worker and _us_network_active(unit):
		if p != null and p.has_tech("network_uplink"):
			m *= 1.20
		else:
			m *= 1.10
	# Japan Combat Synchronization: +10% damage near another friendly JP
	# robotic unit (+20% with Sync Protocol).
	if fid == "japan" and unit.data.is_robotic and _jp_sync_active(unit):
		if p != null and p.has_tech("sync_protocol"):
			m *= 1.20
		else:
			m *= 1.10
	if p != null:
		# Drone AI: +20% damage for Reapers.
		if unit.data.id == "reaper" and p.has_tech("drone_ai"):
			m *= 1.2
		# Rail Amplifiers: +20% damage for all Japan units.
		if fid == "japan" and p.has_tech("rail_amplifiers"):
			m *= 1.2
	return m


static func speed_mult(unit: Unit) -> float:
	var m := 1.0
	if unit == null or unit.data == null:
		return m
	var p := Game.get_player(unit.player_id)
	# Japan Combat Synchronization: +12% speed when linked.
	if unit.faction_id == "japan" and unit.data.is_robotic and _jp_sync_active(unit):
		m *= 1.12
	if p != null:
		# Drone AI: +20% speed for Reapers.
		if unit.data.id == "reaper" and p.has_tech("drone_ai"):
			m *= 1.2
	return m


static func sight_bonus(unit: Unit) -> float:
	if unit == null or unit.data == null:
		return 0.0
	# US Battlefield Network: +2 sight when linked.
	if unit.faction_id == "us" and not unit.data.is_worker and _us_network_active(unit):
		return 2.0
	return 0.0


## Visibility rules. The human player is gated by FogOfWar; AI players
## (pid != human) always "see" everything inside sight range.
## The fog chunk exposes is_visible_at(pos) (renamed from the arch doc's
## is_visible); dynamic dispatch keeps this working under either spelling.
static func can_see(viewer_pid: int, pos: Vector3) -> bool:
	var p := Game.get_player(viewer_pid)
	if p != null and p.is_human:
		# FogOfWar exposes is_visible_at (NOT is_visible: Node3D already has
		# a native no-arg is_visible(), so the fog chunk renamed it).
		var f = Unit.fog
		if f != null and f.has_method("is_visible_at"):
			return bool(f.call("is_visible_at", pos))
	return true


## Max HP for a fresh unit, with tech multipliers applied.
static func max_hp_for(data: UnitData, pid: int) -> float:
	var m := 1.0
	var p := Game.get_player(pid)
	if p != null and data != null:
		# Composite Armor: +25% max HP for vehicles.
		if p.has_tech("composite_armor") and "vehicle" in data.armor_tags:
			m *= 1.25
		# Ceramic Plating: +25% max HP for all units.
		if p.has_tech("ceramic_plating"):
			m *= 1.25
	return data.hp * m


# ------------------------------------------------------------------ helpers
## True when at least one other alive friendly US combat unit (not a worker)
## is within network range.
static func _us_network_active(unit: Unit) -> bool:
	for u in Game.units_of(unit.player_id):
		if u == unit or not (u is Unit):
			continue
		var ou: Unit = u
		if not ou.alive() or ou.faction_id != "us" or ou.data.is_worker:
			continue
		if ou.global_position.distance_to(unit.global_position) <= US_NETWORK_RANGE:
			return true
	return false


## True when at least one other alive friendly Japanese robotic unit is
## within sync range (extended by Sync Protocol).
static func _jp_sync_active(unit: Unit) -> bool:
	var p := Game.get_player(unit.player_id)
	var rng := JP_SYNC_RANGE
	if p != null and p.has_tech("sync_protocol"):
		rng = JP_SYNC_RANGE_TECH
	for u in Game.units_of(unit.player_id):
		if u == unit or not (u is Unit):
			continue
		var ou: Unit = u
		if not ou.alive() or ou.faction_id != "japan" or not ou.data.is_robotic:
			continue
		if ou.global_position.distance_to(unit.global_position) <= rng:
			return true
	return false
