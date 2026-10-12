extends SceneTree
## Ticket-08 reachability + hidden-collision probe.
##
## Two questions static reading cannot answer:
##  1. Is each interactable physically inside the player's movement clamp, or did I
##     author it beyond room_half_extents where no one can stand?
##  2. Does the park subtree, hidden at boot, still put colliders inside the apartment?

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

	print("Player extents (X,Z half) = %s   capsule radius ~0.28" % str(_player.room_half_extents))
	print("Player start = %s\n" % str(_player.global_position))

	_reachable("TrivialObject", Vector3(1.5, 0.0, 1.0))
	_reachable("ApartmentDoor", Vector3(0.0, 0.0, -3.5))
	_reachable("LuxuryShoes (planned)", Vector3(2.0, 0.0, -2.5))

	print("\n--- hidden park colliding inside the apartment? ---")
	var pm := _ws.get_node_or_null("CorporateParkManager")
	if pm == null:
		print("  CorporateParkManager missing")
	else:
		var park := pm.get_node_or_null("CorporatePark")
		var door := park.get_node_or_null("ReturnDoor") as Area3D if park != null else null
		if door == null:
			print("  ReturnDoor missing")
		else:
			var cs := door.get_node_or_null("CollisionShape3D") as CollisionShape3D
			print(
				(
					"      ReturnDoor visible=%s (park visible=%s) shape.disabled=%s"
					% [
						str(door.visible),
						str(park.visible),
						str(cs.disabled) if cs != null else "?"
					]
				)
			)
			_check(
				"hidden park door is DISABLED at boot (no phantom zone)", cs != null and cs.disabled
			)
			# Does the player, at apartment origin, sit inside the hidden door's box?
			var space := _player.get_world_3d().direct_space_state
			var sha := SphereShape3D.new()
			sha.radius = 0.28
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sha
			q.transform = Transform3D(Basis(), _player.global_position + Vector3(0, 0.4, 0))
			q.collide_with_areas = true
			var hits := space.intersect_shape(q, 8)
			var phantom: Array[String] = []
			for h in hits:
				var c: Object = h.get("collider")
				if c != null and c is Area3D and str(c.get_path()).contains("CorporatePark"):
					phantom.append(str(c.name))
			_check(
				(
					"no park Area3D overlaps player in the apartment (found: %s)"
					% (", ".join(phantom) if phantom.size() > 0 else "none")
				),
				phantom.is_empty()
			)

	print("\n--- apartment walls: does the door sit behind a solid wall? ---")
	var space2 := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3(0.0, 0.6, 0.0)
	var to := Vector3(0.0, 0.6, -3.5)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit := space2.intersect_ray(query)
	if hit.is_empty():
		print("      ray to door: no wall hit")
	else:
		var col: Object = hit.get("collider")
		print(
			(
				"      ray to door blocked by %s at %s"
				% [str(col.get_name()) if col != null else "?", str(hit.get("position"))]
			)
		)
	_check("line of sight from player to ApartmentDoor is clear", hit.is_empty())

	print("\n========================================")
	print(" REACHABILITY PROBE  %d PASS / %d FAIL" % [_pass, _fail])
	print("========================================")
	quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


## A point is reachable if the player centre can get within capsule radius of it while
## staying inside the room clamp.
func _reachable(label: String, p: Vector3) -> void:
	var hx := _player.room_half_extents.x
	var hz := _player.room_half_extents.y
	var near_x := absf(p.x) - 0.28 <= hx
	var near_z := absf(p.z) - 0.28 <= hz
	_check(
		(
			"%s at (%.1f, %.1f) reachable (|x|-%.2f=%.2f<=%.2f, |z|-%.2f=%.2f<=%.2f)"
			% [label, p.x, p.z, 0.28, absf(p.x) - 0.28, hx, 0.28, absf(p.z) - 0.28, hz]
		),
		near_x and near_z
	)
