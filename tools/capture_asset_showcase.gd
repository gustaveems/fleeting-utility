extends "res://tools/lib/verify_harness.gd"
## The asset showcase: checks every showcased third-party file loaded, and (windowed) saves
## an overview, one frame per pack row and close-ups along each row → tools/out/showcase_*.png.
##
## Run: godot --path . -s tools/capture_asset_showcase.gd   (headless: checks only)


func _scene_path() -> String:
	return "res://scenes/asset_showcase.tscn"


func _title() -> String:
	return "CAPTURE ASSET SHOWCASE"


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var s := current_scene
	check("showcase loaded assets", s.loaded > 0)
	check("no missing assets (%s)" % ", ".join(s.missing), s.missing.is_empty())
	await wait(3.0)
	for i in s.views.size():
		s.frame(i)
		await wait(1.0)
		await capture("showcase_%d.png" % i)
	# Close-ups: walk each row in segments about one screen wide.
	for r in s.rows_info.size():
		var info: Array = s.rows_info[r]
		var z: float = info[1]
		var length: float = info[2]
		var tall: float = maxf(info[3], 1.5)
		var seg := clampf(tall * 3.0, 8.0, 30.0)
		var x := seg * 0.5
		var k := 0
		while x < length + seg * 0.5:
			s.frame_at(Vector3(x, tall * 0.9, z + seg * 0.75), Vector3(x, tall * 0.35, z))
			await wait(0.6)
			await capture("showcase_row%d_%02d.png" % [r + 1, k])
			x += seg
			k += 1
