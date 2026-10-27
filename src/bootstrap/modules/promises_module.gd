extends BootstrapModule
## The promises (Ticket-18): Focus+ offers by head call, through the shared
## DialogueRunner (after the act_one module), and the leased ad screen on his wall.

## On the west wall (proud of its plaster, like the hung works), north of them, facing
## into the room (+X).
const SCREEN_POSITION := Vector3(-4.41, 0.8, -2.6)


func create(ctx: BootstrapContext) -> void:
	ctx.promises = Promises.new()
	ctx.promises.name = "Promises"
	ctx.ad_screen = AdScreen.new()
	ctx.ad_screen.name = "AdScreen"


func wire(ctx: BootstrapContext) -> void:
	var p := ctx.promises
	p.day_cycle = ctx.day_cycle
	p.runner = ctx.dialogue
	p.state_data = ctx.state_data
	p.entropy_data = ctx.entropy_data
	p.hud = ctx.core_hud
	p.state_machine = ctx.state_machine
	p.dreamscape_manager = ctx.dreamscape_manager
	p.ransacked = ctx.ransacked
	ctx.ambulance.care = p
	ctx.endgame.care = p
	ctx.end_card.care = p
	ctx.ad_screen.promises = p
	ctx.ad_screen.position = SCREEN_POSITION
	ctx.ad_screen.rotation_degrees.y = 90.0
	ctx.lease_renewal.promises = p
	ctx.persistence.promises = p


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.promises)
	ctx.apartment.add_child(ctx.ad_screen)
