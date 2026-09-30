class_name Player
extends RefCounted

## One match participant. Plain data + resource/power bookkeeping.

var id: int = 0
var faction: FactionData = null
var is_human: bool = false
var supply: float = 0.0
var helios: float = 0.0
var techs: Dictionary = {}
var power_produced: float = 0.0
var power_consumed: float = 0.0


func has_tech(upgrade_id: String) -> bool:
	return techs.get(upgrade_id, false)


func power_shortage() -> bool:
	return power_consumed > power_produced


func power_ratio() -> float:
	if power_consumed <= 0.0:
		return 1.0
	if power_produced <= 0.0:
		return 0.0
	return clampf(power_produced / power_consumed, 0.0, 1.0)
