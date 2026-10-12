class_name RansackedStateManager
extends Node
## LOGIC/PRESENTATION — the Ransacked Apartment & Betrayal (Ticket-08 Task 3).
##
## TRIGGER
## -------
## Listens to CorporateParkManager.return_from_walk. When the player returns from the
## corporate park, the apartment has been ransacked: the crafting bench and grid are
## gone, debris is scattered across the floor, the lighting is broken, and a pair of
## luxury shoes sits near the window — the betrayer's calling card.
##
## DESTRUCTION
## -----------
## CraftingBench and SpatialGrid are suppressed in the apartment WorldRoot: hidden,
## non-solid and paused, and they stay that way through later world swaps (Rule 2). 5-10 debris
## objects (simple primitive meshes) are spawned at random positions across the floor.
##
## ATMOSPHERE
## ----------
## AtmosphereController switches to BROKEN mode: flickering key light, dead lamp, cold
## draft audio placeholder.
##
## NARRATIVE PROP
## --------------
## LuxuryShoes are instantiated near the window. The player can interact with them to
## trigger the betrayal_realized signal and narrative text.

## --- SIGNALS -------------------------------------------------------------------------

## Emitted after the ransacked state is fully applied.
signal ransacked_applied

## --- REFERENCES ----------------------------------------------------------------------

@export var corporate_park_manager: CorporateParkManager
@export var crafting_bench: CraftingBench
@export var spatial_grid: SpatialGrid
@export var atmosphere_controller: AtmosphereController
@export var apartment_root: WorldRoot
@export var player: Node3D

## --- TUNING --------------------------------------------------------------------------

## Number of debris objects to spawn (random within range).
@export var debris_count_min: int = 5
@export var debris_count_max: int = 10

## Room bounds for debris scatter (half-extents in XZ).
@export var debris_scatter_bounds: Vector2 = Vector2(3.5, 2.8)

## Position for the luxury shoes (near the window).
@export var shoes_position: Vector3 = Vector3(2.0, 0.0, -2.5)

## --- INTERNAL STATE ------------------------------------------------------------------

## True once the ransacked state has been applied. Read by HesitationController to
## determine whether the door should trigger the psychological break.
var is_ransacked: bool = false

var _luxury_shoes: LuxuryShoes = null


func _ready() -> void:
	if corporate_park_manager != null:
		corporate_park_manager.return_from_walk.connect(_on_return_from_walk)


func _on_return_from_walk() -> void:
	_destroy_bench_and_grid()
	_spawn_debris()
	_apply_broken_atmosphere()
	_place_luxury_shoes()
	is_ransacked = true
	ransacked_applied.emit()


## ----- DESTRUCTION -------------------------------------------------------------------


func _destroy_bench_and_grid() -> void:
	if apartment_root == null:
		return
	apartment_root.suppress(crafting_bench)
	apartment_root.suppress(spatial_grid)


## ----- DEBRIS ------------------------------------------------------------------------


func _spawn_debris() -> void:
	if apartment_root == null:
		return
	var count := randi_range(debris_count_min, debris_count_max)
	for i in count:
		var debris := _make_debris_piece()
		debris.position = Vector3(
			randf_range(-debris_scatter_bounds.x, debris_scatter_bounds.x),
			0.05,
			randf_range(-debris_scatter_bounds.y, debris_scatter_bounds.y)
		)
		debris.rotation_degrees = Vector3(
			randf_range(0.0, 360.0), randf_range(0.0, 360.0), randf_range(0.0, 360.0)
		)
		apartment_root.add_child(debris)


func _make_debris_piece() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Debris"
	# Random primitive: box, sphere, or cylinder.
	var roll := randi() % 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(
		randf_range(0.25, 0.45), randf_range(0.22, 0.38), randf_range(0.18, 0.32)
	)
	mat.roughness = 0.95
	match roll:
		0:
			var box := BoxMesh.new()
			box.size = Vector3(
				randf_range(0.08, 0.25), randf_range(0.04, 0.12), randf_range(0.08, 0.25)
			)
			mi.mesh = box
		1:
			var sphere := SphereMesh.new()
			sphere.radius = randf_range(0.04, 0.10)
			sphere.height = sphere.radius * 2.0
			mi.mesh = sphere
		_:
			var cyl := CylinderMesh.new()
			cyl.top_radius = randf_range(0.03, 0.08)
			cyl.bottom_radius = cyl.top_radius
			cyl.height = randf_range(0.06, 0.18)
			mi.mesh = cyl
	mi.material_override = mat
	return mi


## ----- ATMOSPHERE --------------------------------------------------------------------


func _apply_broken_atmosphere() -> void:
	if atmosphere_controller != null:
		atmosphere_controller.set_broken_mode(true)


## ----- NARRATIVE PROP ----------------------------------------------------------------


func _place_luxury_shoes() -> void:
	if apartment_root == null:
		return
	_luxury_shoes = LuxuryShoes.new()
	_luxury_shoes.name = "LuxuryShoes"
	_luxury_shoes.position = shoes_position
	_luxury_shoes.player = player
	apartment_root.add_child(_luxury_shoes)
