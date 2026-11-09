class_name DinnerDressing
extends RefCounted
## PRESENTATION — the members' club's materials and small things (polish pass, 2026-11-06:
## a warm box with flat walls, green sticks on the shelves and the sky over it). Real metres
## in the layout's world. Every texture and model is optional: without its pack the room
## keeps its plain colour.


## Dark oak panelling (ambientCG Wood060).
static func panel() -> StandardMaterial3D:
	return _textured("Wood060", Color(0.8, 0.62, 0.5), 0.5, 0.22)


## Polished stone, a shade off black under the low light (ambientCG Marble012).
static func stone() -> StandardMaterial3D:
	return _textured("Marble012", Color(0.5, 0.45, 0.4), 0.16, 0.3)


## The ribbed red of the rug and the chairs (ambientCG Fabric026).
static func upholstery() -> StandardMaterial3D:
	return _textured("Fabric026", Color(0.72, 0.5, 0.48), 0.9, 1.6)


## A lid on the room, the bottles lit from behind, a chandelier over the table, the brass
## and a plant.
static func dress(world: Node3D, at: Vector3, bar_shelves: Array) -> void:
	_lid(world, at)
	_bar(world, at, bar_shelves)
	var chandelier := CityKit.prop(
		CityKit.polyhaven("Chandelier_01"), world, at + Vector3(0, 3.75, 0), 0.0, 0.0
	)
	if chandelier != null:
		chandelier.scale = Vector3.ONE * 1.15
	var holders := CityKit.prop(
		CityKit.polyhaven("brass_candleholders"), world, at + Vector3(-0.1, 0.77, -0.3), 20.0, 0.0
	)
	if holders != null:
		holders.scale = Vector3.ONE * 0.42
	var goblets := CityKit.prop(
		CityKit.polyhaven("brass_goblets"), world, at + Vector3(-0.35, 0.77, 0.3), 200.0, 0.0
	)
	if goblets != null:
		goblets.scale = Vector3.ONE * 0.5
	CityKit.prop(
		CityKit.polyhaven("potted_plant_01"), world, at + Vector3(-6.2, 0, -5.0), 40.0, 0.0
	)


static func _lid(world: Node3D, at: Vector3) -> void:
	var lid := MeshInstance3D.new()
	lid.name = "DinnerCeiling"
	var box := BoxMesh.new()
	box.size = Vector3(14.4, 0.2, 12.4)
	lid.mesh = box
	lid.material_override = panel()
	lid.position = at + Vector3(0, 5.1, 0)
	world.add_child(lid)


## Rows of real bottles (one MultiMesh) on the bar's shelves, a warm strip behind each.
static func _bar(world: Node3D, at: Vector3, shelves: Array) -> void:
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color(1.0, 0.8, 0.5)
	strip.emission_enabled = true
	strip.emission = Color(1.0, 0.72, 0.42)
	strip.emission_energy_multiplier = 1.4
	var placed: Array[Transform3D] = []
	for y: float in shelves:
		var light := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(5.6, 0.03, 0.03)
		light.mesh = bar
		light.material_override = strip
		light.position = at + Vector3(2, y + 0.42, 5.94)
		world.add_child(light)
		for k in 7:
			placed.append(
				Transform3D(
					Basis(Vector3.UP, PI + k), at + Vector3(-0.3 + k * 0.76, y + 0.02, 5.82)
				)
			)
	Forest.plant(world, CityKit.polyhaven("wine_bottles_01"), placed)


static func _textured(
	id: String, tint: Color, roughness: float, tiling: float
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = roughness
	var color := CityKit.surface(id, "Color")
	if ResourceLoader.exists(color):
		m.albedo_texture = load(color)
		m.normal_enabled = true
		m.normal_texture = load(CityKit.surface(id, "NormalGL"))
		m.normal_scale = 0.45
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * tiling
	return m
