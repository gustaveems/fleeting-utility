class_name ColossusFigure
extends Node3D
## PRESENTATION — a striding colossus after the Colossus of Rhodes (canon 2026-10-19).
## Feet on two plinths `stance` apart (things pass between its legs), the torch raised.
## The figure is the characters' own base body on the UAL skeleton, posed from the torch
## clip with its legs spread over the plinths and scaled up (playtest 2026-10-30: the
## capsule figure read as "flat, no textures"); without those packs, capsules.
##
##   Style.GOLD_COPY   the corporation's mascot: a CHEAP copy. Gaudy gold paint, moulding
##                     seams where the fibreglass panels meet, the paint chipping to grey,
##                     a logo plate on the plinth.
##   Style.STONE       the dream's real colossi: weathered stone, lichen on what faces the
##                     sky, rain streaks, blood running down the legs and plinths.
## Origin = midpoint between the plinths at ground level; it faces local −Z.

enum Style { GOLD_COPY, STONE }

## The torch held up: the pose, and the moment of the clip it is frozen at.
const POSE_CLIP := "Idle_Torch"
const POSE_AT := 0.4
const BODY := "Superhero_Male_FullBody"

## Both styles: the surface is drawn in the mesh's own space, so it sticks to the figure
## at any scale (`grain` = noise cells per local unit). Blood (STONE) is strongest at
## `blood_from` and gone by `blood_to` (local y).
const SKIN_SHADER := """
shader_type spatial;

uniform int style = 1;  // 0 gold copy, 1 stone
uniform vec3 base_color : source_color = vec3(0.34, 0.32, 0.30);
uniform float grain = 2.0;
uniform float blood = 0.0;
uniform float blood_from = 0.0;
uniform float blood_to = 1.0;
uniform float seam_step = 0.3;

varying vec3 local_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = local_pos * grain;
	float big = fbm(p * 0.35);
	float fine = fbm(p * 3.0);
	float h;
	vec3 c;
	float rough;
	float metal = 0.0;
	if (style == 1) {
		// Weathered stone: blotched tone, pitting, rain streaks, lichen facing the sky.
		c = base_color * mix(0.72, 1.18, big) * mix(0.9, 1.08, fine);
		float streak = smoothstep(0.55, 0.85, noise(vec3(p.x * 4.0, p.y * 0.25, p.z * 4.0)));
		c *= 1.0 - streak * 0.3;
		float up = clamp(world_normal.y, 0.0, 1.0);
		float lichen = smoothstep(0.55, 0.75, fbm(p * 0.9 + 7.0)) * smoothstep(0.2, 0.7, up);
		c = mix(c, vec3(0.42, 0.44, 0.26), lichen * 0.7);
		float t = clamp((local_pos.y - blood_from) / (blood_to - blood_from), 0.0, 1.0);
		float runs = smoothstep(0.5, 0.7, noise(vec3(p.x * 2.5, p.y * 0.15, p.z * 2.5)));
		float b = blood * runs * (1.0 - t) * (1.0 - t);
		c = mix(c, vec3(0.32, 0.03, 0.02), clamp(b * 1.4, 0.0, 0.9));
		h = big * 0.6 + fine * 0.4 - streak * 0.2;
		rough = mix(0.95, 0.55, b);
	} else {
		// Cheap gold paint: panel seams, a sheen, chips to the grey fibreglass beneath.
		float seam = abs(fract(local_pos.y / seam_step + 0.5) - 0.5) * seam_step;
		float on_seam = 1.0 - smoothstep(seam_step * 0.012, seam_step * 0.03, seam);
		float chip = smoothstep(0.68, 0.72, fbm(p * 1.6 + 3.0));
		c = base_color * mix(0.85, 1.12, big);
		c = mix(c, vec3(0.42, 0.41, 0.4), chip);
		c = mix(c, base_color * 0.25, on_seam);
		h = fine * 0.3 - on_seam - chip * 0.4;
		rough = mix(0.38, 0.9, max(chip, on_seam));
		metal = mix(0.45, 0.0, max(chip, on_seam));
	}
	// Bump from the height field, by screen derivatives (no tangents needed).
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.6);
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
}
"""

static var _shader: Shader

@export var style: Style = Style.GOLD_COPY
@export var height: float = 50.0
@export var stance: float = 24.0

## The point gaze shots look at (the head), set by _ready.
var head: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	var s := height / 50.0
	var plinth_h := 8.0 * s
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	var feet := _build_body(plinth_h)
	if feet.is_empty():
		feet = _build_capsules(s, plinth_h)
	var plinth := _skin(
		Color(0.3, 0.28, 0.26) if style == Style.GOLD_COPY else Color(0.45, 0.43, 0.40), 1.2 / s
	)
	if style == Style.STONE:
		plinth.set_shader_parameter("blood", 1.0)
		plinth.set_shader_parameter("blood_from", plinth_h * 0.5)
		plinth.set_shader_parameter("blood_to", -plinth_h * 0.5)
	for x: float in feet:
		_box(Vector3(x, plinth_h * 0.5, 0), Vector3(9, plinth_h, 9) * s, plinth)
	if style == Style.GOLD_COPY:
		_logo_plate(Vector3(feet[-1], plinth_h * 0.6, -4.6 * s), s)


## The base body on the rig, frozen holding the torch up, legs spread so the feet land
## `stance` apart, scaled to stand `height` tall on the plinths. Returns the feet's x
## (for the plinths), or [] without the packs.
func _build_body(plinth_h: float) -> Array:
	var rig := StreetFigure.rig()
	var body_scene := StreetFigure.base_body(BODY)
	if rig == null or body_scene == null:
		return []
	var model: Node3D = rig.instantiate()
	model.name = "Figure"
	model.rotation.y = PI  # the rig faces +Z; the colossus faces −Z
	add_child(model)
	var skeleton := StreetFigure.find_skeleton(model)
	var anim := StreetFigure.find_player(model)
	if skeleton == null or anim == null or not anim.has_animation(POSE_CLIP):
		model.free()
		return []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	var skin := _skin(
		Color(0.86, 0.66, 0.22) if style == Style.GOLD_COPY else Color(0.36, 0.34, 0.32), 22.0
	)
	if style == Style.STONE:
		skin.set_shader_parameter("blood", 1.0)
		skin.set_shader_parameter("blood_from", 0.0)
		skin.set_shader_parameter("blood_to", 0.75)
	else:
		skin.set_shader_parameter("seam_step", 0.28)
	var source := body_scene.instantiate()
	for mi: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Eyes" or mi.name == "Eyebrows":
			continue
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.material_override = skin
	source.free()
	# Freeze the pose: apply the clip once, then drop the player.
	anim.play(POSE_CLIP)
	anim.seek(POSE_AT, true)
	anim.get_parent().remove_child(anim)
	anim.free()
	# Spread the legs about the figure's forward axis until the feet are `stance` apart
	# (in rig units, before scaling: the scale comes from the spread figure's height).
	var foot_l := skeleton.find_bone("foot_l")
	var foot_r := skeleton.find_bone("foot_r")
	var top := skeleton.find_bone("Head")
	var rest_h := _bone_at(skeleton, top).y - _bone_at(skeleton, foot_l).y
	var scale_guess := (height - plinth_h) / (rest_h * 1.12)
	var want := stance / scale_guess
	for k in 6:
		var gap := _bone_at(skeleton, foot_l).distance_to(_bone_at(skeleton, foot_r))
		if gap >= want * 0.97:
			break
		_spread(skeleton, "thigh_l", (want - gap) * 0.5)
		_spread(skeleton, "thigh_r", (want - gap) * 0.5)
	# Scale so the head (plus the skull above its joint) stands at `height`.
	var low := minf(_bone_at(skeleton, foot_l).y, _bone_at(skeleton, foot_r).y)
	var tall := (_bone_at(skeleton, top).y - low) * 1.12
	var k_scale := (height - plinth_h) / tall
	model.scale = Vector3.ONE * k_scale
	# Rest the feet on the plinths, centred between them.
	var fl := _in_figure(model, skeleton, foot_l)
	var fr := _in_figure(model, skeleton, foot_r)
	model.position += Vector3(
		-(fl.x + fr.x) * 0.5, plinth_h - minf(fl.y, fr.y), -(fl.z + fr.z) * 0.5
	)
	fl = _in_figure(model, skeleton, foot_l)
	fr = _in_figure(model, skeleton, foot_r)
	head.position = _in_figure(model, skeleton, top) + Vector3(0, tall * 0.04 * k_scale, 0)
	# The torch in the raised fist.
	var hand_l := _in_figure(model, skeleton, skeleton.find_bone("hand_l"))
	var hand_r := _in_figure(model, skeleton, skeleton.find_bone("hand_r"))
	_torch(hand_l if hand_l.y > hand_r.y else hand_r, skin)
	return [fl.x, fr.x]


## A torch held upright in the fist: a shaft, the bowl on top.
func _torch(fist: Vector3, mat: Material) -> void:
	var u := height / 50.0
	var shaft := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.45 * u
	rod.bottom_radius = 0.35 * u
	rod.height = 7.0 * u
	shaft.mesh = rod
	shaft.material_override = mat
	shaft.position = fist + Vector3(0, 1.5 * u, 0)
	add_child(shaft)
	var bowl := MeshInstance3D.new()
	var cup := CylinderMesh.new()
	cup.top_radius = 1.6 * u
	cup.bottom_radius = 0.5 * u
	cup.height = 1.8 * u
	bowl.mesh = cup
	bowl.material_override = mat
	bowl.position = fist + Vector3(0, 5.6 * u, 0)
	add_child(bowl)


## Rotate a thigh outward (away from the figure's middle) so its foot moves ~`by` rig
## units sideways.
func _spread(skeleton: Skeleton3D, thigh_name: String, by: float) -> void:
	var thigh := skeleton.find_bone(thigh_name)
	var parent := skeleton.get_bone_parent(thigh)
	if thigh < 0 or parent < 0:
		return
	var at := skeleton.get_bone_global_pose(thigh)
	var foot := _bone_at(skeleton, skeleton.find_bone("foot_" + thigh_name.right(1)))
	var leg := maxf(at.origin.distance_to(foot), 0.01)
	var side := signf(at.origin.x) if absf(at.origin.x) > 0.001 else 1.0
	var angle := side * asin(clampf(by / leg, -0.9, 0.9))
	var global_basis := Basis(Vector3.BACK, angle) * at.basis
	var local := skeleton.get_bone_global_pose(parent).basis.inverse() * global_basis
	skeleton.set_bone_pose_rotation(thigh, local.get_rotation_quaternion())


func _bone_at(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.get_bone_global_pose(bone).origin


## A bone's position in this figure's space (through the model's transform and the
## skeleton's place in it).
func _in_figure(model: Node3D, skeleton: Skeleton3D, bone: int) -> Vector3:
	var xf := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != model and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return model.transform * (xf * _bone_at(skeleton, bone))


## The greybox figure from primitives (no character packs). Returns the feet's x.
func _build_capsules(s: float, plinth_h: float) -> Array:
	var skin := _skin(
		Color(0.86, 0.66, 0.22) if style == Style.GOLD_COPY else Color(0.36, 0.34, 0.32), 0.5 / s
	)
	if style == Style.STONE:
		skin.set_shader_parameter("blood", 1.0)
		skin.set_shader_parameter("blood_from", -10.0 * s)
		skin.set_shader_parameter("blood_to", 4.0 * s)
	else:
		skin.set_shader_parameter("seam_step", 6.0 * s)
	var half := stance * 0.5
	var hip := Vector3(0, plinth_h + 18.0 * s, 0)
	for side in [-1.0, 1.0]:
		var foot := Vector3(side * half, plinth_h, 0)
		_limb(foot, hip + Vector3(side * 3.0 * s, 0, 0), 2.6 * s, skin)
	var chest := hip + Vector3(0, 13.0 * s, 0)
	_limb(hip, chest, 5.2 * s, skin)
	head.position = chest + Vector3(0, 5.0 * s, 0)
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
	return [-half, half]


func _skin(color: Color, grain: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SKIN_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("style", 0 if style == Style.GOLD_COPY else 1)
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("grain", grain)
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


func _logo_plate(at: Vector3, s: float) -> void:
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.9, 0.9, 0.92)
	plate.emission_enabled = true
	plate.emission = Color(0.2, 0.84, 0.9)
	plate.emission_energy_multiplier = 1.2
	_box(at, Vector3(4.0, 1.6, 0.2) * s, plate)
