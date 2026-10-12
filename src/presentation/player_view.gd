class_name PlayerView
extends Node3D
## PRESENTATION LAYER — the body that glides between cell centres.
##
## Purely reactive: it holds no position authority of its own. GridMover decides which
## cell the player is in; this node decides what travelling between two cells looks
## like. The distinction matters for constraint #3 — snapping stays exact because every
## endpoint is a real cell centre, while the motion between them is free to be eased,
## arced and rotated.
##
## Visuals are a code-built blockout (a torso box + a facing wedge). Every node is named
## and parented so an artist can swap an imported glTF in place of `BodyPivot` without
## touching a line of logic.

var _grid: WorkspaceGridData

## Endpoints of the step currently being drawn, in world space.
var _from_world: Vector3 = Vector3.ZERO
var _to_world: Vector3 = Vector3.ZERO

var _body_pivot: Node3D
var _target_yaw: float = 0.0
var _current_yaw: float = 0.0


func _ready() -> void:
	_build_placeholder_body()


func configure(grid: WorkspaceGridData, cell: Vector2i) -> void:
	_grid = grid
	_from_world = grid.cell_to_world(cell)
	_to_world = _from_world
	global_position = _from_world


## Called from GridMover.step_started.
func begin_step(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _grid == null:
		return
	_from_world = _grid.cell_to_world(from_cell)
	_to_world = _grid.cell_to_world(to_cell)


## alpha is GridMover.step_alpha(), already eased by logic, so presentation only has to
## blend the endpoints and add the footstep arc.
func advance(alpha: float, arc_height: float) -> void:
	if _grid == null:
		return
	var blended := _from_world.lerp(_to_world, alpha)
	# Parabolic lift: zero at both endpoints, so the foot lands exactly on the grid point
	# and the snap is never visually undercut by the arc.
	var lift := arc_height * 4.0 * alpha * (1.0 - alpha)
	global_position = blended + Vector3(0.0, lift, 0.0)


## Called from GridMover.step_completed: locks the body onto the settled cell centre.
func settle(cell: Vector2i) -> void:
	if _grid == null:
		return
	_from_world = _grid.cell_to_world(cell)
	_to_world = _from_world
	advance(1.0, 0.0)


## Commit a new facing. The logic-side delay already happened in TurnController; what is
## visible here is the body physically catching up, which is the felt "turn speed".
func set_target_yaw(yaw_radians: float) -> void:
	_target_yaw = yaw_radians


## Frame-rate independent rotation towards the committed facing, taking the shortest arc
## so NORTH -> WEST turns 90 degrees, not 270.
func rotate_towards(delta: float, speed_degrees_per_second: float) -> void:
	if _body_pivot == null or delta <= 0.0:
		return
	var max_step := deg_to_rad(speed_degrees_per_second) * delta
	var diff := wrapf(_target_yaw - _current_yaw, -PI, PI)
	if absf(diff) <= max_step or is_zero_approx(diff):
		_current_yaw = _target_yaw
	else:
		_current_yaw += clampf(diff, -max_step, max_step)
	_body_pivot.rotation.y = _current_yaw


func _build_placeholder_body() -> void:
	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)

	var torso := MeshInstance3D.new()
	torso.name = "TorsoPlaceholder"
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.42, 0.9, 0.32)
	torso.mesh = torso_mesh
	# PrimitiveMesh has no `position` in Godot 4 (Godot 3 API): offset the instance.
	torso.position = Vector3(0.0, 0.55, 0.0)
	torso.material_override = _mat(Color(0.82, 0.76, 0.66))
	_body_pivot.add_child(torso)

	# Facing wedge: without it the direction is unreadable at an isometric angle, because
	# a box looks identical from four sides.
	var wedge := MeshInstance3D.new()
	wedge.name = "FacingMarker"
	var wedge_mesh := BoxMesh.new()
	wedge_mesh.size = Vector3(0.14, 0.12, 0.26)
	wedge.mesh = wedge_mesh
	wedge.position = Vector3(0.0, 0.72, -0.3)
	wedge.material_override = _mat(Color(0.85, 0.30, 0.24))
	_body_pivot.add_child(wedge)


static func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material
