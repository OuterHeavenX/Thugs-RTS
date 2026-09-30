class_name UpgradeData
extends Resource

## Researchable technology. Effects are applied by code keyed on upgrade id;
## the dictionary documents intent for UI and future factions.

@export var id: String = ""
@export var name: String = ""
@export var desc: String = ""
@export var cost_supply: float = 150.0
@export var cost_helios: float = 50.0
@export var research_time: float = 45.0
## e.g. {"us_network_bonus": 0.20} or {"vehicle_hp_mult": 1.25}.
@export var effects: Dictionary = {}


static func make(p_id: String, p_name: String) -> UpgradeData:
	var u := UpgradeData.new()
	u.id = p_id
	u.name = p_name
	return u
