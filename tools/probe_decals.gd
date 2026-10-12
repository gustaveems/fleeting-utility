extends "res://tools/lib/verify_harness.gd"
## SurfaceDegradation probe: decals must project INTO a surface (Godot 4 Decals project
## along local −Y, with size.y the projection depth), and must stay put while entropy
## changes within one tier.
##
## Run: godot --headless --path . -s tools/probe_decals.gd


func _title() -> String:
	return "DECALS PROBE"


func _run() -> void:
	var decals := node("Apartment/SurfaceDegradation") as SurfaceDegradation
	var entropy := (node("PlayerStateMachine") as PlayerStateMachine).entropy_data
	check("SurfaceDegradation present", decals != null)
	if decals == null:
		return

	entropy.entropy = 95.0
	entropy.entropy_changed.emit(95.0)
	await wait(0.1)
	var active: Array[Decal] = []
	for child in decals.get_children():
		if child is Decal and (child as Decal).visible:
			active.append(child)
	check("all three batches active at 95 (%d decals)" % active.size(), active.size() == 15)

	section("projection goes into a surface")
	# Walls have colliders, so a ray along −Y must hit them. The floor is mesh-only
	# (no collider), so floor decals (y ≈ 0) must simply project straight down.
	var ok := 0
	for d in active:
		var down := -d.global_transform.basis.y.normalized()
		var p := d.global_position
		if p.y < 0.1:
			if down.dot(Vector3.DOWN) > 0.99:
				ok += 1
		elif ray_hits(p - down * 0.05, p + down * (d.size.y * 0.5 + 0.05)):
			ok += 1
	check(
		"every decal projects into its surface (%d/%d)" % [ok, active.size()], ok == active.size()
	)

	section("stable within a tier")
	var before: Array[Transform3D] = []
	for d in active:
		before.append(d.global_transform)
	for value in [95.5, 96.0, 97.0]:
		entropy.entropy = value
		entropy.entropy_changed.emit(value)
	await wait(0.1)
	var moved := 0
	for i in active.size():
		if not active[i].global_transform.is_equal_approx(before[i]):
			moved += 1
	check("no decal moved while entropy stayed in its tier (%d moved)" % moved, moved == 0)

	section("tier drop hides a batch")
	entropy.entropy = 50.0
	entropy.entropy_changed.emit(50.0)
	await wait(0.1)
	var visible := 0
	for child in decals.get_children():
		if child is Decal and (child as Decal).visible:
			visible += 1
	check("only the low batch remains at 50 (%d visible)" % visible, visible == 5)
