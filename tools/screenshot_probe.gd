extends Node
## Temporary verification autoload — captures the dreamscape transition end-to-end.
## Registered in project.godot only for the capture run, then removed.
##   frame 40:  seed apartment
##   frame 60:  N (dev key) forces the dreamscape transition (3.5 s of fades)
##   frame 300: valley, settled
##   frame 320: N again forces the return
##   frame 560: apartment again, post-return crash state
## get_viewport().get_texture().get_image() reads the engine's own render target, so
## unlike screencapture it needs no macOS screen-recording permission.

var _frames := 0


func _process(_delta: float) -> void:
	_frames += 1
	match _frames:
		40:
			_shot("res://.qwen/tmp/fu_seed.png")
		60:
			_tap(KEY_N)
		300:
			_shot("res://.qwen/tmp/fu_valley.png")
		320:
			_tap(KEY_N)
		560:
			_shot("res://.qwen/tmp/fu_return.png")
		580:
			get_tree().quit()


func _shot(path: String) -> void:
	# Headless runs use the dummy renderer: no render target, and calling get_image()
	# on it logs an engine-level ERROR before returning null. Skip the whole probe path
	# when the display server is headless so smoke tests stay clean.
	if DisplayServer.get_name() == "headless":
		return
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		print("SHOT skipped (no render target)")
		return
	var err := img.save_png(path)
	print("SHOT ", path, " err=", err)


func _tap(key: int) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.physical_keycode = key
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.physical_keycode = key
	Input.parse_input_event(up)
