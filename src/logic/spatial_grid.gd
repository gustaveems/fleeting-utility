class_name SpatialGrid
extends Node3D
## LOGIC/PRESENTATION GLUE — a 2D placement grid for crafting/inventory items.
##
## This is a *different* grid from WorkspaceGridData (the room floor). The room is 9×7m
## where the player walks; this grid is typically 4×4m for a crafting bench or inventory
## panel. Items placed here are children of this node, positioned at cell centers in
## local space.
##
## COORDINATE SYSTEM
## -----------------
## The grid's local origin is at the corner of cell (0,0). Cell centers are at:
##   local_pos = ((cell.x + 0.5) * cell_size, 0, (cell.y + 0.5) * cell_size)
##
## So if this node is at world (10, 0, 5), cell (0,0) center is world (10.5, 0, 5.5).
## Items are added as children, so their world position = grid.world_transform * local_pos.
##
## OCCUPANCY
## ---------
## `grid_cells` is a 2D array: grid_cells[x][y] = Node or null. Null = empty.
## place_item() checks bounds and occupancy before instantiating.
## remove_item() calls queue_free() and clears the cell.

## Signal emitted when an item is successfully placed.
signal item_placed(item: Node, cell: Vector2i)

## Signal emitted when an item is removed (after queue_free).
signal item_removed(cell: Vector2i)

## Grid dimensions in cells. Default 4×4 for a crafting bench.
@export var grid_width: int = 4
@export var grid_depth: int = 4

## Cell size in metres. Must match the item scenes' scale.
@export var cell_size: float = 1.0

## 2D occupancy array. grid_cells[x][y] = Node or null.
var grid_cells: Array = []


func _ready() -> void:
	_init_grid()


## Build the 2D array filled with nulls. Called once at _ready; if you resize the grid
## at runtime, call this again (but existing items will be lost).
func _init_grid() -> void:
	grid_cells.clear()
	for x in range(grid_width):
		var column: Array = []
		for y in range(grid_depth):
			column.append(null)
		grid_cells.append(column)


## Convert a cell coordinate to a local position (cell center).
func cell_to_local(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size,
		0.0,
		(float(cell.y) + 0.5) * cell_size
	)


## Is the cell within the grid bounds?
func is_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_depth


## Is the cell occupied by an item?
func is_cell_occupied(cell: Vector2i) -> bool:
	if not is_cell_valid(cell):
		return false
	return grid_cells[cell.x][cell.y] != null


## Instantiate an item scene and place it at the given cell. Returns the instantiated
## node, or null if the cell is out of bounds or already occupied.
func place_item(item_scene: PackedScene, grid_pos: Vector2i) -> Node:
	if not is_cell_valid(grid_pos):
		push_warning("SpatialGrid.place_item: cell %s out of bounds" % grid_pos)
		return null
	if is_cell_occupied(grid_pos):
		push_warning("SpatialGrid.place_item: cell %s already occupied" % grid_pos)
		return null

	var item := item_scene.instantiate()
	item.position = cell_to_local(grid_pos)
	add_child(item)
	grid_cells[grid_pos.x][grid_pos.y] = item
	item_placed.emit(item, grid_pos)
	return item


## Remove the item at the given cell. Calls queue_free() and clears the occupancy.
## Does nothing if the cell is empty or out of bounds.
func remove_item(grid_pos: Vector2i) -> void:
	if not is_cell_valid(grid_pos):
		return
	var item = grid_cells[grid_pos.x][grid_pos.y]
	if item != null:
		item.queue_free()
		grid_cells[grid_pos.x][grid_pos.y] = null
		item_removed.emit(grid_pos)


## Return all cells that are currently empty.
func get_available_cells() -> Array[Vector2i]:
	var available: Array[Vector2i] = []
	for x in range(grid_width):
		for y in range(grid_depth):
			if grid_cells[x][y] == null:
				available.append(Vector2i(x, y))
	return available


## Return the item at the given cell, or null if empty/out of bounds.
func get_item_at(cell: Vector2i) -> Node:
	if not is_cell_valid(cell):
		return null
	return grid_cells[cell.x][cell.y]
