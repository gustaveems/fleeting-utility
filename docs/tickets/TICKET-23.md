# Ticket-23: Corporate Care (the promise that comes due)

Story: `docs/STORY.md` 8 and 20, *"A corporate ambulance (the same brand as the
billboards) resuscitates him against his will. The promise comes due."* Alain's ruling
(2026-10-26): **if he refuses Care, no ambulance comes; he wakes on his own.** Scoped on
2026-10-27, all the recommended options:
- offered after his first collapse;
- asked once more after the ransack;
- gentler collapses while enrolled;
- without Care, the same scars and a different card.

## The offer
`Promises` (Ticket-18) makes it, as a gold **FOCUS+ CARE** head-call. Lines live in
`PromisesScript`.
- **His first collapse:** waking from it: *"We noticed you collapsed. You're not in
  trouble… Corporate Care: never face a crisis alone. We come to you. Enrolment is free.
  Resuscitation included."*
  - Enrol: *"We'll be watching over you."*
  - No thanks: *"We'll keep your file open."*
- **After the ransack, once, if he declined:** *"We're sorry for your loss. Residents in
  crisis qualify for emergency enrolment. This is your last chance to be covered."*
  - Enrol: *"Covered. Whatever happens now, we'll be there."*
  - Leave me alone: *"As you wish. No one will come."* (*Good.*)
  - If his first offer only comes after the ransack, that first answer is the last one.
- **Enrolled:** a collapse wake lands at overload 30, not 50, with 6 s of calm. Care
  visibly helps.
- **Interrupted:** an offer cut off before he answers is asked again next time.

## The climax
- **Covered:** the ambulance comes as before. The clinic's message adds his consent:
  *"SYSTEM RECALIBRATING... / Corporate Care · enrolled day N · resuscitation included."*
- **Refused** (`Promises.care_refused()`; never asked is not a no):
  1. At the interception moment no one comes. There's no siren and no strobe; the exits
     close.
  2. `DreamscapeManager.quiet_return_to_workspace()`: a 5 s fade to **black**, *"No one
     came."*, a 4 s hold, then the room fades back in over 3 s. He's on his own, with no
     clinic and no medics.
  3. `GameFlow` goes to the new phase **ALONE**, then SCARRED.
  4. The scars land as usual (faster decay, the bench gone). The flavour line and the end
     card read *"No one came. He woke anyway."* Renew or walk away as usual.
- **Renewal:** an enrolment stays (he's subscribed). A refusal resets, so he'll be asked
  again.

## Plumbing
- **New signals:** `AmbulanceInterception.nobody_came`;
  `DreamscapeManager.quiet_return_started` and `quiet_return_completed`.
- **The care reference:** `AmbulanceInterception`, `EndgameLoopManager` and `EndCard`
  each hold an `@export var care: Promises`.
- **`EndgameLoopManager._on_woke_alone()`** applies the post-climax state without the
  clinic, then the same scarred reset with its own flavour.
- **Saved** as additive fields on `promises` (`care`, `care_day`, `care_last_offered`).
  No checkpoint is written in ALONE, so a quit there resumes at the last one.
- **Probe:** `tools/probe_care.gd` (23 checks).
