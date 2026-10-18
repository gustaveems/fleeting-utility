extends BootstrapModule
## Ticket-10: the bus graph and the AudioDirector. Beds are parented into the world
## roots by the director itself, so they pause with their world.


func create(ctx: BootstrapContext) -> void:
	AudioBuses.register()
	ctx.audio_director = AudioDirector.new()
	ctx.audio_director.name = "AudioDirector"


func wire(ctx: BootstrapContext) -> void:
	var a := ctx.audio_director
	a.game_flow = ctx.game_flow
	a.state_machine = ctx.state_machine
	a.entropy_data = ctx.entropy_data
	a.dreamscape_manager = ctx.dreamscape_manager
	a.ambulance = ctx.ambulance
	a.self_soothing = ctx.self_soothing
	a.trivial_object = ctx.trivial_object
	a.hesitation = ctx.hesitation
	a.dual_vision = ctx.dual_vision
	a.interaction_controller = ctx.interaction
	a.endgame = ctx.endgame
	a.ransacked = ctx.ransacked
	a.park_manager = ctx.park
	a.apartment = ctx.apartment
	a.valley = ctx.valley
	a.easel = ctx.easel
	a.day_cycle = ctx.day_cycle


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.audio_director)


## Statue narratives are created in the valley module's post_attach (valley runs first).
func post_attach(ctx: BootstrapContext) -> void:
	ctx.audio_director.listen_to_statues(ctx.statue_narratives)
