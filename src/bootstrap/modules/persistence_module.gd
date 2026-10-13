extends BootstrapModule
## Ticket-12: save/load. Runs last so post_attach can restore a save onto a fully built
## and wired world.


func create(ctx: BootstrapContext) -> void:
	ctx.persistence = Persistence.new()
	ctx.persistence.name = "Persistence"


func wire(ctx: BootstrapContext) -> void:
	var p := ctx.persistence
	p.game_flow = ctx.game_flow
	p.state_machine = ctx.state_machine
	p.entropy_data = ctx.entropy_data
	p.park = ctx.park
	p.ransacked = ctx.ransacked
	p.hesitation = ctx.hesitation
	p.ambulance = ctx.ambulance
	p.endgame = ctx.endgame
	p.spatial_grid = ctx.spatial_grid
	p.decals = ctx.decals
	p.item_scenes = {&"raw_compound": ctx.raw_compound_scene, &"pill_bottle": ctx.pill_scene}


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.persistence)


func post_attach(ctx: BootstrapContext) -> void:
	if ctx.persistence.auto_load and ctx.persistence.has_save():
		ctx.persistence.load_game()
