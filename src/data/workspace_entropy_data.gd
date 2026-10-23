class_name WorkspaceEntropyData
extends Resource
## DATA LAYER — the apartment's Entropy (clutter) meter.
##
## Ticket-02 "Workspace Degradation": the leased room passively generates clutter over
## time — dishes stacking, papers drifting, shadows deepening. The narrative point is
## that the workspace is never neutral ground: it degrades whether the protagonist
## engages with it or not, and that degradation pressures the nervous system.
##
## MODEL
## -----
##   entropy (0..100)  how cluttered the room currently is
##   growth_rate       entropy added per second, constant (the room decays whether or
##                     not the player is present — it does not pause when ignored)
##   overload_feed_ratio  fraction of CURRENT entropy added to sensory_overload each
##                     second by WorkspaceEntropy.advance()
##
## The feed is "fraction of current entropy" rather than flat, so a tidy room pressures
## almost nothing while a hoarded room presses hard — the clutter compounds its own
## cost. Because it scales off current entropy, it stays a bounded curve instead of
## linearly racing to 100.
##
## This resource is pure data + a signal. WorkspaceEntropy (logic layer) owns the growth
## math; PlayerStateMachine pulls the per-frame overload contribution and feeds it into
## PlayerStateData.apply_overload_pressure().

## Emitted whenever the entropy value moves after a growth tick.
signal entropy_changed(new_entropy: float)

## The first cycle's per-second growth (later cycles and the co-sign multiply it).
const BASE_GROWTH_RATE := 0.05

## 0..100 — how cluttered the room currently is. 0 = freshly leased, 100 = hoarded.
@export var entropy: float = 0.0

## Entropy gained per second. Constant: the room does not wait for the player.
## Retuned for the days (full-run playtest 2026-10-23): at the old 0.5/s the room hit
## the betrayal threshold (70) on Day 1 and sat at 100 through Act I. Now a slow clock
## (~9 points over a ~3-minute day) plus the overnight step below: the threshold lands
## around day 5, after the friend's favours and the borrowed painting.
@export var entropy_growth_rate: float = BASE_GROWTH_RATE

## Each morning the room starts this much more decayed (STORY: "Morning. The room is a
## little more decayed."), scaled by how fast it is decaying now (co-sign, later cycles).
@export var morning_decay: float = 8.0

## Fraction of current entropy added to sensory_overload per second.
## At entropy 60 this feeds 60 * 0.05 = 3.0/s — exactly canceling PlayerStateData's
## High-Focus decay (3.0/s), which is the designed tipping point: an unmanaged room
## eventually out-pressures even a medicated player. All values are first-pass guesses.
@export var overload_feed_ratio: float = 0.05


## Reset to a tidy room. Used at scene start and by Ticket-05's dreamscape transition.
func reset() -> void:
	entropy = 0.0
	entropy_changed.emit(entropy)


## Overnight: the room starts the day a little more decayed.
func decay_overnight() -> void:
	var step := morning_decay * entropy_growth_rate / BASE_GROWTH_RATE
	entropy = clampf(entropy + step, 0.0, 100.0)
	entropy_changed.emit(entropy)
