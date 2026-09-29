class_name HQ
extends Building

## Headquarters: trains Workers, resource drop-off. Destroyed = defeat.


func _init() -> void:
	kind = "hq"
	size = Vector2i(2, 2)
	max_hp = Balance.HQ_HP
	trains = "worker"
