# Ticket-15: Prologue, Phase A (previs)

Story: `docs/STORY.md` Prologue 1–5. Reference: the Cyberpunk 2077 Corpo AV flight (a long,
framed, on-rails glide; exposition by radio; a landing that hands off to play). Our
version: his class, his transport. Decisions grilled on 2026-10-20.

## Decisions
- **Vehicle: a packed commuter maglev** on an elevated track, from the dying town into
  the city. No flying.
- **A film, no control.** Three scripted **gaze moments**: the camera turns to look
  1. at the luxury campaign billboard,
  2. down at his phone (the lease notification),
  3. up at the golden colossus, a **cheap copy of the Colossus of Rhodes**, as the train
     passes between its legs.
- **POV: mixed.** First person through the carriage window (packed commuters as dark
  silhouettes, the window frame) and external establishing shots.
- **Skippable:** hold E or Esc for 1 s.

## Phase A scope: greybox previs only
The movement, timing and framing come first. Only build what the camera sees.
- `scenes/prologue.tscn` + `Prologue` composer. New Game goes Boot → Prologue → game.
- **Track:** a `Curve3D` route: town station → tunnel → outskirts → monolith canyon →
  through the colossus's legs over a canal → descent into the low blocks → his station.
- **Maglev:** a few box carriages following the curve.
- **Shots:** a data-driven list. Each shot has a camera mode (train first-person /
  external fixed / external follow), a duration, a train progress range, an FOV, look
  targets and gaze moments, and subtitle lines (station PA, radio ads, news).
- **Greybox city:** procedural box towers placed along the route; a district parameter
  sets their height. Placeholder emissive billboard panels with text. A box-built golden
  colossus. His beige sliver tower wedged between blocks. The town: a dust plane, the
  dead mall, the fenced stone.
- **Overlays:** the carriage window frame and commuter silhouettes in first person; the
  phone card; subtitles; the title at the end.
- **End:** "FLEETING UTILITY", then into the game (lease signing is Phase E).

## Shot list (≈90 s)
| # | POV | Beat | ~s |
|---|---|---|---|
| 1 | EXT | Dawn, the dying town: the maglev pulls out of a dusty station; the fenced stone in the parking lot | 8 |
| 2 | FP | The town slides past the window; the stone passes close | 10 |
| 3 | FP | Tunnel to black, then the city's edge; packed commuters | 6 |
| 4 | EXT | Wide aerial: the train threading between teal monoliths | 8 |
| 5 | FP | Canyon run, ads flaring. **Gaze 1:** the campaign billboard (birches, stones, model) | 14 |
| 6 | FP | **Gaze 2:** his phone: "LEASE CONFIRMED — Unit 7-14B. Terms apply." | 8 |
| 7 | EXT | Reveal: the golden colossus (cheap copy) straddling the canal; the train between its legs | 10 |
| 8 | FP | **Gaze 3:** looking up at it from beneath; the seams show | 8 |
| 9 | EXT | Descent into the low blocks, neon haze; a grimy station | 8 |
| 10 | EXT | Hold on the beige sliver wedged between blocks; title | 8 |

## Later phases
B: city layout · C: look dev (`docs/references/notes.md` palettes) · D: sound and radio
· E: lease signing + integration (prologue_seen saved).

## Verification
`tools/probe_prologue.gd` (run at an accelerated time scale) must show:
- the shots play in order with the right modes
- the train advances monotonically
- each gaze moment fires
- skipping lands in the game
- the full run lands in the game

Windowed captures at each shot go to `tools/out/prologue_*.png` for review.

## Phase A.2: train look, carriage interior, the avenue walk (2026-10-20)
Alain's review: the train moves correctly; the flying shots, the ad and the notification
work (graphics can come later). He asked for a short walk from the metro stop to the
building.

- **Maglev exterior** (ref: Shanghai Transrapid): sleek white body, rounded nose, blue and
  orange stripes, an elevated T-beam guideway. The future as advertised.
- **Carriage interior** (ref: grimy subway car): one new shot down the packed aisle:
  steel poles, ads above the windows, graffiti and litter, harsh fluorescent light, a
  neon "DO NOT CROSS THE LINE". The future as lived.
- **The avenue walk:** third person, the camera following him, still a film. A short
  avenue from Block 31 station to his building door:
  - he walks the **median line**, the same "DO NOT CROSS THE LINE" glyph as in the
    carriage, between the classes
  - **left (rich):** a clean, lit Heritage Collection boutique (the campaign's own store),
    a guard and a rope line, suits going in
  - **right (poor):** tents, a trash fire, people slumped, a dealer huddle, two men fighting
  - **suits cross his path twice**; middle-class commuters pass with their heads down
- **Ends** at the beige sliver's door: a low angle, then the title.
- **Shot list** becomes 13 (~2 min): `carriage_interior` is added after the tunnel;
  `his_tower` is replaced by `station_exit`, `avenue_walk` and `his_door`.

### A.2 layout pass: Alain's sketch (2026-10-20)
`docs/references/sketch_walk_layout.png`. The line's last stretch now runs north along the
avenue's left side, in front of massive blocks; the train stops at a platform beside the
avenue. The walk is a path (`PrologueAvenue.PATH`): platform → stairs down to the road →
the median → up the avenue (rundown block on the right) → right at the corner by the
fight → the cross street → his complex's door. The follow camera turns with his heading.
`w` in the shot list is now a fraction of the walk. Walk shots: `station_exit` 8 s,
`avenue_walk` 36 s, `his_door` 8 s (film ≈ 139 s).

### A.2 review pass 2 (2026-10-20)
Alain: everything else is fine, then:
- **Metro windows at head height.** The window band is centred at 1.35 m (it was 2.0 m).
  The stripes moved below it, his seated eye is at 1.25 m, and the aisle shot now has
  night glass at the same height.
- **A shoulder bag** at his right hip, the strap across his chest.
- **He waits at the curb** (new shot `curb_wait`, 7 s): a car rides past, then a group
  of ten crosses toward the metro around him and climbs to the platform.
- **The street is packed** (81 figures): commuters stream both ways on each sidewalk,
  along the median and in his street, plus a stall, the fire, the queue, the slumped and
  people by his door. Cables, laundry, AC units and more neon close in overhead.
- **The fight starts at the left corner of his street** (a lit liquor store). They argue,
  then the shove, the stagger, the first swing. He sees about two seconds of it, then
  turns away into his street. Its lines are timed from `PrologueAvenue.fight_progress()`.
- Film: 14 shots, about 146 s.

### A.3 cinematic camera (2026-10-20)
Alain: make the film fully camera based; keep the shots. The decisions: the camera frames
the three beats (no first person), and one camera glides between moves with few cuts.
- **No POV.** The window overlay is gone. Every shot is cinematic and letterboxed.
- **Glides:** each shot blends in from wherever the camera is (`blend`, default 2 s).
  It cuts only where it must: the aerial, `through_train` (a glide down would pass
  through the towers), the metro, the colossus reveal, the station, the door.
- **Shots (15, about 146 s):**
  1. `town_establishing`
  2. `town_glide`: down beside the train, sliding back along it
  3. `tunnel`: the chase
  4. `aerial_canyon`: a travelling aerial
  5. `through_train`: in at the left windows, through the packed carriage, out the
     right, holding on the campaign
  6. `metro_interior`: handheld, shaking with the train (scaled by the reduce-motion
     setting). Down the aisle to him seated, then over his shoulder for the lease on
     his phone.
  7. `colossus_reveal`: a slow push
  8. `through_statue`: chasing the train between its legs, tilting up to the head
  9. `descent`
  10. `station_exit` and 11. `curb_wait`: kept
  12. `avenue_walk`: third person up the median
  13. `avenue_top`: the camera glides off him to the metro side and up, looking down
      on the whole street
  14. `corner_walk`: back behind his shoulder 3 m before the corner; the fight, the turn
  15. `his_door`
