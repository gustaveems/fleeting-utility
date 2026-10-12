class_name RecipeDatabase
extends Resource
## DATA LAYER — the set of recipes known to a crafting bench.
##
## A bench holds one database. Multiple benches can share the same database (.tres) or
## each bench can have its own — the design supports both. Recipes are authored as
## CraftingRecipe resources and stored in the `recipes` array.
##
## Default recipe (built in _init() so a freshly-created database already knows how to
## turn raw compound into pills):
##   2x "raw_compound" → 1x "pill_bottle"  (base_craft_time 4.0 s)

## The set of recipes. Authored in the inspector as an array of CraftingRecipe resources,
## or populated at runtime by a quest/loot system (future).
@export var recipes: Array[CraftingRecipe] = []


func _init() -> void:
	if recipes.is_empty():
		_add_default_recipes()


func _add_default_recipes() -> void:
	var pill_recipe := CraftingRecipe.new()
	pill_recipe.required_items = {&"raw_compound": 2}
	pill_recipe.result_item_id = &"pill_bottle"
	pill_recipe.base_craft_time = 4.0
	recipes.append(pill_recipe)


## Return the first recipe that matches all required items on the given SpatialGrid.
## Returns null if no recipe is satisfiable with the items currently placed.
func find_satisfiable(grid: SpatialGrid) -> CraftingRecipe:
	for recipe in recipes:
		if _can_fulfill(recipe, grid):
			return recipe
	return null


## Check whether a specific recipe's required items all exist on the grid.
func _can_fulfill(recipe: CraftingRecipe, grid: SpatialGrid) -> bool:
	for item_id in recipe.required_items:
		var needed: int = recipe.required_items[item_id]
		var found := _count_item_on_grid(grid, item_id)
		if found < needed:
			return false
	return true


## Count how many items of a given item_id are placed on the grid.
func _count_item_on_grid(grid: SpatialGrid, item_id: StringName) -> int:
	var total := 0
	for x in range(grid.grid_width):
		for y in range(grid.grid_depth):
			var item := grid.get_item_at(Vector2i(x, y))
			if item != null and item is InventoryItem:
				var inv_item := item as InventoryItem
				if inv_item.item_id == item_id:
					total += 1
	return total