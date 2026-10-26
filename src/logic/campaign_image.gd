class_name CampaignImage
extends Node
## LOGIC — the campaign's new image (docs/STORY.md 7d, second half; Ticket-21). The
## morning after the friend says the canvas SOLD, the brand's Heritage campaign wears it,
## polished. It shows on the metro (a billboard sliding past with the city) and in the
## corporate park (a billboard by the path). The first time he sees it: "That's mine." He can call
## the friend about it ("It's inspired by. That's how it works."), which costs him
## self-belief, or let it go. The image stays up for good (a scar on the city).
##
## Lines in CampaignScript; the boards (CampaignBoard) are presentation and are handed in.

signal seen

## Days after the "sold" call before the campaign is up.
const DAYS_AFTER_SOLD := 1
## Seconds into a ride or walk before the sighting plays (after the ride's own thoughts
## have started, so they queue behind them).
const SEEN_DELAY := 1.2
## Calling the friend about it: what asking costs.
const ASK_COST := 0.1

@export var act_one: ActOne
@export var day_cycle: DayCycle
@export var runner: DialogueRunner
@export var self_belief: SelfBelief
@export var metro_ride: MetroRide
@export var park: CorporateParkManager
@export var carriage_board: CampaignBoard
@export var park_board: CampaignBoard
@export var carriage: MetroCarriage

## Saved state (Persistence "campaign").
var live_from_day: int = -1
var was_seen: bool = false
## "asked" / "silent" once he has seen it.
var reaction: String = ""


func _ready() -> void:
	if act_one != null:
		act_one.sold.connect(_on_sold)
	if metro_ride != null:
		metro_ride.ride_started.connect(func(_stage: int): _on_outing(false))
	if park != null:
		park.walk_started.connect(func(): _on_outing(true))
	if runner != null:
		runner.choice_made.connect(_on_choice)


func is_live() -> bool:
	return live_from_day > 0 and day_cycle != null and day_cycle.day >= live_from_day


## The renewed lease doesn't take the billboards down: everything stays.
func reset_cycle() -> void:
	pass


func snapshot() -> Dictionary:
	return {"live_from_day": live_from_day, "seen": was_seen, "reaction": reaction}


func restore(data: Dictionary) -> void:
	live_from_day = int(data.get("live_from_day", -1))
	was_seen = bool(data.get("seen", false))
	reaction = str(data.get("reaction", ""))


func _on_sold(day: int) -> void:
	live_from_day = day + DAYS_AFTER_SOLD


func _on_outing(in_park: bool) -> void:
	var board := park_board if in_park else carriage_board
	var live := is_live() and act_one != null
	if board != null:
		var stopped := not in_park and carriage != null and carriage.is_stopped()
		if live and not stopped:
			board.show_work(act_one.lent_work)
		else:
			board.hide_work()
	if not live or was_seen or runner == null:
		return
	was_seen = true
	if in_park and park != null:
		park.hold_return(true)  # from the start: the walk can't end before he sees it
	await get_tree().create_timer(SEEN_DELAY, false).timeout
	runner.enqueue(CampaignScript.SEEN, true)
	seen.emit()
	if in_park and park != null:
		while not runner.is_idle():
			await runner.finished
		park.hold_return(false)


func _on_choice(key: String, tag: String) -> void:
	if key != "campaign":
		return
	reaction = tag
	if tag == "asked" and self_belief != null:
		self_belief.set_value(self_belief.value - ASK_COST)
