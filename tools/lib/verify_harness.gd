extends SceneTree
## Shared base for every headless verify / probe script.
##
## A script opts in with:
##     extends "res://tools/lib/verify_harness.gd"
## and overrides `_run()` (a coroutine) plus, optionally, `_title()`.
## No class_name on purpose: `-s` scripts load by path, so the Import Gate never applies.
##
## The harness instantiates the REAL main scene, waits for it to settle, awaits
## `_run()`, prints a summary and exits non-zero on any failed check, so
## tools/run_all.sh can gate on exit codes.
##
## Headless truths (learned Tickets 05–09):
##   - This script IS the tree: there is no get_tree(); waits use create_timer().
##   - _process is unthrottled headless, so never count frames for timing.
##   - The headless display server has no render target: capture() is a no-op there.
##   - Windowed (captures), the window is QUIET by default: a few pixels in a corner of
##     the screen, borderless, on top, never taking focus, while the game renders its
##     full 1280×720 inside (viewport stretch). macOS stops drawing a covered or hidden
##     window, but not a tiny visible one. `-- loud` shows the normal window.
##
## Run: godot --headless --path . -s tools/<script>.gd

const MAIN_SCENE := "res://scenes/workspace.tscn"
const OUT_DIR := "res://tools/out/"
const SETTLE_SECONDS := 0.5

## Watchdog: a test awaiting a signal that never fires would otherwise hang run_all.
const TIMEOUT_SECONDS := 120.0

## Tests never touch the player's real save: every run gets its own, wiped first.
const TEST_SAVE_PATH := "user://verify_save.json"
const TEST_SETTINGS_PATH := "user://verify_settings.cfg"
## The quiet window: what the game renders at, and the dot on screen.
const RENDER_SIZE := Vector2i(1280, 720)
const QUIET_SIZE := Vector2i(4, 4)

var ws: Node
var passed := 0
var failed := 0


func _initialize() -> void:
	_quiet_window()
	Persistence.save_path = TEST_SAVE_PATH
	wipe_test_save()
	SettingsStore.path = TEST_SETTINGS_PATH
	_remove(TEST_SETTINGS_PATH)
	GameSettings.reset_current()
	var scene: PackedScene = load(_scene_path())
	ws = scene.instantiate()
	root.add_child(ws)
	current_scene = ws  # so change_scene_to_* works (menus, quit to menu)
	# Real seconds (ignore_time_scale): probes may run the game faster than real time.
	create_timer(_timeout_seconds(), true, false, true).timeout.connect(_on_watchdog)
	_drive()


## Captures without a window in your way (see the header). Headless: nothing to do.
func _quiet_window() -> void:
	if DisplayServer.get_name() == "headless" or "loud" in OS.get_cmdline_user_args():
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = RENDER_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	for flag in [
		DisplayServer.WINDOW_FLAG_BORDERLESS,
		DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,
		DisplayServer.WINDOW_FLAG_NO_FOCUS,
	]:
		DisplayServer.window_set_flag(flag, true)
	DisplayServer.window_set_size(QUIET_SIZE)
	var screen := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(screen.end - QUIET_SIZE)


func wipe_test_save() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		_remove(TEST_SAVE_PATH + suffix)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Quit-and-relaunch inside one test: free the whole game and boot it again (which
## auto-loads the save, if there is one).
func reboot() -> void:
	ws.queue_free()
	await process_frame
	await process_frame
	var scene: PackedScene = load(_scene_path())
	ws = scene.instantiate()
	root.add_child(ws)
	current_scene = ws
	await create_timer(SETTLE_SECONDS).timeout


func _drive() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await _run()
	print("\n========================================")
	print(" %s  %d PASS / %d FAIL" % [_title(), passed, failed])
	print("========================================")
	quit(1 if failed > 0 else 0)


## Override for long probes (the full playthrough).
func _timeout_seconds() -> float:
	return TIMEOUT_SECONDS


func _on_watchdog() -> void:
	print(
		(
			"\n  [FAIL] WATCHDOG: no result after %.0f s (awaiting a signal that never fired?)"
			% _timeout_seconds()
		)
	)
	print(" %s  %d PASS / %d FAIL" % [_title(), passed, failed + 1])
	quit(2)


## Override: the test body. May await.
func _run() -> void:
	pass


## Override: the scene to boot (default: the game itself, skipping the menu).
func _scene_path() -> String:
	return MAIN_SCENE


## Override: the summary-line label.
func _title() -> String:
	return "VERIFY"


func section(label: String) -> void:
	print("\n--- %s ---" % label)


func check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


## Debug lookup for tests only. Production code must use @export refs (Ironclad Rule 3).
func node(path: NodePath) -> Node:
	return ws.get_node_or_null(path)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Press-and-release an input action through the real input pipeline.
func tap_action(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Guards Ironclad Rule 4: fail loudly if an engine property we write does not exist.
func check_property_exists(obj: Object, property: StringName) -> void:
	var found := false
	for p in obj.get_property_list():
		if p["name"] == property:
			found = true
			break
	check("%s has property '%s'" % [obj.get_class(), property], found)


## True when a physics ray between the two points hits a body (areas ignored).
func ray_hits(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var space := (ws as Node3D).get_world_3d().direct_space_state if ws is Node3D else null
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, exclude)
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()


## Count live (enabled) CollisionShape3D nodes under `node`.
func live_shapes(under: Node) -> int:
	var count := 0
	for child in under.find_children("*", "CollisionShape3D", true, false):
		if not (child as CollisionShape3D).disabled:
			count += 1
	return count


## Save the current frame. No-op headless (dummy renderer has no render target).
## Run windowed for captures: godot --path . -s tools/<script>.gd
func capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("  [SKIP] capture %s (headless)" % file_name)
		return
	await process_frame
	await process_frame
	var tex := root.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		print("  [SKIP] capture %s (no render target)" % file_name)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err := img.save_png(OUT_DIR + file_name)
	print("  [SHOT] %s err=%d" % [OUT_DIR + file_name, err])
