class_name Soldier
extends Unit

## Attack-move and simple aggro: engages nearby enemies while idle
## or while moving with attack-move armed.


func _init() -> void:
	kind = "soldier"


func extra_tick(_delta: float) -> void:
	if game == null:
		return
	if attack_target != null:
		return
	if state == UState.IDLE or (state == UState.MOVE and attack_move):
		var e = game.find_enemy_in_range(tile_pos, Balance.SOLDIER_AGGRO, is_player)
		if e != null:
			attack_target = e
