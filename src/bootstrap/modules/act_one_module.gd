extends BootstrapModule
## Act I's people (Ticket-17): the friend's calls, the borrowed painting, the neighbour
## through the wall. A DialogueRunner + ChoicePanel for the game world (the evening has
## its own), sharing Night Zero's HeadCall. Runs after the night_zero module.


func create(ctx: BootstrapContext) -> void:
	ctx.choices = ChoicePanel.new()
	ctx.choices.name = "ChoicePanel"
	ctx.dialogue = DialogueRunner.new()
	ctx.dialogue.name = "DialogueRunner"
	ctx.act_one = ActOne.new()
	ctx.act_one.name = "ActOne"


func wire(ctx: BootstrapContext) -> void:
	ctx.dialogue.head_call = ctx.head_call
	ctx.dialogue.choices_ui = ctx.choices
	ctx.dialogue.interaction = ctx.interaction
	var a := ctx.act_one
	a.day_cycle = ctx.day_cycle
	a.easel = ctx.easel
	a.game_flow = ctx.game_flow
	a.entropy_data = ctx.entropy_data
	a.runner = ctx.dialogue
	a.hud = ctx.core_hud
	ctx.lease_renewal.act_one = a
	ctx.persistence.act_one = a


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.choices)
	ctx.root.add_child(ctx.dialogue)
	ctx.apartment.add_child(ctx.act_one)
