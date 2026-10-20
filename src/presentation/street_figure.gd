class_name StreetFigure
extends Node3D
## PRESENTATION — a greybox person for the prologue streets (Ticket-15 A.2). Primitives
## only; character art replaces it later. Faces local −Z.
##
##   Dress    SUIT (the rich: charcoal, a white collar), MIDDLE (muted coat),
##            POOR (ragged brown), HERO (him: grey-green parka), GUARD (black, cap)
##   Pose     STAND, WALK (legs and arms swing while `moving`), SLUMP (sitting against
##            a wall), FIGHT (lunging toward `fight_target`), HUDDLE (head bob, a hand out)

enum Dress { SUIT, MIDDLE, POOR, HERO, GUARD }
enum Pose { STAND, WALK, SLUMP, FIGHT, HUDDLE }

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
			_box(
				_body,
				Vector3(0, 1.12, 0.17),
				Vector3(0.34, 0.4, 0.12),
				_mat(Color(0.18, 0.2, 0.17), 0.9)
			)  # backpack


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
