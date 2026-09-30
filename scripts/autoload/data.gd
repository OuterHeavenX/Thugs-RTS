extends Node

## Data registry autoload. Owns all FactionData; everything else queries it.
## Adding a faction later = write its data builder, register one line here.

var factions: Dictionary = {}


func _ready() -> void:
	var us: FactionData = USData.build()
	var japan: FactionData = JapanData.build()
	factions[us.id] = us
	factions[japan.id] = japan


func faction(id: String) -> FactionData:
	return factions.get(id, null)


func faction_ids() -> Array:
	return factions.keys()


func unit(faction_id: String, unit_id: String) -> UnitData:
	var f: FactionData = faction(faction_id)
	return f.unit(unit_id) if f != null else null


func building(faction_id: String, building_id: String) -> BuildingData:
	var f: FactionData = faction(faction_id)
	return f.building(building_id) if f != null else null


func upgrade(faction_id: String, upgrade_id: String) -> UpgradeData:
	var f: FactionData = faction(faction_id)
	return f.upgrade(upgrade_id) if f != null else null
