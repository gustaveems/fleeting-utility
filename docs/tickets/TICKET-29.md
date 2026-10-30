# Ticket-29: playtest fixes (2026-10-30)

Alain's first playthrough with sound, up to day 5. What he hit, and what changed.

## The film
- **"Two moments the camera moves at the speed of light."** Three glides were the cause:
  - **Town glide and through the statue:** each swept ~90 m in 2–3 s to catch the
    train, turning at up to 124 °/s. They now cut.
  - **The descent:** the camera was fixed in the carriage's frame, so it swung round
    every curve (150 °/s). It's now `steady`: the offset is in world axes.
  - **The call:** it jumped its tilt at the start; it now glides in over 2.5 s.
  - `tools/probe_prologue_camera.gd` measures every shot: at most 60 m/s and 120 °/s.
- **"The train goes straight into a wall."** The tunnel was a box lying on a low slope.
  - The ridge is steep now (60 m).
  - The bore runs mouth to mouth (`PrologueCityPlan.tunnel_mouth()`), with concrete
    portals round each mouth.
  - Each mouth is a one-sided black quad, dark from outside and culled from inside.
- **"The train still isn't textured."** `TrainLook`:
  - **body:** panel seams, two doors a side, belt lines, grime low and rain streaks;
  - **glass:** framed panes, each lit differently, blinds in some.
- **"The towers aren't textured."** The massing shader's walls are now a curtain wall:
  - storey bands, mullions, building-to-building tint and rain stains;
  - glass that holds the sky, lit rooms with blinds.
  - The town gets render over brick with shuttered windows (its look was never drawn).
- **"The statues are flat, no textures."** `ColossusFigure` is now the characters'
  base body:
  - on the UAL skeleton, frozen in the torch clip with its legs spread over the
    plinths and the torch in the raised fist;
  - surfaced by a shader: STONE is weathered, lichened and streaked with blood running
    down; GOLD_COPY is chipped paint with moulding seams;
  - one change fixes both the film's gold copy and the dream's stone colossi;
  - without the packs it falls back to the capsules.
- **"The lettering is weird and ugly."** Every Label3D was Godot's default UI font,
  huge.
  - `SignType.dress()` gives them a condensed signage face from the system fonts:
    DIN Condensed on macOS, Bahnschrift on Windows. Nothing is downloaded or
    redistributed.
  - `SignType.neon()` draws a hot core with a coloured halo; the avenue's neon is
    smaller.
- **"The clothes look duplicated."** Two causes:
  - **The cloth shader** chose shirt or trousers by each point's posed height: a
    swinging hand dipped below the hips into the trousers, and seated figures came out
    in patches. Each vertex's rest position is now baked into CUSTOM2
    (`StreetFigure._with_rest_position`). Head and hands are skin, the feet are shoes.
  - **His bag** was a box on the model that stayed put while he walked past it. It now
    hangs from the pelvis bone.

## The evening
- **"The metro after dinner is just a block."**
  - It is now a stairwell going down into a lit well, with parapets, handrails, a glass
    canopy and the M totem.
  - The street is built round the hole.
- **"The restaurant is awkward, the conversation and the graphics."**
  - **The room:** four walls (the bar with its bottles, the door, a window wall with the
    city in it), a rug, velvet chairs, a cloth to the floor, five places set, candles.
  - **The talk:** the friend introduces the table first. Whoever speaks talks with
    their hands (`StreetFigure.set_talking`), and the camera finds them from over the
    table. His thoughts go back to the wide shot.

## The game
- **"Constantly being shaken / can barely do anything with the shakes."**
  - **Before:** a dose stayed above the recovery line ~35 s, then a crash came within
    seconds.
  - **The drug:** depletion 0.02 → 0.008/s, so a dose lasts ~90 s above the line and
    ~2 min in all.
  - **The overload:** accumulation 8 → 4/s; the empty-tank flood 40 → 15/s.
  - **Crashed:** speed 1.4 → 2.6, response 4.5 → 8; tremor 0.004 → 0.0015, step jolt
    6 → 2 px.
- **"The third-person view is massive."** The camera stands ~6.4 m off (3.9, 3.3, 3.9),
  not ~14 m. The rooms are a half-scale diorama and he is 0.85 m tall.
- **"As a new player you feel lost."** `NextStepHint` adds one line under the meters
  ("NEXT …"). It reads the systems in priority order:
  1. the dream;
  2. the park;
  3. overloaded: what to do about it;
  4. wearing off: the bench;
  5. the room unbearable: the door;
  6. invited out: the door;
  7. not painted today: the easel;
  8. otherwise: sleep.

  It keeps quiet whenever anything else talks or asks. `tools/probe_next_step.gd`
  checks it.
