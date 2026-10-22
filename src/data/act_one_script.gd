class_name ActOneScript
extends RefCounted
## DATA — Act I's lines (docs/STORY.md 7a, 7b, 7d, 16a). Same step format as
## NightZeroScript (say / think / choose / verdict). Editing the act is editing this file.
##
## 7a  the friend keeps calling: warm, funny, busy; every call costs him something
## 7b  the neighbour through the wall: further down the same road; the one who asks
## 7d  the painting sold: the friend "borrows" a canvas for a client; he never sees a cent
## 16a after the ransack, the neighbour at the door (or not)

const FRIEND := NightZeroScript.FRIEND
const HIM := NightZeroScript.HIM
const NEIGHBOUR := "NEIGHBOUR"

## ----- 7a: THE FRIEND'S CALLS, by day (a head call a few seconds after he wakes) --------

const CALLS := {
	2:
	[
		{"say": [FRIEND, "Morning, resident! How's the palace?", 2.6]},
		{
			"say":
			[FRIEND, "Vesna asked about you. She thinks you're 'raw'. That's good, trust me.", 3.6]
		},
		{"say": [FRIEND, "Okay, running. Love you, bye.", 2.0]},
	],
	3:
	[
		{"say": [FRIEND, "Tiny thing. I'm sending you a form. Co-sign it for me?", 3.2]},
		{"say": [FRIEND, "It's nothing. A formality. Lease stuff.", 2.4]},
		{
			"choose":
			{
				"key": "cosign",
				"options":
				[
					{
						"text": "Sure. Send it.",
						"tag": "gave",
						"reply": [{"say": [FRIEND, "You're the best. Seriously.", 2.0]}],
					},
					{
						"text": "What is it, exactly?",
						"tag": "asked",
						"reply":
						[
							{"say": [FRIEND, "God, okay, forget it. I'll ask someone else.", 2.8]},
						],
					},
				],
			},
		},
	],
	4:
	[
		{"say": [FRIEND, "Can my guy leave a crate at yours? Just a few days.", 3.0]},
		{"say": [FRIEND, "Your place is... discreet.", 2.0]},
		{
			"choose":
			{
				"key": "crate",
				"options":
				[
					{
						"text": "Fine. A few days.",
						"tag": "gave",
						"reply":
						[{"say": [FRIEND, "He'll drop it by the door. Don't open it.", 2.8]}],
					},
					{
						"text": "I don't have room.",
						"tag": "asked",
						"reply": [{"say": [FRIEND, "You have nothing but room. Okay. Okay.", 2.6]}],
					},
				],
			},
		},
	],
	6:
	[
		{"say": [FRIEND, "Can't talk long. Big week. Huge.", 2.4]},
		{"say": [FRIEND, "You're still painting? Good. Keep painting.", 2.6]},
	],
}

## What his co-signature cost: said by the lease, much later, as a fact.
const COSIGN_COST := "Lease amended: co-signatory liabilities apply. Decay rate revised."
const CRATE_ARRIVED := "A sealed crate by the door. It isn't yours."
const CRATE_GONE := "The crate is gone too. Of course it is."

## ----- 7d: THE PAINTING (a call right after he finishes one, from day 5) ----------------

const BORROW: Array = [
	{"say": [FRIEND, "Wait, is that new? Send me a picture. Oh. Oh, that's good.", 3.2]},
	{"say": [FRIEND, "I have a client who'd die for that. Let me show it. Just show it.", 3.4]},
	{
		"choose":
		{
			"key": "lend",
			"options":
			[
				{
					"text": "Take it.",
					"tag": "gave",
					"reply":
					[{"say": [FRIEND, "I'll have someone pick it up. You're a genius.", 2.8]}],
				},
				{
					"text": "It's not for sale.",
					"tag": "asked",
					"reply": [{"say": [FRIEND, "Everything's for sale, babe. Fine.", 2.4]}],
				},
			],
		},
	},
]
const LENT_LINE := "Someone came for the canvas. They didn't knock."
## Two days later: it sold. He gets nothing.
const SOLD_CALL: Array = [
	{"say": [FRIEND, "It SOLD. Heritage art, the client called it. Authentic.", 3.2]},
	{"say": [FRIEND, "Fees ate it, obviously. Next one, I promise.", 2.8]},
	{"think": ["Next one.", 1.8]},
]

## ----- 7b: THE NEIGHBOUR, through the wall ------------------------------------------------

## Day 2 morning: the introduction.
const NEIGHBOUR_HELLO: Array = [
	{"say": [NEIGHBOUR, "(through the wall) New one? Walls are thin. Sorry in advance.", 3.2]},
	{"say": [NEIGHBOUR, "If you hear me at night, it's nothing. It passes.", 2.8]},
]
## When his room crosses into decay (entropy thresholds): someone notices.
const NEIGHBOUR_DECAY := {
	40: [{"say": [NEIGHBOUR, "(through the wall) You okay in there? You've gone quiet.", 3.0]}],
	70:
	[
		{"say": [NEIGHBOUR, "(through the wall) I know that sound. The pacing.", 2.6]},
		{"say": [NEIGHBOUR, "I did that for a year. Eat something. Please.", 2.8]},
	],
}
## Some nights he hears the neighbour relapse; the same sounds he makes.
const NEIGHBOUR_NIGHT: Array = [
	{"think": ["Through the wall: someone counting, out loud, the same number.", 3.2]},
]
## 16a: after the ransack. The first time, the neighbour comes; later cycles, silence.
const NEIGHBOUR_AFTER_RANSACK: Array = [
	{"say": [NEIGHBOUR, "(at the door) I heard them. I didn't open. I'm sorry.", 3.2]},
	{"say": [NEIGHBOUR, "They had a key. Whoever it was had a key.", 2.8]},
]
const NEIGHBOUR_SILENT := "No knock from next door. Not this time."
