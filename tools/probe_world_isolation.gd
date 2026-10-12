extends "res://tools/lib/verify_harness.gd"
## World-isolation regression gate. It replaces invisible_walls_probe,
## ticket08_collision_probe, ticket08_reach_probe and ticket08_tree_dump.
##
## One question, asked of every world swap: does the hidden world truly leave the game?
##   A. Hidden apartment walls stop blocking in the valley and come back on return.
##   B. Every interactable Area3D can actually detect the player (layer/mask match plus
##      an empirical overlap, standing at the closest point the movement clamp allows).
##   C. The park, hidden at boot, has no live Area3D overlapping the apartment.
##   E. Colliders that gameplay disabled (the ransacked bench) stay disabled through a
##      Dual Vision cycle.
##   F. The apartment AtmosphereController does not write into the valley Environment.
##
## Run: godot --headless --path . -s tools/probe_world_isolation.gd

var _player: PlayerMovement
var _manager: DreamscapeManager


func _title() -> String:
	return "WORLD ISOLATION PROBE"


func _run() -> void:
	_player = node("Player")
	_manager = node("DreamscapeManager")
	await _test_interactables_detect_player()
	_test_hidden_park_no_phantoms()
	await _test_valley_isolation()
	await _test_ransacked_colliders_survive_dual_vision()


# ------------------------------------------------------------------- B. detection
func _test_interactables_detect_player() -> void:
	section("B. interactables detect the player")
	print("  player layer=%d mask=%d" % [_player.collision_layer, _player.collision_mask])
	await _check_zone("TrivialObject", node("Apartment/TrivialObject"), Vector3(1.5, 0, 1.0))
	await _check_zone("ApartmentDoor", node("Apartment/ApartmentDoor"), Vector3(0, 0, -3.5))


func _check_zone(label: String, area_node: Node, at: Vector3) -> void:
	var area := area_node as Area3D
	check("%s exists as Area3D" % label, area != null)
	if area == null:
		return
	check(
		(
			"%s mask (%d) intersects player layer (%d)"
			% [label, area.collision_mask, _player.collision_layer]
		),
		(area.collision_mask & _player.collision_layer) != 0
	)
	var home := _player.global_position
	var ext := _player.room_half_extents
	var reachable := Vector3(clampf(at.x, -ext.x, ext.x), 0.0, clampf(at.z, -ext.y, ext.y))
	_player.global_position = reachable
	await wait(0.35)
	check("%s detects player at nearest reachable point" % label, area.overlaps_body(_player))
	_player.global_position = home
	await wait(0.2)


# ------------------------------------------------------------------- C. park phantoms
func _test_hidden_park_no_phantoms() -> void:
	section("C. hidden park leaves no live areas in the apartment")
	var park := node("CorporateParkManager/CorporatePark")
	check("CorporatePark exists", park != null)
	if park == null:
		return
	var live_areas := 0
	for a in park.find_children("*", "Area3D", true, false):
		if (a as Area3D).monitoring and live_shapes(a) > 0:
			live_areas += 1
	check(
		"no monitoring Area3D with live shapes under hidden park (%d)" % live_areas, live_areas == 0
	)


# ------------------------------------------------------------------- A + F. valley
func _test_valley_isolation() -> void:
	section("A/F. valley: apartment walls and atmosphere leave the world")
	var valley_env := _manager.valley_environment
	var fog_before := valley_env.fog_light_color
	var ambient_before := valley_env.ambient_light_color

	await _manager.transition_to_dreamscape()
	check("entered dreamscape", _manager.in_dreamscape())
	var eye := _player.global_position + Vector3(0.0, 0.5, 0.0)
	check(
		"hidden east wall does not block",
		not ray_hits(eye, Vector3(5.5, 0.5, 0.0), [_player.get_rid()])
	)
	await wait(0.5)
	check(
		"valley fog colour untouched by apartment atmosphere",
		valley_env.fog_light_color == fog_before
	)
	check(
		"valley ambient untouched by apartment atmosphere",
		valley_env.ambient_light_color == ambient_before
	)

	await _manager.return_to_workspace()
	eye = _player.global_position + Vector3(0.0, 0.5, 0.0)
	check(
		"apartment east wall blocks again",
		ray_hits(eye, Vector3(5.5, 0.5, 0.0), [_player.get_rid()])
	)


# ------------------------------------------------------------------- E. dual vision
func _test_ransacked_colliders_survive_dual_vision() -> void:
	section("E. ransacked bench stays non-solid through Dual Visions")
	var ransacked := node("RansackedStateManager") as RansackedStateManager
	var visions := node("DualVisionController") as DualVisionController
	var bench := node("Apartment/BenchArea/CraftingBench")
	check(
		"ransack, visions and bench present",
		ransacked != null and visions != null and bench != null
	)
	if ransacked == null or visions == null or bench == null:
		return
	ransacked._on_return_from_walk()
	check("ransack disabled bench colliders", live_shapes(bench) == 0)
	var ended := [false]
	visions.visions_ended.connect(func(): ended[0] = true)
	visions.start_visions()
	for i in 40:
		if ended[0]:
			break
		await wait(0.25)
	check("visions ended", ended[0])
	check(
		"bench colliders still disabled after visions (%d live)" % live_shapes(bench),
		live_shapes(bench) == 0
	)
