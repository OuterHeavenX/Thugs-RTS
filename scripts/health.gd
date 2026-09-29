class_name Health
extends Node

## Damageable component: hp, take_damage(), died signal.

signal died
signal changed(hp: int, max_hp: int)

var max_hp := 100
var hp := 100


func setup(p_max_hp: int) -> void:
	max_hp = p_max_hp
	hp = p_max_hp


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()


func is_alive() -> bool:
	return hp > 0


func fraction() -> float:
	return float(hp) / float(maxi(1, max_hp))
