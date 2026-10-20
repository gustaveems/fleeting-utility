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
