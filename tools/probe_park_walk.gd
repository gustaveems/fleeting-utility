extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-11-03 (third): "after day 6 ... I just spawn outside the bedroom,
## walking in an empty space". The walk kept wherever he stood: he arrived in the park
## at the apartment's coordinates and came home at the park's, outside the walls. He
## arrives on the park's path, comes home where he left, and the park is framed low
## and close so the forest reads tall.
##
## Run: godot --headless --path . -s tools/probe_park_walk.gd


func _title() -> String:
	return "PARK WALK PROBE"


func _run() -> void:
	var park := node("CorporateParkManager") as CorporateParkManager
	var player := node("Player") as PlayerMovement
	var camera := ws.find_child("WorkspaceCamera", true, false) as WorkspaceCamera
	await wait(0.3)
	var home := Vector3(1.2, player.global_position.y, -2.4)
	player.global_position = home
	var room_pitch := camera.rotation_degrees.x
	section("into the park")
	park.transition_to_park()
	await wait(0.2)
	var at := player.global_position
	check(
		"arrives on the path %s" % at,
		(
			Vector2(at.x, at.z).distance_to(
				Vector2(CorporateParkManager.START.x, CorporateParkManager.START.z)
			)
			< 0.5
		)
	)
	check(
		"framed lower (pitch %.0f, room %.0f)" % [camera.rotation_degrees.x, room_pitch],
		camera.rotation_degrees.x > room_pitch + 8.0
	)
	section("home again")
	player.global_position = Vector3(14.0, at.y, 11.0)  # wandered far into the park
	park.transition_to_apartment()
	await wait(0.2)
	var back := player.global_position
	check(
		"back where he left %s" % back,
		Vector2(back.x, back.z).distance_to(Vector2(home.x, home.z)) < 0.3
	)
	check(
		"the room's framing again (pitch %.0f)" % camera.rotation_degrees.x,
		is_equal_approx(camera.rotation_degrees.x, room_pitch)
	)
