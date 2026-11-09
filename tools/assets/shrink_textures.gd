extends SceneTree
## Shrink the CC0 textures under assets/third_party so they're small enough to live in git.
##
## A texture whose longest edge is over MAX_SIDE is resized down (Lanczos) in place and keeps
## its format: JPEG at quality 0.9, PNG as is. Idempotent: a texture already at or under the
## limit is left alone. The downloads in assets/_downloads keep full resolution, so this can
## always be rerun. Fab is skipped: its licence keeps those files out of git anyway. Godot does
## the resizing, so it needs no extra Python packages on either machine.
##
## Run: godot --headless --path . -s tools/assets/shrink_textures.gd -- [max_side=1024] [dry]

const ROOT := "res://assets/third_party"
const MAX_SIDE := 1024
const JPEG_QUALITY := 0.9
## JPEGs bigger than this (bytes) are re-encoded at RECOMPRESS_QUALITY: normal maps at 1K
## are ~1 MB each at 0.9, and the loss at 0.8 is invisible once lit.
const RECOMPRESS_OVER := 300000
const RECOMPRESS_QUALITY := 0.8


func _init() -> void:
	var max_side := MAX_SIDE
	var dry := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("max_side="):
			max_side = int(arg.get_slice("=", 1))
		elif arg == "dry":
			dry = true
	var stats := [0, 0, 0]  # changed, bytes before, bytes after
	for path in _textures(ROOT):
		var size := FileAccess.get_file_as_bytes(path).size()
		var image := Image.load_from_file(path)
		var too_big := image != null and maxi(image.get_width(), image.get_height()) > max_side
		var heavy_jpg := (
			image != null and path.get_extension().to_lower() != "png" and size > RECOMPRESS_OVER
		)
		if image == null or not (too_big or heavy_jpg):
			continue
		if not too_big:
			# Same pixels, smaller file.
			if not dry:
				image.save_jpg(path, RECOMPRESS_QUALITY)
				stats[0] += 1
				stats[1] += size
				stats[2] += FileAccess.get_file_as_bytes(path).size()
			continue
		stats[0] += 1
		stats[1] += size
		if dry:
			continue
		var scale := float(max_side) / float(maxi(image.get_width(), image.get_height()))
		image.resize(
			roundi(image.get_width() * scale),
			roundi(image.get_height() * scale),
			Image.INTERPOLATE_LANCZOS
		)
		if path.get_extension().to_lower() == "png":
			image.save_png(path)
		else:
			image.save_jpg(path, JPEG_QUALITY)
		stats[2] += FileAccess.get_file_as_bytes(path).size()
	if dry:
		print("%d textures over %dpx (%.0f MB)" % [stats[0], max_side, stats[1] / 1e6])
	else:
		print("shrunk %d textures: %.0f MB → %.0f MB" % [stats[0], stats[1] / 1e6, stats[2] / 1e6])
	quit(0)


## Every texture under `dir` (recursively), skipping Fab (its licence keeps it out of git).
func _textures(dir: String) -> Array[String]:
	var found: Array[String] = []
	var access := DirAccess.open(dir)
	if access == null:
		return found
	for file in access.get_files():
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			found.append(dir.path_join(file))
	for sub in access.get_directories():
		if sub != "fab" and not sub.begins_with("."):
			found.append_array(_textures(dir.path_join(sub)))
	return found
