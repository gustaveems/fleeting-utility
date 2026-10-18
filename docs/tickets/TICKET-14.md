# Ticket-14: Days and mastery in vain

Source: Alain's loop text (2026-10-18), first two of six loops. Decisions were grilled the same day.

> "He wakes up, trying to master new forms, art, paint… never happy with what's done… all his actions have a fleeting utility since his actions cannot abide to anything."

## Loop 1: the day frame
- **Days are counted.** The game starts on Day 1. The HUD shows `DAY n` under the meters.
- **Sleep at the cot, any time.** The cot is the existing placeholder, near the south-east corner: `[E] Sleep`. Sleeping is blocked during a compulsion, because interactions are locked then.
- **Night is a calm dream in the valley.** It uses the same `transition_to_dreamscape`. If the ambulance is armed, this dream is the climax: "as he fades out and feels at peace…".
- **Morning** comes when a night dream returns calmly, i.e. not by the forced return:
  - `day += 1`
  - he wakes gentle: overload ≤ 15, plus a relief window
  - the line "Day n." shows on screen
  - the lease reclaims every finished work: "The lease does not permit alterations. Your works have been removed."
- Collapse dreams stay as they are. They're crashes, not nights, and do not advance the day.
- **A renewed lease starts again at Day 1.** Skill is his and carries over.

## Loop 2: mastery in vain (painting)
- **An easel** stands on the east side of the room: `[E] Hold to paint`. While painting, the prompt shows `Painting… n%`.
  - Base time is 4 s; High-Focus halves it and a crash doubles it.
  - Releasing E pauses progress.
- **The canvas paints his state.** A shader is driven by:
  - vividness: chemical / High-Focus
  - smear: crash intensity
  - flatness: withdrawal
  - coherence: skill
- **Finished works hang on the west wall,** three hooks. When the wall is full: "No more wall. The lease allows three."
- **Verdict.** Quality is `skill·0.6 + focus·0.4 − crash·0.3`, mapped to a line that is never satisfied:
  - low: "It's nothing. A smear."
  - mid: "Closer. Still wrong."
  - high: "Technically fine. It means nothing."
- **Skill** rises +0.08 per finished work, up to 1. **Nothing lasting**: there is no satisfaction meter, and the lease reclaims every work.
- **Persistence:** day, skill, and the hung works (seed and parameters) are saved. These are additive fields, so the schema stays v1.

## Out of scope (later tickets)
Loop 3 (status), loop 4 (self-belief), loop 5 (forgetting / confession) and loop 6 (techno promises).

## Verification
`tools/probe_days.gd` must cover:
- sleep → dream → morning
- the reclaim
- hold-to-paint, with High-Focus faster
- the verdict and skill gain
- the full wall
- the compulsion blocking painting
- a save/load round-trip
- a renewal resetting the day
