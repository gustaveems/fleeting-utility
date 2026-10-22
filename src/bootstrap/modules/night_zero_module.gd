extends BootstrapModule
## Night Zero (Ticket-16): the first evening. The head-call overlay and the chapter's
## director, which starts when he signs the lease arriving from the prologue (never on
## Continue or a direct boot). Runs after the ui module, which builds the lease.


func create(ctx: BootstrapContext) -> void:
	ctx.head_call = HeadCall.new()
	ctx.head_call.name = "HeadCall"
	ctx.night_zero = NightZero.new()
	ctx.night_zero.name = "NightZero"


func wire(ctx: BootstrapContext) -> void:
	var nz := ctx.night_zero
	nz.player = ctx.player
	nz.interaction = ctx.interaction
	nz.head_call = ctx.head_call
	nz.hud = ctx.core_hud
	nz.evening_scene_path = "res://scenes/evening.tscn"
	ctx.lease_signing.signed.connect(nz.start)


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.head_call)
	ctx.apartment.add_child(ctx.night_zero)


## Home from the evening (Night Zero, N9): the moved-in boxes, Day 1, the gift.
func post_attach(ctx: BootstrapContext) -> void:
	if Evening.returning:
		Evening.returning = false
		ctx.night_zero.restore_moved_in(Evening.gift_refused)
