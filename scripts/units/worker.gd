class_name Worker
extends Unit

## Harvester / builder. The gather loop lives in the base Unit tick.


func _init() -> void:
	kind = "worker"
