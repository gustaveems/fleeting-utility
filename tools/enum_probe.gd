extends SceneTree
## Throwaway engine-introspection probe (not a game class — deliberately no class_name).
## Run: godot --headless --path . -s res://tools/enum_probe.gd
## FastNoiseLite enum member names as the engine actually exposes them.
##
## NOTE: quit() inside _init() never runs — the loop is not started yet, so the call is
## ignored and --headless hangs. Introspection belongs in _process(), whose true return
## value is the official "stop" signal.


func _process(_delta: float) -> bool:
	var noise := FastNoiseLite.new()
	for prop in noise.get_property_list():
		var pname: String = prop["name"]
		if pname in ["noise_type", "fractal_type", "cellular_return_type"]:
			print(pname, " -> ", prop["hint_string"])
	noise.free()
	return true
