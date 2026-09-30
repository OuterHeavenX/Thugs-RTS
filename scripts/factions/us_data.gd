class_name USData
extends RefCounted

## United States — network warfare, combined arms, drones, precision strikes.
## Signature mechanic: BATTLEFIELD NETWORK — US combat units within 12m of at
## least one other friendly US combat unit gain +10% damage (+20% with
## Network Uplink) and +2 sight range. Rewards keeping forces together.


static func build() -> FactionData:
	var f := FactionData.new()
	f.id = "us"
	f.name = "United States"
	f.color = Color(0.25, 0.45, 0.95)
	f.accent = Color(0.4, 0.7, 1.0)
	f.doctrine = "Networked combined arms. Flexible forces that grow stronger fighting together — drones, armor, and infantry sharing one battlefield picture."
	f.strengths = PackedStringArray([
		"Battlefield Network: nearby units boost each other's damage",
		"Strong air and drone options",
		"Flexible, well-rounded roster",
	])
	f.weaknesses = PackedStringArray([
		"Individual units rarely dominate specialists",
		"No stealth options",
	])
	f.mechanic_name = "Battlefield Network"
	f.mechanic_desc = "US combat units within 12m of another friendly US combat unit gain +10% damage and +2 sight."
	f.emblem = "star"
	f.worker_id = "worker"

	# ---------------------------------------------------------------- units
	var worker := UnitData.make("worker", "Pioneer")
	worker.desc = "Engineer. Gathers Supply and Helios, constructs buildings."
	worker.cost_supply = 50
	worker.build_time = 10
	worker.hp = 45
	worker.speed = 4.5
	worker.sight = 14
	worker.armor_tags = PackedStringArray(["infantry", "light"])
	worker.is_worker = true
	worker.can_gather = true
	worker.model = "res://assets/models/units/us_worker.glb"
	worker.counter_note = "Fragile. Keep away from combat."
	f.units.append(worker)

	var ranger := UnitData.make("ranger", "Ranger Squad")
	ranger.desc = "Versatile infantry with assault rifles."
	ranger.cost_supply = 50
	ranger.build_time = 12
	ranger.hp = 60
	ranger.speed = 4.2
	ranger.sight = 18
	ranger.armor_tags = PackedStringArray(["infantry", "light"])
	ranger.weapon = WeaponData.make("Assault rifle", 8, 14, 1.0, {"light": 1.5})
	ranger.model = "res://assets/models/units/us_ranger.glb"
	ranger.counter_note = "Strong vs light units. Weak vs vehicles."
	f.units.append(ranger)

	var guardian := UnitData.make("guardian", "Guardian IFV")
	guardian.desc = "Fast infantry fighting vehicle with autocannon."
	guardian.cost_supply = 110
	guardian.build_time = 18
	guardian.hp = 220
	guardian.speed = 7.0
	guardian.sight = 20
	guardian.armor_tags = PackedStringArray(["vehicle"])
	guardian.weapon = WeaponData.make("Autocannon", 10, 15, 0.8,
		{"infantry": 1.6}, 60.0, false, true, 0.0, Color(1.0, 0.8, 0.3))
	guardian.model = "res://assets/models/units/us_guardian_ifv.glb"
	guardian.counter_note = "Strong vs infantry. Vulnerable to anti-armor."
	f.units.append(guardian)

	var abramsx := UnitData.make("abramsx", "Abrams-X Tank")
	abramsx.desc = "Main battle tank. Heavy cannon, thick armor."
	abramsx.cost_supply = 160
	abramsx.cost_helios = 40
	abramsx.build_time = 25
	abramsx.hp = 450
	abramsx.speed = 6.0
	abramsx.sight = 18
	abramsx.armor_tags = PackedStringArray(["vehicle", "tank"])
	abramsx.weapon = WeaponData.make("120mm cannon", 35, 18, 2.5,
		{"vehicle": 1.5, "building": 1.5}, 45.0, false, true, 1.5, Color(1.0, 0.6, 0.2))
	abramsx.model = "res://assets/models/units/us_abramsx.glb"
	abramsx.radius = 1.4
	abramsx.counter_note = "Strong vs vehicles and buildings. Counter with anti-armor."
	f.units.append(abramsx)

	var reaper := UnitData.make("reaper", "Reaper Drone")
	reaper.desc = "Armed drone. Fast, strikes vehicles from above."
	reaper.cost_supply = 140
	reaper.cost_helios = 50
	reaper.build_time = 22
	reaper.hp = 140
	reaper.speed = 10.0
	reaper.sight = 24
	reaper.armor_tags = PackedStringArray(["air"])
	reaper.is_air = true
	reaper.is_robotic = true
	reaper.weapon = WeaponData.make("Hellfire missiles", 18, 20, 2.0,
		{"vehicle": 1.6, "tank": 1.6}, 55.0, true, true, 2.0, Color(0.5, 0.8, 1.0))
	reaper.model = "res://assets/models/units/us_reaper_drone.glb"
	reaper.counter_note = "Strong vs vehicles. Vulnerable to anti-air."
	f.units.append(reaper)

	var paladin := UnitData.make("paladin", "Paladin Carrier")
	paladin.desc = "Long-range missile artillery. Devastating vs buildings."
	paladin.cost_supply = 170
	paladin.cost_helios = 60
	paladin.build_time = 28
	paladin.hp = 160
	paladin.speed = 5.5
	paladin.sight = 22
	paladin.armor_tags = PackedStringArray(["vehicle", "artillery"])
	paladin.weapon = WeaponData.make("MLRS barrage", 40, 26, 4.0,
		{"building": 2.0}, 40.0, false, true, 3.0, Color(1.0, 0.5, 0.2))
	paladin.model = "res://assets/models/units/us_paladin.glb"
	paladin.radius = 1.4
	paladin.counter_note = "Strong vs buildings and clusters. Fragile — protect it."
	f.units.append(paladin)

	# ------------------------------------------------------------ buildings
	var cc := BuildingData.make("command", "Command Center")
	cc.desc = "Trains Pioneers. Heart of the base."
	cc.hp = 1500
	cc.power_gen = 30
	cc.trains = PackedStringArray(["worker"])
	cc.model = "res://assets/models/buildings/us_command_center.glb"
	cc.footprint = Vector2i(5, 5)
	f.buildings.append(cc)

	var gen := BuildingData.make("power", "Fusion Generator")
	gen.desc = "Generates +120 power."
	gen.cost_supply = 100
	gen.build_time = 20
	gen.hp = 500
	gen.power_gen = 120
	gen.model = "res://assets/models/buildings/us_power_generator.glb"
	gen.footprint = Vector2i(3, 3)
	f.buildings.append(gen)

	var rax := BuildingData.make("barracks", "Barracks")
	rax.desc = "Trains infantry."
	rax.cost_supply = 150
	rax.build_time = 30
	rax.hp = 800
	rax.power_use = 10
	rax.trains = PackedStringArray(["ranger"])
	rax.model = "res://assets/models/buildings/us_barracks.glb"
	rax.footprint = Vector2i(4, 4)
	f.buildings.append(rax)

	var fac := BuildingData.make("factory", "Vehicle Factory")
	fac.desc = "Builds vehicles and drones."
	fac.cost_supply = 200
	fac.cost_helios = 25
	fac.build_time = 40
	fac.hp = 900
	fac.power_use = 20
	fac.trains = PackedStringArray(["guardian", "abramsx", "reaper", "paladin"])
	fac.model = "res://assets/models/buildings/us_vehicle_factory.glb"
	fac.footprint = Vector2i(5, 4)
	f.buildings.append(fac)

	var lab := BuildingData.make("lab", "Research Lab")
	lab.desc = "Researches technologies. Requires power."
	lab.cost_supply = 200
	lab.cost_helios = 50
	lab.build_time = 40
	lab.hp = 700
	lab.power_use = 25
	lab.researches = PackedStringArray(["network_uplink", "composite_armor", "drone_ai"])
	lab.model = "res://assets/models/buildings/us_research_lab.glb"
	lab.footprint = Vector2i(4, 4)
	f.buildings.append(lab)

	var tower := BuildingData.make("tower", "Sentry Tower")
	tower.desc = "Automated defense. Good vs infantry and air."
	tower.cost_supply = 125
	tower.cost_helios = 25
	tower.build_time = 25
	tower.hp = 600
	tower.power_use = 15
	tower.weapon = WeaponData.make("Sentry guns", 12, 18, 0.9,
		{"infantry": 1.5, "air": 1.5}, 70.0, true, true, 0.0, Color(0.4, 0.7, 1.0))
	tower.model = "res://assets/models/buildings/us_defense_tower.glb"
	tower.footprint = Vector2i(2, 2)
	tower.counter_note = "Shuts down in a power shortage."
	f.buildings.append(tower)

	# ------------------------------------------------------------- upgrades
	var uplink := UpgradeData.make("network_uplink", "Network Uplink")
	uplink.desc = "Battlefield Network damage bonus 10% -> 20%."
	uplink.cost_supply = 150
	uplink.cost_helios = 50
	uplink.research_time = 45
	uplink.effects = {"us_network_bonus": 0.20}
	f.upgrades.append(uplink)

	var armor := UpgradeData.make("composite_armor", "Composite Armor")
	armor.desc = "+25% max HP for all vehicles."
	armor.cost_supply = 150
	armor.cost_helios = 50
	armor.research_time = 45
	armor.effects = {"vehicle_hp_mult": 1.25}
	f.upgrades.append(armor)

	var droneai := UpgradeData.make("drone_ai", "Drone AI")
	droneai.desc = "+20% damage and speed for Reaper drones."
	droneai.cost_supply = 125
	droneai.cost_helios = 75
	droneai.research_time = 40
	droneai.effects = {"drone_dmg_mult": 1.2, "drone_speed_mult": 1.2}
	f.upgrades.append(droneai)

	return f
