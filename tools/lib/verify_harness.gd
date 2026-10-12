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
##
## Run: godot --headless --path . -s tools/<script>.gd

const MAIN_SCENE := "res://scenes/workspace.tscn"
const OUT_DIR := "res://tools/out/"
const SETTLE_SECONDS := 0.5

var ws: Node
var passed := 0
var failed := 0


func _initialize() -> void:
	var scene: PackedScene = load(MAIN_SCENE)
	ws = scene.instantiate()
	root.add_child(ws)
	_drive()


func _drive() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await _run()
	print("\n========================================")
	print(" %s  %d PASS / %d FAIL" % [_title(), passed, failed])
	print("========================================")
	quit(1 if failed > 0 else 0)


## Override: the test body. May await.
func _run() -> void:
	pass


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
