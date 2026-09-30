extends Node

## Headless combat verification for the UNITS chunk.
## NOTE: runs as a scene, NOT with -s: Godot's -s script mode compiles
## without autoload singletons registered, so any script referencing Game /
## VFX / SFX fails to compile there (verified empirically). Run:
##   godot --headless --path . res://tests/test_combat.tscn
## Uses direct function calls (no timing); units' _process is frozen.

class DummyTarget extends Node3D:
	var hp := 1000.0
	var tags: PackedStringArray = ["infantry"]

	func armor_tags() -> PackedStringArray:
		return tags

	func alive() -> bool:
		return hp > 0.0

	func take_damage(amount: float, _source) -> void:
		hp -= amount


var _passed := 0
var _failed := 0
var _units: Array = []


func _check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name, " -- ", detail)


func _mk_unit(data: UnitData, pid: int, pos: Vector3) -> Unit:
	var u := Unit.new()
	add_child(u)
	u.setup(data, pid)
	u.global_position = pos
	u.set_process(false) # freeze the state machine; drive manually
	_units.append(u)
	return u


func _mk_dummy(pos: Vector3, tags: PackedStringArray) -> DummyTarget:
	var d := DummyTarget.new()
	add_child(d)
	d.global_position = pos
	d.tags = tags
	return d


func _ready() -> void:
	_run()
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run() -> void:
	Game.new_match("us", "japan")
	var us_ranger: UnitData = Data.unit("us", "ranger")
	var us_abrams: UnitData = Data.unit("us", "abramsx")
	var us_worker: UnitData = Data.unit("us", "worker")
	var jp_shinobi: UnitData = Data.unit("japan", "shinobi")
	var jp_tora: UnitData = Data.unit("japan", "tora")
	var jp_kitsune: UnitData = Data.unit("japan", "kitsune")
	var jp_worker: UnitData = Data.unit("japan", "worker")
	var us_guardian: UnitData = Data.unit("us", "guardian")
	var us_paladin: UnitData = Data.unit("us", "paladin")

	# ------------------------------------------------- 1: US network bonus
	var ra: Unit = _mk_unit(us_ranger, 0, Vector3(0, 0, 0))
	var rb: Unit = _mk_unit(us_ranger, 0, Vector3(5, 0, 0))
	var solo: Unit = _mk_unit(us_ranger, 0, Vector3(100, 0, 0))
	_check("network damage_mult paired == 1.10", is_equal_approx(Mechanics.damage_mult(ra), 1.10),
		"got %f" % Mechanics.damage_mult(ra))
	_check("network damage_mult solo == 1.0", is_equal_approx(Mechanics.damage_mult(solo), 1.0),
		"got %f" % Mechanics.damage_mult(solo))
	_check("network sight_bonus paired == +2", is_equal_approx(Mechanics.sight_bonus(ra), 2.0),
		"got %f" % Mechanics.sight_bonus(ra))
	_check("network sight_bonus solo == 0", is_equal_approx(Mechanics.sight_bonus(solo), 0.0),
		"got %f" % Mechanics.sight_bonus(solo))
	var w_rifle: WeaponData = us_ranger.weapon
	var d1 := _mk_dummy(Vector3(0, 0, 20), PackedStringArray(["light"]))
	Combat.apply_damage(d1, w_rifle.damage, w_rifle, ra)
	var d2 := _mk_dummy(Vector3(100, 0, 20), PackedStringArray(["light"]))
	Combat.apply_damage(d2, w_rifle.damage, w_rifle, solo)
	# paired: round(8 * 1.10 * 1.5) = 13 ; solo: round(8 * 1.5) = 12
	_check("network applied damage paired == 13", int(1000.0 - d1.hp) == 13,
		"got %d" % int(1000.0 - d1.hp))
	_check("network applied damage solo == 12", int(1000.0 - d2.hp) == 12,
		"got %d" % int(1000.0 - d2.hp))
	_check("paired damage > solo damage", (1000.0 - d1.hp) > (1000.0 - d2.hp), "")
	Game.get_player(0).techs["network_uplink"] = true
	_check("network_uplink raises mult to 1.20", is_equal_approx(Mechanics.damage_mult(ra), 1.20),
		"got %f" % Mechanics.damage_mult(ra))
	Game.get_player(0).techs["network_uplink"] = false

	# ------------------------------------------------- 2: bonus_vs
	# Abrams-X cannon has splash 1.5, so apply_damage routes through
	# apply_splash: use live registered enemies as targets.
	var ax: Unit = _mk_unit(us_abrams, 0, Vector3(200, 0, 0))
	var w_cannon: WeaponData = us_abrams.weapon
	var tv: Unit = _mk_unit(jp_tora, 1, Vector3(200, 0, 20)) # ["vehicle","tank"]
	var iw: Unit = _mk_unit(jp_worker, 1, Vector3(260, 0, 20)) # ["infantry","light"]
	Combat.apply_damage(tv, w_cannon.damage, w_cannon, ax)
	Combat.apply_damage(iw, w_cannon.damage, w_cannon, ax)
	# vs vehicle: round(35 * 1.5) = 53 (tank tag has no bonus entry) ; vs infantry: 35
	_check("bonus_vs vehicle == 53", is_equal_approx(tv.hp, 400.0 - 53.0),
		"hp=%f" % tv.hp)
	_check("bonus_vs infantry == 35", is_equal_approx(iw.hp, 45.0 - 35.0),
		"hp=%f" % iw.hp)
	_check("bonus_vs vehicle > infantry", (400.0 - tv.hp) > (45.0 - iw.hp), "")

	# --------------------------------- 3: projectile_speed == 0 fire path
	var sh: Unit = _mk_unit(jp_shinobi, 1, Vector3(-50, 0, 0))
	var w_blade: WeaponData = jp_shinobi.weapon
	_check("shinobi weapon is hitscan", w_blade.projectile_speed <= 0.0, "")
	var dt := _mk_dummy(Vector3(-50, 0, 2), PackedStringArray(["vehicle", "tank"]))
	sh._attack_target = dt
	sh._fire()
	# round(20 * 1.75 * 1.75) = 61
	_check("hitscan fire applied 61 dmg", int(1000.0 - dt.hp) == 61,
		"got %d" % int(1000.0 - dt.hp))
	_check("fire sets cooldown", is_equal_approx(sh._cooldown, w_blade.cooldown),
		"got %f" % sh._cooldown)

	# ------------------------------------------------- 4: projectile flight
	var gd: Unit = _mk_unit(us_guardian, 0, Vector3(300, 0, 0))
	var w_auto: WeaponData = us_guardian.weapon
	_check("guardian weapon is projectile", w_auto.projectile_speed > 0.0, "")
	var dp := _mk_dummy(Vector3(330, 0, 0), PackedStringArray(["infantry"]))
	var pr := Projectile.new()
	add_child(pr)
	pr.setup(Vector3(300, 1, 0), dp, dp.global_position, w_auto, solo)
	var steps := 0
	while not pr._dead and steps < 400:
		pr._process(0.05)
		steps += 1
	# solo ranger attacker: mult 1.0 ; round(10 * 1.6) = 16
	_check("projectile impacted", pr._dead, "steps=%d" % steps)
	_check("projectile applied 16 dmg", int(1000.0 - dp.hp) == 16,
		"got %d" % int(1000.0 - dp.hp))

	# ------------------------------------------------- 5: splash
	# Splash needs real registered enemies (Game.enemies_of), so use live units.
	var w_mlrs: WeaponData = us_paladin.weapon
	var wa: Unit = _mk_unit(jp_worker, 1, Vector3(400, 0, 30))
	var wb: Unit = _mk_unit(jp_worker, 1, Vector3(402, 0, 30))
	var wc: Unit = _mk_unit(jp_worker, 1, Vector3(420, 0, 30))
	Combat.apply_damage(wa, w_mlrs.damage, w_mlrs, solo)
	# MLRS: 40 dmg, splash 3.0, no bonus vs infantry/light -> 40 each in radius.
	_check("splash hits primary (hp 5)", is_equal_approx(wa.hp, 5.0), "hp=%f" % wa.hp)
	_check("splash hits nearby (hp 5)", is_equal_approx(wb.hp, 5.0), "hp=%f" % wb.hp)
	_check("splash spares distant (hp 45)", is_equal_approx(wc.hp, 45.0), "hp=%f" % wc.hp)

	# ------------------------------------------------- 6: japan sync
	var t1: Unit = _mk_unit(jp_tora, 1, Vector3(500, 0, 0))
	var t2: Unit = _mk_unit(jp_tora, 1, Vector3(505, 0, 0))
	var t3: Unit = _mk_unit(jp_tora, 1, Vector3(600, 0, 0))
	_check("sync damage_mult paired == 1.10", is_equal_approx(Mechanics.damage_mult(t1), 1.10),
		"got %f" % Mechanics.damage_mult(t1))
	_check("sync damage_mult solo == 1.0", is_equal_approx(Mechanics.damage_mult(t3), 1.0),
		"got %f" % Mechanics.damage_mult(t3))
	_check("sync speed_mult paired == 1.12", is_equal_approx(Mechanics.speed_mult(t1), 1.12),
		"got %f" % Mechanics.speed_mult(t1))
	Game.get_player(1).techs["rail_amplifiers"] = true
	_check("rail_amplifiers stacks (1.32)", is_equal_approx(Mechanics.damage_mult(t1), 1.32),
		"got %f" % Mechanics.damage_mult(t1))
	Game.get_player(1).techs["rail_amplifiers"] = false

	# ------------------------------------------------- 7: stealth / detectors
	var stealth_dummy := _mk_dummy(Vector3(0, 0, 50), PackedStringArray(["infantry", "stealth"]))
	ra.global_position = Vector3(0, 0, 0)
	_check("stealth not targetable at 50m", not Combat.can_target(w_rifle, ra, stealth_dummy), "")
	ra.global_position = Vector3(0, 0, 46)
	_check("stealth targetable within 6m", Combat.can_target(w_rifle, ra, stealth_dummy), "")
	ra.global_position = Vector3(0, 0, 0)
	var kit: Unit = _mk_unit(jp_kitsune, 0, Vector3(0, 0, 40))
	_check("kitsune is_detector", kit.is_detector(), "")
	_check("ranger is not detector", not ra.is_detector(), "")
	_check("stealth targetable via detector", Combat.can_target(w_rifle, ra, stealth_dummy), "")
	kit.global_position = Vector3(0, 0, 200)
	_check("stealth hidden again without detector", not Combat.can_target(w_rifle, ra, stealth_dummy), "")
	_check("non-stealth always targetable", Combat.can_target(w_rifle, ra, d1), "")

	# ------------------------------------------------- 8: air targeting rules
	var w_aa: WeaponData = us_guardian.weapon # targets_air=false
	# Real reaper: is_air() true.
	var rp: Unit = _mk_unit(Data.unit("us", "reaper"), 1, Vector3(0, 6, 60))
	_check("reaper is_air", rp.is_air(), "")
	_check("ground-only weapon cannot target air", not Combat.can_target(w_aa, ra, rp), "")
	var w_reaper: WeaponData = Data.unit("us", "reaper").weapon # targets_air=true
	_check("AA-capable weapon can target air", Combat.can_target(w_reaper, ra, rp), "")

	# ------------------------------------------------- 9: hp/techs, damage, death
	var r2: Unit = _mk_unit(us_ranger, 0, Vector3(700, 0, 0))
	_check("hp == max_hp after setup", is_equal_approx(r2.hp, r2.max_hp), "")
	r2.take_damage(10.0, null)
	_check("take_damage reduces hp", is_equal_approx(r2.hp, r2.max_hp - 10.0),
		"hp=%f max=%f" % [r2.hp, r2.max_hp])
	Game.get_player(0).techs["composite_armor"] = true
	var ax2: Unit = _mk_unit(us_abrams, 0, Vector3(710, 0, 0))
	_check("composite_armor vehicle hp 562.5", is_equal_approx(ax2.max_hp, 562.5),
		"got %f" % ax2.max_hp)
	Game.get_player(0).techs["composite_armor"] = false
	Game.get_player(0).techs["ceramic_plating"] = true
	var r3: Unit = _mk_unit(us_ranger, 0, Vector3(720, 0, 0))
	_check("ceramic_plating all-unit hp 75", is_equal_approx(r3.max_hp, 75.0),
		"got %f" % r3.max_hp)
	Game.get_player(0).techs["ceramic_plating"] = false
	var doomed: Unit = _mk_unit(us_ranger, 0, Vector3(730, 0, 0))
	_check("registered in Game", Game.units_of(0).has(doomed), "")
	doomed.take_damage(99999.0, null)
	_check("lethal damage kills", not doomed.alive(), "")
	_check("dead unit unregistered", not Game.units_of(0).has(doomed), "")
	_units.erase(doomed) # queue_free'd by _die

	# ------------------------------------------------- 10: worker gather smoke
	var wnode := ResourceNode.new()
	add_child(wnode)
	wnode.setup("supply")
	wnode.global_position = Vector3(10, 0, 0)
	wnode.add_to_group("resource_nodes")
	var wk := Worker.new()
	add_child(wk)
	wk.setup(us_worker, 0)
	wk.global_position = Vector3(0, 0, 0)
	wk.set_process(false)
	_units.append(wk)
	wk.order_gather(wnode)
	_check("worker enters GATHER", wk.state == Unit.State.GATHER, "state=%d" % wk.state)
	for i in 200:
		wk._tick_gather(0.05) # 10 simulated seconds
		if wk.carried >= 40.0:
			break
	_check("worker harvested (>0 carried)", wk.carried > 0.0, "carried=%f" % wk.carried)
	_check("node depleted by harvest", wnode.amount < 1500.0, "amount=%f" % wnode.amount)
	_check("worker not yet returning (cap 40)", not wk._returning or wk.carried >= 40.0,
		"carried=%f returning=%s" % [wk.carried, str(wk._returning)])

	# ------------------------------------------------- 11: can_see
	_check("can_see human w/o fog", Mechanics.can_see(0, Vector3(0, 0, 0)), "")
	_check("can_see AI", Mechanics.can_see(1, Vector3(0, 0, 0)), "")

	# ------------------------------------------------- cleanup
	for u in _units:
		if is_instance_valid(u):
			Game.unregister_unit(u)
			u.free()
	for c in get_children():
		if c is DummyTarget:
			c.free()
	if is_instance_valid(wnode):
		wnode.free()
	Game.to_menu()
