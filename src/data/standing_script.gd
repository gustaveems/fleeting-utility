class_name StandingScript
extends RefCounted
## DATA — the status loop (docs/STORY.md 7; Alain's loop text: "mastering social
## relations in the jockeying for power and status… fuelled by greed, advancing and
## advancing"; Ticket-24). The friend's crowd invites him up; he jockeys; whatever he
## gains, they have already moved on. Same step format as NightZeroScript, plus:
##
##   an option with "off": {text, tag, reply} is the line he can only land medicated;
##   off the drug the "off" version replaces it (he stumbles). See perform().

const FRIEND := NightZeroScript.FRIEND
const HIM := NightZeroScript.HIM
const VESNA := NightZeroScript.VESNA
const OKON := NightZeroScript.OKON
const LIOR := NightZeroScript.LIOR
const THOUGHT := NightZeroScript.THOUGHT

## Standing change per answer: fitting in, telling the truth, stumbling.
const DELTA := {"fit": 7.0, "honest": -1.0, "stumble": -4.0}

## The invitations: [day, title on the banner, door menu line, the morning's HUD line].
const EVENTS: Array = [
	[
		3,
		"VESNA'S ROOFTOP · private view",
		"Go up to Vesna's rooftop.",
		"LeaseLink: Vesna invited you. Her rooftop, tonight. Dress code: Heritage.",
	],
	[
		5,
		"FOCUS+ ELITE · launch night",
		"Go to Okon's launch.",
		"LeaseLink: Okon's launch, tonight. Early holders only (you're on his list).",
	],
	[
		8,
		"LIOR'S LEASE PARTY · The Heights",
		"Go to Lior's lease party.",
		"LeaseLink: Lior's new lease. The Heights. Tonight.",
	],
]

const NIGHTS: Array = [
	[
		{"say": [VESNA, "You came! Everyone, this is the raw one.", 2.8]},
		{"think": ["Smile. Stand like them.", 2.0]},
		{"say": [OKON, "So what are you working on? Everyone's working on something.", 3.2]},
		{
			"choose":
			{
				"key": "s_work",
				"options":
				[
					{
						"text": "A heritage series. Collectors are circling.",
						"tag": "fit",
						"reply": [{"say": [OKON, "Circling. Love it. Send me the deck.", 2.6]}],
						"off":
						{
							"text": "I'm, uh... painting. Things.",
							"tag": "stumble",
							"reply": [{"say": [OKON, "...Right.", 1.6]}],
						},
					},
					{
						"text": "The same valley, over and over. I can't get it right.",
						"tag": "honest",
						"reply": [{"say": [LIOR, "That's so... sad? Is it a bit?", 2.6]}],
					},
				],
			},
		},
		{"say": [LIOR, "Are you going to the Heights launch? Everyone's going.", 2.8]},
		{
			"choose":
			{
				"key": "s_heights",
				"options":
				[
					{
						"text": "Wouldn't miss it.",
						"tag": "fit",
						"reply": [{"say": [LIOR, "I'll see if I can get you on the list.", 2.6]}],
						"off":
						{
							"text": "The what?",
							"tag": "stumble",
							"reply": [{"say": [LIOR, "Oh. Never mind.", 1.8]}],
						},
					},
					{
						"text": "I can't afford the Heights.",
						"tag": "honest",
						"reply": [{"say": [VESNA, "Nobody can, darling. That's the point.", 2.8]}],
					},
				],
			},
		},
		{"say": [FRIEND, "See? You're doing great. Don't be weird.", 2.4]},
		{"think": ["Everyone's already somewhere else.", 2.4]},
	],
	[
		{"say": [OKON, "Focus+ Elite. Triple clarity. I'm an early holder.", 3.0]},
		{
			"choose":
			{
				"key": "s_elite",
				"options":
				[
					{
						"text": "I've been on the waitlist for weeks.",
						"tag": "fit",
						"reply": [{"say": [OKON, "Smart. Get in before it's gone.", 2.4]}],
						"off":
						{
							"text": "Is that... the same pills?",
							"tag": "stumble",
							"reply": [{"say": [OKON, "Wow. Okay.", 1.6]}],
						},
					},
					{
						"text": "I can barely afford the basic one.",
						"tag": "honest",
						"reply": [{"say": [OKON, "Then why are you here?", 2.0]}],
					},
				],
			},
		},
		{"say": [VESNA, "Your friend says you paint. Do you have... a following?", 3.0]},
		{
			"choose":
			{
				"key": "s_following",
				"options":
				[
					{
						"text": "It's growing. Organically.",
						"tag": "fit",
						"reply": [{"say": [VESNA, "Organic is huge right now.", 2.2]}],
						"off":
						{
							"text": "No. Not really.",
							"tag": "stumble",
							"reply": [{"say": [VESNA, "Oh.", 1.2]}],
						},
					},
					{
						"text": "Three hooks on a wall. The lease takes them every morning.",
						"tag": "honest",
						"reply": [{"say": [VESNA, "That's... dark. I love dark.", 2.4]}],
					},
				],
			},
		},
		{
			"say":
			[LIOR, "We're moving to the Heights in spring. Our floor has its own weather.", 3.4]
		},
		{"think": ["I was here last week. They're a year ahead.", 2.6]},
	],
	[
		{"say": [LIOR, "Welcome to our new lease! The view comes with the unit.", 3.0]},
		{"think": ["Their window looks down on Block 31.", 2.4]},
		{"say": [LIOR, "Wait, where are you now? Still... down there?", 2.6]},
		{
			"choose":
			{
				"key": "s_where",
				"options":
				[
					{
						"text": "Not for long. I'm in talks.",
						"tag": "fit",
						"reply": [{"say": [LIOR, "Love that for you.", 1.8]}],
						"off":
						{
							"text": "Yeah. Down there.",
							"tag": "stumble",
							"reply": [{"say": [LIOR, "Brave.", 1.4]}],
						},
					},
					{
						"text": "Block 31. You can see it from here.",
						"tag": "honest",
						"reply": [{"say": [LIOR, "Oh my god, can you? Which one's yours?", 2.6]}],
					},
				],
			},
		},
		{"say": [FRIEND, "Vesna's dropping me for the Spire crowd. Help me out here.", 3.0]},
		{
			"choose":
			{
				"key": "s_friend",
				"options":
				[
					{
						"text": "Tell them about the painting you sold.",
						"tag": "fit",
						"reply": [{"say": [FRIEND, "Ha! Yes. My client piece. Everyone—", 2.4]}],
						"off":
						{
							"text": "I can't. Not right now.",
							"tag": "stumble",
							"reply": [{"say": [FRIEND, "Useless.", 1.4]}],
						},
					},
					{
						"text": "I'm not your prop.",
						"tag": "honest",
						"reply": [{"say": [FRIEND, "Wow. Okay. Noted.", 1.8]}],
					},
				],
			},
		},
		{
			"say":
			[VESNA, "Darling, we're all off to the Spire next. Invite-only. You understand.", 3.4]
		},
		{"think": ["Advancing and advancing. And I'm standing still.", 2.8]},
	],
]

const DOOR_PROMPT := "[E] Go out tonight"
## His standing on the wall screen's corner.
const SCREEN := "LEASELINK STANDING  %d%%  ▼"

## After a night: where he stands now, and the truth of it.
const AFTER := "LeaseLink standing: %dth percentile. Everyone else moved up too."
const HOME := "Home. The room is where you left it."


## The night's steps as he can play them: medicated, every line is his; off the drug,
## the smooth ones become the stumbles.
static func perform(steps: Array, medicated: bool) -> Array:
	var out: Array = []
	for step: Dictionary in steps:
		if not step.has("choose") or medicated:
			out.append(step)
			continue
		var spec: Dictionary = step["choose"].duplicate()
		var options: Array = []
		for o: Dictionary in spec["options"]:
			options.append(o["off"] if o.has("off") else o)
		spec["options"] = options
		out.append({"choose": spec})
	return out
