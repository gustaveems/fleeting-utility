extends BootstrapModule
## The Core HUD (Ticket-07): meters, interaction prompt, dream state, loop flavor text.
## And the Esc pause menu (Ticket-13).
## Its references are all assigned in wire(), before CoreHud._ready forwards them to
## HudUI, so the prompt and flavor-text signals connect.


func create(ctx: BootstrapContext) -> void:
	ctx.core_hud = CoreHud.new()
	ctx.core_hud.name = "CoreHud"
	ctx.fader = ScreenFader.new()
	ctx.fader.name = "ScreenFader"
	ctx.pause_menu = PauseMenu.new()
	ctx.pause_menu.name = "PauseMenu"


func wire(ctx: BootstrapContext) -> void:
	ctx.core_hud.state_machine = ctx.state_machine
	ctx.core_hud.interaction_controller = ctx.interaction
	ctx.core_hud.dreamscape_manager = ctx.dreamscape_manager
	ctx.core_hud.endgame_loop_manager = ctx.endgame
	ctx.pause_menu.persistence = ctx.persistence
	ctx.park.fader = ctx.fader
	# Arrival lines for the walk: where you are, and what happened while you were out.
	ctx.park.walk_started.connect(func(): ctx.core_hud.show_line(CorporateParkManager.ARRIVAL_TEXT))
	ctx.ransacked.ransacked_applied.connect(
		func(): ctx.core_hud.show_line(RansackedStateManager.RETURN_TEXT)
	)
	# Narrative lines that must reach the player's eyes, not just stdout.
	ctx.ransacked.betrayal_realized.connect(ctx.core_hud.show_line)


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.core_hud)
	ctx.root.add_child(ctx.fader)
	ctx.root.add_child(ctx.pause_menu)


## Statue narratives exist only after the valley module's post_attach (module order:
## valley before ui).
func post_attach(ctx: BootstrapContext) -> void:
	for narrative in ctx.statue_narratives:
		narrative.statue_truth_revealed.connect(ctx.core_hud.show_line)
