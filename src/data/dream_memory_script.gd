class_name DreamMemoryScript
extends RefCounted
## DATA — forgetting and confession (docs/STORY.md 10, 18; Ticket-20). In the dream he
## reaches for the colossi's meaning and it slips away mid-sentence. After the third lost
## memory in a cycle, a dream ends at a statue's feet with the confession: every answer
## admits it. In the dual visions (18) the lost sentences finally finish.

const THOUGHT := NightZeroScript.THOUGHT

## [the half he gets, the end he loses], in the order he reaches for them. The ends
## are what the visions finally give back.
const FRAGMENTS: Array = [
	["They raised their arms because", "they stood for something greater."],
	["The blood on the stone was", "theirs. Given, not taken."],
	["They weren't asking for anything. They were", "holding the line for whoever came after."],
	["Someone carved them so we would", "remember what people can be."],
	["It was never heritage. It was", "a monument. It still is."],
]
const GONE := "It's gone."

## Seconds of one reach: the half writes itself, holds, unwrites, then "It's gone."
const WRITE_SECONDS := 1.8
const HOLD_SECONDS := 0.6
const ERASE_SECONDS := 1.3
const GONE_SECONDS := 1.3

## At a colossus's feet. Every answer is a flavour of no.
const CONFESSION := [
	{"think": ["Fifty feet of stone. Arms up. Bleeding for something.", 3.0]},
	{"think": ["Could you have stood there?", 2.4]},
	{
		"choose":
		{
			"key": "confession",
			"options":
			[
				{
					"text": "I'd run.",
					"tag": "run",
					"reply": [{"think": ["Before the first stone fell.", 2.2]}],
				},
				{
					"text": "I'd watch from somewhere safe.",
					"tag": "watch",
					"reply": [{"think": ["And call it respect.", 2.0]}],
				},
				{
					"text": "I'd sell the photo.",
					"tag": "sell",
					"reply": [{"think": ["Someone would. Why not me.", 2.2]}],
				},
			],
		},
	},
	{"think": ["I can't even imagine it.", 2.2]},
	{"think": ["Selfish animal.", 2.6]},
]
