class_name DailyLifeScript
extends RefCounted
## DATA — the paper under his door and the radio's bulletins (docs/STORY.md 8a, 8b).
## A notice is [from, title, body]. Radio bulletins are dialogue steps (NightZeroScript's
## format), one a day, in order, the last repeating.

const RADIO := "RADIO"
const LINE_SECONDS := 4.2

## day → notice.
const NOTICES: Dictionary = {
	2:
	[
		"LESSOR SERVICES",
		"WELCOME TO THE PREMISES",
		(
			"We hope you slept well. Premises are serviced nightly.\n\n"
			+ "Works produced on the premises remain subject to the lessor and are "
			+ "collected at no charge.\n\nNo alterations."
		)
	],
	3:
	[
		"LEASELINK",
		"YOUR STANDING IS READY",
		(
			"You now have a LeaseLink percentile. It is calculated daily from who you know "
			+ "and what they think of you.\n\nStanding that is not maintained will decline.\n\n"
			+ "This is not a score. Do not call it a score."
		)
	],
	4:
	[
		"HERITAGE COLLECTION",
		"THE WALK. HAND-FINISHED.",
		(
			"Oxblood calf, stitched in a valley that remembers.\n\n"
			+ "Worn on the misty path, past stones older than any lease. Authenticity, "
			+ "by appointment.\n\nFinance available to members in good standing."
		)
	],
	6:
	[
		"FOCUS+ SUPPLY",
		"A NOTE ON AVAILABILITY",
		(
			"Compound is moving to a managed allocation. Residents of your district "
			+ "may notice less of it.\n\nNothing has been taken from you. It was never "
			+ "yours.\n\nUpgrade your focus."
		)
	],
	8:
	[
		"LESSOR SERVICES",
		"RENEWAL",
		(
			"Renewal is at the lessor's discretion.\n\nA representative may enter "
			+ "the premises to assess its condition. You need not be home.\n\n"
			+ "You need not be anything."
		)
	],
}

## After the ransack, the morning after.
const INCIDENT := [
	"LESSOR SERVICES",
	"INCIDENT 31-0417: CLOSED",
	(
		"Our records show an entry to your premises. All items removed were subject to the "
		+ "lessor. No loss has occurred.\n\nThank you for your understanding.\n\n"
		+ "The referring party has been paid."
	)
]

## Prefixed to a title when the lease has been renewed: the same paper, again.
const SECOND_NOTICE := "SECOND NOTICE: "

const BULLETINS: Array = [
	[
		{"say": [RADIO, "Good morning, Block 31. The line is running. So are you.", LINE_SECONDS]},
		{"say": [RADIO, "Leases signed this week: up. Complaints: resolved.", LINE_SECONDS]},
	],
	[
		{
			"say":
			[RADIO, "The Colossus is being regilded, a second coat by the weekend.", LINE_SECONDS]
		},
		{"say": [RADIO, "It stands where nobody remembers anything else standing.", LINE_SECONDS]},
	],
	[
		{
			"say":
			[
				RADIO,
				"Heritage Quarter opens two more blocks. Residents were consulted.",
				LINE_SECONDS
			]
		},
		{"say": [RADIO, "Their replies are being held on file.", LINE_SECONDS]},
	],
	[
		{
			"say":
			[RADIO, "Traffic on Line 4 is light. Traffic in your head is heavy.", LINE_SECONDS]
		},
		{"say": [RADIO, "Focus+ Care. We'll come for you.", LINE_SECONDS]},
	],
	[
		{
			"say":
			[RADIO, "Compound prices are up again. Experts call it a correction.", LINE_SECONDS]
		},
		{"say": [RADIO, "Experts are available to members.", LINE_SECONDS]},
	],
	[
		{"say": [RADIO, "Weather: rain tonight, on the avenue, by arrangement.", LINE_SECONDS]},
		{"say": [RADIO, "And now, the sound of a forest. Licensed.", LINE_SECONDS]},
	],
]

## After the ransack: the batteries went with everything else.
const RADIO_DEAD := "No batteries. They took those too."
const RADIO_DONE := "Nothing new until morning."
const RADIO_PROMPT := "[E] Radio"
const NOTICE_PROMPT := "[E] Read"
const NOTICE_HINT := "Something came under the door."
