class_name BuildingData
extends Resource

## Data-driven building definition.

@export var id: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var cost_supply: float = 100.0
@export var cost_helios: float = 0.0
@export var build_time: float = 20.0
@export var hp: float = 600.0
@export var power_gen: float = 0.0
@export var power_use: float = 0.0
## Unit ids this building can train.
@export var trains: PackedStringArray = []
## Upgrade ids this building can research.
@export var researches: PackedStringArray = []
@export var weapon: WeaponData = null
@export var model: String = ""
## Footprint in nav-grid cells.
@export var footprint: Vector2i = Vector2i(4, 4)
@export var counter_note: String = ""


static func make(p_id: String, p_name: String) -> BuildingData:
	var b := BuildingData.new()
	b.id = p_id
	b.name = p_name
	return b
