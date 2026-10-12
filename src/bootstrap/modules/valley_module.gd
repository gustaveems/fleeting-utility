extends BootstrapModule
## The autumn valley (Ticket-05), the world-swap manager, its countdown HUD, the
## ambulance interception (Ticket-06) and the statue narratives (Ticket-09).


func create(ctx: BootstrapContext) -> void:
	ctx.valley = DreamscapeEnvironment.new()
	ctx.valley.name = "DreamscapeValley"

	ctx.dreamscape_manager = DreamscapeManager.new()
	ctx.dreamscape_manager.name = "DreamscapeManager"

	ctx.dreamscape_hud = DreamscapeHud.new()
	ctx.dreamscape_hud.name = "DreamscapeHud"

	ctx.ambulance = AmbulanceInterception.new()
	ctx.ambulance.name = "AmbulanceInterception"


func wire(ctx: BootstrapContext) -> void:
	var dm := ctx.dreamscape_manager
	dm.workspace_root = ctx.apartment
	dm.dreamscape_root = ctx.valley
	dm.world_environment = ctx.world_env
	dm.apartment_environment = ctx.apartment_environment
	dm.valley_environment = ctx.valley.valley_environment
	dm.player = ctx.player
	dm.state_machine = ctx.state_machine
	dm.camera = ctx.camera
	dm.interaction_controller = ctx.interaction
	# The manager self-wires its collapse trigger; only the statue-proximity edge lives
	# here, because the valley is bootstrap-built.
	ctx.valley.statue_proximity_changed.connect(dm.set_statue_proximity)

	ctx.dreamscape_hud.dreamscape_manager = dm

	ctx.ambulance.dreamscape_manager = dm
	ctx.ambulance.screen_effects = ctx.screen_effects
	ctx.ambulance.valley_root = ctx.valley


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.valley)
	ctx.root.add_child(ctx.dreamscape_manager)
	ctx.root.add_child(ctx.dreamscape_hud)
	ctx.root.add_child(ctx.ambulance)


## Anchors and statues are built in the valley's own _ready, so they exist only now.
func post_attach(ctx: BootstrapContext) -> void:
	for anchor in ctx.valley.memory_anchors:
		anchor.dreamscape_manager = ctx.dreamscape_manager
	for i in ctx.valley.statues.size():
		var narrative := StatueNarrative.new()
		narrative.name = "StatueNarrative_%d" % i
		narrative.dual_vision_controller = ctx.dual_vision
		narrative.camera = ctx.camera
		ctx.valley.statues[i].add_child(narrative)
		ctx.statue_narratives.append(narrative)
