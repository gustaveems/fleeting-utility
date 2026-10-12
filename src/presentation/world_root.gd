class_name WorldRoot
extends Node3D
## PRESENTATION — one whole world (apartment, valley, park) that can leave and re-enter
## the game as a unit.
##
## WHY THIS EXISTS (Ironclad Rule 2)
## ---------------------------------
## `visible = false` is cosmetic. A hidden subtree keeps its CollisionShape3Ds in the
## physics space, keeps its Area3Ds sensing and keeps its `_process` running. Before
## this class, four managers each carried their own copy of a "toggle every shape" loop,
## and each copy force-ENABLED every shape on the way back in. That resurrected
## colliders gameplay had removed on purpose (the ransacked bench, the sealed memory
## anchors). Hidden worlds also kept processing: the apartment AtmosphereController
## wrote apartment fog into the valley.
##
## CONTRACT
## --------
##   set_active(false)  hidden, every shape disabled, process_mode DISABLED. Timers,
##                      _process, audio players and particles under it all pause.
##   set_active(true)   visible, processing, shapes re-enabled EXCEPT those under a
##                      suppressed node.
##   suppress(node)     takes one descendant out of the world for good (until restore):
##                      non-solid, paused and, by default, hidden. It survives any
##                      number of set_active cycles.
##
## Future systems (ambient audio beds, particles) parent under a WorldRoot and pause
## with it for free.

## Emitted after every set_active call. Audio/VFX layers listen here.
signal activation_changed(active: bool)

var is_active: bool = true

var _suppressed: Array[Node] = []


func set_active(active: bool) -> void:
	is_active = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_apply_shapes()
	activation_changed.emit(active)


## Remove a descendant from play until restore(). `hide_node` false keeps it visible (e.g.
## sealed memory anchors still glow but can no longer be entered).
func suppress(node: Node, hide_node: bool = true) -> void:
	if node == null or _suppressed.has(node):
		return
	_suppressed.append(node)
	if hide_node and node is Node3D:
		(node as Node3D).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_apply_shapes()


func restore(node: Node) -> void:
	if not _suppressed.has(node):
		return
	_suppressed.erase(node)
	if node is Node3D:
		(node as Node3D).visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_shapes()


func is_suppressed(node: Node) -> bool:
	for s in _suppressed:
		if s == node or s.is_ancestor_of(node):
			return true
	return false


func _apply_shapes() -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		var shape := child as CollisionShape3D
		shape.disabled = not is_active or is_suppressed(shape)
