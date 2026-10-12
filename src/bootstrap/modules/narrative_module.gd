extends BootstrapModule
## The narrative systems from Ticket-06 onward: the interaction lock gate, the scarred
## reset loop, self-soothing, the corporate park walk, the ransacked apartment, the dual
## visions and the hesitation at the door.


func create(ctx: BootstrapContext) -> void:
	ctx.interaction = InteractionController.new()
	ctx.interaction.name = "InteractionController"

	ctx.endgame = EndgameLoopManager.new()
	ctx.endgame.name = "EndgameLoopManager"

	ctx.self_soothing = SelfSoothingController.new()
	ctx.self_soothing.name = "SelfSoothingController"

	ctx.park = CorporateParkManager.new()
	ctx.park.name = "CorporateParkManager"

	ctx.ransacked = RansackedStateManager.new()
	ctx.ransacked.name = "RansackedStateManager"

	ctx.dual_vision = DualVisionController.new()
	ctx.dual_vision.name = "DualVisionController"

	ctx.hesitation = HesitationController.new()
	ctx.hesitation.name = "HesitationController"

	ctx.game_flow = GameFlow.new()
	ctx.game_flow.name = "GameFlow"


func wire(ctx: BootstrapContext) -> void:
	# Ticket-07: the scarred reset, plus the post-climax state it applies at the forced
	# return (Ticket-06).
	var endgame := ctx.endgame
	endgame.dreamscape_manager = ctx.dreamscape_manager
	endgame.state_machine = ctx.state_machine
	endgame.player = ctx.player
	endgame.interaction_controller = ctx.interaction
	endgame.atmosphere_controller = ctx.atmosphere
	endgame.entropy_data = ctx.entropy_data
	endgame.crafting_bench = ctx.bench
	endgame.spatial_grid = ctx.spatial_grid
	endgame.apartment_root = ctx.apartment
	endgame.screen_effects = ctx.screen_effects
	endgame.camera = ctx.camera

	# Ticket-08 Task 1: the compulsive fidget.
	var soothing := ctx.self_soothing
	soothing.state_machine = ctx.state_machine
	soothing.player = ctx.player
	soothing.camera = ctx.camera
	soothing.interaction_controller = ctx.interaction
	soothing.trivial_object = ctx.trivial_object
	soothing.apartment_root = ctx.apartment

	# Ticket-08 Task 2: the walk.
	var park := ctx.park
	park.world_environment = ctx.world_env
	park.apartment_environment = ctx.apartment_environment
	park.apartment_root = ctx.apartment
	park.player = ctx.player
	park.state_machine = ctx.state_machine
	park.interaction_controller = ctx.interaction

	# Ticket-08 Task 3: the betrayal after the walk.
	var ransacked := ctx.ransacked
	ransacked.corporate_park_manager = ctx.park
	ransacked.crafting_bench = ctx.bench
	ransacked.spatial_grid = ctx.spatial_grid
	ransacked.atmosphere_controller = ctx.atmosphere
	ransacked.apartment_root = ctx.apartment
	ransacked.player = ctx.player

	# Ticket-09: the psychological break.
	ctx.dual_vision.apartment_root = ctx.apartment
	ctx.dual_vision.valley_root = ctx.valley

	var hesitation := ctx.hesitation
	hesitation.player = ctx.player
	hesitation.apartment_door = ctx.door
	hesitation.dual_vision_controller = ctx.dual_vision
	hesitation.ransacked_state_manager = ctx.ransacked
	hesitation.camera = ctx.camera
	# The forced-detox beat (dual visions) earns the climax: the next dream is the
	# ambulance (MASTER_BRIEF order).
	ctx.dual_vision.visions_ended.connect(ctx.ambulance.arm)

	# The narrative-phase observer: one phase_changed for audio, saves and menus.
	var flow := ctx.game_flow
	flow.dreamscape_manager = ctx.dreamscape_manager
	flow.ambulance = ctx.ambulance
	flow.endgame = ctx.endgame
	flow.park = ctx.park
	flow.ransacked = ctx.ransacked
	flow.hesitation = ctx.hesitation
	flow.dual_vision = ctx.dual_vision


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.interaction)
	ctx.root.add_child(ctx.endgame)
	ctx.root.add_child(ctx.self_soothing)
	ctx.root.add_child(ctx.park)
	ctx.root.add_child(ctx.ransacked)
	ctx.root.add_child(ctx.dual_vision)
	ctx.root.add_child(ctx.hesitation)
	ctx.root.add_child(ctx.game_flow)
