class_name VfxDirector
extends Node
## PRESENTATION — world particles (Ticket-11): dust in the apartment, falling leaves in
## the valley.
##
## Like AudioDirector's beds, each emitter is a child of its WorldRoot and follows that
## world's activation_changed: inactive worlds freeze their particles in place
## (speed_scale 0) and resume them on return, Dual Visions flashes included.
## GPU particles simulate on the RenderingServer, so process_mode alone would not stop
## them.
##
## DUST tells the room's state:
##   WORKSPACE    thickens with entropy (the room decays into the air)
##   CLINICAL     none: sterile
##   SCARRED      a thin, slow haze
##   RANSACKED    heavy: the wreck is still settling
##   crash        swirls faster
## LEAVES drift around the player wherever they walk in the valley.

## Emitter sizes.
const DUST_AMOUNT := 220
const LEAF_AMOUNT := 240

## Leaves fall through a box this far around the player, starting this high.
const LEAF_AREA := Vector3(16.0, 1.0, 16.0)
const LEAF_HEIGHT := 9.0

@export var game_flow: GameFlow
@export var state_machine: PlayerStateMachine
@export var entropy_data: WorkspaceEntropyData
@export var player: Node3D
@export var apartment: WorldRoot
@export var valley: WorldRoot

## Dust density as a fraction of DUST_AMOUNT per phase; WORKSPACE scales with entropy.
@export var dust_floor: float = 0.15

var dust: GPUParticles3D
var leaves: GPUParticles3D

var _phase: GameFlow.Phase = GameFlow.Phase.WORKSPACE


func _ready() -> void:
	if apartment != null:
		dust = _build_dust()
		_adopt(dust, apartment)
	if valley != null:
		leaves = _build_leaves()
		_adopt(leaves, valley)
	if game_flow != null:
		game_flow.phase_changed.connect(
			func(_from: GameFlow.Phase, to: GameFlow.Phase): _phase = to
		)


func _process(_delta: float) -> void:
	if dust != null:
		dust.amount_ratio = _dust_ratio()
		var crashed := (
			state_machine != null
			and state_machine.state_data != null
			and state_machine.state_data.is_crashed()
		)
		if dust.speed_scale > 0.0:
			dust.speed_scale = 2.2 if crashed else 1.0
	if leaves != null and player != null and leaves.speed_scale > 0.0:
		leaves.global_position = player.global_position + Vector3(0.0, LEAF_HEIGHT, 0.0)


func _dust_ratio() -> float:
	match _phase:
		GameFlow.Phase.CLINICAL:
			return 0.0
		GameFlow.Phase.SCARRED:
			return 0.2
		GameFlow.Phase.RANSACKED, GameFlow.Phase.HESITATION:
			return 1.0
	var entropy := entropy_data.entropy if entropy_data != null else 0.0
	return lerpf(dust_floor, 1.0, clampf(entropy / 100.0, 0.0, 1.0))


## Parent an emitter into its world and freeze/resume it with that world.
func _adopt(emitter: GPUParticles3D, world: WorldRoot) -> void:
	world.add_child(emitter)
	_set_frozen(emitter, not world.is_active)
	world.activation_changed.connect(func(active: bool): _set_frozen(emitter, not active))


func _set_frozen(emitter: GPUParticles3D, frozen: bool) -> void:
	emitter.speed_scale = 0.0 if frozen else 1.0


## ----- BUILDERS --------------------------------------------------------------------------


## Fine motes hanging in the room air, drifting on slow turbulence.
func _build_dust() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(4.2, 1.2, 3.2)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.01
	mat.initial_velocity_max = 0.05
	mat.gravity = Vector3(0.0, -0.004, 0.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale = 3.0
	mat.turbulence_noise_speed = Vector3(0.05, 0.02, 0.05)
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	mat.color = Color(1.0, 0.94, 0.82, 0.45)

	var p := GPUParticles3D.new()
	p.name = "DustMotes"
	p.amount = DUST_AMOUNT
	p.lifetime = 14.0
	p.preprocess = 14.0  # the room is already dusty when you arrive
	p.position = Vector3(0.0, 1.3, 0.0)
	p.visibility_aabb = AABB(Vector3(-5.0, -1.5, -4.0), Vector3(10.0, 3.0, 8.0))
	p.process_material = mat
	p.draw_pass_1 = _billboard_quad(Vector2(0.025, 0.025), Color(1.0, 0.95, 0.85, 0.5))
	return p


## Autumn leaves tumbling on a light wind around the player.
func _build_leaves() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = LEAF_AREA
	mat.direction = Vector3(1.0, -0.3, 0.35)
	mat.spread = 25.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0.0, -0.9, 0.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 1.2
	mat.turbulence_noise_scale = 4.0
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	mat.scale_min = 0.7
	mat.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(
		[Color(0.95, 0.55, 0.15), Color(0.78, 0.22, 0.10), Color(0.98, 0.78, 0.25)]
	)
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_initial_ramp = ramp_tex

	var p := GPUParticles3D.new()
	p.name = "FallingLeaves"
	p.amount = LEAF_AMOUNT
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.local_coords = false  # leaves already falling stay put as the emitter follows him
	p.visibility_aabb = AABB(Vector3(-20.0, -12.0, -20.0), Vector3(40.0, 16.0, 40.0))
	p.process_material = mat
	p.draw_pass_1 = _billboard_quad(Vector2(0.16, 0.11), Color.WHITE)
	return p


## Camera-facing quad for particles; vertex colour carries each particle's tint.
func _billboard_quad(size: Vector2, tint: Color) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = m
	return quad
