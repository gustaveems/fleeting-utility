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
	ctx.metro_carriage = MetroCarriage.new()
	ctx.metro_carriage.name = "MetroCarriage"
	ctx.metro_ride = MetroRide.new()
	ctx.metro_ride.name = "MetroRide"


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
	a.bench_station = ctx.bench_station
	a.spatial_grid = ctx.spatial_grid
	a.compound_scene = ctx.raw_compound_scene
	ctx.lease_renewal.act_one = a
	ctx.persistence.act_one = a
	var m := ctx.metro_ride
	m.world_environment = ctx.world_env
	m.apartment_root = ctx.apartment
	m.player = ctx.player
	m.state_machine = ctx.state_machine
	m.day_cycle = ctx.day_cycle
	m.runner = ctx.dialogue
	m.hud = ctx.core_hud
	m.fader = ctx.fader
	m.carriage = ctx.metro_carriage
	m.game_flow = ctx.game_flow
	ctx.persistence.metro_ride = m
	ctx.door.metro_ride = m
	ctx.door.runner = ctx.dialogue


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.choices)
	ctx.root.add_child(ctx.dialogue)
	ctx.apartment.add_child(ctx.act_one)
	ctx.root.add_child(ctx.metro_carriage)
	ctx.root.add_child(ctx.metro_ride)
