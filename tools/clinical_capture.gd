extends Node
## Temporary capture autoload: enter the dream, compress the ambulance sequence, and
## screenshot the post-climax CLINICAL apartment. Registered in project.godot only for
## the capture run, then removed.
##   frame 40:  tap N (enter dream)
##   frame ~420: capture clinical apartment after the forced return


var _frames := 0


func _ready() -> void:
	# Compress the interception so the whole climax fits in the capture window.
	await get_tree().process_frame
	var ws := get_tree().root.get_node_or_null("Workspace")
	if ws == null:
		return
	var ambulance := ws.get_node("AmbulanceInterception")
	ambulance.interception_delay = 1.0
	ambulance.escalation_seconds = 0.5


func _process(_delta: float) -> void:
	_frames += 1
	match _frames:
		40:
			_tap(KEY_N)
		420:
			_shot("res://.qwen/tmp/fu_clinical.png")
		440:
			get_tree().quit()


func _shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
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
