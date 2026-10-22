class_name NightZeroScript
extends RefCounted
## DATA — Night Zero's lines (docs/STORY.md, N1–N9). Phase 1: the call, the move-in, the
## invitation. Each line is [speaker, text, seconds on screen]. Editing the chapter's
## dialogue is editing this file.
##
## The friend's name is still open (Alain: "wait"); FRIEND is the placeholder.

const FRIEND := "FRIEND"
const HIM := "YOU"

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

## Until Phase 2 builds the dinner: the chapter hands to Day 1 here.
const PHASE_ONE_END := "The car never came that night. (Night Zero continues in Phase 2.)"
