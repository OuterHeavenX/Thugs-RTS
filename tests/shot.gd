extends SceneTree

## Render-verification: captures the title screen and early gameplay as PNGs.
## Run under Xvfb (the binary needs a display server to render):
##   xvfb-run -a godot --path <project> -s tests/shot.gd

var _frames := 0
var _started_game := false


func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	root.add_child(main_scene.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 90:
		_shot("/tmp/shot_title.png")
	elif _frames == 100 and not _started_game:
		_started_game = true
		var main: Node = root.get_child(root.get_child_count() - 1)
		var title: Object = main.get("_title")
		if title != null:
			title.emit_signal("start_game", "america")
			print("SHOT: match started")
		else:
			print("SHOT: ERROR could not find title node")
	elif _frames == 430:
		_shot("/tmp/shot_game.png")
		print("SHOT: done")
		return true
	return false


func _shot(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(path)
	print("SHOT: saved %s (err=%d)" % [path, err])
