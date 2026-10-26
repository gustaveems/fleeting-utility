class_name CampaignScript
extends RefCounted
## DATA — the campaign's new image (docs/STORY.md 7d, second half; Ticket-21). The
## friend sold his canvas; the day after, the brand's Heritage campaign wears it,
## polished: brighter, cleaner, the flaws gone. The lie he was sold, sold again with his
## hand in it. He sees it on the metro or in the park; he can call the friend about it,
## and every answer fizzles (asking costs him self-belief).

const FRIEND := NightZeroScript.FRIEND
const HIM := NightZeroScript.HIM

const BRAND := "HERITAGE COLLECTION"
const TAGLINE := "Authentic origin. Remember where you came from."

## The first sighting. Played as a call: his thoughts show without the card; the
## friend's lines (if he asks) come with it.
const SEEN := [
	{"think": ["That's mine.", 2.0]},
	{"think": ["They fixed it. It's better than I could do.", 2.8]},
	{
		"choose":
		{
			"key": "campaign",
			"options":
			[
				{
					"text": "Call the friend about it.",
					"tag": "asked",
					"reply":
					[
						{"say": [FRIEND, "Babe! You saw it? Isn't it gorgeous?", 2.6]},
						{"say": [HIM, "That's my painting.", 1.8]},
						{"say": [FRIEND, "It's inspired by. That's how it works.", 2.6]},
						{"say": [FRIEND, "You should be flattered. Seriously. Gotta run.", 2.8]},
						{"think": ["Should I.", 1.6]},
					],
				},
				{
					"text": "Let it go.",
					"tag": "silent",
					"reply": [{"think": ["Let it go. Like everything else.", 2.4]}],
				},
			],
		},
	},
]
