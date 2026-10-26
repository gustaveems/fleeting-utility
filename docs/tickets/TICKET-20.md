# Ticket-20: forgetting and confession (loop 5)

Story: `docs/STORY.md` 10, *"When he reaches for the meaning, it slips away. He cannot
imagine sacrificing himself, and he admits it: he is a selfish animal"*, paid off in 18,
*"For the first time, the meaning stays."* Scoped with Alain on 2026-10-26, all the
recommended options: a sentence that erases itself, the confession after the third lost
memory, a choice where every answer admits it, and the lost sentences completing in the
visions.

## The loop
`DreamMemory` (dream_memory module) holds the logic; `DreamText` draws it. Lines live in
`DreamMemoryScript`.

- **Forgetting.** "[E] Remember" at a glowing anchor no longer just flashes him home:
  - he stops, and half a sentence writes itself: *"They raised their arms because—"*;
  - it holds, then unwrites from the end (*"They raised—"*);
  - then *"It's gone."*, and the flash home.

  The countdown pauses while he reaches, so a timeout can't cut the sentence off. Each
  reach takes the next of five fragments, kept in order across cycles.
- **Confession.** After the **third lost memory in a cycle**, the next dream opens (moved
  under the white) before a colossus, looking up at it:
  - he can't move, and the countdown stops;
  - *"Fifty feet of stone. Arms up. Bleeding for something."* / *"Could you have stood
    there?"*
  - every answer is a no: *"I'd run."* (*"Before the first stone fell."*), *"I'd watch
    from somewhere safe."* (*"And call it respect."*), *"I'd sell the photo."* (*"Someone
    would. Why not me."*);
  - then *"I can't even imagine it."* / *"Selfish animal."*, and he wakes.

  It happens once per cycle, never in the climax dream (with the ambulance armed). The
  answer is saved as `confession_tag`.
- **The payoff (18).** In the dual visions, each valley flash shows one lost sentence
  whole, in gold: *"They raised their arms because they stood for something greater."*
  The statue's own line follows as before.

## Plumbing
- **`DreamscapeManager`:**
  - `_remember()` awaits `DreamMemory.reach()` before the flash;
  - new signal `worlds_swapped(to_dreamscape)` fires under the white, after the swap;
  - a stopped countdown hides its label (the confession, the ambulance).
- **`PlayerMovement.face(direction)`** turns him at once (scripted moments).
- **The confession's colossus is statue 1:** the dream camera looks −X−Z, so it stands
  beyond him in frame.
- **Saved** as an additive `dream_memory` field (`lost`, `lost_this_cycle`,
  `confession_due`, `confessed`, `confession_tag`).
- **Renewal:** he can confess again. What he lost stays lost: the fragments continue.
- **Probe:** `tools/probe_dream_memory.gd` (23 checks).

## Not yet
- The confession answer (`run` / `watch` / `sell`) isn't used later. It could colour
  the visions or the end card.
- No sound for the reach and the erase.
