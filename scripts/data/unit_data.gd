class_name UnitData
extends Resource

## Data-driven unit definition. New units = new UnitData, no engine changes.

@export var id: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var cost_supply: float = 50.0
@export var cost_helios: float = 0.0
@export var build_time: float = 10.0
@export var hp: float = 50.0
@export var speed: float = 4.0
@export var sight: float = 18.0
## Armor tags used by WeaponData.bonus_vs, e.g. ["infantry"], ["vehicle","tank"].
@export var armor_tags: PackedStringArray = []
@export var weapon: WeaponData = null
@export var is_air: bool = false
@export var is_worker: bool = false
@export var can_gather: bool = false
@export var is_robotic: bool = false
## Path to the .glb model, e.g. "res://assets/models/units/us_ranger.glb".
@export var model: String = ""
@export var radius: float = 0.9
@export var counter_note: String = ""


static func make(p_id: String, p_name: String) -> UnitData:
	var u := UnitData.new()
	u.id = p_id
	u.name = p_name
	return u
