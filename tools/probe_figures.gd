extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-11-03: "multiple instances of NPCs, the character phasing through things
## or getting clipped, some models collide". In every space he plays in: no two people
## stand inside each other, nobody stands inside a wall or a prop, no stranger is a copy
## of someone with a name (the friend), and he can't walk through the people the space
## calls solid.
##
## Run: godot --headless --path . -s tools/probe_figures.gd

## Two people closer than this (in their own scale, shoulder to shoulder) overlap.
const PERSONAL := 0.5


func _title() -> String:
	return "FIGURES PROBE"


func _run() -> void:
	var dialogue := node("DialogueRunner") as DialogueRunner
	dialogue.clear_queue()
	if dialogue.is_running:
		dialogue.cancel()
	await wait(0.3)
	section("the apartment")
	_check_furniture(node("Apartment"))
	section("the carriage")
	_check_space(node("MetroCarriage"))
	section("the rooftop")
	_check_space(node("RooftopLounge"))
	section("the evening")
	var evening := (load("res://scenes/evening.tscn") as PackedScene).instantiate()
	evening.set_process(false)  # the layout only: no film
	root.add_child(evening)
	await wait(0.5)
	_check_space(evening.find_child("Layout", true, false))
	evening.queue_free()


func _check_space(space: Node) -> void:
	if space == null:
		check("space exists", false)
		return
	var figures: Array[StreetFigure] = []
	for f in space.find_children("*", "StreetFigure", true, false):
		figures.append(f)
	var overlaps: Array[String] = []
	for i in figures.size():
		for j in range(i + 1, figures.size()):
			var a := figures[i]
			var b := figures[j]
			if not a.is_visible_in_tree() or not b.is_visible_in_tree():
				continue
			var scale := a.global_transform.basis.get_scale().x
			var d := Vector2(
				a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z
			)
			if d.length() < PERSONAL * scale:
				overlaps.append("%s/%s %.2f" % [a.name, b.name, d.length() / scale])
	check(
		"%d people, none inside another %s" % [figures.size(), overlaps.slice(0, 4)],
		overlaps.is_empty()
	)
	var clones: Array[String] = []
	for f in figures:
		if f.dress == StreetFigure.Dress.FRIEND and not str(f.name).begins_with("Friend"):
			clones.append(str(f.name))
	check("no stranger dressed as the friend %s" % [clones.slice(0, 4)], clones.is_empty())
	var inside: Array[String] = []
	var space_state := (space as Node3D).get_world_3d().direct_space_state
	for f in figures:
		var scale := f.global_transform.basis.get_scale().x
		var q := PhysicsShapeQueryParameters3D.new()
		var probe := CylinderShape3D.new()
		probe.radius = 0.12 * scale
		probe.height = 1.0 * scale
		q.shape = probe
		q.transform = Transform3D(Basis(), f.global_position + Vector3(0, 0.9 * scale, 0))
		q.collision_mask = PhysicsLayers.WORLD
		var own := f.find_child("Body", false, false)
		if own != null:
			q.exclude = [(own as CollisionObject3D).get_rid()]
		# Only this space's own walls and props: the carriage and the rooftop are built
		# where the room is, and the room is live while they are checked.
		for hit in space_state.intersect_shape(q, 8):
			if space.is_ancestor_of(hit["collider"]):
				inside.append("%s %s" % [f.name, f.global_position])
				break
	check("nobody inside a wall or a prop %s" % [inside.slice(0, 4)], inside.is_empty())


## Every piece of furniture in his reach (anything 0.3–2.5 m tall inside the room; floor
## debris is lower) has a body: he walked through the bed, the cabinet and the easel.
func _check_furniture(apt: Node3D) -> void:
	var space := apt.get_world_3d().direct_space_state
	var ghosts: Array[String] = []
	var seen := 0
	for mi: MeshInstance3D in apt.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var box := mi.global_transform * mi.get_aabb()
		var c := box.get_center()
		var small := box.size.y < 0.3 or box.size.y > 2.5 or box.size.x > 6 or box.size.z > 6
		if small or absf(c.x) > 4.3 or absf(c.z) > 3.3:
			continue
		seen += 1
		var q := PhysicsShapeQueryParameters3D.new()
		var probe := BoxShape3D.new()
		probe.size = Vector3(box.size.x, 0.4, box.size.z) * 0.8
		q.shape = probe
		q.transform = Transform3D(Basis(), Vector3(c.x, 0.4, c.z))
		q.collision_mask = PhysicsLayers.WORLD
		if space.intersect_shape(q, 1).is_empty():
			ghosts.append(str(apt.get_path_to(mi)))
	check("%d pieces of furniture, all solid %s" % [seen, ghosts.slice(0, 4)], ghosts.is_empty())
