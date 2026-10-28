class_name StreetFigure
extends Node3D
## PRESENTATION — a person on the prologue streets (Ticket-15). Faces local −Z.
##
## With the Quaternius Universal Animation Library present (assets/third_party, CC0) it is
## a rigged figure, faceless as the story wants (voices, no faces). With the Universal
## Base Characters also present it wears their body (male or female) and hair on the same
## skeleton, dressed by class in three tones: top, trousers and a skin-toned head with no
## eyes (the eyes and brows are left out). Otherwise the UAL mannequin, tinted by class,
## playing real clips: Walk / Walk_Formal, Idle, Sitting_Idle, Idle_Talking, Idle_No,
## Push, Punch_Jab / Punch_Cross, Hit_Knockback. Without the pack it falls back to the
## primitive greybox figure below.
##
##   Dress    SUIT (the rich: charcoal, a white collar), MIDDLE (muted coat),
##            POOR (ragged brown), HERO (him: grey-green parka, a shoulder bag at his hip),
##            GUARD (black, cap)
##   Pose     STAND, WALK (legs and arms swing while `moving`), SLUMP (sitting against
##            a wall), FIGHT (lunging toward `fight_target`), HUDDLE (head bob, a hand out),
##            ARGUE (squared up to `fight_target`, jabbing a finger)
## shove() / stagger() play the beat where an argument turns into a fight.

enum Dress { SUIT, MIDDLE, POOR, HERO, GUARD, MEDIC, FRIEND }
enum Pose { STAND, WALK, SLUMP, FIGHT, HUDDLE, ARGUE }

const HEIGHT := 1.78
## Clothes by class: the rich charcoal, the poor ragged brown, his grey-green parka,
## the guard black, the medics white, the friend the campaign's camel coat.
const CLOTH := {
	Dress.SUIT: Color(0.16, 0.16, 0.18),
	Dress.POOR: Color(0.30, 0.24, 0.18),
	Dress.HERO: Color(0.33, 0.38, 0.32),
	Dress.GUARD: Color(0.06, 0.06, 0.07),
	Dress.MEDIC: Color(0.88, 0.92, 0.95),
	Dress.FRIEND: Color(0.62, 0.48, 0.32),
}
const CLOTH_ROUGH := {
	Dress.SUIT: 0.5,
	Dress.POOR: 1.0,
	Dress.HERO: 0.9,
	Dress.GUARD: 0.6,
	Dress.MEDIC: 0.4,
	Dress.FRIEND: 0.45,
}
## The class's outfit as [top, trousers] (the base bodies wear it; the mannequin, CLOTH).
const OUTFIT := {
	Dress.SUIT: [Color(0.13, 0.13, 0.15), Color(0.1, 0.1, 0.12)],
	Dress.MIDDLE: [Color(0.34, 0.37, 0.42), Color(0.18, 0.21, 0.28)],
	Dress.POOR: [Color(0.31, 0.3, 0.25), Color(0.19, 0.17, 0.15)],
	Dress.HERO: [Color(0.33, 0.38, 0.32), Color(0.18, 0.18, 0.2)],
	Dress.GUARD: [Color(0.05, 0.05, 0.06), Color(0.04, 0.04, 0.05)],
	Dress.MEDIC: [Color(0.9, 0.93, 0.96), Color(0.82, 0.88, 0.92)],
	# Away from skin tones, or the camel and cream read as bare skin.
	Dress.FRIEND: [Color(0.46, 0.32, 0.19), Color(0.13, 0.12, 0.12)],
}
## Hair by class, [for men, for women] ("" = none: a shaved head, or the veil over it).
const HAIR := {
	Dress.SUIT: [["SimpleParted"], ["Buns", "Long"]],
	Dress.MIDDLE: [["SimpleParted", "Buzzed", ""], ["Long", "Buns", "BuzzedFemale"]],
	Dress.POOR: [["Beard", "Buzzed", "Long", ""], ["Long", "BuzzedFemale"]],
	Dress.HERO: [["Buzzed"], ["Buzzed"]],
	Dress.GUARD: [["Buzzed"], ["BuzzedFemale"]],
	Dress.MEDIC: [["Buzzed", "SimpleParted"], ["Buns"]],
	Dress.FRIEND: [["SimpleParted"], ["Long"]],
}
const BASE := "res://assets/third_party/quaternius_chars/"
## Skin tones for the faceless heads (and hands).
const SKIN: Array[Color] = [
	Color(0.74, 0.56, 0.44),
	Color(0.58, 0.42, 0.31),
	Color(0.42, 0.29, 0.21),
	Color(0.83, 0.67, 0.55),
	Color(0.32, 0.22, 0.16),
]
## Three tones split by height on the skinned body (model space, the figure upright):
## trousers below the hips, the top to the collar, the head and neck above.
const CLOTH_SHADER := """
shader_type spatial;

uniform vec3 top_color : source_color;
uniform vec3 bottom_color : source_color;
uniform vec3 skin_color : source_color;
uniform float hip = 0.95;
uniform float collar = 1.47;
uniform float rough = 0.8;
varying float height;

void vertex() {
	height = VERTEX.y;
}

void fragment() {
	bool head = height >= collar;
	vec3 c = height < hip ? bottom_color : (head ? skin_color * 0.85 : top_color);
	// Faceless: the head's shading flattened toward the viewer, so eyes, nose and mouth
	// melt into one matte form under the hair. The bodysuit's muscle relief softened.
	vec3 toward = normalize(vec3(0.0, 0.25, 1.0));
	NORMAL = normalize(mix(NORMAL, toward, head ? 0.85 : 0.4));
	ALBEDO = c;
	ROUGHNESS = head ? 0.9 : rough;
	SPECULAR = 0.12;
}
"""
const RIG := "res://assets/third_party/quaternius_anim/UAL1_Standard.glb"
const RIG_EXTRA := "res://assets/third_party/quaternius_anim/UAL2_Standard.glb"
## Clips that loop (the rest play once).
const LOOPING: Array[String] = [
	"Idle",
	"Walk",
	"Walk_Formal",
	"Sitting_Idle",
	"Idle_Talking",
	"Sitting_Talking",
	"ual2/Idle_No",
	"ual2/Idle_FoldArms",
	"ual2/Idle_TalkingPhone",
	"ual2/Walk_Carry",
]
## Sitting clips put the pelvis at chair height above the root: drop the root to sit.
const SIT_DROP := 0.47
## The Walk clip's ground speed at full scale, m/s.
const WALK_PACE := 1.4

static var _rig_scene: PackedScene
static var _rig_extra: AnimationLibrary
static var _rig_checked: bool = false
static var _tints: Dictionary = {}
static var _cloth_shader: Shader
static var _bodies: Dictionary = {}

@export var dress: Dress = Dress.MIDDLE
@export var pose: Pose = Pose.STAND

## Walking: legs swing while true (callers move the figure).
var moving: bool = false
var fight_target: Node3D
## Walk clip speed (1 = the clip's own pace); the hero walks briskly.
var anim_speed: float = 1.0
## When set, walks while this body moves and paces the clip to its speed (the player's
## avatar in the apartment).
var follow: PlayerMovement
## Arms full (moving boxes): walks with the carry clip, holds it when standing.
var carrying: bool = false
## A sheer fashion-tech veil over the face (the rich at dinner: their faces a product).
var veiled: bool = false
## Which base body: 0 man, 1 woman, −1 picked from where the figure stands (a crowd's mix,
## the same every run). Set before add_child.
var body: int = -1
## A body he can't walk through (the crowds in the play spaces press; the film's extras
## stay ghosts). Set before add_child.
var solid: bool = false

var _body: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _head: Node3D
var _bag: Node3D
var _phase: float = 0.0
var _home: Vector3
var _anim: AnimationPlayer
var _model: Node3D
var _punch: int = 0


func _ready() -> void:
	_phase = randf() * TAU
	if solid:
		_add_body()
	if _rig_available():
		_build_rig()
		_home = position
		if pose == Pose.WALK:
			moving = true
		_play_for_pose()
		return
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
	if _anim != null:
		if follow != null:
			var speed := follow.planar_speed()
			moving = speed > 0.15
			anim_speed = clampf(speed / (WALK_PACE * scale.x), 0.6, 2.5)
		if carrying and _anim.has_animation("ual2/Walk_Carry"):
			_play("ual2/Walk_Carry")
			_anim.speed_scale = anim_speed if moving else 0.0
		elif pose == Pose.WALK:
			_play(_walk_clip() if moving else "Idle")
			_anim.speed_scale = anim_speed if moving else 1.0
		return
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
	if _anim != null:
		moving = p == Pose.WALK
		_play_for_pose()
		return
	_body.rotation = Vector3.ZERO
	for leg in _legs:
		leg.rotation = Vector3.ZERO
	for arm in _arms:
		arm.rotation = Vector3.ZERO
	moving = p == Pose.WALK


## Both arms thrust: the shove that starts it.
func shove() -> void:
	if _anim != null:
		_anim.play("Push", 0.1)
		return
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
	if _anim != null:
		_anim.play("ual2/Hit_Knockback", 0.1)
		return
	t.parallel().tween_property(_body, "rotation:x", 0.35, 0.18)
	for arm in _arms:
		t.parallel().tween_property(arm, "rotation:x", -0.8, 0.18)
	t.tween_property(_body, "rotation:x", 0.0, 0.3)


## ----- RIGGED (Universal Animation Library) -------------------------------------------


## True when the rigged mannequin pack is installed.
static func has_rig() -> bool:
	return _rig_available()


static func _rig_available() -> bool:
	if not _rig_checked:
		_rig_checked = true
		if ResourceLoader.exists(RIG):
			_rig_scene = load(RIG)
		if ResourceLoader.exists(RIG_EXTRA):
			var extra: Node = (load(RIG_EXTRA) as PackedScene).instantiate()
			var player := _find_player(extra)
			if player != null:
				_rig_extra = player.get_animation_library(&"")
			extra.free()
	return _rig_scene != null


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_player(c)
		if found != null:
			return found
	return null


func _build_rig() -> void:
	_model = _rig_scene.instantiate()
	_model.rotation.y = PI  # the mannequin faces +Z; we face −Z
	add_child(_model)
	_anim = _find_player(_model)
	if _rig_extra != null and not _anim.has_animation_library(&"ual2"):
		_anim.add_animation_library(&"ual2", _rig_extra)
	for clip in LOOPING:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_on_clip_finished)
	_tint(_model, _tint_material())
	_dress_body()
	if veiled:
		_add_veil()
	if dress == Dress.HERO:
		# His shoulder bag at the right hip.
		var canvas := _mat(Color(0.24, 0.2, 0.15), 0.95)
		_box(_model, Vector3(-0.2, 0.92, 0.0), Vector3(0.1, 0.28, 0.34), canvas)


## The base character's body and hair on the rig's skeleton (same 65 joints), the
## mannequin hidden. No eyes, no brows: faceless. Nothing happens without the pack.
func _dress_body() -> void:
	var skeleton := _find_skeleton(_model)
	if skeleton == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(position * 10.0)) + int(dress) * 7919
	# He is a man; so is the friend, the same body in every scene (the game's lines say
	# "He sold me out"). The crowds mix.
	var fixed := dress == Dress.HERO or dress == Dress.FRIEND
	var woman := body == 1 or (body < 0 and not fixed and rng.randf() < 0.45)
	var body_scene := _base("Superhero_Female_FullBody" if woman else "Superhero_Male_FullBody")
	if body_scene == null:
		return
	var hair_pool: Array = HAIR[dress][1 if woman else 0]
	var hair_name: String = hair_pool[rng.randi() % hair_pool.size()]
	if veiled:
		hair_name = ""  # under the veil
	var meshes: Array[MeshInstance3D] = []
	var source := body_scene.instantiate()
	for mi: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "Eyes" and mi.name != "Eyebrows":
			meshes.append(mi)
	var hair_source: Node = null
	var hair_scene := _base("Hair_" + hair_name) if not hair_name.is_empty() else null
	if hair_scene != null:
		hair_source = hair_scene.instantiate()
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var outfit: Array = OUTFIT[dress]
	var cloth := ShaderMaterial.new()
	cloth.shader = _cloth_outfit_shader()
	cloth.set_shader_parameter("top_color", outfit[0])
	cloth.set_shader_parameter("bottom_color", outfit[1])
	cloth.set_shader_parameter("skin_color", SKIN[rng.randi() % SKIN.size()])
	cloth.set_shader_parameter("rough", maxf(float(CLOTH_ROUGH.get(dress, 0.85)), 0.8))
	for mi in meshes:
		_move_to(mi, skeleton, cloth)
	if hair_source != null:
		var hair := StandardMaterial3D.new()
		hair.albedo_color = Color(0.08, 0.07, 0.06).lerp(Color(0.32, 0.22, 0.14), rng.randf())
		hair.roughness = 0.7
		for mi: MeshInstance3D in hair_source.find_children("*", "MeshInstance3D", true, false):
			_move_to(mi, skeleton, hair)
		hair_source.free()
	source.free()


## Re-parent a skinned mesh under `skeleton` (its skin binds by bone name).
func _move_to(mi: MeshInstance3D, skeleton: Skeleton3D, mat: Material) -> void:
	mi.get_parent().remove_child(mi)
	mi.owner = null
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.material_override = mat


static func _base(asset: String) -> PackedScene:
	if not _bodies.has(asset):
		var path := BASE + asset + ".gltf"
		_bodies[asset] = load(path) if ResourceLoader.exists(path) else null
	return _bodies[asset]


static func _cloth_outfit_shader() -> Shader:
	if _cloth_shader == null:
		_cloth_shader = Shader.new()
		_cloth_shader.code = CLOTH_SHADER
	return _cloth_shader


## The veil rides the head bone: a sheer dark shell with a cold sheen.
func _add_veil() -> void:
	var skeleton := _find_skeleton(_model)
	if skeleton == null or skeleton.find_bone("Head") < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.bone_name = "Head"
	skeleton.add_child(mount)
	var veil := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 0.15
	shell.height = 0.32
	veil.mesh = shell
	veil.position = Vector3(0, 0.09, 0.02)
	var sheer := StandardMaterial3D.new()
	sheer.albedo_color = Color(0.03, 0.03, 0.05, 0.82)
	sheer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheer.metallic = 0.6
	sheer.roughness = 0.18
	veil.material_override = sheer
	mount.add_child(veil)


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null


func _tint(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_tint(c, mat)


func _tint_material() -> StandardMaterial3D:
	if not _tints.has(dress):
		var m := _cloth()
		if dress == Dress.SUIT:
			m.metallic = 0.2
			m.roughness = 0.35
		_tints[dress] = m
	return _tints[dress]


func _walk_clip() -> String:
	return "Walk_Formal" if dress == Dress.SUIT else "Walk"


func _play_for_pose() -> void:
	_model.position.y = -SIT_DROP if pose == Pose.SLUMP else 0.0
	match pose:
		Pose.STAND:
			_play("ual2/Idle_FoldArms" if dress == Dress.GUARD else "Idle")
		Pose.WALK:
			_play(_walk_clip() if moving else "Idle")
		Pose.SLUMP:
			_play("Sitting_Idle")
		Pose.HUDDLE:
			_play("Idle_Talking")
		Pose.ARGUE:
			_play("ual2/Idle_No")
		Pose.FIGHT:
			_play("Punch_Jab")
	# Desync the crowd: start each clip somewhere different.
	var clip := _anim.get_animation(_anim.current_animation)
	if clip != null and clip.loop_mode != Animation.LOOP_NONE:
		_anim.seek(randf() * clip.length, true)


func _play(clip: String) -> void:
	if _anim.current_animation != clip and _anim.has_animation(clip):
		_anim.play(clip, 0.25)


## One-shots hand back: punches alternate while fighting; a shove or a hit returns to
## the pose's own clip.
func _on_clip_finished(_clip: StringName) -> void:
	if pose == Pose.FIGHT:
		_punch += 1
		_anim.play("Punch_Cross" if _punch % 2 == 1 else "Punch_Jab", 0.1)
	else:
		_play_for_pose()


## ----- PRIMITIVE FALLBACK ----------------------------------------------------------------


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
	var c: Color = CLOTH.get(dress, Color(0.36, 0.36, 0.38))
	return _mat(c, CLOTH_ROUGH.get(dress, 0.85))


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


## A capsule his size (scaled with the figure), on the world layer the player collides with.
func _add_body() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	body.add_child(shape)
	add_child(body)
