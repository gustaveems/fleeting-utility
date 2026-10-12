class_name DreamscapeEnvironment
extends Node3D
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
## visible = false at _ready. The manager flips it during the white-out.

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

## The valley's Environment resource, built in _ready and handed to the manager.
var valley_environment: Environment

var _near_zone_count: int = 0


func _ready() -> void:
	visible = false
	_build_environment()
	_build_terrain()
	_build_sun()
	_build_statues()
	_build_memory_anchors()


## ----- ENVIRONMENT ------------------------------------------------------------------


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Late-afternoon sky, saturated to the edge of believability — the dream's opposite
	# of the apartment's near-black green.
	env.background_color = Color(0.95, 0.62, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.55, 0.30)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# Soft warm haze for depth. Denser than the apartment's: at 120 m of plane the fog
	# has to swallow the terrain edge into the sky, or the horizon reads as a cut line
	# (confirmed on the first valley render).
	env.fog_enabled = true
	env.fog_light_color = Color(0.90, 0.60, 0.35)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004

	# High saturation is the whole visual brief for the valley.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.35
	env.adjustment_contrast = 1.1
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
	ground.material_override = material
	add_child(ground)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.light_color = Color(1.0, 0.72, 0.42)
	sun.light_energy = 1.7
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

	add_child(statue)
	_build_return_zone(index, origin)


## Walk-into zone at each statue base: the manual-return trigger.
func _build_return_zone(index: int, origin: Vector3) -> void:
	var zone := Area3D.new()
	zone.name = "StatueReturnZone_%d" % index
	zone.position = origin + Vector3(0.0, 1.0, 0.0)
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
		# Wire the manager reference (set by bootstrap after add_child).
		add_child(anchor)


func _on_zone_entered(_body: Node3D) -> void:
	_near_zone_count += 1
	if _near_zone_count == 1:
		statue_proximity_changed.emit(true)


func _on_zone_exited(_body: Node3D) -> void:
	_near_zone_count = maxi(0, _near_zone_count - 1)
	if _near_zone_count == 0:
		statue_proximity_changed.emit(false)
