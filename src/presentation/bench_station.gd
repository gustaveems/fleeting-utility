class_name BenchStation
extends Interactable
## PRESENTATION — the player's way to the drug: walk up to the bench and press E.
##
##   a pill on the worktop          → "[E] Take a pill"   (+PILL_DOSE chemical)
##   enough compounds, bench idle   → "[E] Cook a dose"   (CraftingBench.interact)
##   cooking                        → "Cooking…"
##   nothing left                   → "Nothing left to cook."
##
## Supply is deliberately finite (the bench is seeded with a few compounds): the drug is
## being enclosed (MASTER_BRIEF "Chemical Gentrification"), so withdrawal arrives on
## schedule. Until this existed the bench was unreachable from input and the chemical
## could only fall (playtest 2026-10-14).
##
## A child of the CraftingBench, so it is suppressed with it after the ransack.

const PILL_ID := &"pill_bottle"
const PILL_DOSE := 0.55
const ZONE_RADIUS := 1.6

@export var bench: CraftingBench
@export var spatial_grid: SpatialGrid
@export var state_data: PlayerStateData


func _ready() -> void:
	prompt_text = "[E] Cook a dose"
	super()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = ZONE_RADIUS
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 1.0, 0.0)
	add_child(shape)


func can_interact() -> bool:
	if bench == null or spatial_grid == null:
		return false
	if _pill_cell() != Vector2i(-1, -1):
		return true
	return not bench.is_crafting() and _can_cook()


func current_prompt() -> String:
	if can_interact():
		return "[E] Take a pill" if _pill_cell() != Vector2i(-1, -1) else prompt_text
	return blocked_prompt()


func blocked_prompt() -> String:
	if bench != null and bench.is_crafting():
		return "Cooking…"
	return "Nothing left to cook."


func _on_interacted() -> void:
	var pill := _pill_cell()
	if pill != Vector2i(-1, -1):
		spatial_grid.remove_item(pill)
		if state_data != null:
			state_data.apply_chemical_change(PILL_DOSE)
		return
	bench.interact()


## No pill to take and nothing left to cook: the supply has run dry.
func is_dry() -> bool:
	if bench == null or spatial_grid == null:
		return false
	return _pill_cell() == Vector2i(-1, -1) and not bench.is_crafting() and not _can_cook()


func _can_cook() -> bool:
	return (
		bench.recipe_database != null
		and bench.recipe_database.find_satisfiable(spatial_grid) != null
	)


func _pill_cell() -> Vector2i:
	for x in spatial_grid.grid_width:
		for y in spatial_grid.grid_depth:
			var item := spatial_grid.get_item_at(Vector2i(x, y))
			if item is InventoryItem and (item as InventoryItem).item_id == PILL_ID:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
