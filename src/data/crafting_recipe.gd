class_name CraftingRecipe
extends Resource
## DATA LAYER — one crafting recipe: inputs → output, with a base craft time.
##
## Piece of a RecipeDatabase. Each recipe declares:
##   required_items   a map of item_id (StringName) → count (int) that must be present
##                    on the SpatialGrid for this recipe to be usable.
##   result_item_id   the item_id of the item produced on completion.
##   base_craft_time  wall-clock seconds to craft before chemical modifiers apply.
##
## Modifiers (High-Focus = 0.5×, Crash = 2.0×) are applied by the crafting bench, not
## here — this resource is pure data.

## Item IDs mapped to the count required (e.g., {&"raw_compound": 2}).
@export var required_items: Dictionary = {}

## The item_id of the item placed on the grid when crafting completes.
@export var result_item_id: StringName = &""

## Craft time in seconds before chemical modifiers (High-Focus/Crash).
@export var base_craft_time: float = 0.0