# Playtest log

Alain's playthroughs, newest first. Each entry is the raw list of what went wrong or
needs work, sorted by severity. A line is ticked when a commit fixes it, and the fix is
noted next to it. The first fix pass (2026-10-30) is in `docs/tickets/TICKET-29.md`.

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
