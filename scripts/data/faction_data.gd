class_name FactionData
extends Resource

## One playable faction. Everything faction-specific lives here or in the
## models it points at; the engine never hardcodes faction behavior.

@export var id: String = ""
@export var name: String = ""
@export var color: Color = Color.WHITE
@export var accent: Color = Color.CYAN
@export var doctrine: String = ""
@export var strengths: PackedStringArray = []
@export var weaknesses: PackedStringArray = []
@export var mechanic_name: String = ""
@export var mechanic_desc: String = ""
@export var worker_id: String = "worker"
@export var units: Array[UnitData] = []
@export var buildings: Array[BuildingData] = []
@export var upgrades: Array[UpgradeData] = []
## Short emblem description; UI draws a procedural emblem from this.
@export var emblem: String = ""


func unit(id: String) -> UnitData:
	for u in units:
		if u.id == id:
			return u
	return null


func building(id: String) -> BuildingData:
	for b in buildings:
		if b.id == id:
			return b
	return null


func upgrade(id: String) -> UpgradeData:
	for u in upgrades:
		if u.id == id:
			return u
	return null
