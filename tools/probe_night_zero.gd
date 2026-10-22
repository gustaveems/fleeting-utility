extends "res://tools/lib/verify_harness.gd"
## Ticket-16 Phase 1 probe: Night Zero. Direct boots never start it; arriving from the
## prologue and signing the lease does. The friend is in the room, three boxes wait by
## the door; carried to the west wall they each land, then the invitation plays and the
## chapter ends with him free to move.
##
## Run: godot --headless --path . -s tools/probe_night_zero.gd


func _title() -> String:
	return "NIGHT ZERO PROBE"


func _run() -> void:
	var nz := ws.find_child("NightZero", true, false) as NightZero
	check("a direct boot does not start Night Zero", nz != null and not nz.is_running)

	section("arriving from the prologue")
	LeaseSigning.pending = true
	await reboot()
	nz = ws.find_child("NightZero", true, false) as NightZero
	var player := ws.find_child("Player", true, false) as PlayerMovement
	var ended := [false]
	nz.finished.connect(func(): ended[0] = true)
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(LeaseSigning.HOLD_SECONDS + 0.4)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await wait(0.3)
	check("signing the lease starts Night Zero", nz.is_running)
	check("the friend is in the room", nz.friend != null and nz.friend.is_inside_tree())
	check("three boxes wait by the door", nz.boxes.size() == NightZero.BOX_COUNT)
	check(
		"the friend talks as you move in",
		(ws.find_child("HeadCall", true, false) as HeadCall).is_playing
	)

	section("carrying the boxes")
	var zone := NightZero.DROP_ZONE
	var target := Vector3(zone.get_center().x + 0.3, 0, zone.get_center().y)
	for box in nz.boxes:
		check("he picks up a box", box.try_interact() and box.carried)
		check("one box at a time", not nz.boxes.any(func(b): return b != box and b.can_interact()))
		await wait(0.1)
		player.global_position = nz.to_global(target)
		nz.drop_carried()
		await wait(0.1)
	check("all three landed by the west wall (%d)" % nz.placed, nz.placed == NightZero.BOX_COUNT)
	check("he is held for the invitation", player.input_locked)

	section("the invitation")
	(ws.find_child("HeadCall", true, false) as HeadCall).stop()
	await wait(0.3)
	check("the chapter ends", ended[0] and not nz.is_running)
	check("he can move again", not player.input_locked)
	check("the friend has gone", nz.friend == null)
