extends "res://tools/lib/verify_harness.gd"
## The title screen → tools/out/title.png.
##
## Run: godot --path . -s tools/capture_title.gd   (windowed)


func _scene_path() -> String:
	return "res://scenes/boot.tscn"


func _title() -> String:
	return "CAPTURE TITLE"


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await wait(4.0)
	await capture("title.png")
