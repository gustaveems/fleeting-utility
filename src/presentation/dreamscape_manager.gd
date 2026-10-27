class_name DreamscapeManager
extends Node
## LOGIC/PRESENTATION GLUE — the Crash-state collapse into the autumn valley (Ticket-05).
##
## STATE MACHINE
## -------------
##   APARTMENT --(collapse signal / dev key)--> fade-to-white --> VALLEY
##   VALLEY --(30 s timer OR E at a statue)--> fade-to-white --> APARTMENT
##
## The fade is a white ColorRect on a dedicated CanvasLayer (layer 30, above post-FX at
## 4 and the vignette at 6): 1.5 s out, 0.5 s hold in white, 1.5 s in. During both fades
## PlayerMovement.input_locked is true — input dies but momentum decays, so the body
## glides to a stop instead of freezing mid-stride.
##
## WORLD SWAP
## ----------
## One WorldEnvironment node, two Environment resources: the manager swaps the node's
## `environment` property between the apartment's and the valley's. Godot's behaviour
## with multiple WorldEnvironment nodes per viewport is not something we want to depend
## on; a property swap is unambiguous and costs nothing.
##
## The apartment subtree (lights, blockout, clutter, decals, atmosphere, bench) is
## hidden, not freed — entropy, meters and placed items all survive the dream. The
## player and camera never move between worlds: the valley is simply a bigger space
## around the same controller, with room_half_extents widened for the trip.
##
## METER BOOKKEEPING lives in PlayerStateMachine (on_dreamscape_entered/returned):
## entering drops overload to 0 (the dream is serene, and it disarms the collapse
## trigger), returning sets it to post_dreamscape_overload (lucid, unmedicated, crashed
## again — the brief's violent revival).

## --- SIGNALS -------------------------------------------------------------------------

## Emitted when a transition INTO the dreamscape begins (spec requirement).
signal transition_started

## Emitted when a transition back to the apartment begins.
signal return_started

## Emitted when either fade sequence finishes. Payload: true if now in the dreamscape.
signal transition_completed(now_in_dreamscape: bool)

## Emitted when the violent forced return (Ticket-06) finishes its hard flash. The
## clinical post-climax state keys off this, not off transition_completed.
signal forced_return_completed

## Emitted each second during the dreamscape with the auto-return timer remaining.
signal timer_updated(seconds_remaining: float)

## The ending without Care (Ticket-23): no one came. The slow fade to black begins…
signal quiet_return_started
## …and he has woken on his own, in the room. Like forced_return_completed, it precedes
## transition_completed(false).
signal quiet_return_completed
## Emitted under the white, the moment the worlds swap (a scripted dream can move him).
signal worlds_swapped(to_dreamscape: bool)
## Emitted when the player enters/leaves a memory anchor zone.
signal anchor_proximity_changed(near: bool)

## --- REFERENCES (spec requirement #1) --------------------------------------------------

@export var workspace_root: WorldRoot
@export var dreamscape_root: WorldRoot
@export var world_environment: WorldEnvironment
@export var apartment_environment: Environment
@export var valley_environment: Environment
@export var player: PlayerMovement
@export var state_machine: PlayerStateMachine

## The shared iso camera. Its far plane is tuned tight (45 m) for the apartment to keep
## volumetric fog cheap; the valley needs 150 m or the terrain edge clips mid-frame.
@export var camera: WorkspaceCamera

## Ticket-06: the interaction lock gate. When locked, E-key returns are disabled.
@export var interaction_controller: InteractionController
## Ticket-20: "[E] Remember" reaches for the meaning, and loses it, before the flash home.
@export var dream_memory: DreamMemory

## --- TIMING (spec: 1.5 out / 0.5 hold / 1.5 in) ----------------------------------------

@export var fade_out_seconds: float = 1.5
@export var fade_hold_seconds: float = 0.5
@export var fade_in_seconds: float = 1.5

## Spec requirement #4: auto-return after 30 s in the valley.
@export var auto_return_seconds: float = 30.0

## The valley is open country: widen the movement clamp for the trip.
@export var dreamscape_room_extents: Vector2 = Vector2(28.0, 28.0)

## --- INTERNAL STATE --------------------------------------------------------------------

## True when the most recent return was the violent forced return (Ticket-06), false
## after any smooth return or a fresh dream entry. Post-climax systems read this.
var is_forced_return: bool = false

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _auto_return_timer: Timer
var _in_dreamscape: bool = false
var _transitioning: bool = false
var _near_statue: bool = false
var _near_anchor: MemoryAnchor = null
var _reaching: bool = false
var _apartment_extents: Vector2

## Last whole-second value pushed to timer_updated, so the HUD gets one signal per
## tick instead of one per frame.
var _last_timer_second: int = -1

## ----- LIFECYCLE ------------------------------------------------------------------------


func _ready() -> void:
	_build_fade_layer()
	_auto_return_timer = Timer.new()
	_auto_return_timer.name = "AutoReturnTimer"
	_auto_return_timer.one_shot = true
	_auto_return_timer.wait_time = auto_return_seconds
	_auto_return_timer.timeout.connect(return_to_workspace)
	_auto_return_timer.timeout.connect(func(): timer_updated.emit(0.0))
	add_child(_auto_return_timer)

	if state_machine != null:
		# Guarded: GameBootstrap used to wire this too, which double-connected the
		# signal (engine error). The manager owns its trigger wiring; the bootstrap
		# only wires what the manager cannot see (statue proximity, references).
		if not state_machine.dreamscape_transition_requested.is_connected(transition_to_dreamscape):
			state_machine.dreamscape_transition_requested.connect(transition_to_dreamscape)

	# Sanity: the valley starts dormant (its own _ready deactivates it), but the manager
	# asserts the apartment side too so a mis-wired export cannot start the game inside
	# the dream.
	if workspace_root != null and not workspace_root.is_active:
		workspace_root.set_active(true)
	if dreamscape_root != null and dreamscape_root.is_active:
		dreamscape_root.set_active(false)


func _build_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "DreamFade"
	_fade_layer.layer = 30  # above post-FX (4) and vignette (6): white-out wins
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


func _process(_delta: float) -> void:
	if _transitioning:
		return
	# Countdown feed: emit once per whole second while the auto-return timer runs.
	# The timeout signal alone only fires at 0.0 — the HUD would otherwise show nothing
	# until the dream ended (the gap flagged in the Ticket-05 guide, 4.4).
	if _in_dreamscape:
		var remaining := int(ceilf(_auto_return_timer.time_left))
		if remaining != _last_timer_second:
			_last_timer_second = remaining
			timer_updated.emit(float(remaining))
	# Dev shortcut: force the collapse without waiting out the meters.
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_DREAMSCAPE):
		if _in_dreamscape:
			return_to_workspace()
		else:
			transition_to_dreamscape()
		return
	# Manual return: standing in a statue zone and pressing E.
	if _in_dreamscape and _near_statue:
		if Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
			if interaction_controller == null or interaction_controller.try_interact():
				return_to_workspace()
	# Memory anchor return: standing near an anchor and pressing E. The anchor's own
	# memory_triggered signal fires first so lore/audio listeners have the hook the
	# guide flagged as decorative (4.5) — it was declared but never emitted.
	if _in_dreamscape and _near_anchor != null and not _reaching:
		if Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
			if interaction_controller == null or interaction_controller.try_interact():
				_remember(_near_anchor)


## ----- PUBLIC API -----------------------------------------------------------------------


## An anchor's memory: he reaches for it (and loses it), then the flash home. The
## countdown pauses while he reaches; a timeout can't cut the sentence off.
func _remember(anchor: MemoryAnchor) -> void:
	anchor.memory_triggered.emit()
	if dream_memory != null:
		_reaching = true
		_lock_player(true)
		_auto_return_timer.paused = true
		await dream_memory.reach()
		_auto_return_timer.paused = false
		_lock_player(false)
		_reaching = false
	if not _in_dreamscape:
		return
	trigger_memory_flash()
	return_to_workspace()


## Called by DreamscapeEnvironment.statue_proximity_changed via bootstrap wiring.
func set_statue_proximity(near: bool) -> void:
	_near_statue = near
	# Ticket-07: feed the interaction prompt when near a statue (manual return).
	if interaction_controller != null:
		if near and _in_dreamscape:
			interaction_controller.set_target("[E] Return")
		elif not near:
			interaction_controller.clear_target()


## Called by MemoryAnchor._on_body_entered/exited. The anchor passes itself so the
## manager can emit its memory_triggered signal on interaction.
func _set_anchor_near(anchor: MemoryAnchor, near: bool) -> void:
	if near:
		_near_anchor = anchor
	elif _near_anchor == anchor:
		_near_anchor = null
	anchor_proximity_changed.emit(_near_anchor != null)
	# Ticket-07: feed the interaction prompt when near a memory anchor.
	if interaction_controller != null:
		if _near_anchor != null and _in_dreamscape:
			interaction_controller.set_target("[E] Remember")
		elif _near_anchor == null:
			interaction_controller.clear_target()


## True while a fade sequence runs (requests are ignored meanwhile).
func is_busy() -> bool:
	return _transitioning


func in_dreamscape() -> bool:
	return _in_dreamscape


## Stop the 30 s auto-return without changing worlds. Called by the ambulance
## interception so the peaceful exit can never race the forced one.
func cancel_auto_return() -> void:
	_auto_return_timer.stop()


## Forget any anchor the player is standing in. Called by the ambulance interception
## after it disables the anchors, so a stale proximity flag can't re-open the E return.
func clear_anchor_proximity() -> void:
	if _near_anchor != null:
		_near_anchor = null
		anchor_proximity_changed.emit(false)


## Violent, jarring return (Ticket-06). Skips the smooth fade entirely: snap to full
## white instantly, swap worlds under the white, then a 0.1 s LINEAR white→transparent
## reveal. No hold, no sine ease — a hard flash, the opposite of return_to_workspace.
func force_return_to_workspace() -> void:
	if _transitioning or not _in_dreamscape:
		return
	_transitioning = true
	is_forced_return = true
	_lock_player(true)
	_auto_return_timer.stop()
	return_started.emit()

	# Hard flash: alpha snaps to 1.0 this frame (no tween), worlds swap while the
	# screen is fully white, then a fast linear reveal.
	_fade_rect.modulate.a = 1.0
	_swap_worlds(false)
	_in_dreamscape = false
	if state_machine != null:
		state_machine.on_dreamscape_returned()
	await _hard_flash_out(0.1)

	_lock_player(false)
	_transitioning = false
	forced_return_completed.emit()
	transition_completed.emit(false)


## No one comes (Ticket-23): he fades out at peace. A slow fade to BLACK, a long hold,
## the room again, slowly. Not a rescue: he simply wakes.
func quiet_return_to_workspace(
	fade_out: float = 5.0, hold: float = 4.0, fade_in: float = 3.0
) -> void:
	if _transitioning or not _in_dreamscape:
		return
	_transitioning = true
	is_forced_return = false
	_lock_player(true)
	_auto_return_timer.stop()
	quiet_return_started.emit()
	_fade_rect.color = Color.BLACK
	await _fade_to(1.0, fade_out)
	_swap_worlds(false)
	_in_dreamscape = false
	if state_machine != null:
		state_machine.on_dreamscape_returned()
	await get_tree().create_timer(hold, false).timeout
	await _fade_to(0.0, fade_in)
	_fade_rect.color = Color.WHITE
	_lock_player(false)
	_transitioning = false
	quiet_return_completed.emit()
	transition_completed.emit(false)


## Linear white→transparent over `seconds`. TRANS_LINEAR (not the sine used by the
## smooth fades) so the reveal reads as a hard cut resolving, not a gentle dissolve.
func _hard_flash_out(seconds: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_fade_rect, "modulate:a", 0.0, seconds)
	await tween.finished


## ----- TRANSITIONS ------------------------------------------------------------------------


func transition_to_dreamscape() -> void:
	if _transitioning or _in_dreamscape:
		return
	if workspace_root == null or dreamscape_root == null:
		push_warning("DreamscapeManager: workspace/dreamscape roots not wired.")
		return
	_transitioning = true
	is_forced_return = false
	_lock_player(true)
	transition_started.emit()

	await _fade_to(1.0, fade_out_seconds)
	_swap_worlds(true)
	_in_dreamscape = true
	if state_machine != null:
		state_machine.on_dreamscape_entered()
	await _hold()
	await _fade_to(0.0, fade_in_seconds)

	# Timer starts AFTER the fade-in, not at the world swap: the 30 s dream is 30 s of
	# playable valley, not 30 s minus the 3.5 s of transition.
	_last_timer_second = -1
	_auto_return_timer.start(auto_return_seconds)
	_lock_player(false)
	_transitioning = false
	transition_completed.emit(true)


func return_to_workspace() -> void:
	if _transitioning or not _in_dreamscape:
		return
	_transitioning = true
	is_forced_return = false
	_lock_player(true)
	_auto_return_timer.stop()
	return_started.emit()

	await _fade_to(1.0, fade_out_seconds)
	_swap_worlds(false)
	_in_dreamscape = false
	if state_machine != null:
		state_machine.on_dreamscape_returned()
	await _hold()
	await _fade_to(0.0, fade_in_seconds)

	_lock_player(false)
	_transitioning = false
	transition_completed.emit(false)


## ----- INTERNALS --------------------------------------------------------------------------


func _lock_player(locked: bool) -> void:
	if player == null:
		return
	if locked:
		player.lock_input(&"dream_transition")
	else:
		player.unlock_input(&"dream_transition")


## One WorldEnvironment, two resources — see class doc.
func _swap_worlds(to_dreamscape: bool) -> void:
	# WorldRoot handles Rule 2: hidden worlds lose their colliders and stop processing,
	# and gameplay-suppressed nodes stay suppressed (tools/probe_world_isolation.gd).
	workspace_root.set_active(not to_dreamscape)
	dreamscape_root.set_active(to_dreamscape)

	if world_environment != null:
		world_environment.environment = (
			valley_environment if to_dreamscape else apartment_environment
		)
	if player != null:
		if to_dreamscape:
			_apartment_extents = player.room_half_extents
			player.room_half_extents = dreamscape_room_extents
		else:
			player.room_half_extents = _apartment_extents
	if camera != null:
		camera.far = 150.0 if to_dreamscape else 45.0
		camera.set_dream_framing(to_dreamscape)
	worlds_swapped.emit(to_dreamscape)


## Plays a quick white flash (0.3 s) for the memory-trigger effect.
func trigger_memory_flash() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.15)
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.15)


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fade_rect, "modulate:a", alpha, seconds)
	await tween.finished


func _hold() -> void:
	await get_tree().create_timer(fade_hold_seconds, false).timeout
