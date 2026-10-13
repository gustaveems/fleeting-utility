class_name WorkspaceBlockout
extends Node3D
## PRESENTATION LAYER — greybox of the leased apartment workspace.
##
## Built in code from WorkspaceGridData so the geometry can never disagree with the
## logical grid: walls are placed at the footprint boundary.
##
## COLLISION (free-roam pivot, 2026-10-11): with locomotion no longer grid-refused,
## the walls ARE StaticBody3D — free roam needs real containment. The two
## camera-facing walls (south +Z, east +X) are visually cut to sill height for iso
## sightlines but keep an invisible collision extension upward; the player never sees
## that face, so the "no invisible walls" spirit holds: every surface that stops you
## is one you looked at from the room side. The soft-boundary vignette/fog still
## expresses the edge atmospherically on top of the physical one.
##
## This is scaffolding. It gets replaced by authored art in a later ticket, but the
## footprint math stays, because that math lives in the Data layer.

const COLOR_FLOOR := Color(0.19, 0.17, 0.16)
const COLOR_WALL := Color(0.28, 0.26, 0.25)
const COLOR_BENCH := Color(0.42, 0.33, 0.24)
const COLOR_WINDOW := Color(0.62, 0.68, 0.74)

## Invisible collision height for the camera-facing sill walls. The capsule tops out
## at 0.8 m; 2.5 m is generous margin with no gameplay downside (nothing can hop it).
const NEAR_WALL_COLLISION_HEIGHT := 2.5

@export var grid: WorkspaceGridData

## Wall height in metres. Low-ish, so the isometric camera can see over the far walls
## instead of them filling the frame — the classic 2.5D iso tradeoff.
@export var wall_height: float = 1.35

## Thickness of the wall band, in metres. Thin so it reads as a room edge, not a maze.
@export var wall_thickness: float = 0.12

## The floor's material, created up front so AtmosphereController can be handed it at
## wire time (it turns the floor glossy for the clinical reflections).
var floor_material: StandardMaterial3D = _mat(COLOR_FLOOR, 0.9)

## The bench's visible block. The apartment module hands it to the CraftingBench so
## removing the bench (ransack, scarred reset) removes what the player actually sees.
var bench_placeholder: MeshInstance3D


func _ready() -> void:
	if grid == null:
		push_warning("WorkspaceBlockout: no WorkspaceGridData assigned, nothing built.")
		return
	_build_floor()
	_build_walls()
	_build_furniture_blocking()


func _build_floor() -> void:
	var floor_instance := MeshInstance3D.new()
	floor_instance.name = "Floor"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(
		float(grid.width_cells) * grid.cell_size, float(grid.depth_cells) * grid.cell_size
	)
	floor_instance.mesh = mesh
	floor_instance.material_override = floor_material
	add_child(floor_instance)


func _build_walls() -> void:
	var span_x := float(grid.width_cells) * grid.cell_size + wall_thickness * 2.0
	var span_z := float(grid.depth_cells) * grid.cell_size
	var half_x := float(grid.width_cells) * grid.cell_size * 0.5
	var half_z := float(grid.depth_cells) * grid.cell_size * 0.5
	var sill_height := wall_height * 0.35

	# Camera-facing walls (+Z south, +X east) get dropped to sill height. The iso camera
	# sits on the +X/+Z diagonal, so full-height near walls occlude the entire room —
	# confirmed on the first real render. Only the camera-facing pair is cut; the far
	# walls stay solid to keep the room readable as an enclosed space. Collision still
	# runs the full NEAR_WALL_COLLISION_HEIGHT: the cut faces the camera's back side.
	_solid_wall(
		"WallSouth",
		Vector3(span_x, sill_height, wall_thickness),
		Vector3(0.0, sill_height * 0.5, half_z),
		COLOR_WALL,
		NEAR_WALL_COLLISION_HEIGHT
	)
	_solid_wall(
		"WallEast",
		Vector3(wall_thickness, sill_height, span_z),
		Vector3(half_x, sill_height * 0.5, 0.0),
		COLOR_WALL,
		NEAR_WALL_COLLISION_HEIGHT
	)
	_solid_wall(
		"WallWest",
		Vector3(wall_thickness, wall_height, span_z),
		Vector3(-half_x, wall_height * 0.5, 0.0),
		COLOR_WALL,
		wall_height
	)

	# Far wall (-Z): the window. The protagonist's only view of the outside world, and the
	# literal stage for the Recognition beat (MASTER_BRIEF.md #2) — sill band below,
	# translucent pane above, so the frame reads as glass rather than a hole.
	add_child(
		_box(
			"WallNorthSill",
			Vector3(span_x, sill_height, wall_thickness),
			Vector3(0.0, sill_height * 0.5, -half_z),
			COLOR_WALL
		)
	)
	var pane := _box(
		"WindowPane",
		Vector3(span_x * 0.72, wall_height - sill_height, wall_thickness * 0.4),
		Vector3(0.0, sill_height + (wall_height - sill_height) * 0.5, -half_z),
		COLOR_WINDOW
	)
	pane.material_override = _mat_transparent(COLOR_WINDOW, 0.35)
	add_child(pane)
	# One solid box across the whole north footprint: the transparent pane must not be
	# the thing that stops the player (decals and movement both want real geometry).
	_add_wall_collision(
		"WallNorthCollision",
		Vector3(span_x, wall_height, wall_thickness),
		Vector3(0.0, wall_height * 0.5, -half_z),
		wall_height
	)


## Visible wall box + StaticBody3D collision of a possibly different height.
func _solid_wall(
	node_name: String, size: Vector3, origin: Vector3, color: Color, collision_height: float
) -> void:
	add_child(_box(node_name, size, origin, color))
	_add_wall_collision(node_name + "Collision", size, origin, collision_height)


## Collision box spanning floor..collision_height at the wall's footprint. The visual
## box is centred at size.y/2, so the taller collision is offset up by half the delta.
func _add_wall_collision(
	node_name: String, visual_size: Vector3, origin: Vector3, collision_height: float
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = origin
	var shape_node := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(visual_size.x, collision_height, visual_size.z)
	shape_node.shape = box_shape
	shape_node.position = Vector3(0.0, (collision_height - visual_size.y) * 0.5, 0.0)
	body.add_child(shape_node)
	add_child(body)


## Two props that define the playable footprint: the crafting bench (Ticket-03 will hang
## its interaction grid off the cell it occupies) and a cot. Everything else in the room
## is empty floor, which is the point — the space is leased and minimal.
func _build_furniture_blocking() -> void:
	var bench_cell := Vector2i(1, 1)
	var bench_world := grid.cell_to_world(bench_cell)
	bench_placeholder = _box(
		"CraftingBenchPlaceholder",
		Vector3(0.95, 0.42, 0.95),
		bench_world + Vector3(0.0, 0.21, 0.0),
		COLOR_BENCH
	)
	add_child(bench_placeholder)
	var cot_cell := Vector2i(grid.width_cells - 2, grid.depth_cells - 2)
	var cot_world := grid.cell_to_world(cot_cell)
	add_child(
		_box(
			"CotPlaceholder",
			Vector3(0.95, 0.24, 0.6),
			cot_world + Vector3(0.0, 0.12, 0.0),
			COLOR_WALL.lightened(0.1)
		)
	)


func _box(node_name: String, size: Vector3, origin: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = _mat(color, 0.85)
	return instance


static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material


static func _mat_transparent(color: Color, alpha: float) -> StandardMaterial3D:
	var material := _mat(color, 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = alpha
	material.shadow_to_opacity = true
	return material
