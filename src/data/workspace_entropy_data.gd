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

## 0..100 — how cluttered the room currently is. 0 = freshly leased, 100 = hoarded.
@export var entropy: float = 0.0

## Entropy gained per second. Constant: the room does not wait for the player.
## 0.5/s means the room reaches ~30/100 after a minute and ~60/100 after two.
@export var entropy_growth_rate: float = 0.5

## Fraction of current entropy added to sensory_overload per second.
## At entropy 60 this feeds 60 * 0.05 = 3.0/s — exactly canceling PlayerStateData's
## High-Focus decay (3.0/s), which is the designed tipping point: an unmanaged room
## eventually out-pressures even a medicated player. All values are first-pass guesses.
@export var overload_feed_ratio: float = 0.05


## Reset to a tidy room. Used at scene start and by Ticket-05's dreamscape transition.
func reset() -> void:
	entropy = 0.0
	entropy_changed.emit(entropy)