extends BootstrapModule
## The apartment WorldRoot and everything inside it: lights, blockout geometry, clutter,
## decals, atmosphere, the crafting bench, the self-soothing fidget object and the door.
##
## Everything apartment-specific lives under one WorldRoot so world swaps take the whole
## room out of play in one call (visibility, colliders, processing). The WorldEnvironment
## node stays OUTSIDE (its resource is swapped, not hidden), as do the player, camera,
## post-FX and boundary, which persist across worlds.

## Where the BenchArea sits in room coordinates. Matches WorkspaceBlockout's
## CraftingBenchPlaceholder cell (1,1) in a 9x7 room.
const BENCH_ORIGIN := Vector3(-3.0, 0.0, -2.0)

## Desk lamp placement above the bench, warm incandescent. AtmosphereController scales
## its flicker from this base.
const LAMP_POSITION := Vector3(-3.0, 1.25, -2.0)
const LAMP_COLOR := Color(1.0, 0.85, 0.63)
const LAMP_ENERGY := 1.4
const LAMP_RANGE := 3.5

const TRIVIAL_OBJECT_POSITION := Vector3(1.5, 0.0, 1.0)  # near player start
const DOOR_POSITION := Vector3(0.0, 0.0, -3.5)  # north edge of the room

## Compounds seeded on the worktop: two doses. Finite on purpose (gentrification).
const SEED_COMPOUND_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)
]

var _blockout: WorkspaceBlockout
var _station: BenchStation


func create(ctx: BootstrapContext) -> void:
	ctx.apartment = WorldRoot.new()
	ctx.apartment.name = "Apartment"

	ctx.key_light = DirectionalLight3D.new()
	ctx.key_light.name = "KeyLight"
	ctx.key_light.light_energy = 1.15
	ctx.key_light.light_color = Color(0.98, 0.90, 0.78)
	ctx.key_light.shadow_enabled = true
	ctx.key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)

	ctx.lamp = OmniLight3D.new()
	ctx.lamp.name = "DeskLamp"
	ctx.lamp.light_energy = LAMP_ENERGY
	ctx.lamp.light_color = LAMP_COLOR
	ctx.lamp.omni_range = LAMP_RANGE
	ctx.lamp.shadow_enabled = false  # a flickering shadow strobes; the key light owns shadows
	ctx.lamp.position = LAMP_POSITION

	# Blockout geometry: the SurfaceDecal batches project onto these walls/floor.
	_blockout = WorkspaceBlockout.new()
	_blockout.name = "WorkspaceBlockout"

	# Position (0,0,0): the clutter manager's spawn positions are room-absolute and
	# applied as LOCAL positions, so the node must sit at the room origin.
	ctx.clutter = VisualClutterManager.new()
	ctx.clutter.name = "ClutterField"

	ctx.decals = SurfaceDegradation.new()
	ctx.decals.name = "SurfaceDegradation"

	ctx.atmosphere = AtmosphereController.new()
	ctx.atmosphere.name = "AtmosphereController"

	ctx.bench_area = Node3D.new()
	ctx.bench_area.name = "BenchArea"
	ctx.bench_area.position = BENCH_ORIGIN

	# 4x4 worktop centered on the placeholder box; cells span ±2 m around it.
	ctx.spatial_grid = SpatialGrid.new()
	ctx.spatial_grid.name = "SpatialGrid"
	ctx.spatial_grid.position = Vector3(-2.0, 0.45, -2.0)

	ctx.bench = CraftingBench.new()
	ctx.bench.name = "CraftingBench"
	ctx.bench.recipe_database = RecipeDatabase.new()

	_station = BenchStation.new()
	_station.name = "BenchStation"

	ctx.trivial_object = TrivialObject.new()
	ctx.trivial_object.name = "TrivialObject"
	ctx.trivial_object.position = TRIVIAL_OBJECT_POSITION

	ctx.door = ApartmentDoor.new()
	ctx.door.name = "ApartmentDoor"
	ctx.door.position = DOOR_POSITION


func wire(ctx: BootstrapContext) -> void:
	_blockout.grid = ctx.grid

	ctx.clutter.entropy_data = ctx.entropy_data
	ctx.clutter.clutter_item_scene = ctx.clutter_scene
	ctx.decals.entropy_data = ctx.entropy_data

	ctx.atmosphere.entropy_data = ctx.entropy_data
	ctx.atmosphere.environment = ctx.apartment_environment
	ctx.atmosphere.key_light = ctx.key_light
	ctx.atmosphere.lamp = ctx.lamp
	ctx.atmosphere.floor_material = _blockout.floor_material

	ctx.bench.spatial_grid = ctx.spatial_grid
	ctx.bench.chemical_manager = ctx.state_data
	ctx.bench.result_item_scene = ctx.pill_scene
	ctx.bench.interaction_controller = ctx.interaction
	_station.bench = ctx.bench
	_station.spatial_grid = ctx.spatial_grid
	_station.state_data = ctx.state_data
	_station.player = ctx.player
	_station.interaction_controller = ctx.interaction

	ctx.trivial_object.state_machine = ctx.state_machine

	ctx.door.entropy_data = ctx.entropy_data
	ctx.door.corporate_park_manager = ctx.park
	ctx.door.interaction_controller = ctx.interaction
	ctx.door.player = ctx.player


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.apartment)
	ctx.apartment.add_child(ctx.key_light)
	ctx.apartment.add_child(ctx.lamp)
	ctx.apartment.add_child(_blockout)
	ctx.apartment.add_child(ctx.clutter)
	ctx.apartment.add_child(ctx.decals)
	ctx.apartment.add_child(ctx.atmosphere)
	ctx.apartment.add_child(ctx.bench_area)
	ctx.bench_area.add_child(ctx.spatial_grid)
	ctx.bench_area.add_child(ctx.bench)
	ctx.bench.add_child(_station)
	ctx.apartment.add_child(ctx.trivial_object)
	ctx.apartment.add_child(ctx.door)


func post_attach(ctx: BootstrapContext) -> void:
	# The bench's visible block belongs to the bench: suppressing the bench (ransack,
	# scarred reset) must take its look with it. It used to stay standing.
	if _blockout.bench_placeholder != null:
		_blockout.bench_placeholder.reparent(ctx.bench)
	# The stash: raw compounds for two doses. Cook at the bench (E), take the pill (E).
	for cell in SEED_COMPOUND_CELLS:
		ctx.spatial_grid.place_item(ctx.raw_compound_scene, cell)
