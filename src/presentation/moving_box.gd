class_name MovingBox
extends Interactable
## PRESENTATION — one of his moving boxes (Night Zero, N3). Walk up and press E to pick
## it up; NightZero carries it with him and puts it down on the next E. A cardboard box
## (Poly Haven, CC0) or a brown box if the pack is missing.

signal picked_up(box: MovingBox)

const MODEL := "res://assets/third_party/polyhaven/cardboard_box_01/cardboard_box_01.gltf"

var carried: bool = false
var placed: bool = false
## NightZero clears this while he already has his hands full.
var hands_free: bool = true


func _ready() -> void:
	super()
	prompt_text = "[E] Pick up the box"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)
	var model := CityKit.prop(MODEL, self, Vector3.ZERO, 0.0, 0.0)
	if model != null:
		model.scale = Vector3.ONE * 0.6
	else:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.3, 0.22, 0.25)
		mi.mesh = mesh
		mi.position = Vector3(0, 0.11, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.42, 0.28)
		mi.material_override = m
		add_child(mi)


func can_interact() -> bool:
	return hands_free and not carried and not placed


func _on_interacted() -> void:
	picked_up.emit(self)
