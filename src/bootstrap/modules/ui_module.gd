extends BootstrapModule
## The Core HUD (Ticket-07): meters, interaction prompt, dream state, loop flavor text.
## Its references are all assigned in wire(), before CoreHud._ready forwards them to
## HudUI, so the prompt and flavor-text signals connect.


func create(ctx: BootstrapContext) -> void:
	ctx.core_hud = CoreHud.new()
	ctx.core_hud.name = "CoreHud"


func wire(ctx: BootstrapContext) -> void:
	ctx.core_hud.state_machine = ctx.state_machine
	ctx.core_hud.interaction_controller = ctx.interaction
	ctx.core_hud.dreamscape_manager = ctx.dreamscape_manager
	ctx.core_hud.endgame_loop_manager = ctx.endgame


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.core_hud)
