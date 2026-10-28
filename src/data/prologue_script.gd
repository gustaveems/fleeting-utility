class_name PrologueScript
extends RefCounted
## DATA — the prologue film (Ticket-15): the maglev route, the shot list, the billboards
## and the lines. Everything about timing and framing is here, so tuning the film is
## editing this file. See docs/tickets/TICKET-15.md.
##
## The film is fully cinematic (no first-person POV): one camera that GLIDES from each
## shot into the next over `blend` seconds, except where a shot says `cut`.
## `d` is metres along the track; `w` is the fraction (0..1) of his walk. Modes:
##   EXT_FIXED    a static camera at `cam`, looking at `look`
##   EXT_PATH     a camera travelling through the `cam` points, looking at `look`
##   EXT_FOLLOW   riding with the train: carriage-local offsets `cam` (one point, or a
##                path to travel), carriage `car` (default the lead), looking at `look`
##   INTERIOR     handheld inside his carriage: local `cam` and `look` paths, shaking
##   WALK_FOLLOW  third person, behind his shoulder, turning with him
##   TOP_TRACK    high over the metro side looking down on the street, sliding with him
##                (`cam` / `look` are world points whose z is relative to his)
## `look` is a world point or a named target: "train", "campaign", "colossus", "hero".
## `gaze` names the beat a shot frames (the ad, his phone, the colossus); `phone` is the
## [from, to] span (0..1) the lease notification shows; `interior` shows his carriage's
## inside from outside shots (the camera flies through it).

enum Mode { EXT_FIXED, EXT_PATH, EXT_FOLLOW, INTERIOR, WALK_FOLLOW, TOP_TRACK }

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
## Its lettering under the image (CampaignArt): the brand, small; the image sells.
const CAMPAIGN_BRAND := "HERITAGE COLLECTION\nAuthentic origin."

## Where the train stops (the end of the line).
const END_OF_LINE := 1108.0

const LEASE_TEXT := "LEASE CONFIRMED\nUnit 7-14B, Block 31\nTerms apply. Renewal at discretion."
const TITLE := "FLEETING UTILITY"

## His walking pace (m/s), and where (walk fraction) the walk hands to the door shot.
const WALK_SPEED := 2.3
const WALK_END := 0.9
## The walk's camera marks (metres along his path): the top view starts this far up the
## median, and third person returns this far before the corner.
const TOP_AFTER_MEDIAN := 6.0
const BACK_BEFORE_CORNER := 3.0


## The shot list. `d` = [train distance at start, at end]. The train runs at one steady
## ~19–20 m/s wherever it is seen from outside.
static func shots() -> Array[Dictionary]:
	# Walk marks come from the avenue's path (metres → fractions and durations).
	var total := PrologueAvenue.walk_length()
	var curb := PrologueAvenue.path_distance(PrologueAvenue.CURB)
	var top_from := PrologueAvenue.path_distance(PrologueAvenue.CURB + 1) + TOP_AFTER_MEDIAN
	var top_to := PrologueAvenue.path_distance(PrologueAvenue.CORNER) - BACK_BEFORE_CORNER
	var end := WALK_END * total
	var fight := PrologueAvenue.fight_progress() * total
	var fight_t := (fight - top_to) / WALK_SPEED  # seconds into the corner shot
	return [
		{
			"name": "town_establishing",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"d": [0.0, 150.0],
			"cam": Vector3(-560, 9, 34),
			"look": Vector3(-610, 10, 0),
			"fov": 50.0,
			"lines": [[0.5, "PA: Regional line 4. Doors closing."]],
		},
		{
			# Glide down beside the train and slide back along it over the dying town.
			"name": "town_glide",
			"mode": Mode.EXT_FOLLOW,
			"dur": 8.0,
			"blend": 3.0,
			"d": [150.0, 300.0],
			"cam": [Vector3(9, 1.5, -14), Vector3(10, 3.0, 34)],
			"look": "train",
			"fov": 55.0,
			"lines": [[3.0, "PA: This service does not return."]],
		},
		{
			"name": "tunnel",
			"mode": Mode.EXT_FOLLOW,
			"dur": 5.5,
			"blend": 2.0,
			"d": [300.0, 410.0],
			"cam": [Vector3(0, 3.6, 30), Vector3(0, 3.0, 18)],
			"look": "train",
			"fov": 60.0,
			"lines": [[3.5, "RADIO: …lease rates in the inner districts rose again overnight…"]],
		},
		{
			"name": "aerial_canyon",
			"mode": Mode.EXT_PATH,
			"dur": 6.0,
			"cut": true,
			"d": [410.0, 530.0],
			"cam": [Vector3(-60, 230, 330), Vector3(-20, 150, 200)],
			"look": "train",  # threading the canyon (Phase B: the walls part for it)
			"fov": 55.0,
			"lines": [[1.0, "RADIO: Upgrade your focus. Outperform yourself."]],
		},
		{
			# Through the train: in at the left windows, through the packed carriage, out
			# the right, holding on the campaign.
			"name": "through_train",
			"mode": Mode.EXT_FOLLOW,
			"dur": 8.0,
			"cut": true,  # a glide down from the aerial would pass through the towers
			"d": [530.0, 690.0],
			"car": 1,
			"cam":
			[Vector3(-9, 2.2, 6), Vector3(-2.5, 1.7, 2), Vector3(2.5, 1.7, -1), Vector3(9, 3, -3)],
			"look": "campaign",
			"interior": true,
			"gaze": "campaign",
			"fov": 60.0,
			"lines":
			[
				[1.0, "RADIO: The Heritage Collection. Walk where your ancestors stood."],
				[4.5, "RADIO: Authenticity, now available on lease."],
			],
		},
		{
			# Inside the metro, handheld and shaking: down the packed aisle to him, over his
			# shoulder, the lease on his phone.
			"name": "metro_interior",
			"mode": Mode.INTERIOR,
			"dur": 8.0,
			"cut": true,
			"d": [690.0, 770.0],
			"cam": [Vector3(0.45, 1.75, -8.2), Vector3(0.5, 1.68, 1.2), Vector3(1.0, 1.9, 3.7)],
			"look": [Vector3(0.2, 1.4, 8.0), Vector3(0.9, 1.0, 4.6), Vector3(0.77, 0.92, 4.55)],
			"gaze": "phone",
			"phone": [0.62, 0.98],
			"fov": 66.0,
			"lines": [[1.0, "PA: For your safety, do not cross the line."]],
		},
		{
			"name": "colossus_reveal",
			"mode": Mode.EXT_PATH,
			"dur": 5.5,
			"cut": true,
			"d": [770.0, 880.0],
			"cam": [Vector3(150, 20, 120), Vector3(172, 26, 98)],
			"look": Vector3(230, 30, 30),
			"fov": 48.0,
			"lines": [[1.5, "PA: Colossus Canal. Please do not photograph the landmark."]],
		},
		{
			# Through the statue: chasing the train between its legs, tilting up to the head.
			"name": "through_statue",
			"mode": Mode.EXT_FOLLOW,
			"dur": 5.0,
			"blend": 2.5,
			"d": [880.0, 980.0],
			"cam": [Vector3(2, 7, 30), Vector3(1.5, 3.5, 4)],
			"look": "colossus",
			"gaze": "colossus",
			"fov": 66.0,
			"lines": [],
		},
		{
			"name": "descent",
			"mode": Mode.EXT_FOLLOW,
			"dur": 6.4,
			"blend": 1.5,
			"d": [980.0, END_OF_LINE],
			"cam": Vector3(10, 30, 34),
			"look": "train",
			"fov": 58.0,
			"lines": [[2.0, "PA: Block 31. Mind the gap. Mind your lease."]],
		},
		{
			"name": "station_exit",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"cut": true,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [0.0, curb / total],
			"cam": Vector3(427, 1.6, -58),
			"look": Vector3(413, 3.5, -71),
			"fov": 55.0,
			"lines": [[1.0, "SPEAKER: Residents remain on their side of the line."]],
		},
		{
			"name": "avenue_walk",
			"mode": Mode.WALK_FOLLOW,
			"dur": (top_from - curb) / WALK_SPEED,
			"blend": 0.0,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [curb / total, top_from / total],
			"fov": 58.0,
			# The crowd crosses to the metro against him; the car rides past behind him.
			"events": [[0.0, "crowd"], [5.5, "car"]],
			"lines": [[3.0, "VENDOR: Focus! Fresh focus, cheap, cheaper than theirs."]],
		},
		{
			# The camera glides off him to the metro side and up: the whole street below.
			"name": "avenue_top",
			"mode": Mode.TOP_TRACK,
			"dur": (top_to - top_from) / WALK_SPEED,
			"blend": 4.0,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [top_from / total, top_to / total],
			"cam": Vector3(418, 28, 12),
			"look": Vector3(434, 0, -4),
			"fov": 58.0,
			"lines": [[2.5, "BOUTIQUE: Heritage Collection. By appointment."]],
		},
		{
			# Back behind his shoulder 3 m before the corner: the fight starts, he turns.
			"name": "corner_walk",
			"mode": Mode.WALK_FOLLOW,
			"dur": (end - top_to) / WALK_SPEED,
			"blend": 1.4,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [top_to / total, WALK_END],
			"fov": 58.0,
			"lines":
			[
				[fight_t - 0.6, "— you calling me a liar? — "],
				[fight_t + 0.4, "…get off me — get OFF me…"],
			],
		},
		{
			"name": "his_door",
			"mode": Mode.EXT_FIXED,
			"dur": 8.0,
			"cut": true,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [WALK_END, 1.0],
			"cam": Vector3(452.6, 0.6, -107),
			"look": Vector3(452, 9, -126),
			"fov": 60.0,
			"lines": [],
			"title": true,
		},
		{
			# N1: the friend calls, straight into his head, at his door (Night Zero).
			"name": "the_call",
			"mode": Mode.EXT_PATH,
			"dur": 16.0,
			"blend": 0.0,
			"d": [END_OF_LINE, END_OF_LINE],
			"w": [1.0, 1.0],
			"cam": [Vector3(452.6, 0.6, -107), Vector3(452.4, 1.4, -111.5)],
			"look": Vector3(452, 2.2, -118),
			"fov": 58.0,
			"call": "arrival",
			"lines": [],
		},
	]


static func total_duration() -> float:
	var total := 0.0
	for s in shots():
		total += float(s["dur"])
	return total
