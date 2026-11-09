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
## Tired cream plaster (it was a loud mustard: playtest 2026-11-03, "the apartment
## could do with some work").
const COLOR_PLASTER := Color(0.66, 0.61, 0.5)
const COLOR_DADO := Color(0.44, 0.48, 0.43)
const DADO_HEIGHT := 0.42
## Real props are full scale; the room is a diorama (walls 1.35 m, him 0.8 m).
const PROP_SCALE := 0.47
const BED_TABLE_AT := Vector3(4.05, 0.0, 2.75)
const RUG_WEAVE := 0.4
## Sun-faded and trodden: the weave's colours, browned and dimmed.
const RUG_FADE := Color(0.62, 0.5, 0.4)
const KIT_TEX := "res://assets/third_party/quaternius_downtown/models/"

const COLOR_BENCH := Color(0.42, 0.33, 0.24)
const COLOR_WINDOW := Color(0.62, 0.68, 0.74)
## The north wall's windows, (centre x, width): either side of the door; the east one
## frames the street where the friend's shoes are seen.
const WINDOWS: Array[Vector2] = [Vector2(-2.25, 2.6), Vector2(2.25, 2.6)]

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
	_furnish()


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

	# Far wall (-Z): the windows. The protagonist's only view of the outside world, and
	# the literal stage for the Recognition beat (MASTER_BRIEF.md #2): a sill band, then
	# two windows of grimy glass either side of the door, between solid piers under a
	# header. (Playtest 2026-11-04: one pane across 72% of the wall, open at both ends,
	# read as a shopfront onto the block outside.)
	add_child(
		_box(
			"WallNorthSill",
			Vector3(span_x, sill_height, wall_thickness),
			Vector3(0.0, sill_height * 0.5, -half_z),
			COLOR_WALL
		)
	)
	var header := 0.14
	var glass_h := wall_height - sill_height - header
	add_child(
		_box(
			"WallNorthHeader",
			Vector3(span_x, header, wall_thickness),
			Vector3(0.0, wall_height - header * 0.5, -half_z),
			COLOR_WALL
		)
	)
	var edges: Array[float] = [-span_x * 0.5]
	for w in WINDOWS:
		edges.append(w.x - w.y * 0.5)
		edges.append(w.x + w.y * 0.5)
		var pane := _box(
			"WindowPane",
			Vector3(w.y, glass_h, wall_thickness * 0.4),
			Vector3(w.x, sill_height + glass_h * 0.5, -half_z),
			COLOR_WINDOW
		)
		pane.material_override = _glass_material()
		add_child(pane)
		_build_window_frame(w.y, glass_h, sill_height, -half_z, w.x)
	edges.append(span_x * 0.5)
	for k in range(0, edges.size(), 2):
		var width := edges[k + 1] - edges[k]
		add_child(
			_box(
				"WallNorthPier%d" % (k / 2),
				Vector3(width, glass_h, wall_thickness),
				Vector3((edges[k] + edges[k + 1]) * 0.5, sill_height + glass_h * 0.5, -half_z),
				COLOR_WALL
			)
		)
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
func _build_window_frame(
	width: float, height: float, bottom: float, z: float, cx: float = 0.0
) -> void:
	var steel := _mat(Color(0.12, 0.12, 0.13), 0.5)
	steel.metallic = 0.6
	var bar := 0.035
	var top := bottom + height
	var mid_y := bottom + height * 0.5
	for y in [bottom + bar * 0.5, top - bar * 0.5, bottom + height * 0.62]:
		var rail := _box("WindowRail", Vector3(width, bar, 0.06), Vector3(cx, y, z), Color.BLACK)
		rail.material_override = steel
		add_child(rail)
	var panes := maxi(2, roundi(width / 0.8))
	for k in panes + 1:
		var x := cx - width * 0.5 + width * float(k) / panes
		var mullion := _box(
			"WindowMullion", Vector3(bar, height, 0.06), Vector3(x, mid_y, z), Color.BLACK
		)
		mullion.material_override = steel
		add_child(mullion)
	var sill := _box(
		"WindowSill",
		Vector3(width + 0.1, 0.04, 0.16),
		Vector3(cx, bottom - 0.02, z + 0.05),
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


## Underfoot, the reference room's hex tiles (RoomTiles: cream, oxblood, slate, worn),
## with the kit's concrete normal for wear when it's installed; plaster on the walls
## (tinted to the palette). Triplanar, so boxes of any size tile cleanly.
func _texture_surfaces() -> void:
	floor_material.albedo_texture = RoomTiles.texture()
	floor_material.uv1_triplanar = true
	# One texture (8 hexes across) per 0.9 m: tiles about 11 cm at the diorama's scale
	# (~24 cm real), muted (at 20 cm and full colour the floor drowned the room).
	floor_material.albedo_color = Color(0.5, 0.48, 0.45)
	floor_material.uv1_scale = RoomTiles.uv_scale(0.9)
	if ResourceLoader.exists(KIT_TEX + "T_Concrete_Normal.png"):
		floor_material.normal_enabled = true
		floor_material.normal_texture = load(KIT_TEX + "T_Concrete_Normal.png")
		floor_material.normal_scale = 0.6


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
	_damp(m)
	return m


## Damp coming through the plaster (the reference room; the palette's damp #5A5240): a
## blotchy noise mask mixing in the stain colour, triplanar like the rest.
func _damp(m: StandardMaterial3D) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 52
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var mask := NoiseTexture2D.new()
	mask.noise = noise
	mask.seamless = true
	mask.width = 256
	mask.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0, 0, 0))
	ramp.set_color(1, Color(1, 1, 1))
	ramp.set_offset(0, 0.42)
	ramp.set_offset(1, 0.68)
	mask.color_ramp = ramp
	var stain := Image.create(4, 4, false, Image.FORMAT_RGB8)
	stain.fill(Color("#5A5240"))
	m.detail_enabled = true
	m.detail_mask = mask
	m.detail_albedo = ImageTexture.create_from_image(stain)
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1


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
			var plaster := _wall_mat(COLOR_PLASTER)
			plaster.next_pass = WallPaper.material()
			(wall as MeshInstance3D).material_override = plaster
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
	# The cabinet and the bed are solid (playtest 2026-11-03: he walked through them).
	_add_wall_collision(
		"CabinetCollision", Vector3(0.3, 0.6, 0.6), Vector3(-half_x + 0.25, 0.3, 1.2), 0.6
	)
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
	# Outside the window: the next block across the alley, its upper storeys (he lives
	# up high). Playtest 2026-11-04: at -2 m its street door and railings stood level
	# with his floor and read as part of the room.
	var outside := Node3D.new()
	outside.name = "Neighbours"
	outside.position = Vector3(0, -7.0, -half_z - 3.5)
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


## A cheap studio someone lives in (playtest 2026-11-03: four props on an empty plaza of
## tiles). Everything he could walk into has a body (tools/probe_figures.gd); the west
## wall's floor stays clear for the moving boxes (NightZero.DROP_ZONE), the north-east
## for the window beat, the paths to the bench, easel, cot and door open.
##   south-west   the kitchenette: a counter with a sink and a kettle, a small fridge
##   centre       a threadbare rug; by the cot, a smaller one
##   west         a table and a chair under the shelves (his few things unpacked)
##   north        a radiator under the window; a dead plant in the corner
##   north-east   a floor lamp; skirting along the walls you see whole
func _furnish() -> void:
	var half_x := float(grid.width_cells) * grid.cell_size * 0.5
	var half_z := float(grid.depth_cells) * grid.cell_size * 0.5
	var wood := _mat(Color(0.3, 0.2, 0.13), 0.6)
	var laminate := _mat(Color(0.72, 0.7, 0.64), 0.5)
	var steel := _mat(Color(0.62, 0.64, 0.66), 0.3)
	steel.metallic = 0.7
	var enamel := _mat(Color(0.86, 0.85, 0.8), 0.35)
	# Kitchenette along the south wall's west end.
	var counter := Vector3(-half_x + 1.1, 0.0, half_z - 0.32)
	_piece("Counter", Vector3(1.6, 0.45, 0.45), counter + Vector3(0, 0.225, 0), wood)
	_piece("Worktop", Vector3(1.66, 0.03, 0.5), counter + Vector3(0, 0.46, 0), laminate)
	_piece("Sink", Vector3(0.4, 0.02, 0.3), counter + Vector3(0.35, 0.475, 0), steel)
	_piece("Kettle", Vector3(0.09, 0.11, 0.09), counter + Vector3(-0.4, 0.53, 0), enamel)
	_piece("Fridge", Vector3(0.45, 0.8, 0.42), counter + Vector3(-1.1, 0.4, 0), enamel)
	_add_wall_collision(
		"KitchenCollision", Vector3(2.1, 0.8, 0.5), counter + Vector3(-0.25, 0.4, 0), 0.8
	)
	# Rugs: the moquette weave, worn (TransitLook's: cheap, everywhere in this city).
	var rug := _piece("Rug", Vector3(2.4, 0.01, 1.6), Vector3(0.2, 0.006, 0.4), null)
	# A rug's weave is coarse: 0.4 scales the moquette's 8 cm diamonds up ~5× (at the
	# diorama's true scale the pattern shimmered).
	rug.material_override = TransitLook.seat(RUG_WEAVE, RUG_FADE)
	var mat_by_bed := _piece("BedRug", Vector3(0.9, 0.01, 0.55), Vector3(2.2, 0.006, 2.1), null)
	mat_by_bed.material_override = TransitLook.seat(RUG_WEAVE, RUG_FADE)
	# Table and chair by the west wall, south of the boxes' corner.
	var table := Vector3(-half_x + 0.75, 0.0, 1.95)
	_piece("Table", Vector3(0.7, 0.03, 0.5), table + Vector3(0, 0.36, 0), wood)
	for x in [-0.3, 0.3]:
		for z in [-0.2, 0.2]:
			_piece("TableLeg", Vector3(0.03, 0.35, 0.03), table + Vector3(x, 0.175, z), wood)
	_piece("ChairSeat", Vector3(0.3, 0.03, 0.3), table + Vector3(0.5, 0.22, 0), wood)
	_piece("ChairBack", Vector3(0.03, 0.3, 0.3), table + Vector3(0.64, 0.38, 0), wood)
	_add_wall_collision(
		"TableCollision", Vector3(1.0, 0.4, 0.55), table + Vector3(0.15, 0.2, 0), 0.4
	)
	_personal_things(table, half_x)
	# Shelves above the boxes' corner: what he unpacked.
	var shelf_x := -half_x + 0.14
	for y in [0.78, 1.02]:
		_piece("Shelf", Vector3(0.18, 0.02, 1.2), Vector3(shelf_x, y, -0.3), wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in 9:
		var y: float = [0.78, 1.02][k % 2] + 0.07
		var tint := Color(0.25, 0.3, 0.45).lerp(Color(0.6, 0.25, 0.2), rng.randf())
		_piece(
			"Book",
			Vector3(0.12, rng.randf_range(0.08, 0.13), 0.035),
			Vector3(shelf_x, y, -0.8 + k * 0.11),
			_mat(tint, 0.8)
		)
	# The radiator under the window, west of the door.
	var rad := Vector3(-1.9, 0.0, -half_z + 0.12)
	var paint := _mat(Color(0.82, 0.8, 0.74), 0.5)
	for k in 9:
		_piece("Fin", Vector3(0.04, 0.32, 0.08), rad + Vector3(-0.32 + k * 0.08, 0.2, 0), paint)
	_add_wall_collision(
		"RadiatorCollision", Vector3(0.75, 0.4, 0.12), rad + Vector3(0, 0.2, 0), 0.4
	)
	# A dead plant in the north-west corner (the window's light never reaches it).
	var corner := Vector3(-half_x + 0.3, 0.0, -half_z + 0.3)
	_piece(
		"Pot",
		Vector3(0.18, 0.18, 0.18),
		corner + Vector3(0, 0.09, 0),
		_mat(Color(0.5, 0.28, 0.18), 0.9)
	)
	var branches := CityKit.prop(
		CityKit.polyhaven("dry_branches_medium_01"), self, corner + Vector3(0, 0.18, 0), 0.0, 0.0
	)
	if branches != null:
		branches.scale = Vector3.ONE * 0.35
	_add_wall_collision("PotCollision", Vector3(0.22, 0.4, 0.22), corner + Vector3(0, 0.2, 0), 0.4)
	# A floor lamp in the north-east corner, its shade lit.
	var lamp_at := Vector3(half_x - 0.3, 0.0, -half_z + 0.3)
	_piece("LampPole", Vector3(0.03, 1.0, 0.03), lamp_at + Vector3(0, 0.5, 0), steel)
	var shade := _mat(Color(0.95, 0.85, 0.65), 0.7)
	shade.emission_enabled = true
	shade.emission = Color(1.0, 0.8, 0.55)
	shade.emission_energy_multiplier = 0.8
	_piece("LampShade", Vector3(0.22, 0.16, 0.22), lamp_at + Vector3(0, 1.05, 0), shade)
	var glow := OmniLight3D.new()
	glow.name = "FloorLampLight"
	glow.light_color = Color(1.0, 0.82, 0.6)
	glow.light_energy = 0.7
	glow.omni_range = 2.5
	glow.position = lamp_at + Vector3(0, 0.95, 0)
	add_child(glow)
	_add_wall_collision("LampCollision", Vector3(0.2, 1.1, 0.2), lamp_at + Vector3(0, 0.55, 0), 1.1)
	# Skirting along the walls you see whole (west, north).
	var skirt := _mat(Color(0.22, 0.17, 0.12), 0.6)
	_piece("SkirtWest", Vector3(0.02, 0.06, half_z * 2.0), Vector3(-half_x + 0.075, 0.03, 0), skirt)
	_piece(
		"SkirtNorth", Vector3(half_x * 2.0, 0.06, 0.02), Vector3(0, 0.03, -half_z + 0.075), skirt
	)


## His things (polish pass, 2026-11-06): the boombox and a desk lamp on the table, a wall
## lamp over it, a side table by the cot with a can on it. Small enough to stay off the
## paths; each skips if its pack is missing.
func _personal_things(table: Vector3, half_x: float) -> void:
	var boombox := CityKit.prop(
		CityKit.polyhaven("boombox"), self, table + Vector3(-0.1, 0.375, -0.1), 90.0, 0.0
	)
	if boombox != null:
		boombox.scale = Vector3.ONE * 0.34
	var desk := CityKit.prop(
		CityKit.polyhaven("desk_lamp_arm_01"), self, table + Vector3(0.1, 0.375, 0.16), 200.0, 0.0
	)
	if desk != null:
		desk.scale = Vector3.ONE * 0.42
	var wall := CityKit.prop(
		CityKit.polyhaven("industrial_wall_lamp"),
		self,
		Vector3(-half_x + 0.1, 0.92, 2.1),
		90.0,
		0.0
	)
	if wall != null:
		wall.scale = Vector3.ONE * PROP_SCALE
		var bulb := OmniLight3D.new()
		bulb.name = "WallLampLight"
		bulb.light_color = Color(1.0, 0.76, 0.5)
		bulb.light_energy = 0.55
		bulb.omni_range = 2.2
		bulb.position = Vector3(-half_x + 0.3, 0.9, 2.1)
		add_child(bulb)
	var by_bed := Vector3(BED_TABLE_AT)
	var side := CityKit.prop(CityKit.polyhaven("side_table_01"), self, by_bed, 20.0, 0.0)
	if side != null:
		side.scale = Vector3.ONE * PROP_SCALE
		_add_wall_collision("SideTableCollision", Vector3(0.3, 0.3, 0.3), by_bed, 0.3)
		CityKit.prop(
			CityKit.polyhaven("can_rusted"), self, by_bed + Vector3(0.03, 0.26, 0.02), 40.0, 0.0
		)


## A named box of furniture (added; `mat` null leaves it for the caller).
func _piece(node_name: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	return mi


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
	_add_wall_collision(
		"CotCollision", Vector3(0.95, 0.5, 0.6), cot_world + Vector3(0, 0.25, 0), 0.5
	)
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
