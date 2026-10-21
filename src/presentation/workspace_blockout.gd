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
## Look-dev palette (docs/references/notes.md, apartment): yellowed plaster over a
## grey-green dado; the dado band's height.
const COLOR_PLASTER := Color(0.78, 0.71, 0.42)
const COLOR_DADO := Color(0.44, 0.48, 0.43)
const DADO_HEIGHT := 0.42
## Real props are full scale; the room is a diorama (walls 1.35 m, him 0.8 m).
const PROP_SCALE := 0.47
const KIT_TEX := "res://assets/third_party/quaternius_downtown/models/"

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
	_texture_surfaces()
	_build_floor()
	_build_walls()
	_build_furniture_blocking()
	_dress_room()


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
	pane.material_override = _glass_material()
	add_child(pane)
	_build_window_frame(span_x * 0.72, wall_height - sill_height, sill_height, -half_z)
	# One solid box across the whole north footprint: the transparent pane must not be
	# the thing that stops the player (decals and movement both want real geometry).
	_add_wall_collision(
		"WallNorthCollision",
		Vector3(span_x, wall_height, wall_thickness),
		Vector3(0.0, wall_height * 0.5, -half_z),
		wall_height
	)


## The window: grimy glass in a steel frame, mullions every ~0.8 m and one transom,
## a concrete sill. Thin, so the recognition beat outside still reads through it.
func _build_window_frame(width: float, height: float, bottom: float, z: float) -> void:
	var steel := _mat(Color(0.12, 0.12, 0.13), 0.5)
	steel.metallic = 0.6
	var bar := 0.035
	var top := bottom + height
	var mid_y := bottom + height * 0.5
	for y in [bottom + bar * 0.5, top - bar * 0.5, bottom + height * 0.62]:
		var rail := _box("WindowRail", Vector3(width, bar, 0.06), Vector3(0, y, z), Color.BLACK)
		rail.material_override = steel
		add_child(rail)
	var panes := maxi(2, roundi(width / 0.8))
	for k in panes + 1:
		var x := -width * 0.5 + width * float(k) / panes
		var mullion := _box(
			"WindowMullion", Vector3(bar, height, 0.06), Vector3(x, mid_y, z), Color.BLACK
		)
		mullion.material_override = steel
		add_child(mullion)
	var sill := _box(
		"WindowSill",
		Vector3(width + 0.1, 0.04, 0.16),
		Vector3(0, bottom - 0.02, z + 0.05),
		Color.BLACK
	)
	sill.material_override = _wall_mat(Color(0.6, 0.58, 0.54))
	add_child(sill)


## Old glass: faintly blue-grey, a little reflective, filmed with grime (the kit's dirt
## texture, if installed).
func _glass_material() -> StandardMaterial3D:
	var m := _mat_transparent(Color(0.55, 0.62, 0.66), 0.28)
	m.metallic = 0.35
	m.roughness = 0.12
	if ResourceLoader.exists(KIT_TEX + "T_Dirt_BaseColor.png"):
		m.albedo_texture = load(KIT_TEX + "T_Dirt_BaseColor.png")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.7
	return m


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


## Real surfaces when the city kit is installed: worn concrete underfoot, plaster on the
## walls (tinted to the palette). Triplanar, so boxes of any size tile cleanly.
func _texture_surfaces() -> void:
	if not ResourceLoader.exists(KIT_TEX + "T_Concrete_BaseColor.png"):
		return
	floor_material.albedo_texture = load(KIT_TEX + "T_Concrete_BaseColor.png")
	floor_material.normal_enabled = true
	floor_material.normal_texture = load(KIT_TEX + "T_Concrete_Normal.png")
	floor_material.albedo_color = Color(0.82, 0.77, 0.69)
	floor_material.uv1_triplanar = true
	floor_material.uv1_scale = Vector3.ONE * 0.6


## The wall material: plaster (or the dado's grey-green), textured if the kit is in.
func _wall_mat(color: Color) -> StandardMaterial3D:
	var m := _mat(color, 0.92)
	if ResourceLoader.exists(KIT_TEX + "T_Concrete_BaseColor.png"):
		m.albedo_texture = load(KIT_TEX + "T_Concrete_BaseColor.png")
		m.normal_enabled = true
		m.normal_texture = load(KIT_TEX + "T_Concrete_Normal.png")
		m.normal_scale = 0.5
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.9
	return m


## Dress the room with real things (Poly Haven, CC0): the tool cart IS the workbench
## (inside the bench placeholder, so the ransack still takes what you see), a painted
## cabinet, cigarette packs; the dado band; and the neighbours' brick walls crammed
## right outside the window (Downtown kit). Each step skips if its pack is missing.
func _dress_room() -> void:
	var half_x := float(grid.width_cells) * grid.cell_size * 0.5
	var half_z := float(grid.depth_cells) * grid.cell_size * 0.5
	# Plaster walls over a grey-green dado (west and north, the walls you see whole).
	for wall in get_children():
		if wall is MeshInstance3D and str(wall.name).begins_with("Wall"):
			(wall as MeshInstance3D).material_override = _wall_mat(COLOR_PLASTER)
	var dado := _wall_mat(COLOR_DADO)
	var band := _box(
		"DadoWest",
		Vector3(0.02, DADO_HEIGHT, half_z * 2.0),
		Vector3(-half_x + wall_thickness * 0.5 + 0.01, DADO_HEIGHT * 0.5, 0),
		COLOR_DADO
	)
	band.material_override = dado
	add_child(band)
	# The workbench: a steel tool cart, stretched to the worktop's footprint and height.
	var cart := CityKit.prop(
		CityKit.polyhaven("tool_cart"), bench_placeholder, Vector3(0, -0.21, 0), 90.0, 0.0
	)
	if cart != null:
		cart.scale = Vector3(0.75, PROP_SCALE, 1.27)
		bench_placeholder.mesh = null
	var cabinet := CityKit.prop(
		CityKit.polyhaven("painted_wooden_cabinet"),
		self,
		Vector3(-half_x + 0.25, 0, 1.2),
		90.0,
		0.0
	)
	if cabinet != null:
		cabinet.scale = Vector3.ONE * PROP_SCALE
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	for k in 5:
		var at := Vector3(
			rng.randf_range(-half_x + 0.6, half_x - 0.6),
			0.0,
			rng.randf_range(-half_z + 0.6, half_z - 0.6)
		)
		var pack := CityKit.prop(
			CityKit.polyhaven("cigarette_pack"), self, at, rng.randf_range(0, 360), 0.0
		)
		if pack != null:
			pack.scale = Vector3.ONE * 0.8
			pack.rotation_degrees.x = 90.0
	# Outside the window: the next block, an arm's length away.
	var outside := Node3D.new()
	outside.name = "Neighbours"
	outside.position = Vector3(0, -2.0, -half_z - 3.0)
	outside.scale = Vector3.ONE * PROP_SCALE
	add_child(outside)
	var kit := CityKit.new()
	kit.facade(Vector3(-16, 0, 0), Vector3.BACK, 16, 6, CityKit.Style.BRICK, 77)
	kit.build(outside)
	# In shadow: the gap between the blocks gets no direct light.
	for mm in outside.get_children():
		(mm as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mm as GeometryInstance3D).transparency = 0.0
	var gloom := StandardMaterial3D.new()
	gloom.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	gloom.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gloom.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var veil := MeshInstance3D.new()
	veil.name = "AlleyGloom"
	var quad := QuadMesh.new()
	quad.size = Vector2(half_x * 2.0 + 6.0, 12.0)
	veil.mesh = quad
	veil.material_override = gloom
	veil.position = Vector3(0, 4.0, -half_z - 2.9)
	add_child(veil)


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
	var cot := _box(
		"CotPlaceholder",
		Vector3(0.95, 0.24, 0.6),
		cot_world + Vector3(0.0, 0.12, 0.0),
		COLOR_WALL.lightened(0.1)
	)
	add_child(cot)
	# The real bed: an old iron frame (Poly Haven, CC0), the box becomes its stained
	# mattress, thinned to sit inside the frame.
	var frame := CityKit.prop(
		CityKit.polyhaven("old_bed_frame"), cot, Vector3(0, -0.12, 0), 90.0, 0.0
	)
	if frame != null:
		frame.scale = Vector3.ONE * PROP_SCALE
		(cot.mesh as BoxMesh).size = Vector3(0.9, 0.08, 0.4)
		cot.position.y = 0.2
		frame.position.y = -0.2
		cot.material_override = _mat(Color(0.62, 0.58, 0.5), 0.95)


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
