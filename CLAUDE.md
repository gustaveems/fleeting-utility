# Fleeting Utility — agent guide

Narrative immersive sim, Godot 4.7 (GDScript 2.0), fixed angled isometric 2.5D.
Narrative: `MASTER_BRIEF.md`. Mechanics: `GAME_SPEC.md`. Roadmap and plan: `docs/`.

## Commands
```bash
godot --headless --import                       # Import Gate: after ANY new/renamed class_name
tools/run_all.sh                                # lint + format check + every verify/probe (exit≠0 on fail)
godot --headless --path . -s tools/<name>.gd    # one verify script
godot --path . -s tools/capture_states.gd       # windowed: PNG per lighting state → tools/out/
.venv/bin/gdformat src tools                    # format (gdtoolkit 4 lives in .venv/)
```
`.venv` missing → `python3 -m venv .venv && .venv/bin/pip install 'gdtoolkit==4.*'`.

## Ironclad rules
1. **Import Gate.** A new or renamed `class_name` is invisible until `godot --headless --import` runs. Say so whenever you add one.
2. **Hidden ≠ gone.** `visible = false` leaves child `CollisionShape3D`s in physics, Area3Ds monitoring, and `_process` / audio / particles running. Deactivating a world must disable shapes and set `process_mode`. Restoring must NOT blanket-enable shapes that gameplay disabled on purpose.
3. **No string node paths** in `src/` (`get_node("A/B")`, `$A`, `find_child("x")`). Use `@export` refs or refs handed over by the bootstrap. Test scripts in `tools/` may use paths via the harness `node()`.
4. **Verified APIs only.** No invented properties (e.g. `tonemap_exposure`, not `exposure_multiplier`; shaders use `uniform sampler2D screen_texture : hint_screen_texture;`). Godot 4 `Decal` projects along local −Y. Unsure? Use the harness `check_property_exists()`.
5. **Lint clean.** `gdlint` and `gdformat --check` must pass (`gdlintrc`). Member order: signals → enums → consts → static vars → @export → public vars → private vars → @onready.

## Architecture
- `src/data` Resources · `src/logic` state machines/controllers · `src/presentation` visuals/audio/UI · `src/player` movement/camera · `src/bootstrap` composition root.
- `scenes/workspace.tscn` is one Node3D running `workspace_bootstrap.gd`, which builds and wires **everything in code**. There are no authored sub-scenes.
- **Movement is free-roam everywhere** (velocity, `move_and_slide`). Grid-snapped stepping was rejected after playtesting (2026-10-11). The grid survives only as data (bench worktop, clutter spawn points). The old grid pipeline (`Main.tscn`, `GameBootstrap`, `GridMover`…) was deleted. `assets/shaders/_salvage/perception_post.gdshader` is kept as T11 input.
- Logic scripts emit signals and never own audio/VFX nodes. Presentation listens.
- Soft boundaries (vignette/fog), never invisible walls.

## Testing
- Every verify script extends `tools/lib/verify_harness.gd` and overrides `_run()` and `_title()`. Use `check()`, `wait()`, `tap_action()`, `live_shapes()`, `ray_hits()`, `capture()`.
- Headless: the script IS the tree (no `get_tree()`), `_process` is unthrottled, so time with `wait()`, never frame counts.
- Write the failing check first (red), then fix.
- `tools/probe_world_isolation.gd` is the regression gate for rule 2 and interactable detection.
