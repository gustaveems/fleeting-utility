extends BootstrapModule
## Self-belief (Ticket-19): hidden, felt through the easel, the compulsion threshold and
## the people who notice. Runs after the act_one module (the dialogue runner, ActOne).


func create(ctx: BootstrapContext) -> void:
	ctx.self_belief = SelfBelief.new()
	ctx.self_belief.name = "SelfBelief"


func wire(ctx: BootstrapContext) -> void:
	var b := ctx.self_belief
	b.state_data = ctx.state_data
	b.soothing = ctx.self_soothing
	b.easel = ctx.easel
	b.day_cycle = ctx.day_cycle
	b.runner = ctx.dialogue
	b.act_one = ctx.act_one
	ctx.easel.self_belief = b
	ctx.lease_renewal.self_belief = b
	ctx.persistence.self_belief = b


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.self_belief)
