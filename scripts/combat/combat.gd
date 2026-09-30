class_name Combat
extends RefCounted

## Static combat helpers: damage application and target legality.
## Called by Unit._fire, Projectile._impact, and Building defense code.

const STEALTH_REVEAL_DIST := 6.0
const DETECTOR_RANGE := 25.0


## Apply a weapon hit to a single target (or splash when weapon.splash > 0).
## final = max(1, round(base * damage_mult(attacker) * product(bonus_vs[tag]))).
static func apply_damage(target: Node3D, base: float, weapon: WeaponData, attacker: Unit) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("alive") and not target.alive():
		return
	if weapon.splash > 0.0:
		apply_splash(target.global_position, weapon.splash, base, weapon, attacker)
		return
	if not target.has_method("take_damage"):
		return
	target.take_damage(_final_damage(base, weapon, attacker, target), attacker)


## Damage every enemy of the attacker within radius of center (buildings
## included). Used for splash weapons and projectile impacts.
static func apply_splash(center: Vector3, radius: float, base: float, weapon: WeaponData, attacker: Unit) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	for e in Game.enemies_of(attacker.player_id):
		if e == null or not is_instance_valid(e):
			continue
		if not (e is Node3D):
			continue
		if (e as Node3D).global_position.distance_to(center) > radius:
			continue
		if e.has_method("alive") and not e.alive():
			continue
		if not e.has_method("take_damage"):
			continue
		e.take_damage(_final_damage(base, weapon, attacker, e), attacker)


static func _final_damage(base: float, weapon: WeaponData, attacker: Unit, target: Node3D) -> int:
	var mult := 1.0
	if attacker != null and is_instance_valid(attacker):
		mult *= Mechanics.damage_mult(attacker)
	if target.has_method("armor_tags"):
		var tags: PackedStringArray = target.armor_tags()
		for tag in tags:
			mult *= float(weapon.bonus_vs.get(tag, 1.0))
	return maxi(1, int(round(base * mult)))


## Can this weapon engage this target? Checks air/ground capability and the
## stealth rules: a "stealth"-tagged target is only targetable within 6m,
## or when a friendly detector (is_detector unit or tower building) is
## within 25m of the target.
static func can_target(weapon: WeaponData, attacker: Unit, target: Node3D) -> bool:
	if weapon == null or target == null or not is_instance_valid(target):
		return false
	if target.has_method("alive") and not target.alive():
		return false
	var t_air: bool = target.has_method("is_air") and bool(target.is_air())
	if t_air and not weapon.targets_air:
		return false
	if not t_air and not weapon.targets_ground:
		return false
	if target.has_method("armor_tags") and "stealth" in target.armor_tags():
		return _stealth_visible(attacker, target)
	return true


static func _stealth_visible(attacker: Unit, target: Node3D) -> bool:
	if attacker == null or not is_instance_valid(attacker):
		return false
	var tp: Vector3 = (target as Node3D).global_position
	# Point-blank reveal.
	if attacker.global_position.distance_to(tp) < STEALTH_REVEAL_DIST:
		return true
	# Detectors: kitsune-type units (is_detector) or tower buildings.
	for u in Game.units_of(attacker.player_id):
		if u == attacker or not (u is Unit):
			continue
		var ou: Unit = u
		if not ou.alive() or not ou.is_detector():
			continue
		if ou.global_position.distance_to(tp) <= DETECTOR_RANGE:
			return true
	for b in Game.buildings_of(attacker.player_id):
		if not (b is Node3D):
			continue
		if b.has_method("alive") and not b.alive():
			continue
		var bd = b.get("data")
		if bd == null or str(bd.id) != "tower":
			continue
		if (b as Node3D).global_position.distance_to(tp) <= DETECTOR_RANGE:
			return true
	return false
