class_name Cot
extends Interactable
## PRESENTATION — the cot (Ticket-14): "[E] Sleep" ends the day (DayCycle.sleep).

@export var day_cycle: DayCycle


func _ready() -> void:
	prompt_text = "[E] Sleep"
	super()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.0, 1.6)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.0)
	add_child(shape)


func can_interact() -> bool:
	return day_cycle != null and day_cycle.can_sleep()


func _on_interacted() -> void:
	day_cycle.sleep()
