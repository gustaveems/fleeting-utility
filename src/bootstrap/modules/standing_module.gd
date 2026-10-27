extends BootstrapModule
## The status loop (Ticket-24): Standing (the sinking percentile, the invitations, the
## night out) and the crowd's rooftop (RooftopLounge, a WorldRoot like the carriage).
## Runs after the promises module (the wall screen shows the standing).


func create(ctx: BootstrapContext) -> void:
	ctx.standing = Standing.new()
	ctx.standing.name = "Standing"
	ctx.lounge = RooftopLounge.new()
	ctx.lounge.name = "RooftopLounge"


func wire(ctx: BootstrapContext) -> void:
	var s := ctx.standing
	s.day_cycle = ctx.day_cycle
	s.runner = ctx.dialogue
	s.hud = ctx.core_hud
	s.player = ctx.player
	s.state_data = ctx.state_data
	s.apartment_root = ctx.apartment
	s.world_environment = ctx.world_env
	s.fader = ctx.fader
	s.lounge = ctx.lounge
	s.act_one = ctx.act_one
	ctx.door.standing = s
	ctx.ad_screen.standing = s
	ctx.lease_renewal.standing = s
	ctx.persistence.standing = s


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.standing)
	ctx.root.add_child(ctx.lounge)
