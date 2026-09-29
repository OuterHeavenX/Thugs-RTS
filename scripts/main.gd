extends Node

## Bootstrap: title screen <-> match scene switching.

const TitleScene := preload("res://scenes/title_screen.tscn")
const GameScript := preload("res://scripts/game.gd")

var _title: TitleScreen = null
var _game: Game = null


func _ready() -> void:
	_show_title()


func _show_title() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	_title = TitleScene.instantiate()
	add_child(_title)
	_title.start_game.connect(_on_start_game)


func _on_start_game(faction: String) -> void:
	if _title != null:
		_title.queue_free()
		_title = null
	_game = GameScript.new()
	add_child(_game)
	_game.exit_to_title.connect(_show_title)
	_game.setup_match(faction)
