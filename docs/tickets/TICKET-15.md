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

### Phase E: lease signing (2026-10-20)
`LeaseSigning` (ui module): when the prologue hands over, the lease lies over the bare
room. He can't move or interact until you hold E for 1.2 s. It takes a fresh press, so
E still held from skipping the prologue doesn't sign it. Its six clauses are the
mechanics he will live under: decay, productivity review, works reclaimed, sanctioned
focus, renewal at discretion, stay on your side of the line. It is gated by a static
`pending` flag, so Continue and tests never see it. Verified by `tools/probe_lease.gd`.

## Phase B: the city layout (approved and built 2026-10-28)
Built by `PrologueCity` (src/presentation), from the numbers in `PrologueCityPlan`
(src/data), replacing Phase A's random towers. Every tall thing keeps off the shots'
sightlines and the billboards, and now also off the lines from each external camera to the
train while its shot runs. The aerial (shot 4) follows the train (`look: "train"`): before,
the canyon's south wall hid it. The massing is one MultiMesh, the neon another, and the
town's shopfronts are kit facades. Against Phase A: the descent runs 50 → 75 fps, the
avenue 29 → 53 fps, the town 154 → 111 fps (`tools/fps_prologue.gd`).

## Phase C: look development (2026-10-28)
The palettes and references in `docs/references/notes.md`, applied per stretch of the
film. The values live in `PrologueLook`, as one stage per stretch; each shot plays in its
stage (`SHOT_STAGE`).
- **town:** decay. Rust and orange dust haze (#B9875A), a low dawn sun, and the station's
  sodium lamps (#E8A040) still burning (2049's dead Vegas outlets).
- **canyon:** teal-grey monoliths (#2E3B3F → #5F7478) in an oppressive haze, a low sun
  burning through the warm horizon (Heywood flyover, 2049's massing). The ads are the
  brightest thing in the sky (`AD_GLOW`).
- **colossus:** the same city, warmer: the gold copy catches the last sun.
- **descent:** dusk going to night in the low blocks, the neon picked out by glow.
- **street:** the avenue's night as Phase A had it, with light glow.

How it's done:
- **The massing shader** (`PrologueCity.MASSING_SHADER`): per instance (`Look`), the
  megatowers get the endless lit windows, sparse (one in eight), warm and cool. The low
  blocks get fewer, there's grime toward the street, and the roofs are a shade lighter.
  It works in world space, so the scaled boxes need no UVs.
- **The shadows** are lit by the palette's base (`ambient_color`), not the sky. The warm
  horizon had been turning the teal towers tan.
- **Glow** only blooms past white (threshold 1): the ads, the neon, the lit windows.
- **The warm-up** renders every spot under every stage behind the black.
- **Cost:** about 20% in the early shots (the town 111 → ~80 fps, the canyon 102 → ~85),
  measured once under the same conditions. Glow isn't it. The window shader is the
  suspect, but the measurements on this Mac were too noisy to confirm.

### The plan as proposed
Plan: `docs/references/city_plan_v1.png`. The plan is drawn on the real track; the yellow
circles are shots 1–9. It replaces the Phase A greybox (random box towers) with authored
districts. Only what the cameras see gets built.
- **A. The town:**
  - a shuttered main street of low brick shopfronts running beside the line (shots 1–2);
  - the station and the fenced stone in its car park;
  - the dead mall with its empty car park, and a logistics depot with a truck yard;
  - the agri-corp's leased fields, fenced, to the south;
  - the same billboards, older and peeling.
- **B. The ridge** the tunnel cuts through (shot 3).
- **C. The city's edge:** an old grid of low blocks, crossed by a ring highway on stilts.
- **D. The monolith canyon** (shots 4–6):
  - two walls of megatowers, 80–200 m tall, 26–44 m either side of the track;
  - a cross street every 90 m, so the aerial shot reads streets and not a forest of
    pillars;
  - the old low blocks crammed beneath and between them, 8–15 m (*"megatowers over older
    low blocks crammed beneath"*).
- **E. The colossus canal** (shots 7–8):
  - a 36 m canal running north–south under the colossus, with quays and two bridges;
  - Colossus Plaza on the west bank, kept open for the reveal's sightline;
  - the Heritage Quarter upstream (18a's boutique window lives here);
  - warehouses on the east bank.
- **F. The low blocks** (shot 9): dense 12–34 m blocks and neon, descending to Block 31,
  where the avenue (Alain's walk sketch, already built) takes over.
