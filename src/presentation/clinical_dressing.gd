class_name ClinicalDressing
extends Node3D
## PRESENTATION — the post-climax clinical scene (story beat 21: "he wakes screaming,
## lucid and unmedicated, under clinical white light, trapped back inside the system").
## Built around his bed and shown only while AtmosphereController is in CLINICAL mode:
## surgical lamps over the bed, two faceless corporate medics standing over him, an IV
## stand, opened medical kits and tape, and the brand's standee: CORPORATE CARE.
## Purely visual (no colliders), so showing/hiding it is safe (Rule 2).

## The room is a diorama: real-scale props shrink to match (walls 1.35 m, him 0.8 m).
const PROP := 0.47

@export var atmosphere: AtmosphereController


func _ready() -> void:
	_build()
	visible = false
	if atmosphere != null:
		atmosphere.mode_changed.connect(_on_mode_changed)
		_on_mode_changed(
			(
				AtmosphereController.Mode.CLINICAL
				if atmosphere.is_clinical_mode()
				else AtmosphereController.Mode.NORMAL
			)
		)


func _on_mode_changed(mode: AtmosphereController.Mode) -> void:
	visible = mode == AtmosphereController.Mode.CLINICAL


func _build() -> void:
	# Surgical lamps hung over the bed, throwing hard cold light straight down.
	for x in [-0.3, 0.3]:
		var lamp := CityKit.prop(
			CityKit.polyhaven("modern_ceiling_lamp_01"), self, Vector3(x, 1.75, 0), 0.0, 0.0
		)
		if lamp != null:
			lamp.scale = Vector3.ONE * 0.6
		var cable := _box(
			Vector3(x, 2.2, 0), Vector3(0.01, 0.9, 0.01), _mat(Color(0.1, 0.1, 0.1), 0.5)
		)
		cable.name = "Cable"
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.9, 0.96, 1.0)
		spot.light_energy = 4.0
		spot.spot_range = 3.0
		spot.spot_angle = 35.0
		spot.position = Vector3(x, 1.6, 0)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		add_child(spot)
	# The corporate medics: faceless, white, standing over him.
	for spec in [[Vector3(-0.8, 0, 0.45), 120.0], [Vector3(0.1, 0, -0.75), 10.0]]:
		var medic := StreetFigure.new()
		medic.dress = StreetFigure.Dress.MEDIC
		medic.pose = StreetFigure.Pose.STAND
		medic.position = spec[0]
		medic.rotation_degrees.y = spec[1]
		medic.scale = Vector3.ONE * PROP
		add_child(medic)
	# IV stand: steel pole, a bag of something clear.
	var steel := _mat(Color(0.75, 0.77, 0.8), 0.25)
	steel.metallic = 0.8
	_box(Vector3(0.75, 0.55, 0.35), Vector3(0.02, 1.1, 0.02), steel)
	_box(Vector3(0.75, 0.01, 0.35), Vector3(0.25, 0.02, 0.25), steel)
	var bag := _mat(Color(0.85, 0.92, 0.95, 0.5), 0.1)
	bag.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(0.75, 1.0, 0.38), Vector3(0.1, 0.16, 0.04), bag)
	# Opened kits and tape on the floor by the bed.
	for at in [Vector3(-0.55, 0, -0.35), Vector3(0.55, 0, -0.5)]:
		var kit := CityKit.prop(
			CityKit.polyhaven("medical_box"), self, at, randf_range(0, 360), 0.0
		)
		if kit != null:
			kit.scale = Vector3.ONE * 0.8
	CityKit.prop(CityKit.polyhaven("medical_tape"), self, Vector3(-0.3, 0, -0.6), 40.0, 0.0)
	# The brand's standee: the care was always part of the lease.
	_box(Vector3(-1.2, 0.45, -0.9), Vector3(0.5, 0.9, 0.04), _mat(Color(0.95, 0.97, 1.0), 0.3))
	var sign := Label3D.new()
	sign.text = "CORPORATE CARE\nYour life is covered."
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = Color(0.1, 0.55, 0.65)
	sign.position = Vector3(-1.2, 0.6, -0.875)
	add_child(sign)


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	return mi


func _mat(c: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m
