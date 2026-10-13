extends BootstrapModule
## Ticket-13: apply the player's settings to this game instance. After audio (buses must
## exist) and ui (the HUD must exist).


func create(ctx: BootstrapContext) -> void:
	ctx.settings_applier = SettingsApplier.new()
	ctx.settings_applier.name = "SettingsApplier"


func wire(ctx: BootstrapContext) -> void:
	ctx.settings_applier.screen_effects = ctx.screen_effects
	ctx.settings_applier.core_hud = ctx.core_hud


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.settings_applier)
