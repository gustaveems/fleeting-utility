# Polish backlog (look and feel)

What's left to make the game look more finished, after the polish pass of 2026-11-06.
Palettes and references are in `docs/references/notes.md`, sources in
`docs/references/asset_shortlist.md`. Story and mechanics are in `docs/ROADMAP.md`.

The first version of this list was written without looking at the game; checking each
space in captures changed several items. What was found is noted below.

## Done (2026-11-06)

- [x] **The walk's road and pavement** (`StreetLook`): wet asphalt with a worn centre line
  and puddles that take screen-space reflections; concrete slabs with dirty joints. These
  replace the mottled road and the flat sand-coloured marble.
- [x] **Lamp pools.** The lamps weren't even, as first listed: they were white specular
  discs. They now give warm pools with a short range and little specular.
- [x] **Shop light on the pavement** (`Storefront._spill`): added, not lit, so it costs no
  extra light. Shop glass already read as rooms; nothing was needed there.
- [x] **Litter and rats** (`StreetFurniture.litter`, `.rat`): cans, packets, bags by the
  bins, two rats working the kerb. The photo shoot's white-out is toned down too.
- [x] **Night haze** on the evening's environment.
- [x] **The apartment:** quieter floor, a black void round the cutaway, soft round dust
  instead of square specks, the boombox, a desk lamp, a lit wall lamp, a side table by the
  cot.
- [x] **The dinner** (`DinnerDressing`): oak walls, stone floor, ribbed red rug and chairs,
  a ceiling (the sky showed over the room), real bottles lit from behind, the chandelier,
  brass candleholders and goblets, a plant; the table no longer glares.
- [x] **The rooftop:** real sofas, table and ottoman, with bodies.
- [x] **The metro:** the tube no longer burns white, the seats are muted, and the wall tags
  are sprayed strokes rather than yellow and pink blobs.
- [x] **The valley:** forest-floor texture, 40,000 fallen leaves (one MultiMesh), low sun
  through a little more haze.
- [x] **The park:** a sky instead of a flat blue, a real lawn, lighter trunks.
- [x] **Characters:** folds, a waistband shadow and a fine weave on the clothes, a shadow
  under the jaw.

## New features (2026-11-06, the second pass)

- [x] **Lease notices** under the door on set mornings, including the Heritage flyer that
  shows the shoes before beat 15 and an incident report after the ransack.
- [x] **The radio:** one bulletin a day on the boombox. It eases overload a little and
  stops working after the ransack.
- [x] **LeaseLink** (P): day, standing and a log of his calls; no signal in the valley.
- [x] **Day cards:** "DAY 4" over the room on waking, replacing the small "Day 4." line.
- [x] **Rain on the walk:** streaks, rings in the puddles, and its sound.
- [x] **A title screen:** the city at night in the rain, with the gold colossus.
- [x] **Tearing wallpaper:** striped paper above the dado that tears away with entropy.
- [x] **The rooftop's skyline:** lit rooms in the towers and the gold colossus in the
  distance.
- [x] **The metro:** a warm tunnel lamp sweeps through the carriage.
- [x] **Passersby:** each wears their own coat and trousers.

## Dropped, and why

- **Damp ceiling:** the apartment has no visible ceiling (it's a cutaway).
- **Statues:** already textured stone. The first list was wrong.
- **Irregular shrubs in the park:** the cloned, gridded planting is the point of the park.
- **The colossus on the metro:** at that camera only stray pieces of it showed in frame,
  so it was taken out again.
- **Overhead wires:** at this camera they'd cross the player and the shop windows, and this
  is the polished quarter. Better suited to the film's rundown street, if anywhere.
- **Bigger metro ads:** they already read at this size.
- **Pigeons:** Poly Haven has no bird.

## Still worth doing

1. **Graffiti and puddle decals:** the Fab Quixel graffiti and "Simple Water Puddles" packs.
   Needs Alain to click Download while signed in.
2. **Rooftop sofas:** `Sofa_01` is ornate. It works as old-money pretence, but the Fab
   sectionals on the shortlist are closer to a rooftop lounge. Same Download step.
3. **Passersby:** hair varies by class only; the crowd could use more of it.
4. **Grade across spaces:** one side-by-side pass over the palettes in `notes.md`. Each
   space was tuned on its own in this pass.
5. **The dinner's bottles** bunch to the left of each shelf (the model's own layout), and
   the candleholders sit low in the opening shot.
6. **Dream light:** the shafts are faint. Stronger ones would need the sun higher or the
   camera turned toward it.
