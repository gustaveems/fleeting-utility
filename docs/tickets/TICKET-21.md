# Ticket-21: the campaign's new image (7d, second half)

Story: `docs/STORY.md` 7d, *"Later the campaign's new image looks very like his canvas:
the lie he was sold, sold again with his hand in it."* Scoped with Alain on 2026-10-26:
- it appears on the **metro and in the park** (not his wall screen);
- the copy is **his canvas, polished**;
- he reacts with **a thought and a choice**: asking costs him self-belief.

## The beat
`CampaignImage` (campaign module) runs the beat. Lines live in `CampaignScript`.
1. The friend "borrows" a canvas (7d). `Easel.last_lent` and `ActOne.lent_work` keep its
   `PaintedWork` parameters.
2. Two mornings later, *"It SOLD."* (`ActOne.sold`). **The morning after**, the Heritage
   campaign wears it.
3. **The copy** (`CampaignBoard.polish()`): the same seed and composition, but at least
   0.92 vivid and 0.9 coherent, with the smear and greyness gone. It is recognisably his,
   and better than he could do. It sits under *"HERITAGE COLLECTION · Authentic origin.
   Remember where you came from."*
4. **Where:**
   - **The metro:** a billboard that slides past with the city, on a 16 m loop, so it
     comes round every couple of seconds. It's hidden while the train stands at the
     Heritage window.
   - **The park:** a freestanding billboard by the path, turned to the camera. The
     walls sit at the frame's top edge.
5. **The first sighting** (once): *"That's mine."* / *"They fixed it. It's better than I
   could do."*
   - **Call the friend about it:** *"Babe! You saw it? Isn't it gorgeous?"* / *"That's my
     painting."* / *"It's inspired by. That's how it works."* / *"You should be flattered.
     Seriously. Gotta run."* (*Should I.*) Self-belief −0.1.
   - **Let it go:** *"Let it go. Like everything else."*
6. **It stays up for good.** A renewed lease doesn't take it down.

## Plumbing
- **The metro ride** now lasts until all talk is done (`DialogueRunner.is_idle()`), so a
  beat queued behind his ride thoughts isn't cut off.
- **The park walk** holds its auto-return while the beat plays
  (`CorporateParkManager.hold_return`).
- **`MetroCarriage.campaign_board`**: the carriage carries its own board; the module
  builds the park's in `post_attach`.
- **Saved** as additive fields: `campaign` (`live_from_day`, `seen`, `reaction`), and
  `act_one.lent_work`.
- **Probe:** `tools/probe_campaign.gd` (19 checks).

## Not yet
- The campaign image isn't in the apartment's wall screen or the prologue's billboards.
- Nothing remembers his reaction later (the friend could bring it up).
