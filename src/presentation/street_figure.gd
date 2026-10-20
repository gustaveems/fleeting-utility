class_name StreetFigure
extends Node3D
## PRESENTATION — a greybox person for the prologue streets (Ticket-15 A.2). Primitives
## only; character art replaces it later. Faces local −Z.
##
##   Dress    SUIT (the rich: charcoal, a white collar), MIDDLE (muted coat),
##            POOR (ragged brown), HERO (him: grey-green parka, a shoulder bag at his hip),
##            GUARD (black, cap)
##   Pose     STAND, WALK (legs and arms swing while `moving`), SLUMP (sitting against
##            a wall), FIGHT (lunging toward `fight_target`), HUDDLE (head bob, a hand out),
##            ARGUE (squared up to `fight_target`, jabbing a finger)
## shove() / stagger() play the beat where an argument turns into a fight.

enum Dress { SUIT, MIDDLE, POOR, HERO, GUARD }
enum Pose { STAND, WALK, SLUMP, FIGHT, HUDDLE, ARGUE }

const HEIGHT := 1.78

@export var dress: Dress = Dress.MIDDLE
@export var pose: Pose = Pose.STAND

## Walking: legs swing while true (callers move the figure).
var moving: bool = false
var fight_target: Node3D

var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _head: Node3D
var _bag: Node3D
var _phase: float = 0.0
var _home: Vector3


func _ready() -> void:
	_phase = randf() * TAU
	_build()
	_home = position
	match pose:
		Pose.SLUMP:
			_body.rotation_degrees = Vector3(-20, 0, 0)
			_body.position = Vector3(0, -0.55, 0)
			for leg in _legs:
				leg.rotation_degrees = Vector3(-70, 0, 0)
		Pose.WALK:
			moving = true


func _process(delta: float) -> void:
	_phase += delta
	match pose:
		Pose.WALK:
			var swing := sin(_phase * 7.0) * (0.6 if moving else 0.0)
			_legs[0].rotation.x = swing
			_legs[1].rotation.x = -swing
			_arms[0].rotation.x = -swing * 0.7
			_arms[1].rotation.x = swing * 0.7
			_body.position.y = absf(sin(_phase * 7.0)) * 0.04 if moving else 0.0
			if _bag != null:
				_bag.rotation.x = swing * 0.25  # the bag bumps against his hip
		Pose.ARGUE:
			# Squared up, leaning in, a finger jabbing at the other's face.
			var jab := maxf(sin(_phase * 6.0), 0.0)
			_arms[1].rotation.x = -1.3 - jab * 0.3
			_body.rotation.x = -0.08 - jab * 0.06
			_head.rotation.x = sin(_phase * 3.0) * 0.1
		Pose.FIGHT:
			# Lunge and recoil; a swinging arm.
			var lunge := maxf(sin(_phase * 5.0), 0.0)
			if fight_target != null:
				var toward := fight_target.position - _home
				toward.y = 0.0
				position = _home + toward.normalized() * lunge * 0.35
			_arms[1].rotation.x = -lunge * 1.6
			_body.rotation.x = -lunge * 0.25
		Pose.HUDDLE:
			_head.rotation.x = sin(_phase * 2.0) * 0.15
			_arms[1].rotation.x = -0.9 - sin(_phase * 1.3) * 0.2
		Pose.STAND:
			_body.rotation.y = sin(_phase * 0.6) * 0.05


## Switch pose at runtime (limbs return to rest; FIGHT lunges from where it stands now).
func set_pose(p: Pose) -> void:
	pose = p
	_home = position
	_body.rotation = Vector3.ZERO
	for leg in _legs:
		leg.rotation = Vector3.ZERO
	for arm in _arms:
		arm.rotation = Vector3.ZERO
	moving = p == Pose.WALK


## Both arms thrust: the shove that starts it.
func shove() -> void:
	var t := create_tween()
	for arm in _arms:
		t.parallel().tween_property(arm, "rotation:x", -1.5, 0.12)
	t.parallel().tween_property(_body, "rotation:x", -0.3, 0.12)
	t.tween_interval(0.25)
	for arm in _arms:
		t.parallel().tween_property(arm, "rotation:x", -0.2, 0.3)
	t.parallel().tween_property(_body, "rotation:x", 0.0, 0.3)


## Knocked back `distance` metres away from `from`, rocking, arms flung up.
func stagger(from: Vector3, distance: float = 0.9) -> void:
	var away := position - from
	away.y = 0.0
	var to := position + away.normalized() * distance
	var t := create_tween()
	t.tween_property(self, "position", to, 0.35).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_body, "rotation:x", 0.35, 0.18)
	for arm in _arms:
		t.parallel().tween_property(arm, "rotation:x", -0.8, 0.18)
	t.tween_property(_body, "rotation:x", 0.0, 0.3)


func _build() -> void:
	var cloth := _cloth()
	var skin := _mat(Color(0.62, 0.48, 0.40), 0.8)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	for side in [-1.0, 1.0]:
		var leg := _pivot(_body, Vector3(side * 0.11, 0.92, 0))
		_capsule(
			leg,
			Vector3(0, -0.45, 0),
			0.09,
			0.9,
			cloth if dress != Dress.SUIT else _mat(Color(0.12, 0.12, 0.13), 0.6)
		)
		_legs.append(leg)
	_capsule(_body, Vector3(0, 1.22, 0), 0.2, 0.68, cloth)
	for side in [-1.0, 1.0]:
		var arm := _pivot(_body, Vector3(side * 0.27, 1.5, 0))
		_capsule(arm, Vector3(0, -0.32, 0), 0.06, 0.64, cloth)
		_arms.append(arm)
	_head = _pivot(_body, Vector3(0, 1.62, 0))
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.26
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(0, 0.05, 0)
	_head.add_child(head)
	match dress:
		Dress.SUIT:
			_box(
				_body,
				Vector3(0, 1.44, -0.17),
				Vector3(0.1, 0.2, 0.04),
				_mat(Color(0.92, 0.92, 0.9), 0.5)
			)
		Dress.GUARD:
			_box(
				_head,
				Vector3(0, 0.16, -0.04),
				Vector3(0.28, 0.06, 0.3),
				_mat(Color(0.05, 0.05, 0.06), 0.5)
			)
		Dress.HERO:
			# A shoulder bag at his right hip, the strap across his chest and back.
			var canvas := _mat(Color(0.24, 0.2, 0.15), 0.95)
			_bag = _pivot(_body, Vector3(0.27, 1.5, 0))
			_box(_bag, Vector3(0.11, -0.58, 0.0), Vector3(0.1, 0.28, 0.34), canvas)
			for z in [-0.205, 0.205]:
				var strap := _pivot(_body, Vector3(0, 1.26, z))
				strap.rotation.z = deg_to_rad(38)  # left shoulder → right hip
				_box(strap, Vector3.ZERO, Vector3(0.04, 0.72, 0.02), canvas)


func _cloth() -> StandardMaterial3D:
	match dress:
		Dress.SUIT:
			return _mat(Color(0.16, 0.16, 0.18), 0.5)
		Dress.POOR:
			return _mat(Color(0.30, 0.24, 0.18), 1.0)
		Dress.HERO:
			return _mat(Color(0.33, 0.38, 0.32), 0.9)
		Dress.GUARD:
			return _mat(Color(0.06, 0.06, 0.07), 0.6)
	return _mat(Color(0.36, 0.36, 0.38), 0.85)


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = at
	parent.add_child(p)
	return p


func _capsule(parent: Node3D, at: Vector3, radius: float, h: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func _mat(c: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m
