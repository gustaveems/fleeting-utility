extends BootstrapModule
## The small daily things (docs/STORY.md 8a–c): the notice under the door, the radio on the
## table, LeaseLink, the day card. Runs after the standing and act_one modules.

## Inside the door, clear of its own prompt.
const ENVELOPE_AT := Vector3(1.1, 0.0, -3.0)
## Over the boombox, on the side he can reach the table from.
const RADIO_AT := Vector3(-3.3, 0.0, 1.95)


func create(ctx: BootstrapContext) -> void:
	ctx.daily_life = DailyLife.new()
	ctx.daily_life.name = "DailyLife"
	ctx.notice_panel = NoticePanel.new()
	ctx.notice_panel.name = "NoticePanel"
	ctx.envelope = NoticeEnvelope.new()
	ctx.envelope.name = "NoticeEnvelope"
	ctx.radio = RadioSet.new()
	ctx.radio.name = "RadioSet"
	ctx.phone = LeasePhone.new()
	ctx.phone.name = "LeasePhone"
	ctx.day_card = DayCard.new()
	ctx.day_card.name = "DayCard"


func wire(ctx: BootstrapContext) -> void:
	var d := ctx.daily_life
	d.day_cycle = ctx.day_cycle
	d.state_data = ctx.state_data
	d.ransacked = ctx.ransacked
	d.head_call = ctx.head_call
	ctx.notice_panel.player = ctx.player
	ctx.notice_panel.interaction = ctx.interaction
	ctx.envelope.daily = d
	ctx.envelope.panel = ctx.notice_panel
	ctx.envelope.player = ctx.player
	ctx.envelope.interaction_controller = ctx.interaction
	ctx.envelope.position = ENVELOPE_AT
	ctx.radio.daily = d
	ctx.radio.runner = ctx.dialogue
	ctx.radio.player = ctx.player
	ctx.radio.interaction_controller = ctx.interaction
	ctx.radio.position = RADIO_AT
	ctx.phone.player = ctx.player
	ctx.phone.daily = d
	ctx.phone.standing = ctx.standing
	ctx.phone.day_cycle = ctx.day_cycle
	ctx.phone.dreamscape_manager = ctx.dreamscape_manager
	ctx.day_card.day_cycle = ctx.day_cycle
	ctx.next_step.daily = d
	ctx.lease_renewal.daily_life = d
	ctx.persistence.daily_life = d


func attach(ctx: BootstrapContext) -> void:
	ctx.root.add_child(ctx.daily_life)
	ctx.apartment.add_child(ctx.envelope)
	ctx.apartment.add_child(ctx.radio)
	ctx.root.add_child(ctx.notice_panel)
	ctx.root.add_child(ctx.phone)
	ctx.root.add_child(ctx.day_card)


func post_attach(ctx: BootstrapContext) -> void:
	WallPaper.set_decay(ctx.entropy_data.entropy)
	ctx.entropy_data.entropy_changed.connect(WallPaper.set_decay)
