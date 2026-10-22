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

## Phase 2 (2026-10-22): the evening. Mechanics and layout (greybox); graphics next
After the invitation, `NightZero` changes scene to `scenes/evening.tscn` (`Evening`), and
the director plays:
1. **car (N5):** a film. The car glides down a canyon of tall, pale, styled towers, seen
   from above. His thought: *"Even the air looks expensive here."*
2. **dinner (N6):** a fixed shot of the round table.
   - Five diners: the friend, Vesna, Okon, Lior, him.
   - The first **dialogue choices**:
     - what he does: I paint / creative, freelance / say nothing;
     - where he lives: Block 31 / near the Heritage boutique;
     - the friend's **shoes**: "Nice shoes" / look away.
   - A **verdict** line from the friend, depending on how the night leaned:
     - honest: *"You don't have to say everything"*;
     - fit: *"See? You fit right in"*.
   - *"My treat. Referral bonus came in."*
3. **gift (N7):** outside the restaurant, in the iso view.
   - The ride: walking is honest; "Sure" makes the friend's work suddenly ping.
   - The drug: take it, or *"I don't need that."*
4. **walk (N8):** playable, on the iso camera. The boulevard runs from the restaurant to
   the METRO, past:
   - the campaign shoot (paper leaves, a fog machine);
   - the shop window with the valley in it, priced;
   - a couple.

   His thoughts play as he passes each one. The station ends the walk.
5. **metro (N9):** a film inside the night train.
6. **home:** back to the workspace. `Evening.returning` makes `NightZero.restore_moved_in`
   put the stacked boxes back and show "Day 1". If he refused, it adds *"There's
   something in your bag. You didn't put it there."*

New systems:
- `DialogueRunner` (logic): steps are say / think / choose / verdict. It records
  `choices` by key and counts honest vs fit.
- `ChoicePanel` (presentation): keys 1–9, or up/down then E/Enter.
- `HeadCall`: thoughts show in muted parentheses; `allow_skip` lets E advance a line.
- `EveningLayout`: greybox, in real metres, scaled to the diorama (0.47). The camera side
  of the boulevard is low podiums, so the iso view reads (the apartment's cut-wall rule).

The lines live in `NightZeroScript`.

**Not yet:**
- Graphics: Downtown kit facades in METAL style, brand shops, real cars, the shoot's
  props, the diners' face veils, the train.
- Saving mid-evening: quitting skips it.
- The friend's name.

## Phase 2 graphics pass (2026-10-22)
- **Car:** a canyon of glass curtain-wall towers (Downtown kit, METAL) over the massing.
- **Boulevard:**
  - Far side: glass towers.
  - Near (camera) side: two-storey shopfront podiums with neon brands (AUREL, MAISON
    VÉRIDE, HERITAGE, FOCUS+ ELITE, OSTRA, LUMEN & SON) facing the camera. Seen from
    behind they would read mirrored.
  - Marble pavements, cast-iron street lamps, planters, parked luxury cars.
  - The skyline: the Fab high-rise and mega tower; flying traffic overhead.
- **Shoot:** light stands, softboxes, a gold reflector.
- **Restaurant:** a marble floor, gilt frames, the bust on a plinth, hanging lamps, wine
  (Poly Haven `wine_bottles_01`, CC0).
- **Dinner guests:** the three corpo friends wear sheer dark veils on the head bone
  (`StreetFigure.veiled`).
- **Metro:** opens on the platform, the graffiti tram (Fab) waiting, then cuts inside.
- **Pre-warm:** `Evening._warm_up` renders each heavy area behind black before the car.

## Verification
`tools/probe_evening.gd` plays the whole evening: car → dinner → gift → walk → metro →
home, five choices, an honest verdict, the gift refused, the walk beats, the station,
and the boxes back home.

`tools/probe_night_zero.gd` checks:
- a direct boot doesn't start it; signing does;
- the friend and the boxes exist;
- one box at a time; the three land;
- he is held for the invitation; then he is freed and the friend is gone.
