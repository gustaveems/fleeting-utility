extends BootstrapModule
## Forgetting and confession (Ticket-20): DreamMemory (the reach, the confession at a
## colossus's feet, the lost sentences) and DreamText (draws them). Runs after the
## act_one module (the dialogue runner).


func create(ctx: BootstrapContext) -> void:
	ctx.dream_memory = DreamMemory.new()
	ctx.dream_memory.name = "DreamMemory"
	ctx.dream_text = DreamText.new()
	ctx.dream_text.name = "DreamText"


func wire(ctx: BootstrapContext) -> void:
	var m := ctx.dream_memory
	m.dreamscape_manager = ctx.dreamscape_manager
	m.runner = ctx.dialogue
	m.player = ctx.player
	m.ambulance = ctx.ambulance
	m.camera = ctx.camera
	ctx.dreamscape_manager.dream_memory = m
	ctx.dream_text.dream_memory = m
	ctx.dream_text.dual_vision = ctx.dual_vision
	ctx.lease_renewal.dream_memory = m
	ctx.persistence.dream_memory = m


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.dream_memory)
	ctx.root.add_child(ctx.dream_text)
