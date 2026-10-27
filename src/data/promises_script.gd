class_name PromisesScript
extends RefCounted
## DATA — the promises (docs/STORY.md 8; Ticket-18): the billboards follow him inside as
## offers. Each one helps at once and comes due later, and every way out costs more.
## Same step format as NightZeroScript (say / think / choose). Editing the loop is
## editing this file.
##
## Focus+ Pro   day 3: "your dose, lasting longer, first month free". Declined, it asks
##              once more on day 5. Three days into the trial the month is "over":
##              keep it (billed to the lease) or cancel (the tolerance stays).

const CARE := ActOneScript.FOCUS_CARE
const HIM := NightZeroScript.HIM

## ----- FOCUS+ PRO -------------------------------------------------------------------------

const PRO_OFFER := [
	{"say": [CARE, "Good morning from Focus+. Three days with us already.", 2.8]},
	{"say": [CARE, "We'd like to offer you Focus+ Pro. Your dose, lasting longer.", 3.2]},
	{"say": [CARE, "Your first month is free. Cancel anytime.", 2.6]},
	{
		"choose":
		{
			"key": "pro",
			"options":
			[
				{
					"text": "Start the free month.",
					"tag": "accepted",
					"reply": [{"say": [CARE, "Welcome to Pro. You'll feel it by noon.", 2.6]}],
				},
				{
					"text": "Not now.",
					"tag": "declined",
					"reply": [{"say": [CARE, "Of course. The offer stays open. For now.", 2.6]}],
				},
			],
		},
	},
]

const PRO_OFFER_AGAIN := [
	{"say": [CARE, "Still thinking about Pro? Half your block already has it.", 3.0]},
	{"say": [CARE, "The free month ends today. For new members, that is.", 2.8]},
	{
		"choose":
		{
			"key": "pro",
			"options":
			[
				{
					"text": "Fine. Start it.",
					"tag": "accepted",
					"reply": [{"say": [CARE, "Welcome to Pro. We knew you'd come round.", 2.6]}],
				},
				{
					"text": "No.",
					"tag": "refused",
					"reply":
					[
						{"say": [CARE, "Understood. We'll remember that.", 2.2]},
						{"think": ["They will.", 1.8]},
					],
				},
			],
		},
	},
]

const PRO_DUE := [
	{"say": [CARE, "Your free month of Focus+ Pro has ended.", 2.6]},
	{"say": [CARE, "Pro renews today. The charge is added to your lease.", 2.8]},
	{"think": ["A month. It's been three days.", 2.2]},
	{
		"choose":
		{
			"key": "pro_due",
			"options":
			[
				{
					"text": "Keep Pro.",
					"tag": "kept",
					"reply": [{"say": [CARE, "Thank you for staying with Focus+.", 2.2]}],
				},
				{
					"text": "Cancel it.",
					"tag": "cancelled",
					"reply":
					[
						{
							"say":
							[CARE, "Cancelled. Pro tolerance may persist. This is normal.", 3.0]
						},
					],
				},
			],
		},
	},
]

## HUD lines when a term lands.
const PRO_STARTED := "Focus+ Pro: active. Your dose lasts longer."
const PRO_KEPT := "Lease amended: Focus+ Pro, billed monthly. Decay rate revised."
const PRO_CANCELLED := "Your dose wears off faster than it did before Pro."

## ----- THE WALL SCREEN (the leased ad panel in his room) -----------------------------------

## Before any offer: the brand, rotating.
const SCREEN_IDLE: Array[String] = [
	"FOCUS+\nThe future is leased.",
	"CLARITY IS A\nSUBSCRIPTION",
	"LEASELINK\nAlways in your head.",
]
## [headline, fine print] per Pro state.
const SCREEN_PRO := {
	"offer": ["FOCUS+ PRO\nFirst month FREE", "*Cancel anytime. Terms apply."],
	"declined": ["FOCUS+ PRO\nStill free. Still waiting.", "*Offer ends soon."],
	"refused": ["FOCUS+ PRO\nOthers said yes.", ""],
	"trial": ["FOCUS+ PRO · ACTIVE\nFree until day %d", "*Renews automatically."],
	"kept": ["FOCUS+ PRO\nBilled to your lease", "Thank you for staying."],
	"cancelled": ["WE MISS YOU\nCome back to Pro", "*Tolerance may persist."],
}

## ----- CORPORATE CARE (after his first collapse; once more after the ransack) ------------

const CARE_OFFER := [
	{"say": [CARE, "We noticed you collapsed. You're not in trouble.", 2.8]},
	{"say": [CARE, "Corporate Care: never face a crisis alone. We come to you.", 3.2]},
	{"say": [CARE, "Enrolment is free. Resuscitation included.", 2.6]},
	{
		"choose":
		{
			"key": "care",
			"options":
			[
				{
					"text": "Enrol.",
					"tag": "enrolled",
					"reply": [{"say": [CARE, "Welcome to Care. We'll be watching over you.", 2.8]}],
				},
				{
					"text": "No thanks.",
					"tag": "declined",
					"reply": [{"say": [CARE, "We'll keep your file open.", 2.2]}],
				},
			],
		},
	},
]

const CARE_LAST := [
	{"say": [CARE, "We're sorry for your loss.", 2.0]},
	{"say": [CARE, "Residents in crisis qualify for emergency enrolment.", 2.8]},
	{"say": [CARE, "This is your last chance to be covered.", 2.4]},
	{
		"choose":
		{
			"key": "care_last",
			"options":
			[
				{
					"text": "Enrol.",
					"tag": "enrolled",
					"reply":
					[{"say": [CARE, "Covered. Whatever happens now, we'll be there.", 2.8]}],
				},
				{
					"text": "Leave me alone.",
					"tag": "refused",
					"reply":
					[
						{"say": [CARE, "As you wish. No one will come.", 2.4]},
						{"think": ["Good.", 1.4]},
					],
				},
			],
		},
	},
]

const CARE_ENROLLED := "Corporate Care: enrolled. Resuscitation included."
## The clinical scene, when Care was what came for him.
const CARE_CONSENT := "Corporate Care · enrolled day %d · resuscitation included."
## The ending without Care.
const ALONE := "No one came."
const ALONE_FLAVOR := "No one came. He woke anyway."
