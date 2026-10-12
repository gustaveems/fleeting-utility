extends SceneTree
## Ticket-08 collision-layer probe. Verifies the question I got wrong by assumption:
## can each new Area3D interactable actually DETECT the player?
##
## Rule 4 (API accuracy) means: do not trust a layer/mask number you did not read from
## the object that has to match it. This script reads the live values out of the running
## scene and then moves the player into each zone to see whether body_entered fires.

var _ws: Node
var _player: PlayerMovement
var _pass := 0
var _fail := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/workspace.tscn")
	_ws = scene.instantiate()
	root.add_child(_ws)
	await create_timer(0.5).timeout

	_player = _ws.get_node("Player")

	print("=== live collision identity ===")
	print(
		(
			"  Player.collision_layer = %d   collision_mask = %d"
			% [_player.collision_layer, _player.collision_mask]
		)
	)

	_check_zone(
		"TrivialObject", _ws.get_node_or_null("Apartment/TrivialObject"), Vector3(1.5, 0.0, 1.0)
	)
	_check_zone(
		"ApartmentDoor", _ws.get_node_or_null("Apartment/ApartmentDoor"), Vector3(0.0, 0.0, -3.5)
	)
	_check_zone("ReturnDoor (park)", _find_park_door(), Vector3(0.0, 0.0, 0.0))
	_check_zone("LuxuryShoes.proximity", null, Vector3(2.0, 0.0, -2.5))

	print("\n========================================")
	print(" COLLISION PROBE  %d PASS / %d FAIL" % [_pass, _fail])
	print("========================================")
	quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


## Teleport the player to the zone centre, let physics run, and see if body_entered
## fired. Detection is the only thing that matters for an interactable.
func _check_zone(label: String, node: Node, at: Vector3) -> void:
	print("\n--- %s ---" % label)
	if node == null:
		print("      node not found in tree -- SKIPPED")
		return
	if not (node is Area3D):
		print("      not an Area3D (%s) -- SKIPPED" % node.get_class())
		return
	var area := node as Area3D
	print(
		(
			"      layer=%d mask=%d monitoring=%s"
			% [area.collision_layer, area.collision_mask, str(area.monitoring)]
		)
	)

	# Does the mask include any bit of the player's layer?
	var overlap_bits := area.collision_mask & _player.collision_layer
	_check(
		(
			"%s mask intersects player layer (mask=%d & layer=%d = %d)"
			% [label, area.collision_mask, _player.collision_layer, overlap_bits]
		),
		overlap_bits != 0
	)

	# Empirical: move the player in and count bodies the area reports.
	var home := _player.global_position
	_player.global_position = at + Vector3(0.0, 0.4, 0.0)
	await create_timer(0.35).timeout
	var seen := area.get_overlapping_bodies()
	var found_player := false
	for b in seen:
		if b == _player:
			found_player = true
	_check(
		"%s actually detects player when standing in it (n=%d)" % [label, seen.size()], found_player
	)
	_player.global_position = home
	await create_timer(0.2).timeout


## The park subtree is created inside CorporateParkManager._ready().
func _find_park_door() -> Area3D:
	var pm := _ws.get_node_or_null("CorporateParkManager")
	if pm == null:
		return null
	var park := pm.get_node_or_null("CorporatePark")
	if park == null:
		return null
	return park.get_node_or_null("ReturnDoor") as Area3D
