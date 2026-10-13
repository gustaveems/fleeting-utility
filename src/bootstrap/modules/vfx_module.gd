extends BootstrapModule
## Ticket-11: world particles. The director parents each emitter into its WorldRoot.


func create(ctx: BootstrapContext) -> void:
	ctx.vfx_director = VfxDirector.new()
	ctx.vfx_director.name = "VfxDirector"


func wire(ctx: BootstrapContext) -> void:
	var v := ctx.vfx_director
	v.game_flow = ctx.game_flow
	v.state_machine = ctx.state_machine
	v.entropy_data = ctx.entropy_data
	v.player = ctx.player
	v.apartment = ctx.apartment
	v.valley = ctx.valley


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.vfx_director)
