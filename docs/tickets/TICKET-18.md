# Ticket-18: the promises (loop 6, first offer)

Story: `docs/STORY.md` 8, *"The billboards follow him inside as messages and offers…
Can he trust them?"* Scoped with Alain on 2026-10-26: **Focus+ Pro only** for now, and a
wall screen in the room. The ambulance stays as it is (it always comes).

## The loop
`Promises` (promises module) makes offers through the shared `DialogueRunner`, as gold
**FOCUS+ CARE** head-calls queued after the friend's morning call. Each offer helps at
once and comes due later, and every way out costs more than never saying yes. Lines live
in `PromisesScript`.

- **Day 3, the offer:** *"Focus+ Pro. Your dose, lasting longer. First month free.
  Cancel anytime."*
  - Start the free month: the drug wears off **25% slower** (`chemical_depletion_rate`
    ×0.75).
  - Not now: *"The offer stays open. For now."* It asks once more on **day 5** (*"Half
    your block already has it."*). Refused twice: *"We'll remember that."* (*They will.*)
- **Three days into the trial, the bill:** *"Your free month has ended."* (*A month.
  It's been three days.*)
  - Keep Pro: billed to the lease, so its **decay rate ×1.15**. He keeps the slower dose.
  - Cancel it: *"Pro tolerance may persist. This is normal."* The drug now wears off
    **30% faster** than before he ever tried Pro.
- **The wall screen** (`AdScreen`, on the west wall north of the hung works): it rotates
  the brand's slogans (*"The future is leased."*, *"Clarity is a subscription"*) until
  the offer. Then it shows the offer, *"Still free. Still waiting."*, *"Free until day
  N"*, *"Billed to your lease"* or *"WE MISS YOU"*. It pulses while a Focus+ call is
  incoming.

## Plumbing
- **The queue moved into `DialogueRunner`** (`enqueue`, `is_idle`, `clear_queue`), so the
  friend, the neighbour and the corporation share one line and never talk over each
  other. `ActOne.play()` delegates to it. `ActOne` only records its own choice keys
  (`ActOneScript.FAVOURS`).
- **Saved** as an additive `promises` field (`pro`, `pro_day`, `depletion_scale`), so the
  schema stays v1. The keep-bill rides on the saved entropy growth rate.
- **Renewal** (`LeaseRenewal` → `reset_cycle()`): the depletion scale is a scar and stays.
  A declined or refused offer comes round again. A running trial restarts its clock on
  Day 1.
- **Probe:** `tools/probe_promises.gd` covers the order after the friend, decline then
  accept, the rate, the screen, save, both bills and renewal.

## Not yet (decided 2026-10-26, for later)
- **Corporate Care**, the offer that ties the loop to the ambulance. Alain's ruling for
  when it's built: **if he refuses Care, no ambulance comes; he wakes on his own** (on the
  floor, alive, no clinic), and gets the end card without the clinical scene. Renewing
  stays possible.
- Other offers that were proposed but not picked: Restful nights (sleep data), Heritage
  Exchange (his canvas becomes the campaign image, 7d).
- Graphics: the screen is a greybox panel with Label3D text.
