class_name WeaponData
extends Resource

## Weapon definition. Damage math is intentionally simple and readable:
## final = base_damage * product(bonus_vs[tag] for tag in target.armor_tags).

@export var name: String = ""
@export var damage: float = 10.0
@export var range: float = 12.0
@export var cooldown: float = 1.0
## Armor-tag -> damage multiplier, e.g. {"vehicle": 1.5}.
@export var bonus_vs: Dictionary = {}
## 0 = instant/hitscan (melee, beams); >0 = projectile speed in m/s.
@export var projectile_speed: float = 0.0
@export var targets_air: bool = false
@export var targets_ground: bool = true
## Splash radius in meters; 0 = single target.
@export var splash: float = 0.0
@export var tracer_color: Color = Color(1.0, 0.85, 0.4)


static func make(p_name: String, p_damage: float, p_range: float, p_cooldown: float,
		p_bonus_vs: Dictionary = {}, p_projectile_speed: float = 0.0,
		p_targets_air: bool = false, p_targets_ground: bool = true,
		p_splash: float = 0.0, p_tracer: Color = Color(1.0, 0.85, 0.4)) -> WeaponData:
	var w := WeaponData.new()
	w.name = p_name
	w.damage = p_damage
	w.range = p_range
	w.cooldown = p_cooldown
	w.bonus_vs = p_bonus_vs
	w.projectile_speed = p_projectile_speed
	w.targets_air = p_targets_air
	w.targets_ground = p_targets_ground
	w.splash = p_splash
	w.tracer_color = p_tracer
	return w


func describe_counters() -> String:
	if bonus_vs.is_empty():
		return "Standard damage."
	var parts: PackedStringArray = []
	for tag in bonus_vs.keys():
		parts.append("%s x%.1f" % [tag.capitalize(), float(bonus_vs[tag])])
	return "Bonus vs " + ", ".join(parts) + "."
