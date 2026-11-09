class_name RainFall
extends Node3D
## PRESENTATION — rain on the evening's walk (polish pass, 2026-11-06): streaks over the
## boulevard, kept to the street so none falls inside the shops, following him down it,
## and its sound. Off unless set_active(true). StreetLook rings the puddles.

const HEIGHT := 9.0
const LENGTH := 16.0
const DROPS := 4200
const FALL := 16.0
const LOOP_SECONDS := 2.0
const MIX_RATE := 22050
const VOLUME_DB := -14.0

## Who it follows along the street (z only: the boxes of rain stay over the road).
var follow: Node3D
var half_width: float = 6.0
var active: bool = false

var _drops: GPUParticles3D
var _sound: AudioStreamPlayer


func _ready() -> void:
	_build_drops()
	_build_sound()


func _process(_delta: float) -> void:
	if follow != null:
		position = Vector3(0, HEIGHT, follow.global_position.z)


func set_active(on: bool) -> void:
	active = on
	_drops.emitting = on
	if on:
		_sound.play()
	else:
		_sound.stop()


func _build_drops() -> void:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(half_width, 0.1, LENGTH)
	motion.direction = Vector3(0.06, -1, 0)
	motion.spread = 0.0
	motion.initial_velocity_min = FALL
	motion.initial_velocity_max = FALL * 1.2
	motion.gravity = Vector3.ZERO
	var streak := QuadMesh.new()
	streak.size = Vector2(0.007, 0.24)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.75, 0.82, 0.92, 0.13)
	streak.material = look
	_drops = GPUParticles3D.new()
	_drops.name = "Drops"
	_drops.amount = DROPS
	_drops.lifetime = HEIGHT / FALL
	_drops.preprocess = 1.0
	_drops.emitting = false
	_drops.process_material = motion
	_drops.draw_pass_1 = streak
	_drops.visibility_aabb = AABB(
		Vector3(-half_width, -HEIGHT - 1.0, -LENGTH),
		Vector3(half_width, HEIGHT + 1.0, LENGTH) * 2.0
	)
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)


## A loop of soft noise: a hiss, lowered so it reads as rain and not as static.
func _build_sound() -> void:
	var frames := int(LOOP_SECONDS * MIX_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var low := 0.0
	for i in frames:
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.35)
		pcm.encode_s16(i * 2, int(clampf(low, -1.0, 1.0) * 22000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	stream.data = pcm
	_sound = AudioStreamPlayer.new()
	_sound.name = "RainSound"
	_sound.stream = stream
	_sound.volume_db = VOLUME_DB
	_sound.bus = &"Ambience"
	add_child(_sound)
