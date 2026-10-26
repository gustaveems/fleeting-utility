class_name SelfBeliefScript
extends RefCounted
## DATA — self-belief (docs/STORY.md 6, 9; Ticket-19): hidden, felt. Each relapse erodes
## his belief in himself; off the drug he is slower, his verdicts harsher, and at the
## bottom he won't paint without it. These are the lines it is felt through.

const FRIEND := NightZeroScript.FRIEND
const HIM := NightZeroScript.HIM
const NEIGHBOUR := ActOneScript.NEIGHBOUR

## The easel's prompt by stage (sure / doubting / hollow), and its refusal at the bottom.
const PAINT_PROMPTS: Array[String] = [
	"[E] Hold to paint",
	"[E] Hold to try",
	"[E] Hold to try. Again.",
]
const REFUSE := "Not like this. Not without it."

## People notice (once each, on a morning): the neighbour first, then the friend.
const NEIGHBOUR_TIRED := [
	{"say": [NEIGHBOUR, "You sound tired. Through the wall, I mean.", 2.8]},
	{"say": [NEIGHBOUR, "I know that sound. Get some sleep, yeah?", 2.6]},
]
const FRIEND_FLAT := [
	{"say": [FRIEND, "Hey. You okay? You sound... flat.", 2.6]},
	{"say": [HIM, "I'm fine.", 1.4]},
	{"say": [FRIEND, "Okay. Paint something. You're good when you paint.", 3.0]},
]
## The friend is gone (a renewed lease): the neighbour says it instead.
const NEIGHBOUR_FLAT := [
	{"say": [NEIGHBOUR, "You've gone quiet in there. The quiet's worse.", 3.0]},
]
