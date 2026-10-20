extends BootstrapModule
## The Core HUD (Ticket-07): meters, interaction prompt, dream state, loop flavor text.
## And the Esc pause menu (Ticket-13), and the lease he signs on arrival (Ticket-15 E).
## Its references are all assigned in wire(), before CoreHud._ready forwards them to
## HudUI, so the prompt and flavor-text signals connect.


func create(ctx: BootstrapContext) -> void:
	ctx.core_hud = CoreHud.new()
	ctx.core_hud.name = "CoreHud"
	ctx.end_card = EndCard.new()
	ctx.end_card.name = "EndCard"
	ctx.lease_renewal = LeaseRenewal.new()
	ctx.lease_renewal.name = "LeaseRenewal"
	ctx.fader = ScreenFader.new()
	ctx.fader.name = "ScreenFader"
	ctx.pause_menu = PauseMenu.new()
	ctx.pause_menu.name = "PauseMenu"
	ctx.lease_signing = LeaseSigning.new()
	ctx.lease_signing.name = "LeaseSigning"


func wire(ctx: BootstrapContext) -> void:
	ctx.core_hud.state_machine = ctx.state_machine
	ctx.core_hud.interaction_controller = ctx.interaction
	ctx.core_hud.dreamscape_manager = ctx.dreamscape_manager
	ctx.core_hud.endgame_loop_manager = ctx.endgame
	ctx.pause_menu.persistence = ctx.persistence
	ctx.lease_signing.player = ctx.player
	ctx.lease_signing.interaction = ctx.interaction
	ctx.park.fader = ctx.fader

	# Ticket-14: the day on the HUD, the verdicts and the lease's notice.
	ctx.day_cycle.day_changed.connect(ctx.core_hud.set_day)
	ctx.day_cycle.morning.connect(func(day: int): ctx.core_hud.show_line("Day %d." % day))
	ctx.easel.work_finished.connect(ctx.core_hud.show_line)
	ctx.easel.works_reclaimed.connect(func(): ctx.core_hud.show_line(Easel.RECLAIM_TEXT))

	# The end of each cycle: renew the lease or walk away.
	ctx.end_card.game_flow = ctx.game_flow
	ctx.end_card.lease_renewal = ctx.lease_renewal
	ctx.end_card.entropy_data = ctx.entropy_data
	var lease := ctx.lease_renewal
	lease.game_flow = ctx.game_flow
	lease.state_machine = ctx.state_machine
	lease.entropy_data = ctx.entropy_data
	lease.endgame = ctx.endgame
	lease.ransacked = ctx.ransacked
	lease.park = ctx.park
	lease.hesitation = ctx.hesitation
	lease.ambulance = ctx.ambulance
	lease.spatial_grid = ctx.spatial_grid
	lease.persistence = ctx.persistence
	lease.compound_scene = ctx.raw_compound_scene
	lease.day_cycle = ctx.day_cycle
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
	ctx.root.add_child(ctx.lease_renewal)
	ctx.root.add_child(ctx.end_card)
	ctx.root.add_child(ctx.pause_menu)
	ctx.root.add_child(ctx.lease_signing)


## Statue narratives exist only after the valley module's post_attach (module order:
## valley before ui).
func post_attach(ctx: BootstrapContext) -> void:
	for narrative in ctx.statue_narratives:
		narrative.statue_truth_revealed.connect(ctx.core_hud.show_line)
