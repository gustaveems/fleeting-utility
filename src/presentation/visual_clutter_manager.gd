class_name VisualClutterManager
extends Node3D
## PRESENTATION — spawns and manages visual clutter based on WorkspaceEntropy.
##
## Listens to `WorkspaceEntropyData.entropy_changed` and activates/deactivates a pool
## of ClutterItem nodes to match the current entropy level. At 0% entropy, all items are
## hidden; at 100%, all 20 are visible. The manager assigns each active item a predefined
## spawn position from a 20-element array, avoiding the crafting bench and player start.
##
## POOL MANAGEMENT
## ---------------
## The pool is pre-instantiated in `_ready()` and reused. Items are never freed or
## re-instantiated during play — only toggled visible/invisible. This avoids memory
## churn and keeps the scene tree stable.
##
## SPAWN POSITIONS
## ---------------
## 20 predefined positions scattered around the 9×7m room, avoiding the bench area
## (around -3, 0, -2) and player start (4, 0, 3). Positions are in world space, relative
## to this node's transform. If this node is at the room origin, the positions are
## absolute; if offset, they're local.
##
## ACTIVATION LOGIC
## ----------------
## On entropy change: target_count = (entropy / 100.0) * pool_size. Iterate the pool:
##   - If index < target_count and item is inactive → activate, assign spawn position
##   - If index >= target_count and item is active → deactivate
## This ensures the number of visible items matches the entropy percentage.

## Placeholder shapes cycled through the pool so a row of clutter isn't 20 identical
## papers — each ClutterItem._ensure_mesh() variant in turn.
const CLUTTER_TYPES = [&"paper", &"can", &"bottle"]

## The entropy data resource. Typed as WorkspaceEntropyData (the resource, not the
## RefCounted logic driver). The signal `entropy_changed` fires when entropy updates.
@export var entropy_data: WorkspaceEntropyData

## The clutter item scene to instantiate. Must be a PackedScene with a root that
## extends ClutterItem (or at minimum has activate/deactivate methods).
@export var clutter_item_scene: PackedScene

## Number of clutter items in the pool. Default 20.
@export var pool_size: int = 20

## Predefined spawn positions for the 20 clutter slots. Scattered around the room,
## avoiding the bench and player start. Edit in the inspector or populate in code.
@export var spawn_positions: Array[Vector3] = []

## The pool of instantiated clutter items. Managed internally.
var _pool: Array[ClutterItem] = []


func _ready() -> void:
	_init_spawn_positions()
	_init_pool()
	if entropy_data != null:
		entropy_data.entropy_changed.connect(_on_entropy_changed)
		# Sync immediately to the current entropy value.
		_on_entropy_changed(entropy_data.entropy)


## Populate the spawn_positions array with 20 predefined positions if it's empty.
## Positions are scattered around the 9×7m room, avoiding the bench area and player start.
func _init_spawn_positions() -> void:
	if not spawn_positions.is_empty():
		return
	# Room bounds: x from -4.5 to +4.5, z from -3.5 to +3.5 (centered on origin).
	# Bench area: around (-3, 0, -2). Player start: (4, 0, 3).
	# 20 positions scattered around the room, y = 0.05 (just above floor).
	spawn_positions = [
		Vector3(-4.0, 0.05, -3.0),
		Vector3(-3.5, 0.05, 2.5),
		Vector3(-2.0, 0.05, -2.5),
		Vector3(-1.5, 0.05, 3.0),
		Vector3(-1.0, 0.05, -1.0),
		Vector3(-0.5, 0.05, 1.5),
		Vector3(0.9, 0.05, -2.9),  # off the threshold (the neighbour stands there)
		Vector3(0.5, 0.05, 2.0),
		Vector3(1.0, 0.05, -2.0),
		Vector3(1.5, 0.05, 0.5),
		Vector3(2.0, 0.05, -1.5),
		Vector3(2.5, 0.05, 3.0),
		Vector3(3.0, 0.05, -0.5),
		Vector3(3.5, 0.05, 1.0),
		Vector3(-4.0, 0.05, 1.6),  # clear of the boxes' drop zone (Night Zero)
		Vector3(-3.0, 0.05, -1.5),
		Vector3(-2.5, 0.05, 2.0),
		Vector3(-1.0, 0.05, -3.0),
		Vector3(0.0, 0.05, 3.0),
		Vector3(1.0, 0.05, -3.0),
	]


## Instantiate the pool of clutter items. All start inactive (visible=false, monitoring=false).
func _init_pool() -> void:
	if clutter_item_scene == null:
		push_warning("VisualClutterManager: clutter_item_scene is null, no pool created.")
		return
	for i in range(pool_size):
		var item := clutter_item_scene.instantiate()
		if not (item is ClutterItem):
			push_warning("VisualClutterManager: clutter_item_scene root is not a ClutterItem.")
			item.queue_free()
			continue
		# Set BEFORE add_child: ClutterItem._ready() builds its placeholder mesh from
		# clutter_type, so the cycle must be assigned while the node is still detached.
		item.name = "Clutter_%02d" % i
		item.clutter_type = CLUTTER_TYPES[i % CLUTTER_TYPES.size()]
		item.visible = false
		item.monitoring = false
		add_child(item)
		_pool.append(item)


## Called when entropy changes. Activates/deactivates pool items to match the entropy percentage.
func _on_entropy_changed(new_entropy: float) -> void:
	var target_count := int((new_entropy / 100.0) * pool_size)
	target_count = clampi(target_count, 0, pool_size)

	for i in range(_pool.size()):
		var item := _pool[i]
		if i < target_count:
			if not item.is_active():
				item.activate()
				if i < spawn_positions.size():
					item.position = spawn_positions[i]
				# Randomize rotation for visual variety.
				item.rotation.y = randf() * TAU
		else:
			if item.is_active():
				item.deactivate()


## Public API: manually trigger a sync to the current entropy. Useful if the manager is
## added to the scene after entropy has already risen.
func sync_to_current_entropy() -> void:
	if entropy_data != null:
		_on_entropy_changed(entropy_data.entropy)
