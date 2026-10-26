class_name WorkspaceBootstrap
extends Node3D
## COMPOSITION ROOT — workspace.tscn is one Node3D running this script; everything else
## is built in code by the modules below.
##
## PHASES (see BootstrapModule)
## ----------------------------
## Each phase runs across every module before the next phase starts:
##   create → wire → attach → post_attach
## so any node's _ready sees every export already assigned, whatever the module order.
## Module order only decides tree order (and therefore process order).
##
##   core       data, state machine, WorldEnvironment, packed item scenes, demo seed
##   apartment  the apartment WorldRoot: lights, blockout, clutter, decals, atmosphere,
##              bench, fidget object, door
##   player     player, iso camera, screen effects (incl. vignette)
##   valley     dreamscape world + manager + HUD, ambulance, statue narratives
##   narrative  interaction gate, endgame loop, self-soothing, park, ransack, visions,
##              hesitation
##   audio      bus graph + AudioDirector (soundscape keyed off GameFlow)
##   vfx        VfxDirector: dust and falling leaves, frozen with their worlds
##   ui         Core HUD + pause menu
##   settings   applies the player's GameSettings (volumes, accessibility, palette)
##   persistence  save/load; last, so a save restores onto the finished world
##
## DEV RIG: TAB overload +20 · T entropy +20 · R entropy reset · N toggle dreamscape ·
##          F9 wipe the save.

const MODULES: Array[GDScript] = [
	preload("res://src/bootstrap/modules/core_module.gd"),
	preload("res://src/bootstrap/modules/apartment_module.gd"),
	preload("res://src/bootstrap/modules/player_module.gd"),
	preload("res://src/bootstrap/modules/valley_module.gd"),
	preload("res://src/bootstrap/modules/narrative_module.gd"),
	preload("res://src/bootstrap/modules/audio_module.gd"),
	preload("res://src/bootstrap/modules/vfx_module.gd"),
	preload("res://src/bootstrap/modules/ui_module.gd"),
	preload("res://src/bootstrap/modules/night_zero_module.gd"),
	preload("res://src/bootstrap/modules/act_one_module.gd"),
	preload("res://src/bootstrap/modules/promises_module.gd"),
	preload("res://src/bootstrap/modules/settings_module.gd"),
	preload("res://src/bootstrap/modules/persistence_module.gd"),
]

## Dev rig injection amounts.
const DEV_OVERLOAD_DUMP := 20.0
const DEV_ENTROPY_DUMP := 20.0

## Read-only after _ready: the typed registry of every built node.
var ctx: BootstrapContext


func _ready() -> void:
	InputActionData.register()
	ctx = BootstrapContext.new()
	ctx.root = self
	var modules: Array[BootstrapModule] = []
	for script in MODULES:
		modules.append(script.new() as BootstrapModule)
	for m in modules:
		m.create(ctx)
	for m in modules:
		m.wire(ctx)
	for m in modules:
		m.attach(ctx)
	for m in modules:
		m.post_attach(ctx)


func _process(_delta: float) -> void:
	_drive_edge_proximity()
	_handle_dev_keys()


func _handle_dev_keys() -> void:
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_DUMP_OVERLOAD):
		ctx.state_data.apply_overload_pressure(DEV_OVERLOAD_DUMP)
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_DUMP_ENTROPY):
		var data := ctx.entropy_data
		data.entropy = clampf(data.entropy + DEV_ENTROPY_DUMP, 0.0, 100.0)
		data.entropy_changed.emit(data.entropy)
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_RESET_ENTROPY):
		ctx.entropy_data.reset()
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_WIPE_SAVE):
		ctx.persistence.wipe()
		print("Save wiped: the next launch starts fresh.")


## Live vignette drive: edge proximity from the room footprint (same math as
## WorkspaceBlockout), each frame.
func _drive_edge_proximity() -> void:
	var cell := ctx.grid.world_to_cell(ctx.player.global_position)
	# Outside the apartment footprint (the valley, the park) there is no room edge to
	# express. Without this guard the out-of-range cell reads as closeness 1.0 and the
	# vignette closes in across the whole dreamscape.
	if not ctx.grid.contains(cell):
		ctx.screen_effects.set_edge_proximity(0.0)
		return
	ctx.screen_effects.set_edge_proximity(ctx.grid.edge_closeness(cell))
