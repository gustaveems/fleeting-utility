# Playtest log

Alain's playthroughs, newest first. Each entry is the raw list of what went wrong or
needs work, sorted by severity. A line is ticked when a commit fixes it, and the fix is
noted next to it. The first fix pass (2026-10-30) is in `docs/tickets/TICKET-29.md`.

## 2026-11-05: fifth playthrough (screenshots in `Feedback/`)

- [x] **The evening's strangers running on the spot** (the second time this came up).
  - **Fixed:** nine passersby were posed WALK and nothing moved them. They now walk
    loops round the pavements (`EveningLayout.CIRCUITS`), one pace and one direction a
    loop, and stop for him. `tools/probe_figures.gd` now fails anyone in any space who
    walks on the spot, and sweeps the loops clear.
- [x] **"You're invited out tonight. The door." and the door wouldn't open** (day 8,
  Lior's lease party, after the park walk).
  - **Fixed:** the door is shut after the walk (the hesitation), but the invitations
    only stopped at the lease renewal. They now stop with the walk: no party, no
    morning line, no hint. The crash hint no longer offers the metro through that door.

## 2026-11-04: fourth playthrough (screenshots in `Feedback/`)

- [x] **The room showed through the dream**, and the door answered ("Not yet…") in the
  valley.
  - **Fixed:** a collapse on the park walk left the park running under the dream, and
    its timer brought the apartment back mid-dream; he also woke in the park's bounds.
    The walk now ends itself like the metro and the rooftop
    (`CorporateParkManager._cut_short`), and the ransack he'd have come home to lands
    under the white as he wakes (`tools/probe_outing_collapse.gd`).
- [x] **A building's front in the apartment.**
  - **Fixed:** the door was the city kit's full-size 3 m street door on 1.35 m walls (a
    building entrance). It's now scaled to the room and mounted on the wall.
  - The north wall was a sill under one window 72% wide, open at both ends; it's now a
    wall with two windows either side of the door (`WorkspaceBlockout.WINDOWS`; the
    east one still frames the shoes).
  - The block across the alley sits lower: its upper storeys, not its street door.
- [x] **The dinner:** the cloth glared white; the diners had glossy helmets with eyes;
  their clothes were blotched.
  - **Fixed:** the room is lit low, and the cloth is off-white.
  - The veils are matte gauze.
  - The chairs stood inside the seated bodies (the sitting clip puts the back ~0.4 m
    behind the root); they now sit back (`EveningLayout.SEAT_BACK`).
  - The man's collar line ran through his trapezius (a ragged bib of skin on a bowed
    head); it's now set per body (`StreetFigure.COLLAR_MAN` / `COLLAR_WOMAN`).
- [x] **The walk: a ghost on the road, a grey mannequin.**
  - **Fixed:** the night street has no shadows (a shadow per lamp lagged), so every
    figure now stands on a soft contact shadow.
  - The clothes flatten more of the body's sculpted muscle.
- [ ] Follow-up: the shopfronts beside the walk are still black (the lit shop windows).
- [x] **The dinner, again (17.09.41): a black halo round every veiled head.**
  - **Fixed:** the matte veil sphere was bigger than the skull. The veil is now the
    head's own surface (the cloth shader's `veiled`), so it fits. Seated figures drop
    the floor pool too: they sit on seats, and the pool hung in the air at seat height.

## 2026-11-03: third playthrough, up to the park (day 6)

- [x] **The walk spawned him in empty space**, and home again outside the bedroom.
  - **Fixed:** the walk kept his coordinates both ways. He now arrives at the head of
    the park's path (`CorporateParkManager.START`) and comes home where he left
    (`tools/probe_park_walk.gd`). The walk lasts 45 s, not 15.
- [x] **The forest needs much, much more forestation and volume.** A lower camera and a
  narrower lens would sell the size.
  - **Done:** `Forest` plants trees as instanced MultiMeshes (one per model and 30 m
    cell, trunks as one body).
    - **The valley:** ~810 birches instead of 70: groves and glades to the fog, the
      paths to the statues kept open, far more ferns, branches, stumps and rocks.
    - **The park:** a plantation of one cloned tree in rows to the walls (~300) along a
      straight polished path on the camera's diagonal; plates on the trees beside it,
      benches and lamps in step, a haze.
    - **The camera:** the dream is lower (pitch −6°, 45° lens) and the park lower and
      longer (−10°, 38°, `WorkspaceCamera.set_park_framing`). Both hold ~90 fps.

## 2026-11-03: second playthrough (after Ticket-29), up to day 5

Not reached: the park.

### Blockers
- [x] **The metro while overloaded breaks the dream and traps him.**
  - **Fixed:** a collapse on an outing (the metro or the rooftop) now ends it first.
    `MetroRide._cut_short` / `Standing._cut_short` run on
    `DreamscapeManager.transition_started`, bring him home quietly and restore his
    bounds, and only then does the dream save them. `tools/probe_outing_collapse.gd`
    reproduced the strip (3.7 × 0.5 instead of 4.15 × 3.15) and now guards it.
  - **What happened** (day 3): he took the metro while overloading and collapsed. The
    dream showed the metro carriage, with the buildings flying past.
  - **On waking:** stuck in the apartment, body-blocked between the easel and the
    opposite wall. He can't reach the bed, the door or the kitchen.
  - **Suspected:** the collapse fires mid-ride and `MetroRide` never ends the ride.
    The carriage WorldRoot stays active under the valley, and his movement bounds stay
    the carriage's (`_saved_extents` isn't restored), so the room clamps him into a
    strip.
  - **To fix:** no collapse while riding, or end the ride first. A probe should ride
    overloaded and check the wake.

### Broken
- [x] **Characters clip and duplicate.**
  - **Fixed** (gated by `tools/probe_figures.gd`):
    - **Doubles:** the evening's passers-by were dressed as the friend every third one,
      and the campaign model was too. Strangers now wear suits and coats, and only the
      friend wears his clothes.
    - **Walking through things in the evening:** it had no collision at all. Lamps,
      planters, parked cars, the metro's parapets and every passer-by are solid now,
      and they stand in the gaps between lamps and planters.
    - **Walking through things at home:** the bed, the cabinet and the easel had no
      bodies; they do now.
    - The probe checks each space: nobody inside another person, nobody inside a wall
      or a prop, no stranger in the friend's clothes, all furniture solid.
  - Several copies of the same NPC.
  - He phases through things and gets clipped.
  - Some player models collide with each other.
- [x] **The film's opening shots:** the camera clips in and out of the train.
  - **Fixed:** three causes.
    - **The tunnel shot:** it followed from behind at roof height, inside the second
      carriage. It now rides ahead of the nose, looking back, and opens on a cut.
    - **The colossus pass:** it ended over the lead carriage's roof; it now ends
      beside it.
    - **Trailing carriages:** before the train cleared the town platform they collapsed
      onto one point. `_frame_at` now extends the line straight back.
  - `tools/probe_prologue_camera.gd` fails if the camera enters a carriage outside the
    through-the-train shots, and measures speed by film time (the engine's delta
    jittered).
- [x] **After the restaurant scene, the buildings and their window panes flash a lot**
  (flicker, likely z-fighting or LOD popping). It makes the walk slightly laggy.
  - **Fixed** (`911581c`):
    - **The flashing:** the lit shopfront band sat on the facades' plane and z-fought
      the kit glass into jumping white patches. It's now 30 cm inside the building.
    - **The popping:** the walk used the room camera's 45 m far plane, which cut the
      towers in and out. It's now 150 m (`Evening.FOLLOW_FAR`).
    - **The lag:** every lamp had two lights (the prop's and a second "street light"
      set, about 40). The kit's lamps now light alone, a little brighter.
  - **Follow-up:** the kit's shop glass is opaque, so the shopfronts read dark now. Lit
    shop windows want an emissive glass material.

### Look
- [x] **The night train switches model.** The film's maglev is ours, but the night
  train after dinner is the Fab graffiti tram. Use one train family.
  - **Fixed:** `TrainLook.carriage(car, nose, wear)` builds one carriage, used by both
    the film and the evening. The night train is the same maglev worn (wear 2.2:
    greyer, grimier, spray tags on the lower panels; none on the nose). The windscreen
    is painted on the nose in its shader. The Fab tram stays only as the wreck in the
    film's dead town.
- [ ] **Not textured yet:**
  - [x] the metro station: the evening's station is now tiled walls with the line's
    gold band, slab concrete with the yellow tactile edge, a studded trackbed, the
    ceiling's strip lights and the HERITAGE QUARTER name (`TransitLook`);
  - [x] the inside of the metro carriage: panels, moquette seats and a studded floor,
    in the game's ride and the night train;
  - [x] the city: the film's massing shader is now `CityLook`, shared by any building
    box (`CityLook.building(tint, look, unit, anchored)`). The evening's car-ride towers
    and the massing behind its shopfronts, the metro window's and the rooftop's skylines
    (pattern anchored to each sliding block), and the film's avenue backdrop and corner
    blocks wear its curtain wall: storey bands, sky-glass, lit rooms, stains.
- [x] **Neon lettering** is still too much and too janky, even after `SignType`.
  - **Fixed:** `SignType.neon()` no longer draws a hard 22 px outline round floating
    letters.
    - **The letters** burn just past white in their own colour (×1.6), so the scene's
      glow blooms them softly.
    - **Each sign** hangs on a dark metal board sized to its text.
    - **The avenue** has three short signs instead of five long ones, smaller.
    - **The evening:** the brand signs and the restaurant's (2 m letters across the
      pavement) are mounted boards; the evening has glow for them (threshold 1).
- [x] **The apartment** could do with more work.
  - **Done** (`WorkspaceBlockout._furnish`): it read as four props on a plaza of loud
    tiles.
    - **The floor:** muted, and the tiles halved (~24 cm real).
    - **The walls:** tired cream instead of mustard, with skirting.
    - **The furniture:**
      - a kitchenette in the south-west (counter, sink, kettle, fridge);
      - a table and chair;
      - shelves with his books above the boxes' corner;
      - a radiator under the window;
      - a dead plant;
      - a floor lamp lit in the north-east;
      - a faded rug, and one by the bed.
    - All of it is solid. The west wall's floor stays clear for the moving boxes, and
      the north-east for the window beat.

## 2026-10-30: first playthrough with sound, up to day 5
All fixed in `9b806c5` (Ticket-29):
- [x] the camera whipping in the film;
- [x] the train into a wall;
- [x] the train, the towers and the statues untextured;
- [x] the lettering;
- [x] the clothes;
- [x] constant shakes;
- [x] the camera too far;
- [x] the metro entrance;
- [x] the restaurant;
- [x] new players lost.
