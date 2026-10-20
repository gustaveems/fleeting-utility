extends "res://tools/lib/verify_harness.gd"
## Ticket-15 Phase E probe: the lease signing. Booting the game directly shows no lease;
## arriving from the prologue shows it, locks him in place until E is held, then lets go.
##
## Run: godot --headless --path . -s tools/probe_lease.gd


func _title() -> String:
	return "LEASE PROBE"


func _run() -> void:
	var lease := _lease()
	check("booting the game directly shows no lease", lease != null and not lease.is_open)

	section("arriving from the prologue (E still held from the skip)")
	LeaseSigning.pending = true
	Input.action_press(InputActionData.ACTION_INTERACT)
	await reboot()
	await wait(LeaseSigning.HOLD_SECONDS + 0.3)
	Input.action_release(InputActionData.ACTION_INTERACT)
	lease = _lease()
	var player := ws.find_child("Player", true, false) as PlayerMovement
	check("the lease is on screen", lease.is_open and not lease.is_signed)
	check("he cannot move while it is unsigned", player != null and player.input_locked)
	check("the flag is spent", not LeaseSigning.pending)
	check("E held over from the skip does not sign it", not _lease().is_signed)
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(0.5)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await wait(0.3)
	check("a tap does not sign it", not lease.is_signed)
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(LeaseSigning.HOLD_SECONDS + 0.4)
	Input.action_release(InputActionData.ACTION_INTERACT)
	check("holding E signs it", lease.is_signed)
	check("he can move again", not player.input_locked)
	await wait(2.5)
	check("the document fades away", not lease.is_open)


func _lease() -> LeaseSigning:
	return ws.find_child("LeaseSigning", true, false) as LeaseSigning
