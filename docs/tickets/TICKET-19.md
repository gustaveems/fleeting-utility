# Ticket-19: self-belief (loop 4)

Story: `docs/STORY.md` 9, *"Each relapse erodes his belief in himself"*, and 6, *"On the
drug he is sharp, fast and vivid; without it he is nothing."* Scoped with Alain on
2026-10-26:
- it erodes and rarely recovers;
- it is hidden and felt, with no meter;
- its effects are painting off the drug, relapses coming sooner, and people noticing.

## The loop
`SelfBelief` (self_belief module) holds a hidden value, from 1.0 on Day 1 (*"sure that
life starts here"*) down to 0.
- **Each relapse** (a compulsion starting) takes **0.15**, so about six relapses reach
  the bottom.
- **A canvas finished off the drug** (chemical below 0.3) gives back **0.05**. That is
  the only way back, and it's hard: he has to paint slow and sober.

It is felt through:
- **The easel, off the drug only** (on the drug he is sharp, so nothing changes there):
  - a slower hand: paint time ×(1 + lost belief), so up to ×2;
  - a harsher verdict: quality −0.3 × lost belief;
  - the prompt, by stage: *"[E] Hold to paint"* when sure (≥0.66), *"[E] Hold to
    try"* when doubting, *"[E] Hold to try. Again."* when hollow (<0.33);
  - at the bottom (<0.2) he **won't paint off the drug**: *"Not like this. Not without
    it."*
- **The spiral:** the compulsion threshold falls from 80 to 65 as belief falls, so each
  relapse makes the next one come sooner.
- **People notice**, once each, on a morning after the friend's call and the offers:
  - doubting: the neighbour, through the wall: *"You sound tired… I know that sound."*
  - hollow: the friend calls: *"You okay? You sound... flat."* (*"I'm fine."*) *"Paint
    something. You're good when you paint."* If the friend is gone, the neighbour says
    it instead: *"The quiet's worse."*

## Plumbing
- **Lines** live in `SelfBeliefScript`.
- **Easel:** it takes an `@export var self_belief` (`will_paint()`, `paint_time_scale()`,
  `verdict_penalty()`, `paint_prompt()`).
- **Saved** as an additive `self_belief` field (`value`, `relapses`, `cycles`, `said`).
- **Renewal** (`LeaseRenewal` → `reset_cycle()`): he tries again, restored to 1 − 0.15 ×
  cycles (never below 0.4). People can notice again.
- **Probe:** `tools/probe_self_belief.gd` (24 checks).

## Not yet
- No relapse thoughts after a compulsion (Alain didn't pick them).
- No visual of it on him (posture, the room). The look pass may add it.
