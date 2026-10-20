class_name PrologueScript
extends RefCounted
## DATA — the prologue film (Ticket-15): the maglev route, the shot list, the billboards
## and the lines. Everything about timing and framing is here, so tuning the film is
## editing this file. See docs/tickets/TICKET-15.md.
##
## `d` is metres along the track; `w` is the fraction (0..1) of his walk. Modes:
##   FP           first person from his seat, looking out the right-hand window
##   FP_AISLE     first person, standing in the packed aisle looking down the carriage
##   EXT_FIXED    a static camera at `cam`, looking at `look` (or the train if absent)
##   EXT_FOLLOW   a camera riding with the train at train-local offset `cam`
##   WALK_FOLLOW  third person, following him up the avenue and round the corner
## A shot may carry one gaze moment: the first-person view turns to `target` for
## [`from`, `to`] of the shot (0..1), easing in and out.

enum Mode { FP, FP_AISLE, EXT_FIXED, EXT_FOLLOW, WALK_FOLLOW }

## Track control points (metres; y is the elevated rail height).
const ROUTE: Array[Vector3] = [
	Vector3(-620, 12, 0),  # the town station
	Vector3(-450, 12, 0),
	Vector3(-330, 12, 0),  # tunnel mouth
	Vector3(-260, 12, 0),  # tunnel exit: the city's edge
	Vector3(-170, 16, -30),
	Vector3(-60, 20, -40),  # the monolith canyon begins
	Vector3(40, 20, -20),
	Vector3(140, 18, 20),
	Vector3(230, 14, 30),  # between the colossus's legs, over the canal
	Vector3(320, 10, 10),
	Vector3(370, 8, -15),  # the descent into the low blocks
	Vector3(398, 6, -45),
	Vector3(403, 6, -70),  # his station: the line runs along the avenue's left side
	Vector3(403, 6, -95),
]

## Where the districts change (distance along the track).
const TOWN_END := 290.0
const TUNNEL_START := 290.0
const TUNNEL_END := 360.0
const LOW_BLOCKS_START := 960.0

## Distance where the colossus straddles the track.
const COLOSSUS_AT := 880.0

## Billboards: [distance, side (+1 right / -1 left), height, text, colour].
const BILLBOARDS: Array = [
	[420.0, -1, 34.0, "UPGRADE YOUR FOCUS", Color(0.88, 0.2, 0.6)],
	[520.0, 1, 30.0, "OUTPERFORM YOURSELF", Color(0.2, 0.84, 0.9)],
	[640.0, 1, 26.0, "HERITAGE COLLECTION", Color(0.85, 0.62, 0.3)],  # the campaign
	[760.0, -1, 38.0, "THE FUTURE IS LEASED", Color(0.88, 0.2, 0.6)],
	[1010.0, 1, 18.0, "FOCUS+ NOW IN YOUR DISTRICT", Color(0.2, 0.84, 0.9)],
]
const CAMPAIGN_BILLBOARD := 2

## Where the train stops (the end of the line).
const END_OF_LINE := 1108.0

const LEASE_TEXT := "LEASE CONFIRMED\nUnit 7-14B, Block 31\nTerms apply. Renewal at discretion."
const TITLE := "FLEETING UTILITY"

## The avenue walk: how long it takes and where (walk fraction) it hands to the door shot.
const WALK_DUR := 36.0
const WALK_END := 0.9


## The shot list. `d` = [train distance at start, at end]. A shot's `events` cue the
## avenue ([time, name]).
static func shots() -> Array[Dictionary]:
	# Walk marks come from the avenue's path: the curb where he waits, and the moment
	# (seconds into the walk) the fight at the corner starts, for its lines.
	var curb := PrologueAvenue.progress_at(PrologueAvenue.CURB)
	var fight := (PrologueAvenue.fight_progress() - curb) / (WALK_END - curb) * WALK_DUR
	return [
		{
			"name": "town_establishing",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"d": [0.0, 40.0],
			"cam": Vector3(-560, 9, 34),
			"look": Vector3(-610, 10, 0),
			"fov": 50.0,
			"lines": [[0.5, "PA: Regional line 4. Doors closing."]],
		},
		{
			"name": "town_window",
			"mode": Mode.FP,
			"dur": 10.0,
			"d": [40.0, 230.0],
			"fov": 62.0,
			"lines": [[2.0, "PA: This service does not return."]],
		},
		{
			"name": "tunnel",
			"mode": Mode.FP,
			"dur": 6.0,
			"d": [230.0, 400.0],
			"fov": 62.0,
			"lines": [[3.5, "RADIO: …lease rates in the inner districts rose again overnight…"]],
		},
		{
			"name": "carriage_interior",
			"mode": Mode.FP_AISLE,
			"dur": 7.0,
			"d": [400.0, 450.0],
			"fov": 70.0,
			"lines": [[1.0, "PA: For your safety, do not cross the line."]],
		},
		{
			"name": "aerial_canyon",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"d": [450.0, 530.0],
			"cam": Vector3(-60, 230, 330),
			"look": Vector3(40, 15, -30),
			"fov": 55.0,
			"lines": [[1.0, "RADIO: Upgrade your focus. Outperform yourself."]],
		},
		{
			"name": "canyon_campaign",
			"mode": Mode.FP,
			"dur": 14.0,
			"d": [530.0, 700.0],
			"fov": 62.0,
			"gaze": {"target": "campaign", "from": 0.25, "to": 0.8},
			"lines":
			[
				[1.0, "RADIO: The Heritage Collection. Walk where your ancestors stood."],
				[7.0, "RADIO: Authenticity, now available on lease."],
			],
		},
		{
			"name": "phone_lease",
			"mode": Mode.FP,
			"dur": 8.0,
			"d": [700.0, 790.0],
			"fov": 62.0,
			"gaze": {"target": "phone", "from": 0.1, "to": 0.85},
			"lines": [],
		},
		{
			"name": "colossus_reveal",
			"mode": Mode.EXT_FIXED,
			"dur": 10.0,
			"d": [790.0, 880.0],
			"cam": Vector3(150, 20, 120),
			"look": Vector3(230, 30, 30),
			"fov": 48.0,
			"lines": [[1.5, "PA: Colossus Canal. Please do not photograph the landmark."]],
		},
		{
			"name": "colossus_beneath",
			"mode": Mode.FP,
			"dur": 8.0,
			"d": [880.0, 960.0],
			"fov": 66.0,
			"gaze": {"target": "colossus", "from": 0.0, "to": 0.9},
			"lines": [],
		},
		{
			"name": "descent",
			"mode": Mode.EXT_FOLLOW,
			"dur": 8.0,
			"d": [960.0, END_OF_LINE],
			"cam": Vector3(10, 30, 34),
			"fov": 58.0,
			"lines": [[2.0, "PA: Block 31. Mind the gap. Mind your lease."]],
		},
		{
			"name": "station_exit",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [0.0, curb],
			"cam": Vector3(427, 1.6, -58),
			"look": Vector3(413, 3.5, -71),
			"fov": 55.0,
			"lines": [[1.0, "SPEAKER: Residents remain on their side of the line."]],
		},
		{
			# He waits at the curb; a car rides past, then ten people cross to the metro.
			"name": "curb_wait",
			"mode": Mode.WALK_FOLLOW,
			"dur": 7.0,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [curb, curb],
			"fov": 58.0,
			"events": [[0.2, "car"], [3.6, "crowd"]],
			"lines": [],
		},
		{
			"name": "avenue_walk",
			"mode": Mode.WALK_FOLLOW,
			"dur": WALK_DUR,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [curb, WALK_END],
			"fov": 58.0,
			"lines":
			[
				[3.0, "VENDOR: Focus! Fresh focus, cheap, cheaper than theirs."],
				[11.0, "BOUTIQUE: Heritage Collection. By appointment."],
				[fight - 0.6, "— you calling me a liar? — "],
				[fight + 0.4, "…get off me — get OFF me…"],
			],
		},
		{
			"name": "his_door",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [WALK_END, 1.0],
			"cam": Vector3(452.6, 0.6, -107),
			"look": Vector3(452, 9, -126),
			"fov": 60.0,
			"lines": [],
			"title": true,
		},
	]


static func total_duration() -> float:
	var total := 0.0
	for s in shots():
		total += float(s["dur"])
	return total
