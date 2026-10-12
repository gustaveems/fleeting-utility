class_name SurfaceDegradation
extends Node3D
## PRESENTATION — projects stains, cracks, and decay onto walls and floor via Decal nodes.
##
## A pool of 15 Godot 4 Decal nodes is pre-instantiated and toggled on/off as entropy
## crosses activation thresholds (30%, 60%, 90%). Each threshold unlocks a batch of 5
## Decals placed randomly around the room.
##
## TEXTURES
## --------
## Placeholder textures are generated procedurally at runtime using NoiseTexture2D +
## FastNoiseLite. No external image assets or .gdshader files are needed:
##   - "splatter": cellular noise → dark spots on transparent background (oil, grime).
##   - "crack": simplex noise with a narrow dark band → thin jagged lines that read as
##     plaster cracks at isometric distance.
## The noise is seeded randomly so the pattern is different every session.
##
## PLACEMENT
## ---------
## Each batch pulls from a predefined list of position + normal Direction around the
## room. Decals randomly pick a placement so the same entropy level doesn't produce
## identical decay every session.
##
## CLEANING INTEGRATION
## -------------------
## Deactivation mirrors activation: when entropy drops back below a threshold the
## corresponding batch is hidden. Reducing entropy on WorkspaceEntropyData is all that
## is needed — the `clean_workspace()` hook simply lowers the data value, and the
## entropy_changed signal here hides the Decals automatically.
##
## CONFIGURED FOR 2.5D ISOMETRIC VIEW
## ---------------------------------
## Decals are placed flush against flat walls and floor planes. A Godot 4 Decal projects
## along its local −Y, and size.y is the projection DEPTH; size.x/size.z are the
## footprint. Each decal's +Y is therefore aligned to the surface normal. At a fixed 45°
## isometric angle a wall decal then reads as a smear on the wall plane.
##
## STABILITY
## ---------
## entropy_changed fires every frame while entropy grows. A batch is placed only when
## it switches on, and keeps that placement while its tier holds; re-shuffling on every
## signal made decals jump around each frame.

## Projection depth: reaches the surface from a placement a few cm off it.
const PROJECTION_DEPTH := 0.4

## --- DEPENDENCY ----------------------------------------------------------------------

## Procedural textures, built once and shared across all instances (static).
static var _splatter_texture: NoiseTexture2D
static var _crack_texture: NoiseTexture2D

@export var entropy_data: WorkspaceEntropyData

## --- THRESHOLDS & POOL ---------------------------------------------------------------

@export var threshold_low: float = 30.0
@export var threshold_medium: float = 60.0
@export var threshold_high: float = 90.0
@export var batch_size: int = 5

## --- INTERNAL STATE ------------------------------------------------------------------

var _pool: Array[Decal] = []
var _batch_placements: Array[Array] = []
var _batch_active: Array[bool] = [false, false, false]

## ----- LIFECYCLE ---------------------------------------------------------------------


func _ready() -> void:
	_init_textures()
	_init_placements()
	_init_pool()
	if entropy_data != null:
		entropy_data.entropy_changed.connect(_on_entropy_changed)
		_on_entropy_changed(entropy_data.entropy)


## ----- TEXTURES ----------------------------------------------------------------------


func _init_textures() -> void:
	if _splatter_texture == null:
		_splatter_texture = _make_splatter_texture()
	if _crack_texture == null:
		_crack_texture = _make_crack_texture()


## "Splatter" = cellular noise with a sharp gradient. Produces scattered dark spots on
## a transparent background — reads as oil, coffee, or general grime at 2.5D distance.
func _make_splatter_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2
	noise.cellular_jitter = 0.7
	noise.frequency = 0.04
	noise.seed = randi()

	var gradient := Gradient.new()
	# Gradient.new() ships with default points (white@0, black@1) and add_point() only
	# APPENDS — set_offsets/set_colors REPLACE the whole array, killing the leftover
	# white point that rendered low-noise regions as opaque streaks (confirmed on the
	# first real render; Gradient.reset() does not exist in 4.x).
	gradient.set_offsets(PackedFloat32Array([0.0, 0.48, 0.52, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(0.0, 0.0, 0.0, 0.0),
					Color(0.0, 0.0, 0.0, 0.0),
					Color(0.12, 0.09, 0.06, 0.8),
					Color(0.08, 0.06, 0.04, 0.9),
				]
			)
		)
	)

	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = gradient
	texture.width = 256
	texture.height = 256
	texture.seamless = false
	return texture


## "Crack" = simplex noise with a narrow dark band in the centre of the gradient.
## Produces thin jagged lines on a transparent background.
func _make_crack_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.1
	noise.fractal_gain = 0.55
	noise.seed = randi()

	var gradient := Gradient.new()
	# set_offsets/set_colors replace the default white@0 point — see splatter note.
	gradient.set_offsets(PackedFloat32Array([0.0, 0.44, 0.50, 0.56, 1.0]))
	(
		gradient
		. set_colors(
			PackedColorArray(
				[
					Color(0.0, 0.0, 0.0, 0.0),
					Color(0.0, 0.0, 0.0, 0.0),
					Color(0.1, 0.07, 0.05, 0.85),
					Color(0.0, 0.0, 0.0, 0.0),
					Color(0.0, 0.0, 0.0, 0.0),
				]
			)
		)
	)

	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = gradient
	texture.width = 256
	texture.height = 256
	texture.seamless = false
	return texture


## ----- PLACEMENT POOLS ---------------------------------------------------------------


func _init_placements() -> void:
	# Batch 1 (threshold_low = 30): scattered floor stains.
	(
		_batch_placements
		. append(
			[
				{"pos": Vector3(-3.0, 0.02, -2.0), "normal": Vector3.UP},
				{"pos": Vector3(1.5, 0.02, 2.0), "normal": Vector3.UP},
				{"pos": Vector3(3.5, 0.02, -1.0), "normal": Vector3.UP},
				{"pos": Vector3(-2.0, 0.02, 2.5), "normal": Vector3.UP},
				{"pos": Vector3(0.0, 0.02, -1.5), "normal": Vector3.UP},
			]
		)
	)
	# Batch 2 (threshold_medium = 60): wall cracks + floor stains. Wall slots sit on
	# SOLID surfaces only: the west wall (full height) and the north sill band (y ≤ 0.45).
	# The south/east walls are sill-height (iso sightlines) and the north pane is
	# transparent — decals project onto neither.
	(
		_batch_placements
		. append(
			[
				{"pos": Vector3(-4.45, 0.85, -1.5), "normal": Vector3.RIGHT},
				{"pos": Vector3(1.5, 0.28, -3.45), "normal": Vector3.BACK},
				{"pos": Vector3(-4.45, 0.7, 1.0), "normal": Vector3.RIGHT},
				{"pos": Vector3(-4.45, 0.5, 2.0), "normal": Vector3.RIGHT},
				{"pos": Vector3(2.0, 0.02, 2.5), "normal": Vector3.UP},
			]
		)
	)
	# Batch 3 (threshold_high = 90): more wall damage + floor.
	(
		_batch_placements
		. append(
			[
				{"pos": Vector3(0.5, 0.3, -3.45), "normal": Vector3.BACK},
				{"pos": Vector3(-4.45, 0.3, -2.0), "normal": Vector3.RIGHT},
				{"pos": Vector3(-4.45, 1.05, -0.5), "normal": Vector3.RIGHT},
				{"pos": Vector3(-1.0, 0.02, -2.5), "normal": Vector3.UP},
				{"pos": Vector3(3.5, 0.02, 0.5), "normal": Vector3.UP},
			]
		)
	)


## ----- POOL --------------------------------------------------------------------------


func _init_pool() -> void:
	for i in range(batch_size * 3):
		var decal := Decal.new()
		decal.name = "DecayDecal%02d" % i
		decal.visible = false
		decal.size = Vector3(1.0, PROJECTION_DEPTH, 1.5)
		decal.modulate = Color(1.0, 1.0, 1.0, 0.75)
		decal.albedo_mix = 1.0
		decal.cull_mask = (1 << 20) - 1
		decal.texture_albedo = _texture_for_index(i)
		add_child(decal)
		_pool.append(decal)


func _texture_for_index(i: int) -> NoiseTexture2D:
	var batch := i / batch_size
	# Batch 0 is floor stains; batches 1-2 mix in cracks for variety.
	if batch == 1 or (batch == 2 and i % 2 == 0):
		return _crack_texture
	return _splatter_texture


## ----- SYNC LOGIC --------------------------------------------------------------------


func _on_entropy_changed(_new_entropy: float) -> void:
	_sync_batch(0, entropy_data.entropy, threshold_low)
	_sync_batch(1, entropy_data.entropy, threshold_medium)
	_sync_batch(2, entropy_data.entropy, threshold_high)


## Activate/deactivate all Decals in a batch on a tier change. A batch switching on
## takes a fresh random placement; while its tier holds, nothing moves.
func _sync_batch(batch_index: int, entropy: float, threshold: float) -> void:
	var should_be_active := entropy >= threshold
	if should_be_active == _batch_active[batch_index]:
		return
	_batch_active[batch_index] = should_be_active

	var shuffled: Array = (_batch_placements[batch_index] as Array).duplicate()
	shuffled.shuffle()
	for i in range(batch_size):
		var decal_index := batch_index * batch_size + i
		if decal_index >= _pool.size():
			break
		var decal := _pool[decal_index]
		if should_be_active and i < shuffled.size():
			var placement: Dictionary = shuffled[i]
			_place(decal, placement["pos"] as Vector3, placement["normal"] as Vector3)
			decal.visible = true
		else:
			decal.visible = false


## Align local +Y with the surface normal so the −Y projection goes into the surface,
## with a random roll about the normal and a random footprint.
func _place(decal: Decal, pos: Vector3, normal: Vector3) -> void:
	var y := normal.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	var basis := Basis(x, y, z).rotated(y, randf_range(-0.3, 0.3))
	decal.global_transform = Transform3D(basis, pos)
	decal.size = Vector3(randf_range(0.8, 1.4), PROJECTION_DEPTH, randf_range(1.0, 2.2))
