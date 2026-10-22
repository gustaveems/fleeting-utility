# Ticket-16: Night Zero (the first evening)

Story: `docs/STORY.md`, Night Zero N1–N9 (added 2026-10-21). The friend is introduced,
liked, and quietly set up. It is playable, not a cutscene. Calls come straight into his
head: voices only, no faces.

## Phase 1 (2026-10-22): the call, the move-in, the invitation
- **HeadCall** (`src/presentation/head_call.gd`): the in-head call overlay.
  - An "INCOMING · FRIEND" card with a pulsing voice meter.
  - Lines are subtitled with the speaker; his own lines are muted.
  - `play(lines, false)` subtitles people talking in person.
  - Lines live in `NightZeroScript` (data).
- **N1:** the prologue's last shot, `the_call`, is the friend's call at his door: *"You
  signed? Good, good."* The referral fee is asking. The film is now 15 shots, ~119 s.
- **N2:** the lease (Ticket-15 Phase E).
- **N3:** `NightZero` starts on `LeaseSigning.signed`, so only after the prologue.
  - The friend (a faceless mannequin in the campaign's camel coat) is in the room.
  - Three cardboard boxes (Poly Haven, CC0) wait by the door.
  - E picks up and E puts down. He walks with the carry animation. Taped floor marks the
    west wall spot.
  - The friend complains as each box lands: the guy downstairs, the corner, "a first
    step, I found you this one".
- **N4:** the invitation (in person). Dinner with the corpo friends; *"I'll send a car.
  Corpos don't take the metro."* He is held still for it.
- **Phase 1 ends** here with a placeholder line and the friend gone. Day 1 proceeds.
- **Not saved yet:** quitting mid-chapter skips it on Continue.

## Phase 2 (next): the car, the other side, the dinner, the gift, the walk, the metro
- N5: the car and an aerial over the rich side. It reuses the prologue director: a second
  film. The rich side gets real style (not brutalism), brands, shoots, cars.
- N6: the dinner.
  - The first dialogue choices: fit in or be honest. They change tone, not outcome.
  - Faces: veils (proposed).
  - He sees the friend's shoes.
- N7: the gift. Refusing is allowed; it is in his bag anyway.
- N8: the walk through the rich side to the metro.
- N9: the night train home, the shift back into the low blocks, home.

## Verification
`tools/probe_night_zero.gd` checks:
- a direct boot doesn't start it; signing does;
- the friend and the boxes exist;
- one box at a time; the three land;
- he is held for the invitation; then he is freed and the friend is gone.
