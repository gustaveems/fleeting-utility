class_name DreamscapeEnvironment
extends WorldRoot
## PRESENTATION — the autumn valley dreamscape world (Ticket-05).
##
## Everything the dream needs in one toggleable subtree: its own Environment resource
## (high-saturation golden hour), a low warm sun, a 60 m valley floor, and four
## monolithic blood-marked statues with return zones at their bases.
##
## WHY A RESOURCE, NOT A SECOND WorldEnvironment NODE
## -------------------------------------------------
## Godot's behaviour with multiple WorldEnvironment nodes in one viewport is ambiguous
## enough that we do not rely on it. The bootstrap owns ONE WorldEnvironment; the
## DreamscapeManager swaps its `environment` property between the apartment resource
## and `valley_environment` (built here). One node, two resources, no ambiguity.
##
## PLACEHOLDER ART
## ---------------
## Statues are 15 m cylinders with a red collar band — the brief's 50-foot blood-marked
## monoliths, greyboxed. The blood marks are MATERIAL bands, not Decals: decals only
## project onto opaque geometry (Ticket-04 lesson), and a material band cannot fail
## that rule. Replace with GLTF when art exists; the return zones stay as-is.
##
## STARTS DORMANT
## --------------
## set_active(false) at the end of _ready, once every collider exists. The manager
## activates it during the white-out.

## Emitted when the player enters/leaves any statue return zone. DreamscapeManager
## listens to gate the manual-return interact key.
signal statue_proximity_changed(near: bool)

## Statue layout: a loose ring at horizon distance. At the iso camera's 30-degree
## down-tilt, a 15 m monolith only fits in frame from ~30 m out — closer and the top
## crops (confirmed on the first valley render). Horizon-distance also reads as the
## brief's "monolithic" scale instead of garden ornaments.
const STATUE_POSITIONS: Array[Vector3] = [
	Vector3(34.0, 0.0, -12.0),
	Vector3(-28.0, 0.0, -26.0),
	Vector3(-30.0, 0.0, 20.0),
	Vector3(20.0, 0.0, 32.0),
]

## The brief's 50 feet, in metres.
const STATUE_HEIGHT := 15.0
## Real nature (CC0): Quaternius birches with yellow autumn leaves, Poly Haven stones,
## stumps, ferns, branches. Missing packs leave the greybox.
const TREES := "res://assets/third_party/quaternius_trees/"
const YELLOW_LEAVES := TREES + "Birch_Leaves_Yellow.png"
const BARK := TREES + "Birch_Bark.png"
const BARK_DEAD := TREES + "Birch_Bark_Dead.png"
const GROUND_TEX := "res://assets/third_party/quaternius_downtown/models/T_Dirt_BaseColor.png"
const SCATTER: Array = [
	# [poly haven id, count, scale range, blood-marked?]
	["rock_moss_set_01", 10, Vector2(1.0, 2.2), false],
	["rock_moss_set_02", 10, Vector2(1.0, 2.2), false],
	["boulder_01", 6, Vector2(0.8, 1.6), true],
	["stone_01", 8, Vector2(1.2, 2.5), true],
	["tree_stump_01", 6, Vector2(0.9, 1.3), false],
	["dead_tree_trunk", 3, Vector2(0.9, 1.2), false],
	["fern_02", 26, Vector2(0.9, 1.6), false],
	["dry_branches_medium_01", 14, Vector2(0.8, 1.4), false],
]
## Keep the spawn clear (the dream opens at the origin) and the statues' feet open.
const CLEAR_SPAWN := 13.0
const CLEAR_STATUE := 7.5
const SIGHTLINE_CLEAR := 5.0

## The valley's Environment resource. Built in _init (not _ready) so the bootstrap can
## hand it to DreamscapeManager before either node enters the tree.
var valley_environment: Environment

## The four monoliths and the three memory anchors, built in _ready. Typed handles so
## wiring code never looks children up by name.
var statues: Array[StaticBody3D] = []
var memory_anchors: Array[MemoryAnchor] = []

var _near_zone_count: int = 0


func _init() -> void:
	_build_environment()


func _ready() -> void:
	_build_terrain()
	_build_sun()
	_build_statues()
	_build_memory_anchors()
	_build_forest()
	set_active(false)


## ----- ENVIRONMENT ------------------------------------------------------------------


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Late-afternoon sky, saturated to the edge of believability — the dream's opposite
	# of the apartment's near-black green.
	# Look-dev palette (notes.md, Dream): pale mist and white birch, the leaf gold glowing
	# through the fog rather than saturating the frame.
	env.background_color = Color(0.79, 0.77, 0.73)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.74, 0.62)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# Soft warm haze for depth. Denser than the apartment's: at 120 m of plane the fog
	# has to swallow the terrain edge into the sky, or the horizon reads as a cut line
	# (confirmed on the first valley render).
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.78, 0.72)
	env.fog_density = 0.011
	env.fog_sky_affect = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0025

	# High saturation is the whole visual brief for the valley.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	env.glow_enabled = true
	env.glow_strength = 0.4
	env.glow_bloom = 0.1

	valley_environment = env


## ----- TERRAIN + SUN ------------------------------------------------------------------


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "ValleyFloor"
	var plane := PlaneMesh.new()
	# 120 m: the statues sit at ~35 m and the camera far plane opens to 150 m in the
	# valley, so the plane edge must be far enough for fog to swallow it.
	plane.size = Vector2(120.0, 120.0)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.26, 0.12)  # autumn leaf-litter brown-orange
	material.roughness = 0.95
	if ResourceLoader.exists(GROUND_TEX):
		material.albedo_texture = load(GROUND_TEX)
		material.albedo_color = Color(0.8, 0.55, 0.32)  # the dirt warmed to leaf litter
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.25
	ground.material_override = material
	add_child(ground)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.light_color = Color(1.0, 0.82, 0.58)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	# Low angle: 14 degrees above the horizon, raking the statues into long shadows.
	sun.rotation_degrees = Vector3(-14.0, -35.0, 0.0)
	add_child(sun)


## ----- STATUES + RETURN ZONES ----------------------------------------------------------


func _build_statues() -> void:
	for i in range(STATUE_POSITIONS.size()):
		_build_statue(i, STATUE_POSITIONS[i])


func _build_statue(index: int, origin: Vector3) -> void:
	var statue := StaticBody3D.new()
	statue.name = "Statue_%d" % index
	statue.position = origin

	var body := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 1.4
	cylinder_shape.height = STATUE_HEIGHT
	body.shape = cylinder_shape
	body.position = Vector3(0.0, STATUE_HEIGHT * 0.5, 0.0)
	statue.add_child(body)

	var monolith := MeshInstance3D.new()
	monolith.name = "Monolith"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.9
	cylinder.bottom_radius = 1.4
	cylinder.height = STATUE_HEIGHT
	monolith.mesh = cylinder
	monolith.position = Vector3(0.0, STATUE_HEIGHT * 0.5, 0.0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.50)
	stone.roughness = 0.9
	monolith.material_override = stone
	statue.add_child(monolith)

	# Blood mark: a collar band near the top. Material, not decal — see class doc.
	var collar := MeshInstance3D.new()
	collar.name = "BloodMark"
	var band := CylinderMesh.new()
	band.top_radius = 1.55
	band.bottom_radius = 1.55
	band.height = 1.6
	collar.mesh = band
	collar.position = Vector3(0.0, STATUE_HEIGHT - 2.5, 0.0)
	var blood := StandardMaterial3D.new()
	blood.albedo_color = Color(0.55, 0.08, 0.06)
	blood.roughness = 0.6
	collar.material_override = blood
	statue.add_child(collar)

	# The canon colossus: a striding stone figure, blood running down its legs and
	# plinths (ColossusFigure.Style.STONE). The cylinder stays as its collider.
	var figure := ColossusFigure.new()
	figure.name = "Colossus"
	figure.style = ColossusFigure.Style.STONE
	figure.height = STATUE_HEIGHT
	figure.stance = 5.0
	figure.rotation.y = atan2(origin.x, origin.z)  # facing the spawn
	statue.add_child(figure)
	monolith.visible = false
	collar.visible = false

	add_child(statue)
	statues.append(statue)
	_build_return_zone(index, origin)


## Walk-into zone at each statue base: the manual-return trigger.
func _build_return_zone(index: int, origin: Vector3) -> void:
	var zone := Area3D.new()
	zone.name = "StatueReturnZone_%d" % index
	zone.position = origin + Vector3(0.0, 1.0, 0.0)
	PhysicsLayers.make_player_sensor(zone)
	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 3.5
	cylinder_shape.height = 3.0
	shape.shape = cylinder_shape
	zone.add_child(shape)
	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)
	add_child(zone)


## Memory anchors: 3 glowing spheres near 3 of the 4 statues (offset 3m toward origin).
func _build_memory_anchors() -> void:
	# Use the first 3 statue positions, offset toward the spawn point.
	for i in range(3):
		var statue_pos := STATUE_POSITIONS[i]
		var anchor_pos := statue_pos.lerp(Vector3.ZERO, 0.15)  # 15% toward origin
		var anchor := MemoryAnchor.new()
		anchor.name = "MemoryAnchor_%d" % i
		anchor.position = anchor_pos + Vector3(0.0, 1.5, 0.0)
		# The bootstrap wires dreamscape_manager after the valley is built (post_attach).
		add_child(anchor)
		memory_anchors.append(anchor)


## ----- FOREST ---------------------------------------------------------------------------


## The autumn birch wood and its floor: birches (a few dead) with solid trunks, and the
## scatter (mossy rocks, blood-marked stones, stumps, a fallen trunk, ferns, branches).
## Seeded, so every dream is the same valley.
func _build_forest() -> void:
	if not ResourceLoader.exists(TREES + "Birch_1.fbx"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1979
	var yellow: Texture2D = load(YELLOW_LEAVES) if ResourceLoader.exists(YELLOW_LEAVES) else null
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 900:
		tries += 1
		var at := Vector3(rng.randf_range(-55, 55), 0, rng.randf_range(-55, 55))
		if not _open_ground(at):
			continue
		var dead := rng.randf() < 0.18
		var path := (
			TREES + ("DeadBirch_%d.fbx" if dead else "Birch_%d.fbx") % rng.randi_range(1, 10)
		)
		var tree := CityKit.prop(path, self, at, rng.randf_range(0, 360), 0.0)
		if tree == null:
			continue
		tree.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
		if yellow != null:
			_autumn(tree, yellow)
		_trunk_collider(at)
		placed += 1
	for spec in SCATTER:
		var id: String = spec[0]
		var count: int = spec[1]
		var size_range: Vector2 = spec[2]
		var n := 0
		var guard := 0
		while n < count and guard < 400:
			guard += 1
			var at := Vector3(rng.randf_range(-50, 50), 0, rng.randf_range(-50, 50))
			if not _open_ground(at, 4.0):
				continue
			var p := CityKit.prop(CityKit.polyhaven(id), self, at, rng.randf_range(0, 360), 0.0)
			if p == null:
				break
			p.scale = Vector3.ONE * rng.randf_range(size_range.x, size_range.y)
			if spec[3] and rng.randf() < 0.6:
				_blood_mark(p, rng)
			n += 1


func _open_ground(at: Vector3, statue_margin: float = CLEAR_STATUE) -> bool:
	var p := Vector2(at.x, at.z)
	if p.length() < CLEAR_SPAWN:
		return false
	for s in STATUE_POSITIONS:
		var foot := Vector2(s.x, s.z)
		if p.distance_to(foot) < statue_margin:
			return false
		# Keep each colossus in view from the spawn: no trees on the sightline.
		var on_line := Geometry2D.get_closest_point_to_segment(p, Vector2.ZERO, foot)
		if p.distance_to(on_line) < SIGHTLINE_CLEAR:
			return false
	return true


## Swap the birch's leaf texture for the yellow autumn one (bark untouched).
func _autumn(n: Node, yellow: Texture2D) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var tex_path := mat.albedo_texture.resource_path if mat.albedo_texture else ""
			if "eaves" in tex_path or "eaf" in mat.resource_name or "eaves" in mat.resource_name:
				var leaf := mat.duplicate() as StandardMaterial3D
				leaf.albedo_texture = yellow
				# Gold, faintly lit from within: it should glow through the fog.
				leaf.albedo_color = Color(1.0, 0.72, 0.32)
				leaf.emission_enabled = true
				leaf.emission = Color(0.55, 0.32, 0.08)
				leaf.emission_energy_multiplier = 0.35
				mi.set_surface_override_material(s, leaf)
			elif "Bark" in mat.resource_name and ResourceLoader.exists(BARK):
				# The import lost the bark texture: put the birch's papery bark back.
				var bark := mat.duplicate() as StandardMaterial3D
				bark.albedo_texture = load(BARK_DEAD if "Dead" in mat.resource_name else BARK)
				bark.albedo_color = Color.WHITE
				mi.set_surface_override_material(s, bark)
	for c in n.get_children():
		_autumn(c, yellow)


## A solid trunk: you walk around birches, not through them.
func _trunk_collider(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 1.0, 0)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 2.0
	shape.shape = cyl
	body.add_child(shape)
	add_child(body)


## Old blood on a stone: a dark red smear across its face.
func _blood_mark(stone: Node3D, rng: RandomNumberGenerator) -> void:
	var blood := StandardMaterial3D.new()
	blood.albedo_color = Color(0.4, 0.04, 0.03)
	blood.roughness = 0.55
	var smear := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, rng.randf_range(0.25, 0.5), 0.02)
	smear.mesh = box
	smear.material_override = blood
	smear.position = Vector3(rng.randf_range(-0.15, 0.15), 0.35, 0.3)
	smear.rotation_degrees.z = rng.randf_range(-25, 25)
	stone.add_child(smear)


func _on_zone_entered(_body: Node3D) -> void:
	_near_zone_count += 1
	if _near_zone_count == 1:
		statue_proximity_changed.emit(true)


func _on_zone_exited(_body: Node3D) -> void:
	_near_zone_count = maxi(0, _near_zone_count - 1)
	if _near_zone_count == 0:
		statue_proximity_changed.emit(false)
