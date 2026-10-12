extends "res://tools/lib/verify_harness.gd"
## Lock-ownership regression gate (LockSet).
##
## Before named locks, `input_locked` / `is_locked` were bools with six writers and the
## last writer won. Each check below is one of those collisions.
##
## Run: godot --headless --path . -s tools/probe_locks.gd


func _title() -> String:
	return "LOCK OWNERSHIP PROBE"


func _run() -> void:
	var player := node("Player") as PlayerMovement
	var ic := node("InteractionController") as InteractionController
	var soothing := node("SelfSoothingController") as SelfSoothingController
	var camera := node("WorkspaceCamera") as WorkspaceCamera

	section("LockSet semantics")
	var locks := LockSet.new()
	locks.acquire(&"a")
	locks.acquire(&"a")
	locks.acquire(&"b")
	locks.release(&"a")
	check("still locked while another owner holds", locks.is_locked())
	locks.release(&"never_taken")
	locks.release(&"b")
	check("unlocked once every owner released", not locks.is_locked())

	section("compulsion does not release the post-climax interaction lock")
	ic.lock(&"climax")
	soothing._enter_compulsion()
	check("compulsion locked player input", player.input_locked)
	soothing._exit_compulsion()
	check("player input released by compulsion end", not player.input_locked)
	check("interactions STILL locked by climax", ic.is_locked)
	ic.unlock(&"climax")

	section("overlapping input locks")
	player.lock_input(&"dream_transition")
	player.lock_input(&"hesitation")
	player.unlock_input(&"dream_transition")
	check("hesitation lock survives a transition unlock", player.input_locked)
	player.unlock_input(&"hesitation")
	check("input free once both released", not player.input_locked)

	section("hesitation restores the shake it found")
	var hesitation := node("HesitationController") as HesitationController
	camera.withdrawal_shake = 0.02
	hesitation.initiate_hesitation()
	var visions := node("DualVisionController") as DualVisionController
	await visions.visions_ended
	await wait(0.1)
	check(
		"post-climax tremor restored (%.3f)" % camera.withdrawal_shake,
		is_equal_approx(camera.withdrawal_shake, 0.02)
	)
