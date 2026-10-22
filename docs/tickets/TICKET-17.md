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

## Next phases
- **7c, metro or park:** on free days, choose where to go. The night-train and rich-side
  pieces from the evening can be reused. The ride is the city's barometer: more ads, the
  drug dearer, the rich side spreading.
- **Act II as a story beat:** the drug enclosed as an elite commodity; prices in the
  friend's calls and the city.
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
