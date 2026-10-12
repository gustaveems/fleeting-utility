class_name IsoCameraRig
extends Node3D
## PRESENTATION LAYER — the fixed/angled 2.5D isometric camera (constraint #2).
##
## WHY THE SHAPE OF THIS RIG
## -------------------------
## The rig is a Node3D that *translates only*; its rotation never changes. A Camera3D
## child sits at a constant oblique offset from the rig, aimed at the origin once in
## _ready(). Because the projection is orthographic, translating the rig cannot alter
## the view direction, so a single one-time look_at gives a permanently fixed angle —
## no camera drift, no player-controlled yaw, which is what makes the framing read as a
## diorama of the leased room rather than a shooter.
##
## THE ANGLE
## ---------
## Default elevation is 35.264 degrees (arctan(1/sqrt(2))), the true-isometric angle
## where a cube's three visible faces are congruent diamonds. Drop it to ~30 for a
## 2:1 dimetric look if the room blockout reads better that way. Yaw is fixed at 45
## degrees by placing the offset on the +X/+Z diagonal; that placement is what makes the
## four grid axes land on four screen diagonals, and it is documented against the key
## bindings in InputActionData.
##
## ORTHOGRAPHIC BY DEFAULT
## -----------------------
## Orthogonal keeps 1m cells the same pixel size everywhere in the room, which is what
## "precise spatial rendering" wants. Perspective flattens the far corner and makes
## distant clutter ambiguous; @export is_off_perspective lets the dreamscape (Ticket-05)
## switch to a slight perspective for the valley without a second rig.

## World-space offset of the camera relative to the rig. Derived, not authored — see
## _recompute_offset().
@export var iso_elevation_degrees: float = 35.264

## Distance of the camera from the rig along the iso diagonal. With an orthographic
## projection this only affects near/far clipping, not scale.
@export var iso_distance: float = 24.0

## Visible vertical world span when orthographic. 9m across a 7m-deep room frames the
## whole workspace with headroom for the walls.
@export var orthographic_height: float = 9.0

@export var is_off_perspective: bool = false

## Vertical look target offset, so the rig centres on the player's chest rather than
## their feet.
@export var framing_lift: float = 0.85

## Peak shake displacement in metres at full crash intensity. Kept small: this is a
## withdrawal tremor, not an explosion.
@export var max_shake_amplitude: float = 0.16

## Peak shake-induced roll in radians at full crash intensity.
@export var max_shake_roll: float = 0.018

var _camera: Camera3D
var _target: Node3D
var _follow_time: float = 0.10
var _crash_intensity: float = 0.0
var _shake_phase: float = 0.0
var _offset: Vector3 = Vector3(24.0, 17.0, 24.0)


func _ready() -> void:
	_recompute_offset()
	_camera = Camera3D.new()
	_camera.name = "IsoCamera"
	_camera.projection = (
		Camera3D.PROJECTION_PERSPECTIVE if is_off_perspective else Camera3D.PROJECTION_ORTHOGONAL
	)
	_camera.fov = 30.0
	_camera.size = orthographic_height
	_camera.near = 0.05
	_camera.far = iso_distance * 4.0
	add_child(_camera)
	_camera.position = _offset
	# One-time aim. Translation afterwards cannot change the angle, which is the whole
	# point of the rig.
	_camera.look_at(Vector3(0.0, framing_lift, 0.0), Vector3.UP)
	_camera.make_current()


## The player controller pushes the active profile's follow time each frame; a crash
## makes the room slide under the player instead of tracking them.
func set_follow_time(seconds: float) -> void:
	_follow_time = maxf(0.0001, seconds)


## Drives tremor amplitude/roll. Consumed from PerceptionDirector.crash_intensity_changed
## — the rig never asks why the player is crashing.
func set_crash_intensity(intensity: float) -> void:
	_crash_intensity = clampf(intensity, 0.0, 1.0)


func bind_target(node: Node3D) -> void:
	_target = node


func camera() -> Camera3D:
	return _camera


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _target != null:
		global_position = _track(global_position, _target.global_position, delta)
	_apply_shake(delta)


## Exponential smoothing that is frame-rate independent: `follow_time` is the real-time
## window to close ~95% of the gap, converted to a per-frame weight.
func _track(from: Vector3, to: Vector3, delta: float) -> Vector3:
	var weight := 1.0 - exp(-delta / _follow_time)
	return from.lerp(to, weight)


func _apply_shake(delta: float) -> void:
	# Advance the phase faster as the crash deepens: the tremor gets jitterier, not just
	# bigger, which is what sells "cognitive overload" rather than an earthquake.
	_shake_phase += delta * (6.0 + 22.0 * _crash_intensity)
	var amp := max_shake_amplitude * _crash_intensity
	# Three incommensurate sine sums per axis — cheap pseudo-noise, and unlike
	# randf()-based shake it never pops between magnitudes on a dropped frame.
	var nx := _tremor(_shake_phase, 1.0, 0.0)
	var ny := _tremor(_shake_phase, 1.37, 2.1)
	# Camera-local axes so the shake reads as screen-space jitter regardless of yaw.
	var right := _camera.global_transform.basis.x
	var up := _camera.global_transform.basis.y
	_camera.position = _offset + right * (nx * amp) + up * (ny * amp)
	# Roll about the view axis, applied to the camera's own basis so the look direction
	# is preserved: the room tilts, the framing does not move.
	if _crash_intensity > 0.001:
		var roll := _tremor(_shake_phase, 0.71, 4.4) * max_shake_roll
		_camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), roll)


func _tremor(phase: float, frequency: float, seed_offset: float) -> float:
	return (
		sin(phase * frequency + seed_offset) * 0.55
		+ sin(phase * frequency * 1.73 + seed_offset * 2.3) * 0.30
		+ sin(phase * frequency * 3.11 + seed_offset * 4.7) * 0.15
	)


## offset = (cos(elev), sin(elev), cos(elev)) * distance, on the +X/+Z diagonal so yaw is
## exactly 45 degrees.
func _recompute_offset() -> void:
	var elevation := deg_to_rad(iso_elevation_degrees)
	var horizontal := cos(elevation)
	var vertical := sin(elevation)
	_offset = Vector3(horizontal, vertical, horizontal).normalized() * iso_distance
