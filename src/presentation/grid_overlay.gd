@tool
class_name GridOverlay3D
extends MeshInstance3D
## PRESENTATION LAYER — draws the 1m x 1m cell lattice over the blockout floor.
##
## @tool so the grid is visible in the editor viewport while authoring the room:
## constraint #3 makes the grid the thing designers actually think in, so showing it
## during level work is the difference between placing props "near the wall" and placing
## them in cell (7,5).
##
## Lines are unshaded and alpha-blended, drawn just above the floor plane to avoid
## z-fighting. It is a dev aid, not part of the final look — the dreamscape ticket will
## almost certainly want it off in release builds.

## Assign from the editor, or via GridOverlay.configure() when built by code.
@export var grid: WorkspaceGridData:
	set(value):
		grid = value
		_rebuild()

@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.13):
	set(value):
		line_color = value
		_apply_material()

## Lift above y = 0. Must stay small: the player is a metre tall, not a map view.
@export var draw_height: float = 0.012


func _ready() -> void:
	_apply_material()
	_rebuild()


func configure(data: WorkspaceGridData) -> void:
	grid = data


func show_overlay(visible_now: bool) -> void:
	visible = visible_now


func _rebuild() -> void:
	# Only build once we are inside the tree; a @tool script can otherwise be asked to
	# commit geometry during editor teardown, which produces noisy engine errors.
	if not is_inside_tree() or grid == null:
		return

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	var span_x := float(grid.width_cells) * grid.cell_size
	var span_z := float(grid.depth_cells) * grid.cell_size
	var half_x := span_x * 0.5
	var half_z := span_z * 0.5

	# Lines run along both axes at every cell boundary, including the two outer edges so
	# the footprint boundary is unambiguous against the walls.
	for i in range(grid.width_cells + 1):
		var x := -half_x + float(i) * grid.cell_size
		tool.add_vertex(Vector3(x, draw_height, -half_z))
		tool.add_vertex(Vector3(x, draw_height, half_z))
	for j in range(grid.depth_cells + 1):
		var z := -half_z + float(j) * grid.cell_size
		tool.add_vertex(Vector3(-half_x, draw_height, z))
		tool.add_vertex(Vector3(half_x, draw_height, z))

	mesh = tool.commit()
	_apply_material()


func _apply_material() -> void:
	if material_overlay == null:
		material_overlay = StandardMaterial3D.new()
	var material := material_overlay as StandardMaterial3D
	# Unshaded: a grid readout must not depend on the room's light, and line geometry has
	# no meaningful normals from PRIMITIVE_LINES.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = line_color
	material.vertex_color_use_as_albedo = false
