# Ticket-24: the status loop (loop 3)

Story: `docs/STORY.md` 7, and Alain's loop text: *"Mastering social relations in the
jockeying for power and status… his friends and people he interacts with are fuelled by
greed, with a never ending sense of accelerationism, of advancing and advancing."*
Scoped with Alain on 2026-10-27:
- invitation events plus a standing that keeps sinking;
- a new venue;
- he performs on the drug.

## The loop
`Standing` (standing module) runs it; `RooftopLounge` is the venue. Lines live in
`StandingScript`.
- **His LeaseLink standing** is a percentile, starting at 50.
  - **Every morning** everyone else advances, so it sinks: −3, then −3.5, −4… faster
    each day.
  - It shows in the corner of his wall screen: *"LEASELINK STANDING 41% ▼"*.
- **Invitations** come on days 3, 5 and 8 as a LeaseLink line in the morning:
  - *"Vesna invited you. Her rooftop, tonight. Dress code: Heritage."*
  - *"Okon's launch… Early holders only."*
  - *"Lior's new lease. The Heights."*

  The door then offers *"[E] Go out tonight"*, alongside the metro and the park.
- **The night** (`RooftopLounge`, a WorldRoot like the carriage):
  - **The venue:** a terrace high on the rich side, with a teak deck, glass balustrade,
    a bar, cream sofas and string lights. The veiled corpo crowd stands in clusters, the
    friend by the bar, glass towers beyond, and a banner naming the night.
  - **The jockeying:** two choices a night.
    - **Fitting in:** +7 (*"A heritage series. Collectors are circling."*).
    - **The truth:** −1 (*"The same valley, over and over."*).
  - **He performs on the drug.** The smooth lines exist only while he's medicated. Off
    it, each becomes a stumble (*"No. Not really."*, −4).
  - **However it goes, they have moved on:** *"We're moving to the Heights in spring"*,
    *"We're all off to the Spire next. Invite-only."* (*"Advancing and advancing. And I'm
    standing still."*)
  - **Home:** *"LeaseLink standing: 52nd percentile. Everyone else moved up too."*
- **After the betrayal** (a renewed lease) the invitations stop, but the standing keeps
  sinking.

## Plumbing
- **The script format:** an option can carry an `"off"` variant, which
  `StandingScript.perform(steps, medicated)` swaps in when he's off the drug.
- **The door:** `ApartmentDoor.standing` adds the night to the menu.
- **The screen:** `AdScreen.standing` draws the corner line.
- **Saved** as an additive `standing` field (`standing`, `drift`, `attended`).
- **Renewal:** `reset_cycle()` clears the attended nights. The friend is gone after
  that, so there are no invitations anyway.
- **Probe:** `tools/probe_standing.gd` (20 checks).

## Not yet
- The Night Zero dinner's fit/honest answers don't set his starting standing.
- No consequence beyond the number: a high standing unlocks nothing (by design so far).
- Graphics: greybox venue. The crowd is the tinted mannequin, veiled.
