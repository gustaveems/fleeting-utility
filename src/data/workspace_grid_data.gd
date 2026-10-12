class_name WorkspaceGridData
extends Resource
## DATA LAYER — the single source of truth for the workspace grid.
##
## Everything spatial in Fleeting Utility resolves through this resource: which cells
## exist, where their world centre is, and which way a facing points. Logic never
## touches world coordinates and Presentation never invents its own cell math, so the
## 1m x 1m snapping constraint (see GAME_SPEC.md #1.B) cannot drift between systems.
##
## AXIS CONVENTION
## ---------------
## The playfield is the XZ plane at y = 0. A cell is a Vector2i whose components are
## (x, z). "North" and friends are GRID directions, not compass directions: they are
## named after where they appear on screen under the fixed isometric camera (see
## facing_screen_hint() below and docs/TICKET-01.md for the derivation).
##
## This resource is deliberately stateless. It owns geometry, not movement.

enum Facing {
	NORTH = 0,  # -Z, travels up-right on screen
	EAST = 1,  # +X, travels down-right on screen
	SOUTH = 2,  # +Z, travels down-left on screen
	WEST = 3,  # -X, travels up-left on screen
}

## Edge length of one cell in metres. Constraint #3: 1m x 1m cells.
## Exposed so a level can be authored at a different scale without touching logic.
@export var cell_size: float = 1.0

## Room footprint in cells (the leased workspace is meant to feel cramped — MASTER_BRIEF.md #1).
@export var width_cells: int = 9
@export var depth_cells: int = 7

## Cell the player occupies at scene start. Kept in data so Ticket-04 (degradation)
## can relocate the spawn when the room is ransacked without editing any script.
## (4,3) is the footprint centre on a 9x7 room: spawn must sit outside soft_edge_band
## cells of the wall, or the game opens already inside the boundary fog.
@export var spawn_cell: Vector2i = Vector2i(4, 3)

## How far inwards from the wall the "soft boundary" response begins, in cells.
## Constraint #6: edges read as vignette/fog, never as an invisible wall you face-plant
## into, so the band is a gradient rather than a boolean.
@export var soft_edge_band_cells: float = 2.0

## Vertical lift of a cell centre above y = 0 (floor top surface). Kept here so the
## blockout, the player view and the camera agree on where "the floor" is.
@export var floor_height: float = 0.0


## Grid offset for a facing. Static + match instead of a const Dictionary so the
## mapping is guaranteed to be evaluated at call time by the compiler, not the loader.
static func facing_offset(facing: int) -> Vector2i:
	match facing:
		Facing.NORTH:
			return Vector2i(0, -1)
		Facing.EAST:
			return Vector2i(1, 0)
		Facing.SOUTH:
			return Vector2i(0, 1)
		Facing.WEST:
			return Vector2i(-1, 0)
		_:
			return Vector2i.ZERO


static func facing_name(facing: int) -> String:
	match facing:
		Facing.NORTH:
			return "NORTH"
		Facing.EAST:
			return "EAST"
		Facing.SOUTH:
			return "SOUTH"
		Facing.WEST:
			return "WEST"
		_:
			return "?"


## What the player sees when they press this facing's key. Documents the fact that
## under a 45-degree isometric camera the four grid axes project as four screen
## diagonals, which is why W does not mean "straight up".
static func facing_screen_hint(facing: int) -> String:
	match facing:
		Facing.NORTH:
			return "up-right"
		Facing.EAST:
			return "down-right"
		Facing.SOUTH:
			return "down-left"
		Facing.WEST:
			return "up-left"
		_:
			return "?"


## World position of the cell centre. Cells are centred inside a room that is itself
## centred on the origin, so cell (0,0) sits in the up-left corner of the footprint.
func cell_to_world(cell: Vector2i) -> Vector3:
	var x := (float(cell.x) - float(width_cells) * 0.5 + 0.5) * cell_size
	var z := (float(cell.y) - float(depth_cells) * 0.5 + 0.5) * cell_size
	return Vector3(x, floor_height, z)


## Inverse of cell_to_world(), for click-to-target and (later) Ticket-03 asset placement.
func world_to_cell(world: Vector3) -> Vector2i:
	var x := floori((world.x / cell_size) + float(width_cells) * 0.5)
	var z := floori((world.z / cell_size) + float(depth_cells) * 0.5)
	return Vector2i(x, z)


## Is the cell inside the room? This is a query, not a collision test — callers decide
## what refusing means. PlayerController treats a refusal as a soft boundary event.
func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width_cells and cell.y < depth_cells


## Nearest wall distance in whole cells (0 = standing on the edge cell's own ring).
## Used by SoftBoundaryModel to raise proximity as the player approaches owned-space limits.
func distance_to_edge(cell: Vector2i) -> int:
	var dx := mini(cell.x, width_cells - 1 - cell.x)
	var dz := mini(cell.y, depth_cells - 1 - cell.y)
	return maxi(0, mini(dx, dz))


## 1.0 at the wall, 0.0 once soft_edge_band_cells deep inside the room.
func edge_closeness(cell: Vector2i) -> float:
	if soft_edge_band_cells <= 0.0:
		return 0.0
	var closeness := 1.0 - float(distance_to_edge(cell)) / soft_edge_band_cells
	return clampf(closeness, 0.0, 1.0)


## Unit vector of a facing in world space (y always 0 — movement is planar).
func facing_direction(facing: int) -> Vector3:
	var offset := facing_offset(facing)
	return Vector3(float(offset.x), 0.0, float(offset.y)).normalized()


## Yaw in radians that points a node's local -Z forward axis along the facing.
## Derivation: R_y(theta) * (0,0,-1) = (-sin(theta), 0, -cos(theta)) = offset.
func facing_yaw(facing: int) -> float:
	var offset := facing_offset(facing)
	return atan2(-float(offset.x), -float(offset.y))
