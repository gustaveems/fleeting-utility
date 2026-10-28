# Ticket-25: layout review of the play spaces (2026-10-28)

The layout pass after the story systems. The spaces reviewed are the apartment, the
corporate park, the metro carriage, the crowd's rooftop and the valley. Each space was
reviewed from straight above (the true layout) and from the game camera, entered the
way the game enters it: `godot --path . -s tools/capture_layout.gd` writes
`tools/out/layout_<space>_top.png` and `_iso.png`. The positions and the reach of every
interactable were then checked against where he can walk.

## Fixed
- **The box tutorial vs the bench** (a real bug, met in the first minute). Night Zero's
  drop zone overlaps the bench's reach, so E there cooked a dose and the box stayed in
  his arms. Carrying now holds an interaction lock (`NightZero.CARRY_LOCK`), and the
  put-down acts under it (`InteractionController.is_locked_except()`).
  `probe_night_zero` checks it.
- **Two colossi were out of reach in the dream.** The dream's movement bounds were
  ±28 m, but colossus 0 stands at x 34 and colossus 3 at z 32, so their feet and their
  "[E] Return" zones couldn't be reached. The bounds are now ±38 m (the valley floor runs
  to ±60).
- **Clutter spawn slots** moved out from under the stacked boxes and off the door's
  threshold, where the neighbour stands after the ransack.
- **New gate, `tools/probe_layout.gd`.** In every space, everything he must reach lies
  inside where he can walk, the apartment's prompts don't overlap, and he arrives inside
  the carriage and on the roof.

## Done after review (Alain: "do 1 and 2")
- **1, the colossi from the spawn:** the valley fog is thinned (exponential 0.018 → 0.011,
  volumetric 0.004 → 0.0025) and the stone colossi darkened (albedo 0.52 → 0.34), so the
  one in frame reads as a silhouette out of the mist, arm raised. The trees already kept
  every spawn-to-colossus sightline clear.
- **2, the crowds have bodies:** `StreetFigure.solid` adds a capsule on the world layer
  for the carriage's commuters and the rooftop's guests and friend. It lives under their
  `WorldRoot`, so it sleeps with it. The carriage's boarding spot moved into an aisle gap
  (`MetroRide.START`). `probe_layout` checks the bodies, that they sleep, and that he never
  arrives inside one.

## Observations (for Alain; not changed)
1. **The valley's colossi barely read from where he wakes.** They stand 30–37 m out in
   heavy mist, behind birches. To show them clearly: thin the fog toward them, bring
   them in to about 22 m, or clear one sightline from the spawn to a colossus. As it is,
   the dream's subject is only found by walking.
2. **The apartment's things all hug the walls:** bench NW, wall screen and works W, door
   N, easel E, cot SE. The middle is empty floor. That's good for moving, but the room
   reads sparse until the clutter grows.
3. **No one in the carriage or on the rooftop has a body:** he walks through commuters
   and guests. Small colliders would make the crowds press, which suits the
   *"cramped and busy"* brief.
4. **The park is a wide empty plaza:** a 4×4 grid of tree beds, the walls 5 m past the
   walk's bounds. It reads as designed and sterile, which fits the leased park, but the
   walk has nothing on its route except the campaign billboard (once it's live).
5. **The evening** (`scenes/evening.tscn`) is a scene of its own and wasn't covered here.

## Next
The prologue's Phase B city (plan approved: `docs/references/city_plan_v1.png`, in
TICKET-15).
