# Ticket-17: Act I, the middle (the friend, the neighbour, the painting)

Story: `docs/STORY.md` 7a, 7b, 7d, 16a (approved 2026-10-21). This is the empty middle
between Day 1 and the park walk: the beats that give the betrayal its weight. Mechanics
first; graphics follow.

## Phase 1 (2026-10-23): the friend's calls, the borrowed painting, the neighbour
`ActOne` (act_one module, under the apartment WorldRoot). Its lines live in
`ActOneScript`. It plays them through the game world's `DialogueRunner` and
`ChoicePanel`, which share Night Zero's `HeadCall`.

- **7a, the friend calls** as a head call (the caller card) four seconds after he wakes:
  - **Day 2:** gossip. *"Vesna thinks you're 'raw'."*
  - **Day 3:** *"Co-sign this for me? A formality."*
    - Sure: the lease's decay rate rises ×1.15. Next morning, the lease's own line:
      *"Co-signatory liabilities apply."*
    - What is it: the friend sulks.
  - **Day 4:** *"Can my guy leave a crate at yours?"*
    - Fine: a sealed wooden crate (Poly Haven) sits by the door: *"It isn't yours."*
    - In the **ransack** it vanishes: *"The crate is gone too. Of course it is."* They
      cased the room.
  - **Day 6:** *"Big week. Keep painting."*
- **7d, the painting:** from day 5, finishing a canvas brings a call: *"I have a client
  who'd die for that."*
  - Take it: the canvas leaves the wall (*"They didn't knock"*). Two mornings later:
    *"It SOLD… Fees ate it."* He gets nothing.
  - Not for sale: *"Everything's for sale, babe."*
- **7b, the neighbour**, through the wall:
  - hello on day 2;
  - a night sound on every third morning;
  - *"You okay in there?"* at decay 40 and *"I know that sound. The pacing."* at 70.
- **16a:** after the ransack, the neighbour comes to the door on the first cycle (*"They
  had a key."*). On later cycles: *"No knock from next door. Not this time."*
- **After the betrayal** (a renewed lease) the friend never calls again.
- **Plumbing:**
  - Saved as an additive `act_one` field.
  - `LeaseRenewal` calls `reset_cycle()`.
  - Calls queue rather than talk over each other.
  - The interaction lock is held while a choice is open, so E doesn't also press the bench.

## Phase 2 (2026-10-23): 7c, metro or park
- **The door is now a choice** (`ApartmentDoor` + `DialogueRunner.ask`):
  - Below the betrayal threshold: *"[E] Take the metro"*, then the menu: the metro, or
    stay in.
  - At the threshold: the corporate park (the story's walk, unchanged) or the metro, or
    stay in.
  - After a ride that day: *"Not yet. You've been out today…"*
  - After the betrayal: the hesitation, unchanged.
- **The ride** (`MetroRide` + `MetroCarriage`, a WorldRoot):
  - Once a day. A blink to black, then a carriage at the diorama's scale: commuters
    standing and slumped, a fluorescent strip, the city sliding past the window.
  - His thoughts play, then he's home: *"The room is where you left it."*
  - Getting out eases sensory overload by 25: a way to cope that isn't the drug.
- **The barometer:** the carriage's ads and his thoughts change by stage (day / 3):
  - stage 0: upgrades, *"The future is leased"*;
  - stage 1: *"Focus+ · new pricing"*, *"half the carriage is shaking"*;
  - stage 2: *"Block 29 · rezoned for Heritage"*, the rich side *"like a tide"*.
- **Saved** as `metro` (rides, last ride day).
- **Tests updated:** the playability gate and `probe_interactables` now encode the
  metro-or-park door (deliberate change).

## Phase 3 (2026-10-23): Act II, the enclosure (the drug as a story beat)
The scarcity was already mechanical: a finite stash that shrinks per cycle. Now the story
tells it, the first time each cycle he takes the last of it and the bench has nothing
left to cook (`BenchStation.is_dry()`):
- **A notice in his head** (caller card "FOCUS+ CARE"): Focus+ reclassified as a premium
  wellness product; street supply discontinued "for your safety"; Elite membership,
  terms apply.
- **The neighbour, through the wall:** *"It's gone. Everybody's dry. Even my guy."*
- **The friend** (while they still call): *"I can get you some. Pricier now. I'll front
  you."*
  - Okay: two compounds on the worktop, *"Fronted. You owe."*
  - I'll manage: *"Call me when you don't."*
- **The ransack collects:** *"They took what you owed. With interest."*
- **Later cycles:** one line. *"Elite pricing applies. It has gone up again."*
- Saved (`enclosure_told`, `in_debt`); reset per cycle.

## Next phases
- **18a:** the fenced stone priced in the Heritage window, after the realisation.
- **Graphics:** the neighbour's door visit staged, the crate's label, the call card.

## Verification
`tools/probe_act_one.gd` checks:
- the calls on days 2–7 (head-call card) and the hello;
- the co-sign cost, the crate, the borrowed painting and the sale;
- the decay lines;
- the crate gone and the neighbour's visit after the ransack;
- a save round-trip;
- no calls after the betrayal.
