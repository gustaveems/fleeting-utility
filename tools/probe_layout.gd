extends "res://tools/lib/verify_harness.gd"
## Layout gate (the layout review, 2026-10-28): in every play space, everything he must
## reach is inside where he can walk, and no two prompts claim the same floor.
##
##   apartment  each interactable's reach overlaps the walkable rect; the room's
##              interactables don't overlap each other (the box drop zone overlapping the
##              bench is handled by the carry lock: see probe_night_zero)
##   valley     every colossus's return zone and every memory anchor is reachable within
##              the dream's bounds (at ±28 m two colossi were out of reach)
##   carriage, rooftop   he arrives inside the walkable rect, the crowds have bodies (asleep
##                       while he's elsewhere) and he never arrives inside one
##
## Run: godot --headless --path . -s tools/probe_layout.gd


func _title() -> String:
	return "LAYOUT PROBE"


func _run() -> void:
	var player := ws.find_child("Player", true, false) as PlayerMovement
	var dm := ws.find_child("DreamscapeManager", true, false) as DreamscapeManager

	section("the apartment")
	var room := _rect(player.room_half_extents)
	var names := ["ApartmentDoor", "Easel", "Cot", "BenchStation", "TrivialObject"]
	var reach: Dictionary = {}
	for n in names:
		var node := ws.find_child(n, true, false)
		var r := _footprint(node)
		reach[n] = r
		check("%s is reachable" % n, r.size != Vector2.ZERO and room.intersects(r))
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = reach[names[i]]
			var b: Rect2 = reach[names[j]]
			check("%s and %s don't share a prompt" % [names[i], names[j]], not a.intersects(b))

	section("the valley")
	var dream := _rect(dm.dreamscape_room_extents)
	var valley := ws.find_child("DreamscapeValley", true, false) as DreamscapeEnvironment
	for i in DreamscapeEnvironment.STATUE_POSITIONS.size():
		var zone := valley.find_child("StatueReturnZone_%d" % i, true, false)
		check("colossus %d's feet are reachable" % i, dream.intersects(_footprint(zone)))
	for anchor in valley.memory_anchors:
		check("%s is reachable" % anchor.name, dream.intersects(_footprint(anchor)))

	section("the carriage and the rooftop")
	var carriage := _rect(Vector2(MetroCarriage.HALF_LENGTH - 0.3, MetroCarriage.HALF_WIDTH - 0.25))
	check("he boards inside the carriage", carriage.has_point(_xz(MetroRide.START)))
	var roof := _rect(Vector2(RooftopLounge.HALF_LENGTH - 0.3, RooftopLounge.HALF_WIDTH - 0.25))
	check("he arrives on the roof", roof.has_point(_xz(RooftopLounge.START)))

	section("the crowds have bodies")
	for world_name in ["MetroCarriage", "RooftopLounge"]:
		var world := ws.find_child(world_name, true, false) as WorldRoot
		var bodies := world.find_children("Body", "StaticBody3D", true, false)
		check("%s: everyone has a body (%d)" % [world_name, bodies.size()], bodies.size() >= 5)
		check("%s: asleep while he's elsewhere (Rule 2)" % world_name, live_shapes(world) == 0)
		var start := MetroRide.START if world_name == "MetroCarriage" else RooftopLounge.START
		var nearest := 99.0
		for b: Node3D in bodies:
			nearest = minf(nearest, _xz(b.global_position).distance_to(_xz(start)))
		check(
			"%s: he doesn't arrive inside someone (%.2f m)" % [world_name, nearest], nearest > 0.45
		)


func _rect(half: Vector2) -> Rect2:
	return Rect2(-half, half * 2.0)


func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## The ground footprint of the first collision shape under `n` (its own, or a child's).
func _footprint(n: Node) -> Rect2:
	if n == null:
		return Rect2()
	var shape: CollisionShape3D = null
	if n is Area3D:
		for c in n.get_children():
			if c is CollisionShape3D:
				shape = c
	if shape == null:
		for c in n.find_children("*", "CollisionShape3D", true, false):
			if c.get_parent() is Area3D:
				shape = c
				break
	if shape == null:
		return Rect2()
	var half := Vector2(0.5, 0.5)
	if shape.shape is BoxShape3D:
		var s := (shape.shape as BoxShape3D).size
		half = Vector2(s.x, s.z) * 0.5
	elif shape.shape is CylinderShape3D:
		var r := (shape.shape as CylinderShape3D).radius
		half = Vector2(r, r)
	elif shape.shape is SphereShape3D:
		var r2 := (shape.shape as SphereShape3D).radius
		half = Vector2(r2, r2)
	var c := _xz(shape.global_position)
	return Rect2(c - half, half * 2.0)
