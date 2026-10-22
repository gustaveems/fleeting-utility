class_name NightZeroScript
extends RefCounted
## DATA — Night Zero's lines (docs/STORY.md, N1–N9). Phase 1: the call, the move-in, the
## invitation. Each line is [speaker, text, seconds on screen]. Editing the chapter's
## dialogue is editing this file.
##
## The friend's name is still open (Alain: "wait"); FRIEND is the placeholder.
##
## Phase 2 (the evening) is written as DIALOGUE STEPS for DialogueRunner:
##   {"say": [speaker, text, seconds]}          a line, spoken
##   {"think": [text, seconds]}                 his thought (muted, in parentheses)
##   {"choose": {"key": k, "options": [         a choice; each option has a label, a tag
##       {"text": "...", "tag": "honest"|"fit"|"quiet", "reply": [steps]}]}}
##   {"verdict": {"honest": [steps], "fit": [steps]}}   which way the night leaned
## Choices change tone and how the table treats him, never where the night goes.

const FRIEND := "FRIEND"
const HIM := "YOU"
const THOUGHT := "THOUGHT"
## The corpo friends at dinner (veiled; first names only).
const VESNA := "VESNA"
const OKON := "OKON"
const LIOR := "LIOR"

## N1: the call, in his head, at his building's door (end of the prologue). "Did you
## sign?" sounds friendly. It is the referral fee asking.
const CALL_ARRIVAL: Array = [
	[FRIEND, "There he is! You made it. Look at you, a city boy.", 3.4],
	[FRIEND, "You're there? At the building? You signed? Good, good.", 3.6],
	[HIM, "Not yet. I'm at the door.", 2.4],
	[FRIEND, "Sign, sign. It goes fast here, units don't wait.", 3.2],
	[FRIEND, "I'm coming over. I'll help you move in.", 2.8],
]

## N3: moving in. The friend arrives, the boxes are by the door, and the friend talks
## the whole time.
const MOVE_IN_START: Array = [
	[FRIEND, "Okay. Okay. It's... compact.", 2.6],
	[FRIEND, "Boxes by the door. Stack them by the west wall, I'll supervise.", 3.4],
]
const MOVE_IN_OBJECTIVE := "Carry the boxes to the west wall.  [E] pick up · [E] put down"

## Said as boxes land, one batch per box placed (index = boxes placed so far - 1).
const MOVE_IN_PER_BOX: Array = [
	[
		[FRIEND, "Did you see the guy downstairs? Don't look at him. Don't look at anyone.", 3.6],
	],
	[
		[
			FRIEND,
			"This whole block is disgusting. Dangerous. Somebody got cut on the corner last week.",
			4.0
		],
	],
	[
		[FRIEND, "You can't stay here long, okay? It's a first step.", 2.8],
		[FRIEND, "I found you this one. It was the best I could do.", 2.8],
	],
]

## N4: the invitation.
const INVITATION: Array = [
	[FRIEND, "Done. See? You're a resident now.", 2.6],
	[FRIEND, "Dinner tonight. My people, from work. You'll love them.", 3.2],
	[HIM, "I don't have anything to wear.", 2.2],
	[FRIEND, "Nobody'll notice. Okay, they'll notice. Come anyway.", 3.0],
	[FRIEND, "I'll send a car. Corpos don't take the metro.", 3.0],
]

## Phase 1 ends here when the evening scene is unavailable (tests): Day 1 begins.
const PHASE_ONE_END := "The car never came that night."

## ----- PHASE 2: THE EVENING (N5–N9) -----------------------------------------------------

## N5: in the car, crossing to the other side.
const CAR: Array = [
	{"say": [FRIEND, "Look at it. This is where the city actually lives.", 3.0]},
	{"think": ["Even the air looks expensive here.", 2.6]},
]

## N6: the dinner.
const DINNER: Array = [
	{"say": [VESNA, "Oh! You brought someone. He's so... authentic.", 3.0]},
	{"think": ["Everyone here is dressed like the billboard.", 2.6]},
	{"say": [OKON, "So. What do you do?", 2.0]},
	{
		"choose":
		{
			"key": "work",
			"options":
			[
				{
					"text": "I paint.",
					"tag": "honest",
					"reply": [{"say": [LIOR, "Paint? Like... content? Cute.", 2.6]}],
				},
				{
					"text": "I'm in creative. Freelance.",
					"tag": "fit",
					"reply": [{"say": [OKON, "Love that. What's your engagement like?", 2.8]}],
				},
				{
					"text": "(Say nothing. Smile.)",
					"tag": "quiet",
					"reply": [{"say": [VESNA, "Mysterious. I like him.", 2.2]}],
				},
			],
		},
	},
	{"say": [OKON, "Are you on Focus+? You have to be on Focus+. I doubled my output.", 3.6]},
	{"say": [LIOR, "Where did they put you?", 2.0]},
	{
		"choose":
		{
			"key": "home",
			"options":
			[
				{
					"text": "Block 31.",
					"tag": "honest",
					"reply":
					[
						{"say": [VESNA, "Oh. You're brave.", 1.8]},
						{"say": [LIOR, "We did a shoot near there once. For the grit.", 3.0]},
					],
				},
				{
					"text": "Near the Heritage boutique.",
					"tag": "fit",
					"reply": [{"say": [FRIEND, "Great location. Up and coming.", 2.4]}],
				},
			],
		},
	},
	{"think": ["The shoes. The friend's shoes. From the campaign. Gold stitching.", 3.4]},
	{
		"choose":
		{
			"key": "shoes",
			"options":
			[
				{
					"text": "Nice shoes.",
					"tag": "honest",
					"reply":
					[
						{
							"say":
							[FRIEND, "Heritage Collection. Walk where your ancestors stood.", 3.2]
						},
						{"say": [FRIEND, "Ha. You'll get there.", 1.8]},
					],
				},
				{
					"text": "(Look away.)",
					"tag": "quiet",
					"reply": [{"think": ["Where did the money come from?", 2.4]}],
				},
			],
		},
	},
	{
		"verdict":
		{
			"honest": [{"say": [FRIEND, "You don't have to say everything, you know.", 2.8]}],
			"fit": [{"say": [FRIEND, "See? You fit right in.", 2.0]}],
		},
	},
	{"say": [FRIEND, "My treat. Referral bonus came in.", 2.4]},
	{"think": ["Was this the right decision?", 2.4]},
]

## N7: the gift, outside the restaurant.
const GIFT: Array = [
	{"say": [FRIEND, "Let me drive you back.", 2.0]},
	{
		"choose":
		{
			"key": "ride",
			"options":
			[
				{
					"text": "I'll walk. I want to see the city.",
					"tag": "honest",
					"reply": [{"say": [FRIEND, "Romantic. Okay, okay.", 2.0]}],
				},
				{
					"text": "Sure.",
					"tag": "fit",
					"reply":
					[
						{
							"say":
							[
								FRIEND,
								"Ah, work. Sorry. You'll be fine, it's safe on this side.",
								3.2
							]
						},
					],
				},
			],
		},
	},
	{"say": [FRIEND, "Here. Just to take the edge off.", 2.2]},
	{"say": [FRIEND, "Helps you adapt. Everyone's anxious the first month.", 3.0]},
	{
		"choose":
		{
			"key": "gift",
			"options":
			[
				{
					"text": "(Take it.)",
					"tag": "took",
					"reply": [{"say": [FRIEND, "Good man. Get home safe.", 2.0]}],
				},
				{
					"text": "I don't need that.",
					"tag": "refused",
					"reply": [{"say": [FRIEND, "Sure, sure. Get home safe.", 2.0]}],
				},
			],
		},
	},
]
const WALK_OBJECTIVE := "Walk to the metro."

## N8: the walk. Thoughts at the things he passes (zone name → steps).
const WALK_BEATS := {
	"shoot": [{"think": ["They're shooting the campaign. Paper leaves. A fog machine.", 3.2]}],
	"window": [{"think": ["The valley. In a shop window. Priced.", 2.8]}],
	"couple": [{"think": ["Nobody here looks tired.", 2.2]}],
}

## N9: the night train home.
const METRO: Array = [
	{"think": ["The night train. Nobody from that side takes it.", 2.8]},
	{"think": ["Workers asleep on their feet. The ads still talking to them.", 3.2]},
]

## Home: Day 1 begins. If he refused, the gift is in his bag anyway.
const HOME_LINE := "Day 1."
const BAG_LINE := "There's something in your bag. You didn't put it there."
