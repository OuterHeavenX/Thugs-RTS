class_name JapanData
extends RefCounted

## Japan — elite robotics, speed, precision.
## Signature mechanic: COMBAT SYNCHRONIZATION — Japanese robotic units within
## 10m of another friendly Japanese robotic unit gain +12% move speed and
## +10% damage (+20% with Sync Protocol). Expensive, but elite.


static func build() -> FactionData:
	var f := FactionData.new()
	f.id = "japan"
	f.name = "Japan"
	f.color = Color(0.9, 0.9, 0.95)
	f.accent = Color(1.0, 0.25, 0.25)
	f.doctrine = "Elite robotic warfare. Small, fast, precise forces — expensive units that win through synchronization and superior technology."
	f.strengths = PackedStringArray([
		"Combat Synchronization: linked robotic units fight faster and harder",
		"Fast, elite units with excellent sensors",
		"Stealth options (Shinobi)",
	])
	f.weaknesses = PackedStringArray([
		"Units are expensive — losses hurt",
		"Small armies can be overwhelmed",
	])
	f.mechanic_name = "Combat Synchronization"
	f.mechanic_desc = "Japanese robotic units within 10m of another friendly robotic unit gain +12% speed and +10% damage."
	f.emblem = "rising"
	f.worker_id = "worker"

	# ---------------------------------------------------------------- units
	var worker := UnitData.make("worker", "Kōsaku Unit")
	worker.desc = "Engineer frame. Gathers Supply and Helios, constructs buildings."
	worker.cost_supply = 50
	worker.build_time = 10
	worker.hp = 45
	worker.speed = 4.8
	worker.sight = 14
	worker.armor_tags = PackedStringArray(["infantry", "light"])
	worker.is_worker = true
	worker.can_gather = true
	worker.is_robotic = true
	worker.model = "res://assets/models/units/jp_worker.glb"
	worker.counter_note = "Fragile. Keep away from combat."
	f.units.append(worker)

	var raiden := UnitData.make("raiden", "Raiden Infantry")
	raiden.desc = "Elite infantry with rail rifles. Precise and deadly."
	raiden.cost_supply = 75
	raiden.build_time = 14
	raiden.hp = 80
	raiden.speed = 4.6
	raiden.sight = 20
	raiden.armor_tags = PackedStringArray(["infantry"])
	raiden.weapon = WeaponData.make("Rail rifle", 14, 16, 1.4,
		{"light": 1.4, "vehicle": 1.25}, 80.0, false, true, 0.0, Color(0.6, 0.9, 1.0))
	raiden.model = "res://assets/models/units/jp_raiden.glb"
	raiden.counter_note = "Strong all-rounder infantry. Costly."
	f.units.append(raiden)

	var shinobi := UnitData.make("shinobi", "Shinobi")
	shinobi.desc = "Stealth infiltrator with plasma blade. Anti-armor specialist."
	shinobi.cost_supply = 100
	shinobi.cost_helios = 25
	shinobi.build_time = 16
	shinobi.hp = 70
	shinobi.speed = 5.5
	shinobi.sight = 16
	shinobi.armor_tags = PackedStringArray(["infantry", "stealth"])
	shinobi.weapon = WeaponData.make("Plasma blade", 20, 2.5, 1.2, {"vehicle": 1.75, "tank": 1.75})
	shinobi.model = "res://assets/models/units/jp_shinobi.glb"
	shinobi.counter_note = "Invisible until very close or detected. Deadly vs tanks."
	f.units.append(shinobi)

	var tora := UnitData.make("tora", "Tora Hover Tank")
	tora.desc = "Fast hover tank. Strikes and fades."
	tora.cost_supply = 175
	tora.cost_helios = 50
	tora.build_time = 26
	tora.hp = 400
	tora.speed = 8.0
	tora.sight = 19
	tora.armor_tags = PackedStringArray(["vehicle", "tank"])
	tora.is_robotic = true
	tora.weapon = WeaponData.make("Hover cannon", 30, 17, 2.2,
		{"vehicle": 1.5}, 50.0, false, true, 1.5, Color(1.0, 0.4, 0.4))
	tora.model = "res://assets/models/units/jp_tora.glb"
	tora.radius = 1.4
	tora.counter_note = "Fast raider. Counter with anti-armor."
	f.units.append(tora)

	var kitsune := UnitData.make("kitsune", "Kitsune Drone")
	kitsune.desc = "Recon drone. Huge sight range, detects stealth."
	kitsune.cost_supply = 90
	kitsune.cost_helios = 25
	kitsune.build_time = 16
	kitsune.hp = 120
	kitsune.speed = 11.0
	kitsune.sight = 34
	kitsune.armor_tags = PackedStringArray(["air"])
	kitsune.is_air = true
	kitsune.is_robotic = true
	kitsune.weapon = null
	kitsune.model = "res://assets/models/units/jp_kitsune.glb"
	kitsune.counter_note = "Unarmed scout. Detects Shinobi."
	f.units.append(kitsune)

	var ronin := UnitData.make("ronin", "Ronin Mech")
	ronin.desc = "Elite combat mech. Powerful against nearly everything."
	ronin.cost_supply = 280
	ronin.cost_helios = 140
	ronin.build_time = 40
	ronin.hp = 700
	ronin.speed = 5.0
	ronin.sight = 20
	ronin.armor_tags = PackedStringArray(["vehicle", "tank", "elite"])
	ronin.is_robotic = true
	ronin.weapon = WeaponData.make("Rail cannon", 45, 20, 2.8,
		{"vehicle": 1.5, "building": 1.25}, 60.0, false, true, 2.0, Color(1.0, 0.3, 0.3))
	ronin.model = "res://assets/models/units/jp_ronin.glb"
	ronin.radius = 1.5
	ronin.counter_note = "Elite and expensive. Focus fire to bring down."
	f.units.append(ronin)

	# ------------------------------------------------------------ buildings
	var cc := BuildingData.make("command", "Command Center")
	cc.desc = "Trains Kōsaku Units. Heart of the base."
	cc.hp = 1500
	cc.power_gen = 30
	cc.trains = PackedStringArray(["worker"])
	cc.model = "res://assets/models/buildings/jp_command_center.glb"
	cc.footprint = Vector2i(5, 5)
	f.buildings.append(cc)

	var gen := BuildingData.make("power", "Helios Reactor")
	gen.desc = "Generates +120 power."
	gen.cost_supply = 100
	gen.build_time = 20
	gen.hp = 500
	gen.power_gen = 120
	gen.model = "res://assets/models/buildings/jp_power_generator.glb"
	gen.footprint = Vector2i(3, 3)
	f.buildings.append(gen)

	var rax := BuildingData.make("barracks", "Dojo Barracks")
	rax.desc = "Trains infantry."
	rax.cost_supply = 150
	rax.build_time = 30
	rax.hp = 800
	rax.power_use = 10
	rax.trains = PackedStringArray(["raiden", "shinobi"])
	rax.model = "res://assets/models/buildings/jp_barracks.glb"
	rax.footprint = Vector2i(4, 4)
	f.buildings.append(rax)

	var fac := BuildingData.make("factory", "Mech Foundry")
	fac.desc = "Builds vehicles, mechs, and drones."
	fac.cost_supply = 200
	fac.cost_helios = 25
	fac.build_time = 40
	fac.hp = 900
	fac.power_use = 20
	fac.trains = PackedStringArray(["tora", "kitsune", "ronin"])
	fac.model = "res://assets/models/buildings/jp_vehicle_factory.glb"
	fac.footprint = Vector2i(5, 4)
	f.buildings.append(fac)

	var lab := BuildingData.make("lab", "Tech Shrine")
	lab.desc = "Researches technologies. Requires power."
	lab.cost_supply = 200
	lab.cost_helios = 50
	lab.build_time = 40
	lab.hp = 700
	lab.power_use = 25
	lab.researches = PackedStringArray(["sync_protocol", "ceramic_plating", "rail_amplifiers"])
	lab.model = "res://assets/models/buildings/jp_research_lab.glb"
	lab.footprint = Vector2i(4, 4)
	f.buildings.append(lab)

	var tower := BuildingData.make("tower", "Pulse Tower")
	tower.desc = "Energy defense tower. Hard-hitting vs armor."
	tower.cost_supply = 125
	tower.cost_helios = 25
	tower.build_time = 25
	tower.hp = 600
	tower.power_use = 15
	tower.weapon = WeaponData.make("Pulse cannon", 16, 18, 1.2,
		{"vehicle": 1.5, "tank": 1.5}, 75.0, true, true, 0.0, Color(1.0, 0.3, 0.3))
	tower.model = "res://assets/models/buildings/jp_defense_tower.glb"
	tower.footprint = Vector2i(2, 2)
	tower.counter_note = "Shuts down in a power shortage."
	f.buildings.append(tower)

	# ------------------------------------------------------------- upgrades
	var sync := UpgradeData.make("sync_protocol", "Sync Protocol")
	sync.desc = "Combat Synchronization damage bonus 10% -> 20%, link range 10m -> 14m."
	sync.cost_supply = 150
	sync.cost_helios = 50
	sync.research_time = 45
	sync.effects = {"jp_sync_bonus": 0.20, "jp_sync_range": 14.0}
	f.upgrades.append(sync)

	var plating := UpgradeData.make("ceramic_plating", "Ceramic Plating")
	plating.desc = "+25% max HP for all units."
	plating.cost_supply = 150
	plating.cost_helios = 50
	plating.research_time = 45
	plating.effects = {"unit_hp_mult": 1.25}
	f.upgrades.append(plating)

	var rails := UpgradeData.make("rail_amplifiers", "Rail Amplifiers")
	rails.desc = "+20% weapon damage for all units."
	rails.cost_supply = 150
	rails.cost_helios = 75
	rails.research_time = 45
	rails.effects = {"unit_dmg_mult": 1.2}
	f.upgrades.append(rails)

	return f
