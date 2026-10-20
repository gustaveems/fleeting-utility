class_name ColossusFigure
extends Node3D
## PRESENTATION — a striding colossus after the Colossus of Rhodes (canon 2026-10-19),
## greyboxed from primitives. Feet on two plinths `stance` apart (things pass between its
## legs), one arm raised.
##
##   Style.GOLD_COPY   the corporation's mascot: a CHEAP copy. Flat gaudy gold paint,
##                     dark seam bands across limbs and torso, a logo plate on the plinth.
##   Style.STONE       the dream's real colossi: weathered stone, blood running down the
##                     legs and plinths. (For the valley pass.)
## Origin = midpoint between the plinths at ground level; it faces local −Z.

enum Style { GOLD_COPY, STONE }

@export var style: Style = Style.GOLD_COPY
@export var height: float = 50.0
@export var stance: float = 24.0

## The point gaze shots look at (the head), set by _ready.
var head: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	var s := height / 50.0
	var skin := _material()
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = (
		Color(0.32, 0.30, 0.28) if style == Style.GOLD_COPY else Color(0.45, 0.43, 0.40)
	)
	plinth_mat.roughness = 0.9
	var half := stance * 0.5
	var plinth_h := 8.0 * s
	for side in [-1.0, 1.0]:
		_box(Vector3(side * half, plinth_h * 0.5, 0), Vector3(9, plinth_h, 9) * s, plinth_mat)

	# Legs splay from the plinths up to the hips.
	var hip := Vector3(0, plinth_h + 18.0 * s, 0)
	for side in [-1.0, 1.0]:
		var foot := Vector3(side * half, plinth_h, 0)
		_limb(foot, hip + Vector3(side * 3.0 * s, 0, 0), 2.6 * s, skin)
		if style == Style.STONE:
			_blood_run(foot, hip, side)
	# Torso, head, arms.
	var chest := hip + Vector3(0, 13.0 * s, 0)
	_limb(hip, chest, 5.2 * s, skin)
	head = Node3D.new()
	head.name = "Head"
	head.position = chest + Vector3(0, 5.0 * s, 0)
	add_child(head)
	var skull := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0 * s
	sphere.height = 6.6 * s
	skull.mesh = sphere
	skull.material_override = skin
	head.add_child(skull)
	var shoulder_l := chest + Vector3(-5.5 * s, -1.0 * s, 0)
	var shoulder_r := chest + Vector3(5.5 * s, -1.0 * s, 0)
	_limb(shoulder_l, shoulder_l + Vector3(-3, 10, -1) * s, 1.6 * s, skin)  # raised
	_limb(shoulder_r, shoulder_r + Vector3(2, -12, 1) * s, 1.6 * s, skin)  # hanging
	if style == Style.GOLD_COPY:
		_seams(hip, chest, s)
		_logo_plate(Vector3(half, plinth_h * 0.6, -4.6 * s), s)


func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if style == Style.GOLD_COPY:
		# Gaudy paint, not metal: a little shine, no depth.
		m.albedo_color = Color(0.86, 0.66, 0.22)
		m.metallic = 0.35
		m.roughness = 0.45
		m.emission_enabled = true
		m.emission = Color(0.55, 0.38, 0.08)
		m.emission_energy_multiplier = 0.25
	else:
		m.albedo_color = Color(0.52, 0.50, 0.47)
		m.roughness = 0.95
	return m


## A capsule spanning two points.
func _limb(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b) + radius * 2.0
	mi.mesh = capsule
	mi.material_override = mat
	add_child(mi)
	var mid := (a + b) * 0.5
	var up := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	mi.transform = Transform3D(Basis(x, up, x.cross(up)), mid)


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	return mi


## Cheap-copy giveaway: dark moulding seams where the fibreglass panels meet.
func _seams(hip: Vector3, chest: Vector3, s: float) -> void:
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color(0.18, 0.12, 0.05)
	for y in [hip.y - 9.0 * s, hip.y + 4.0 * s, chest.y - 3.0 * s]:
		_box(Vector3(0, y, 0), Vector3(12.0 * s, 0.35 * s, 6.0 * s), seam)


func _logo_plate(at: Vector3, s: float) -> void:
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.9, 0.9, 0.92)
	plate.emission_enabled = true
	plate.emission = Color(0.2, 0.84, 0.9)
	plate.emission_energy_multiplier = 1.2
	_box(at, Vector3(4.0, 1.6, 0.2) * s, plate)


func _blood_run(foot: Vector3, hip: Vector3, side: float) -> void:
	var blood := StandardMaterial3D.new()
	blood.albedo_color = Color(0.45, 0.05, 0.04)
	blood.roughness = 0.6
	var top := foot.lerp(hip, 0.45)
	_box(
		(foot + top) * 0.5 + Vector3(side * 0.5, 0, -2.4), Vector3(0.9, top.y - foot.y, 0.2), blood
	)
