extends BootstrapModule
## Data, the state machine, the shared WorldEnvironment, runtime-packed item scenes and
## the demo seed.
##
## ITEM "SCENES" ARE PACKED AT RUNTIME
## -----------------------------------
## No editor-authored .tscn exists for clutter or items. PackedScene.pack() snapshots a
## bare class-annotated node (script + exported properties serialize; the placeholder
## children are auto-built by each class's _ready() on instantiate). Real art scenes
## replace these once the asset pipeline exists; the pack() sites are the only lines
## that change.
##
## DEMO SEED (deliberate, tunable)
## -------------------------------
## A from-clean boot is ~40 s of nothing happening while chemistry creeps. So the scene
## starts mid-cycle: chemical 0.45 (no High-Focus, crossing the unmedicated threshold in
## ~8 s), entropy 38 (clutter batch + first decal batch already visible, lamp about to
## fail).

const DEMO_CHEMICAL := 0.45
const DEMO_ENTROPY := 38.0


func create(ctx: BootstrapContext) -> void:
	ctx.raw_compound_scene = _pack_inventory(&"raw_compound")
	# The bench re-instantiates this per craft and overwrites item_id from the recipe;
	# the default id only seeds the placeholder color.
	ctx.pill_scene = _pack_inventory(&"pill_bottle")
	var proto := ClutterItem.new()
	ctx.clutter_scene = PackedScene.new()
	ctx.clutter_scene.pack(proto)
	proto.free()

	ctx.grid = WorkspaceGridData.new()
	ctx.state_data = PlayerStateData.new()
	ctx.entropy_data = WorkspaceEntropyData.new()
	ctx.state_machine = PlayerStateMachine.new()
	ctx.state_machine.name = "PlayerStateMachine"

	# Demo seed. Managers read the stored values at their own _ready(), so the seed is
	# reflected without emitting a signal first.
	ctx.state_data.chemical_level = DEMO_CHEMICAL
	ctx.entropy_data.entropy = DEMO_ENTROPY

	ctx.apartment_environment = _build_apartment_environment()
	ctx.world_env = WorldEnvironment.new()
	ctx.world_env.name = "WorldEnvironment"
	ctx.world_env.environment = ctx.apartment_environment


func wire(ctx: BootstrapContext) -> void:
	ctx.state_machine.state_data = ctx.state_data
	ctx.state_machine.entropy_data = ctx.entropy_data


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.state_machine)
	ctx.root.add_child(ctx.world_env)


## Pack a bare InventoryItem with its id authored, so instantiate() carries the
## identity and _ready() builds the colored placeholder mesh.
func _pack_inventory(id: StringName) -> PackedScene:
	var item := InventoryItem.new()
	item.item_id = id
	var scene := PackedScene.new()
	scene.pack(item)
	item.free()
	return scene


## Clean-room defaults only; AtmosphereController owns these values from its first
## _apply_atmosphere() onward.
func _build_apartment_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.045, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.83, 0.80)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.28, 0.26)
	env.fog_density = 0.004
	# Without this the fog paints the whole background its own color (default 1.0) and
	# the room floats in brown soup (confirmed on the first real render).
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	return env
