class_name Barracks
extends Building

## Trains Soldiers. Placed by a worker, then constructed on site.


func _init() -> void:
	kind = "barracks"
	size = Vector2i(2, 2)
	max_hp = Balance.BARRACKS_HP
	trains = "soldier"
