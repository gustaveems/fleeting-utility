# Ticket-01 — Player Movement & Workspace Camera Controller

Scope: `GAME_SPEC.md` pipeline item 1. Grid-snapped locomotion, the fixed isometric
camera, the soft-boundary response, and the seam Ticket-02 plugs into. Nothing else:
no crafting, no degradation, no dreamscape, no Sensory Overload meter.

## What was decided (and why)

| Decision | Choice | Consequence |
|---|---|---|
| Isometric implementation | 3D scene, fixed oblique `Camera3D` | Cells are `Vector2i` on the XZ plane; post-FX is a screen-space shader; Ticket-05 gets a real 3D valley for free |
| Projection | Orthographic, 9 m vertical span | 1 m cells are the same pixel size everywhere — the grid constraint stays legible |
| Elevation / yaw | 35.264°, yaw 45° (+X/+Z diagonal) | True isometric: cube faces are congruent diamonds |
| Crash movement | Both "slower movement" (spec) **and** "reduced turn speed" (brief), as separate tunables | `step_duration_seconds` and `turn_commit_delay_seconds` can be balanced independently |
| Walls | Zero colliders anywhere | A refused step becomes a vignette/fog bloom, never a bump |
| Scene assembly | Built in code from one 4-line `Main.tscn` | Geometry can't drift from `WorkspaceGridData`; every file is lintable headlessly |

## Crash = turn latency, felt while standing still

`TurnController` opens a window of `turn_commit_delay_seconds` between *intending* a
facing and *committing* it, and `GridMover` refuses to start a step until the wanted
facing is the committed one. High-Focus commits in 0.03 s, Crash in 0.16 s — so the crash
is experienced as the body answering late, which is a different sensation from the step
itself being slow. `PlayerView` separately rotates the body model at
`turn_speed_degrees_per_second` (900 → 220), so the visual and the input-side lag are
independently tunable.

## Soft boundary, two rising channels

`SoftBoundaryModel` emits one float, 0..1:

1. **Gradient** — `WorkspaceGridData.edge_closeness(cell)` over `soft_edge_band_cells`
   (2 cells). Walking towards the wall thickens the fog before you arrive.
2. **Impulse** — `GridMover.step_refused` injects 1.0, decaying over 1.4 s. Pressing
   into the limit blooms the screen, which is the rejection being *seen*.

Consumers: `SoftBoundaryPresentation` (fog density, volumetric density, key-light energy)
and `PerceptionPostFX` (vignette + a touch of chromatic split). Spawn is cell (4,3), the
centre of the 9×7 footprint, deliberately outside the band so the game does not open
already fogged.

## Screen mapping — why W is not "up"

At 45° yaw the four grid axes project as four screen diagonals. Bindings follow the
screen component of each axis:

```
W / Up    -> NORTH (-Z)  up-right        S / Down -> SOUTH (+Z)  down-left
A / Left  -> WEST  (-X)  up-left         D /Right -> EAST  (+X)  down-right
```

Every press advances exactly one 1 m cell along a grid line. Diagonals are *not*
available, because a diagonal step would be 1.41 m and break the spatial contract.
Tab toggles High-Focus/Crash (dev stub), G toggles the cell overlay.

## File map

```
Game/
  project.godot                       input actions deliberately absent (see below)
  scenes/Main.tscn                    4 lines: Node3D + GameBootstrap
  src/data/        workspace_grid_data.gd      cell<->world, bounds, facings, edge maths
                   movement_profile_data.gd     one state's tunables
                   workspace_movement_data.gd   the HIGH_FOCUS / CRASH table
                   input_action_data.gd         key map + runtime registration
  src/logic/       grid_mover.gd                discrete cell state, one step in flight
                   turn_controller.gd           facing + commit latency
                   perception_director.gd       STUB: state + 0..1 intensities
                   soft_boundary_model.gd       0..1 proximity
  src/player/      player_controller.gd         the only node that reads Input
  src/presentation/ iso_camera_rig.gd            fixed rig, follow, tremor shake
                   player_view.gd                interpolation, footstep arc, rotation
                   workspace_blockout.gd         greybox room, non-colliding
                   grid_overlay.gd               @tool 1 m lattice
                   soft_boundary_presentation.gd fog/light response
                   perception_post_fx.gd          uniform push
                   dev_hud.gd                     readout
  assets/shaders/perception_post.gdshader  CA + blur + focus edges + vignette + grain
```

Dependency rule enforced throughout: data references nothing; logic references data only;
presentation references logic read-only; `player_controller` + `game_bootstrap` are the
only join points.

## Verification status — read this before trusting the ticket

**Verified**

- `gdparse` (gdtoolkit 4.5.0) — all 13 `.gd` files parse clean.
- `gdlint` — `Success: no problems found` (100-char lines, naming, unused-arg rules).

**Not verified — there is no Godot binary on this machine and no GDScript runtime was
executed.** Specifically unproven:

1. The scene actually boots. `scenes/Main.tscn`, `project.godot` and the `.gdshader`
   compile path were written by hand and have never been loaded by an engine.
2. Shader correctness. The GLSL is plausible and deliberately array-free, but Godot's
   shading-language validator has never seen it. Expect at most a line-numbered error to
   fix on first open.
3. Feel. Every number in `workspace_movement_data.gd` is a guess. The Crash/High-Focus
   ratio is where the whole game's physicality lives and it needs a human on a keyboard.
4. Volumetric fog is Forward+/Mobile only; on the Compatibility backend it is inert and
   the soft boundary degrades to plain fog + vignette (still satisfies the constraint).
5. No automated tests exist yet. `GridMover`, `TurnController`, `SoftBoundaryModel` and
   `WorkspaceGridData` are `RefCounted`/`Resource` with zero `Node` dependencies, so they
   are testable as-is — this ticket should be followed by a gdUnit4 or GUT pass over
   exactly those four, and I have not written it.

## Deliberate gaps

- **`config/features` is absent** from `project.godot` — Godot writes it on first save with
  whichever 4.x minor gets installed, instead of inheriting a guess from me.
- **Input actions are registered at runtime**, not serialised into `project.godot`.
  Tradeoff: rebinding via the editor Settings dialog is unavailable until an options menu
  exists.
- **Blockout furniture is not interactive and not solid.** Walking through the bench and
  the cot is expected; Ticket-03 owns the spatial asset grid that gives furniture
  occupancy and interaction ranges.
- **No `.tres` assets.** Tunables live in `_init()` so they can be read and diffed as code.
  Migrate to `.tres` once the numbers stop moving daily.
- **Nothing editable in the 3D viewport.** Until the bootstrap tree is migrated into scene
  files, level authoring means editing `WorkspaceGridData` fields.
- **`@tool` grid overlay** renders in the editor viewport. If it ever fights the editor
  after a scene-file migration, delete `GridOverlay` rather than working around it — it is
  a dev aid.

## How Ticket-02 plugs in (the reason the seam exists)

`PerceptionDirector` is the only class Ticket-02 replaces. It owns three things other
systems already consume: `state()` (profile selection), `crash_intensity()` (shake,
chromatic aberration, blur, grain) and `focus_intensity()` (edge-detect/contrast). Adding
the Sensory Overload meter, the crafting-speed multiplier and the self-soothing gate is
internal to that class; `PlayerController`, `IsoCameraRig` and `PerceptionPostFX` should
not change. If Ticket-02 requires editing any of them, the seam was drawn wrong and is
worth fixing before the meter is.
