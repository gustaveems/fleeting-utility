# Ticket-02 — Chemical Focus & Workspace Degradation

Scope: the Chemical Cycle gets its third band (High-Focus), the chemical-zero cliff, and
a new passive pressure system (Workspace Entropy). No input, camera, or presentation
pipeline changes. Everything downstream reads `sensory_overload` exactly as before.

## State derivation (locked with Alain 2026-10-10)

| State | Condition | Gameplay meaning |
|---|---|---|
| High-Focus | `chemical_level > 0.7` AND not crashed | clear vision, fast interactions (consumer: Ticket-03 crafting speed) |
| Medicated drift | otherwise, chemical ≥ 0.3 | overload decays at 3.0/s — the drug soothes |
| Unmedicated | chemical < 0.3 | overload accumulates at 8.0/s |
| Fully withdrawn | chemical == 0.0 | overload floods at 40.0/s → Crash in ~1.25 s |
| **Crash** | `sensory_overload >= 50.0` (sole trigger) | existing FX/camera pipeline activates |

The locked decision: chemical == 0.0 does **not** force Crash directly. It guarantees it
by flooding the overload meter. Rationale: one crash authority (the overload meter) keeps
`is_crashed()` and every consumer truthful; the drug's absence is felt as fast-rising
overload rather than a new boolean branch in five places.

## The tuning math (all first-pass guesses, flagged for playtest)

```
High-Focus steady state:    overload += (entropy_feed − 3.0) * dt
Unmedicated:                overload += (entropy_feed + 8.0) * dt
Withdrawn:                  overload += (entropy_feed + 40.0) * dt
entropy_feed = entropy * overload_feed_ratio           (0.05 default)
```

- **The tipping point is designed**: at entropy = 60, feed = 3.0/s, exactly cancelling
  High-Focus decay. Above 60 the room out-pressures a medicated player; below, a tidy
  room buys indefinite calm. "An unmanaged room always crashes you eventually."
- Entropy reaches 60 after ~2 minutes idle (0.5/s growth). Session-length pacing guess.
- Chemical 1.0 → 0.3 takes 35 s at 0.02/s, then the cliff is 3.75 s to zero. The drug
  is a timer with a warning stage, not a death spiral.

## Files

```
src/data/player_state_data.gd          +high_focus_threshold, chemical_zero_accumulation_rate
                                       +is_high_focus(), apply_overload_pressure()
                                       three-band update_overload()
src/data/workspace_entropy_data.gd     NEW — entropy meter (Resource)
src/logic/workspace_entropy.gd        NEW — growth + feed derivation (RefCounted)
src/logic/player_state_machine.gd      +entropy_data export, frame-order integration
src/presentation/dev_hud.gd            +chem/focus/entropy readout (optional bind)
src/bootstrap/game_bootstrap.gd        +entropy wiring, hud bind_state_machine()
```

Frame order in `PlayerStateMachine._process()` (matters): entropy pressure →
`apply_overload_pressure()` → `update_overload()`. Both meters agree within one frame;
a frame never discards entropy pressure by applying it after the accumulation step.

## Verification status

**Verified**

- `gdparse` + `gdlint`: all 25 `.gd` files parse, `Success: no problems found`.

**Not verified — no Godot binary on this machine, nothing executed.** Especially:

1. The 40.0/s withdrawal cliff number (only reachable via debug — no way to consume
   chemical yet; Ticket-03's crafting/consumable is what makes depletion meaningful).
2. The entropy tipping-point balance. The 0.05 feed ratio and 0.5/s growth are guesses
   from reading, not from watching the room fill. Tune live in the DevHud readout.
3. `is_high_focus()` has no consumer yet — it exists so Ticket-03 can gate interaction
   speed without touching the meter model. Unused code until then (deliberate seam).

## Deliberate gaps

- **No way to ingest chemical** (no consumable, no bench) — `apply_chemical_change()`
  exists but nothing calls it with a positive amount. The cycle is currently a one-way
  countdown until Ticket-03.
- **Self-soothing** (the brief's compulsion loop) is not here — Ticket-03's bench
  interaction is the natural home for "reduces overload, at a cost".
- **Entropy has no visual** — the room does not yet *look* cluttered, so degradation is
  HUD-only until Ticket-04 (visible clutter/ransacking hooks).
- **DevHud focus column** reads `is_high_focus()`; the Tab toggle still drives
  `PerceptionDirector` (the Ticket-01 layered pipeline), which is separate from these
  meters. In the Task-1-4 pipeline (workspace.tscn) there is no Tab toggle at all — the
  crash drives itself from the meters.