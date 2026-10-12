extends SceneTree
## Dumps the live runtime tree with each node's visibility and, for every Area3D /
## CollisionShape3D, whether it is actually live in the physics space. Answers the
## "no hidden nodes still colliding" question directly.

var _ws: Node


func _init() -> void:
	var scene: PackedScene = load("res://scenes/workspace.tscn")
	_ws = scene.instantiate()
	root.add_child(_ws)
	await create_timer(0.6).timeout
	_walk(_ws, 0)
	quit()


func _walk(n: Node, d: int) -> void:
	var pad := "  ".repeat(d)
	var note := _note(n)
	print("%s%s (%s)%s" % [pad, n.name, n.get_class(), note])
	for c in n.get_children():
		if c.name == "AutoReturnTimer" or c.name == "InterceptionTimer":
			continue
		_walk(c, d + 1)


func _note(n: Node) -> String:
	var bits: Array[String] = []
	if n is CollisionShape3D or n is Area3D or n is StaticBody3D or n is CharacterBody3D:
		if n is CollisionShape3D:
			bits.append("disabled=%s" % str((n as CollisionShape3D).disabled))
		if n is Area3D:
			var a := n as Area3D
			bits.append(
				"L%d/M%d monitoring=%s" % [a.collision_layer, a.collision_mask, str(a.monitoring)]
			)
		if n is CollisionShape3D and not n.is_visible_in_tree():
			bits.append("IN-HIDDEN-SUBTREE")
	if n is Node3D and not n.visible and n.get_child_count() > 0:
		bits.append("subtree hidden")
	return ("   ; " + " ".join(bits)) if bits.size() > 0 else ""
