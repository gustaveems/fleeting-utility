extends BootstrapModule
## The campaign's new image (Ticket-21): CampaignImage, its billboard in the corporate
## park (built here, freestanding by the path) and the one MetroCarriage carries. Runs
## after the self_belief module.

## Freestanding by the park's path, turned to the iso camera (+X+Z), so the walk
## passes it (the walls sit at the frame's top edge).
const PARK_BOARD_POSITION := Vector3(-6.0, 3.0, -9.0)
const PARK_BOARD_SCALE := 4.0


func create(ctx: BootstrapContext) -> void:
	ctx.campaign = CampaignImage.new()
	ctx.campaign.name = "CampaignImage"


func wire(ctx: BootstrapContext) -> void:
	var c := ctx.campaign
	c.act_one = ctx.act_one
	c.day_cycle = ctx.day_cycle
	c.runner = ctx.dialogue
	c.self_belief = ctx.self_belief
	c.metro_ride = ctx.metro_ride
	c.park = ctx.park
	c.carriage = ctx.metro_carriage
	ctx.lease_renewal.campaign = c
	ctx.persistence.campaign = c


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.campaign)


## The carriage and the park build their worlds in _ready: the boards exist only now.
func post_attach(ctx: BootstrapContext) -> void:
	ctx.campaign.carriage_board = ctx.metro_carriage.campaign_board
	var board := CampaignBoard.new()
	board.name = "CampaignBoard"
	board.board_scale = PARK_BOARD_SCALE
	board.position = PARK_BOARD_POSITION
	board.rotation_degrees.y = 45.0
	board.post_height = PARK_BOARD_POSITION.y
	ctx.park.get_park_root().add_child(board)
	ctx.campaign.park_board = board
