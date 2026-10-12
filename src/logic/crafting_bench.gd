class_name CraftingBench
extends StaticBody3D
## LOGIC/PRESENTATION — the crafting station for the Task pipeline.
##
## The player interacts with this bench (via a future InteractionController raycast).
## The bench checks a linked SpatialGrid for items matching its RecipeDatabase, and if a
## recipe is satisfiable, starts a timed craft. Craft duration is modified by the
## protagonist's chemical state:
##
##   High-Focus (chemical > 0.7, not crashed) → 0.5× (accelerated mastery)
##   Crash      (overload >= 50)              → 2.0× (fumble)
##   otherwise                                 → 1.0× (baseline)
##
## On completion, the required items are removed from the grid and the result item is
## placed in the first available cell.
##
## INTERACTION
## -----------
## This node is added to the "interactable" group so a RayCast3D can detect it. The
## future InteractionController raycasts, checks `is_in_group("interactable")`, and calls
## `interact()` on the collider.
##
## CHEMICAL MANAGER
## ---------------
## The `chemical_manager` export expects a PlayerStateData resource — the same one the
## PlayerStateMachine drives. Before a ChemicalManager wrapper exists, this direct
## reference gives the bench access to `is_high_focus()` and `is_crashed()`. If a
## ChemicalManager class is added later, swap the export type to match it, keeping
## the same property name.

## --- SIGNALS -------------------------------------------------------------------------

## Emitted when a craft begins. UI shows "working..." or equivalent.
signal crafting_started(recipe: CraftingRecipe, total_time: float)

## Emitted when a craft completes successfully. UI shows the result.
signal crafting_completed(result_item_id: StringName)

## Emitted when interact() finds no satisfiable recipe. UI shows "missing ingredients".
signal recipe_unavailable

## --- DEPENDENCIES --------------------------------------------------------------------

## The grid this bench reads from and places results on.
@export var spatial_grid: SpatialGrid

## The set of recipes this bench knows.
@export var recipe_database: RecipeDatabase

## The protagonist's chemical state. Typed as PlayerStateData; rename to ChemicalManager
## when a wrapper class is introduced. If null, all crafts run at 1.0× speed.
@export var chemical_manager: PlayerStateData

## Ticket-06: the interaction lock gate. When locked, the bench can't be used.
@export var interaction_controller: InteractionController

## The scene to instantiate for the result item. Must be a PackedScene containing a node
## that extends InventoryItem (or at minimum has an `item_id` property).
@export var result_item_scene: PackedScene

## --- CRAFTING PARAMETERS -------------------------------------------------------------

## Craft time multiplier when `chemical_manager.is_high_focus()` is true.
@export var high_focus_multiplier: float = 0.5

## Craft time multiplier when `chemical_manager.is_crashed()` is true.
## Crash takes priority over High-Focus: a crashed protagonist fumbles regardless of
## how much chemical is still in their system (is_high_focus() already guards for this).
@export var crash_multiplier: float = 2.0

## --- INTERNAL STATE ------------------------------------------------------------------

var _is_crafting: bool = false
var _current_recipe: CraftingRecipe
var _places_to_consume: Array[Vector2i] = []
var _target_cell: Vector2i
var _collision_shape: CollisionShape3D
var _timer: Timer

## ----- LIFECYCLE ---------------------------------------------------------------------


func _ready() -> void:
	_ensure_collision_shape()
	_setup_timer()
	add_to_group("interactable")


func _ensure_collision_shape() -> void:
	var found_collider := false
	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			found_collider = true
			break
	if not found_collider:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 0.9, 1.0)
		_collision_shape.shape = box
		add_child(_collision_shape)


func _setup_timer() -> void:
	_timer = Timer.new()
	_timer.name = "CraftTimer"
	_timer.one_shot = true
	_timer.autostart = false
	_timer.timeout.connect(_on_craft_completed)
	add_child(_timer)


## ----- INTERACTION -------------------------------------------------------------------


## Called by the InteractionController when the player interacts with this bench.
## Idempotent: if a craft is already in progress, the call is silently ignored.
func interact() -> void:
	if interaction_controller != null and not interaction_controller.try_interact():
		return
	if _is_crafting:
		return
	if recipe_database == null or spatial_grid == null:
		return

	_current_recipe = recipe_database.find_satisfiable(spatial_grid)
	if _current_recipe == null:
		recipe_unavailable.emit()
		return

	_places_to_consume = _collect_required_cells(_current_recipe)
	if _places_to_consume.size() < _total_required(_current_recipe):
		# Should not happen — find_satisfiable guaranteed enough items exist.
		recipe_unavailable.emit()
		return

	var available := spatial_grid.get_available_cells()
	if available.is_empty():
		recipe_unavailable.emit()
		return
	_target_cell = available[0]

	var total_time := _modified_craft_time(_current_recipe.base_craft_time)
	_timer.start(total_time)
	_is_crafting = true
	crafting_started.emit(_current_recipe, total_time)


## ----- CRAFTING COMPLETION ------------------------------------------------------------


func _on_craft_completed() -> void:
	_consume_items()
	_place_result()
	_is_crafting = false
	if _current_recipe != null:
		crafting_completed.emit(_current_recipe.result_item_id)


func _consume_items() -> void:
	for cell in _places_to_consume:
		spatial_grid.remove_item(cell)


func _place_result() -> void:
	if result_item_scene == null:
		push_warning("CraftingBench: result_item_scene is null, result not placed.")
		return
	var item := result_item_scene.instantiate()
	if item is InventoryItem:
		item.item_id = _current_recipe.result_item_id
		item.grid_position = _target_cell
	item.position = spatial_grid.cell_to_local(_target_cell)
	spatial_grid.add_child(item)
	# Direct child placement instead of spatial_grid.place_item() because the grid's
	# place_item instantiates from a scene; we already have the instance.
	spatial_grid.grid_cells[_target_cell.x][_target_cell.y] = item
	spatial_grid.item_placed.emit(item, _target_cell)


## ----- RECIPE HELPERS ----------------------------------------------------------------


## Find a cell on the grid for every required item_id in the recipe, up to the needed
## count. Returns a flat list of cells (e.g., 2 cells for 2× "raw_compound").
func _collect_required_cells(recipe: CraftingRecipe) -> Array[Vector2i]:
	var collected: Array[Vector2i] = []
	for item_id in recipe.required_items:
		var needed: int = recipe.required_items[item_id]
		for x in range(spatial_grid.grid_width):
			for y in range(spatial_grid.grid_depth):
				var cell := Vector2i(x, y)
				var item := spatial_grid.get_item_at(cell)
				if item != null and item is InventoryItem:
					if (item as InventoryItem).item_id == item_id:
						collected.append(cell)
						if collected.size() >= needed:
							break
				if collected.size() >= needed:
					break
			if collected.size() >= needed:
				break
	return collected


func _total_required(recipe: CraftingRecipe) -> int:
	var total := 0
	for item_id in recipe.required_items:
		total += int(recipe.required_items[item_id])
	return total


## ----- CHEMICAL MODIFIERS ------------------------------------------------------------


func _modified_craft_time(base_time: float) -> float:
	if chemical_manager == null:
		return base_time

	var multiplier := 1.0
	# Crash check first: a crashed protagonist fumbles regardless of chemical_level.
	if chemical_manager.is_crashed():
		multiplier = crash_multiplier
	elif chemical_manager.is_high_focus():
		multiplier = high_focus_multiplier

	return base_time * multiplier
