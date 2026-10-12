# Fleeting Utility — Fix + Roadmap Convergence Plan

## Context
T01–T09 are mechanically complete, but T07–T09 are uncommitted. An audit found correctness bugs, several of them invisible to the current verify scripts:
- **Interactables are dead.** The player stays on the default layer 1, but every interactable (door, shoes, park door, trivial object) masks only layer 2.
- **HUD wiring order.** `core_hud` copies its refs in `_ready` before `interaction_controller`/`endgame` exist (`workspace_bootstrap.gd:350,385`). As a result, the prompt and the loop flavor text never show.
- **Collision restore bugs.** The blanket "re-enable all shapes" in `dual_vision_controller`, `dreamscape_manager` and `corporate_park_manager` resurrects colliders that `ransacked_state_manager`/`ambulance_interception` disabled. `endgame_loop_manager:122` hides the bench and grid without disabling them. The hidden park ReturnDoor stays live at the origin.
- **Atmosphere bleed.** `AtmosphereController` keeps writing apartment fog/colour into the valley and park Environments while the apartment is hidden.
- **Lock ownership.** About 6 writers share `input_locked`/`is_locked` with no owner (e.g. `self_soothing_controller:114` undoes the post-climax lock). One-shot flags (`_loop_armed`, `_hesitated_in_this_cycle`) never reset.
- **Decals.** `surface_degradation` projects along the wrong axis (Godot 4 decals project along −Y) and reshuffles every frame.
- **Hygiene.**
  - No `.gitignore` (`.godot/` caches and `.qwen/tmp` PNGs are tracked).
  - gdtoolkit not installed, so rule 5 is unenforceable.
  - No shared test harness; T05/T06 verify scripts always exit 0.
  - A dead legacy T01 pipeline remains.

**Key insight:** most fixes are the same work T10–T13 need anyway. 25 emitted-but-unconnected signals are exactly T10's audio hooks. A "world activation" helper fixes the collision/atmosphere bugs and is where T10 ambient beds and T11 particles attach. A central game-phase model fixes the lock and re-arm bugs and is what T12 serializes and T13 boots into. So the work is ordered as **spine first, features on the spine**, and no system gets built twice.

User decisions: commit T07–T09 first; procedural placeholder assets; long-term (architecture over speed); delete legacy pipeline but salvage its shader; split bootstrap into code modules (not .tscn).

---

## Phase 0 — Baseline & hygiene (no behaviour change)
1. Add a `.gitignore` covering `.godot/`, `.qwen/tmp/`, `*.import` caches and `user://` exports. Run `git rm --cached` on the tracked `.godot/*` and `.qwen/tmp/*`.
2. Commit T07, T08 and T09 as separate commits by file group (T07: core_hud/hud_ui/endgame/atmosphere ACES; T08: self_soothing/park/ransacked/shoes/trivial/door; T09: hesitation/dual_vision/statue). Run `godot --headless --import` first to generate the missing `ticket09_verify.gd.uid`.
3. Tooling:
   - `pip install gdtoolkit` (4.x), add `gdlintrc` (class-definitions-order matching the canonical order) and run `gdformat --check` + `gdlint` on `src/`.
   - Add `CLAUDE.md` with the Ironclad Rules, the run/verify commands and the Import Gate (use `/writing-for-agents`).
4. **Shared test harness:**
   - Create `tools/lib/verify_harness.gd` (base `extends SceneTree`): scene load, `check()`, pass/fail counts, `quit(1)` on failure, `tap_action()`, and `capture()`. Migrate `ticket05`–`ticket09_verify` to it.
   - Fold the overlapping probes (`ticket08_reach/tree_dump`, `invisible_walls_probe`) into one `tools/probe_world_isolation.gd`.
   - Delete the one-offs (`enum_probe`, `ticket07_prop_probe` keeps its idea as a harness `assert_property_exists`).
   - Replace the three capture autoloads with one harness capture mode.
   - Add `tools/run_all.sh` → baseline report (expect current failures to be documented, not fixed, here).
5. **Delete the legacy pipeline.**
   - Remove `scenes/Main.tscn` and `game_bootstrap.gd`, plus its exclusive dependencies. Grep each before deleting: `player_controller`, `grid_mover`, `turn_controller`, `perception_director`, `iso_camera_rig`, `perception_post_fx`, `player_view`, `dev_hud`, `grid_overlay`, `soft_boundary_model`, `soft_boundary_presentation`.
   - Move `perception_post.gdshader` to `assets/shaders/_salvage/` for T11.

## Phase 1 — The Spine (refactor ticket "T09.5", fixes the systemic bugs)
Each item fixes current bugs and is a direct prerequisite of a roadmap ticket.

**1a. `WorldRoot` (`src/presentation/world_root.gd`, class_name).** Wraps the Apartment / Valley / Park roots. `set_active(bool)` does the following:
- toggles `visible`;
- sets `process_mode` (DISABLED when inactive), which stops AtmosphereController bleed, decal/clutter updates and future particles/audio under it;
- disables `CollisionShape3D` nodes and Area3D `monitoring`.

It **remembers each shape's prior disabled state** and restores it, and does not force-enable. There is also `set_flash_visible(bool)` for Dual Visions: visual-only with collisions held off. It replaces the 4 copied toggle loops in `dreamscape_manager:325`, `corporate_park_manager:257`, `dual_vision_controller:95`, `ransacked_state_manager:91` and `memory_anchor:79`. Gameplay disables (ransack, ambulance anchors, endgame bench/grid) go through `WorldRoot.disable_permanently(node)` so restores respect them.
→ *Future reuse:* T10 ambient beds and T11 particles are children of a WorldRoot, so they pause and resume for free. T12 saves `active_world`.

**1b. `GameFlow` (`src/logic/game_flow.gd`, class_name) + `GamePhase` enum.**
- Phases: `WORKSPACE, DREAMSCAPE, INTERCEPTION, CLINICAL, SUBDUED_LOOP, PARK_WALK, RANSACKED, HESITATION, DUAL_VISION`.
- One signal: `phase_changed(from, to)`.
- Existing managers call `game_flow.request_phase()` and do not set each other's flags.
- It owns the **lock-token API** `acquire_lock(owner: StringName)` / `release_lock(owner)`. `player.input_locked` and `interaction_controller.is_locked` become derived ("any token held"), which fixes `self_soothing` unlocking the post-climax lock.
- It handles the double `forced_return_completed` handler and re-arms `_loop_armed` / `_hesitated_in_this_cycle` on phase entry.

→ *Future reuse:* T10 AudioDirector keys soundscapes off `phase_changed` (it replaces the separate `fluorescent_hum_started`/`cold_draft_started` placeholders, and AtmosphereController.Mode is derived from phase). T12 serializes `GameFlow.snapshot()`. T13 boot enters `WORKSPACE` via GameFlow.

**1c. Split the bootstrap.**
- `workspace_bootstrap.gd` becomes a thin composer that calls `src/bootstrap/modules/{apartment,valley,park,systems,narrative,ui}_module.gd` (plain `RefCounted` builders; no class_name needed except where typed). Each module has `build(ctx)` and `wire(ctx)`.
- The composer runs **all `build` before any `wire`**, which fixes the HUD ordering bug structurally. `CoreHud` forwards refs in a `wire()` call rather than `_ready`.
- `ctx` is a typed `BootstrapContext` holding node refs, which replaces the `"Statue_%d"` string lookup (`workspace_bootstrap:452`). `DreamscapeEnvironment` exposes `statues: Array[Node3D]`.

→ *Future reuse:* T10 adds `audio_module.gd`, T11 `vfx_module.gd`, T12 `persistence_module.gd`. T13's menu scene instantiates the game composer.

**1d. `Interactable` base (`src/presentation/interactable.gd`, class_name, extends Area3D).**
- Proximity + `[E]` + prompt text, wired through InteractionController with `target_detected`/`target_lost`.
- Define physics layers in one place, `src/data/physics_layers.gd` (consts: PLAYER=2, INTERACTABLE=4, WORLD=1). Set the player's `collision_layer` to `PLAYER` and add named layers in `project.godot`. **This fixes the dead-interactables bug.**
- Port `apartment_door`, `luxury_shoes`, `trivial_object`, park ReturnDoor and the dreamscape return/anchor input polling to it.

→ *Future reuse:* T10 interact/deny sounds hook one signal. T13 prompt glyphs and rebinding live in one place.

## Phase 2 — Local correctness fixes (small, surgical; batch into one ticket)
- `hud_ui.gd:141`: use `offset_*`, not `position.y`, after the anchor preset (the HUD file is reopened in T13 for colourblind meters).
- `player_movement.gd:116-148`: replace `find_child("...")` with typed refs assigned by the player builder. Remove the fake `@onready` in `player_movement:100` and `crafting_bench:78`.
- `statue_narrative.gd`: change it from `Area3D` to `Node3D`. `dual_vision_controller:88`: rename the `visible` param.
- `input_action_data.gd:54,56`: fix the TAB double-bind (move `dev_dump_overload` to F-key, dev-only).
- Null guards at `screen_effects:284`, `dreamscape_hud:69` and `corporate_park_manager:101,125,248`.
- `surface_degradation.gd`: move `static var` below the exports; orient decals along −Y; only re-sync when the clutter **tier** changes, not every `entropy_changed`. *(The decal work is also the T11 "surface" polish item, so do it once here.)*
- `post_climax` writes (`lucid_cap`, `withdrawal_shake`) move into a GameFlow phase-entry handler so the endgame/hesitation stop clobbering them.

## Phase 3 — Roadmap tickets on the spine
**T10 Audio**
- `default_bus_layout.tres`: `Master → Music/Ambience/SFX/UI`. Master has LowPass + Distortion driven by `crash_intensity`.
- `SoundCue` / `SoundscapeProfile` resources (`src/data/`).
- `AudioDirector` (`src/presentation/`): connects the 25 orphan signals plus `phase_changed`. It owns the pool and the crossfading world beds. `RhythmicCuePlayer` for self-soothing/hesitation.
- `ProceduralTone` generator extracted from `ambulance_interception.gd:179-202` (siren, hum, rumble, thump). The siren player moves out of the ambulance into AudioDirector.
- Spatial `AudioStreamPlayer3D` nodes live under WorldRoots (auto-paused).

**T11 Visual polish**
- Merge `screen_effects` (layer 4) and the `soft_boundary_controller` vignette (layer 6) into one post-FX pass, or insert a `BackBufferCopy`.
- Wire the dead `shake_offset` uniform; stop moving the CanvasLayer offset.
- Fold in the salvaged `perception_post.gdshader` features (focus edges, grain).
- Add an `intensity_scale` uniform per effect, which T13's reduce-motion/accessibility needs.
- `GPUParticles3D`: dust under the Apartment WorldRoot and leaves under the Valley WorldRoot, built in `vfx_module`.
- SSR on the clinical Environment (`ssr_enabled`, verified via the property-exists harness check).

**T12 Save/Load**
- `src/logic/persistence.gd`: `FileAccess` + `JSON` to `user://save.json`, with versioned schema (`"version": 1`).
- Snapshot = `GameFlow.snapshot()` + `PlayerStateData` runtime fields (`chemical_level`, `sensory_overload`) + `WorkspaceEntropyData` (`entropy`, `entropy_growth_rate`) + loop scars (rate multiplier applied, ransacked, realized, cycle count) + `SpatialGrid.grid_cells`.
- **Seed RNG** for ransack debris and decals (one `RandomNumberGenerator` seed per cycle, saved) so restored state reproduces.
- Also add `src/logic/settings_store.gd` (ConfigFile, `user://settings.cfg`) now, because T13 consumes it.

**T13 Menu / settings / accessibility**
- Boot scene `scenes/boot.tscn` → menu → instantiates the game composer.
- Volume sliders map 1:1 to T10 buses.
- Colourblind/high-contrast meter palettes in `hud_ui` (patterns, not colour alone).
- Reduce-motion/shake/CA sliders drive the T11 `intensity_scale` uniforms.
- Everything is persisted via `settings_store`.

**Parallelism:** after Phase 1, T10 and T11 touch disjoint modules and can run in parallel worktrees. In T12, `settings_store` must land before T13.

---

## Workflow & skills (per ticket)
Your Matt Pocock skills are installed in `~/.agents/skills`. Most are user-invoked only (`disable-model-invocation`), so **you** run these slash commands:
- `/setup-matt-pocock-skills`, once. Configure the tracker as local `docs/tickets/` files (matching existing `docs/TICKET-0x.md`).
- `/domain-modeling` (or `/grill-with-docs`) to write `GLOSSARY.md`: Phase, World, Scarred Reset, Lock Token, Soundscape, Cue. Record ADRs for WorldRoot, GameFlow and the code-module bootstrap.
- Per ticket: `/grilling` → `/to-spec` → `/to-tickets` → `/implement-spec`. Use `/tdd` to write the harness verify script first: red, then green.
- `/improve-codebase-architecture` before Phase 1, to sanity-check the WorldRoot/GameFlow seams.
- `/safe-refactor` for 1c (bootstrap split), with the verify suite bracketing each step.
- `/diagnosing-bugs` if any Phase-2 fix regresses physics.
- `/code-review` at each ticket end against CLAUDE.md (Ironclad Rules) + spec. `/git-guardrails-claude-code` to block `git reset --hard`/`clean` on an asset-heavy repo.
- `/research` for verifying Godot 4.7 APIs before use (AudioEffect, SSR, GPUParticles3D props); it complements the harness `assert_property_exists`.
- `/handoff` at the end of each phase for session continuity.

Skip `setup-pre-commit` (Husky/JS-specific). Instead, a plain `.git/hooks/pre-commit` running `gdlint src/ && gdformat --check src/`.

## Verification
- **Import Gate:** run `godot --headless --import` after Phase 0 and after any phase adding class_names (WorldRoot, GameFlow, Interactable, BootstrapContext, SoundCue, SoundscapeProfile, AudioDirector, RhythmicCuePlayer, Persistence, SettingsStore).
- **Every phase:** `tools/run_all.sh` (all verify scripts exit non-zero on fail) + `gdlint src/` + `gdformat --check src/`.
- **New checks added in Phase 1/2, red before the fix:**
  - The player triggers door/shoes `body_entered` via physics.
  - The HUD prompt shows on `target_detected`.
  - After ransack, a Dual Vision cycle leaves bench colliders disabled.
  - The valley Environment fog is unchanged while in the dream.
  - A self-soothing end does not release the climax lock.
  - Decal transforms are stable across frames at constant tier.
- **Manual playthrough** (`godot --path .`): T01→T09 arc end-to-end, then confirm interactables work and the HUD prompt and flavor text appear.
- **T10–T13:** each gets its own harness verify (e.g. a signal fires → expected player `playing` on expected bus; save→quit→load round-trip equality of the snapshot dict).

---

## Baseline after Phase 0 (2026-10-12)
`tools/run_all.sh`: lint+format PASS. Failing checks are pre-existing bugs, kept red on purpose:

| Script | Fails | Cause / owner |
|---|---|---|
| probe_world_isolation | 9 | player layer 1 vs interactable mask 2 (1d); hidden park ReturnDoor live (1a); ApartmentDoor at z=-3.5 outside clamp (1d); atmosphere writes valley Environment (1a); Dual Vision re-enables ransacked bench (1a) |
| ticket07_verify | 8 | HUD refs copied in `_ready` before controllers exist (1c); endgame hides bench without disabling collision (1a); interaction lock released (1b) |
| ticket05_verify | 1 | "D anchor returned": E via parse_input_event does not trigger anchor return. Uninvestigated, likely input polling (1d) |
| ticket06_verify | 1 | "key light shadowless": T07 clinical lighting re-enabled shadows. Check intent vs test (Phase 2) |
| ticket08_task1_verify | 1 | soothe −10 measured as −5.6: overload keeps accumulating during the wait. Test tolerance or design (Phase 2) |
