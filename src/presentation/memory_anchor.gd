class_name MemoryAnchor
extends Area3D
## PRESENTATION — a glowing memory anchor in the dreamscape (Ticket-05 Task 3).
##
## When the player enters the anchor's zone and presses E, the anchor emits
## `memory_triggered` and the DreamscapeManager initiates an immediate return to the
## apartment with a white flash effect.
##
## VISUAL: SphereMesh with a pulsing emission shader (gold/amber glow).
## PLACEMENT: Created by DreamscapeEnvironment near 3 of the 4 statues.

signal memory_triggered

@export var dreamscape_manager: DreamscapeManager

var _near_player: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Build the glowing sphere.
	var mesh := MeshInstance3D.new()
	mesh.name = "GlowSphere"
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mesh.mesh = sphere

	# Pulsing emission shader.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform float pulse_speed = 2.0;
uniform vec3 glow_color = vec3(1.0, 0.9, 0.5);

void fragment() {
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	ALBEDO = glow_color;
	EMISSION = glow_color * pulse * 2.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("pulse_speed", 2.0)
	mat.set_shader_parameter("glow_color", Color(1.0, 0.9, 0.5))
	mesh.material_override = mat
	add_child(mesh)

	# Collision shape for the anchor zone. The anchor floats at y=1.5, so the shape is
	# centred on the anchor with height 3.0 — spanning world y 0..3. A 2.0 m shape here
	# left the zone floating at y 1.5..3.5, entirely above the player capsule (0..0.8),
	# so ground-level proximity never fired (caught by tools/ticket05_verify.gd).
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 3.0
	cylinder.height = 3.0
	shape.shape = cylinder
	add_child(shape)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerMovement:
		_near_player = true
		if dreamscape_manager != null:
			dreamscape_manager._set_anchor_near(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerMovement:
		_near_player = false
		if dreamscape_manager != null:
			dreamscape_manager._set_anchor_near(self, false)


## Gate interaction + collision. The ambulance interception calls set_enabled(false) on
## every anchor so the player cannot escape the sequence via the manual E return.
func set_enabled(enabled: bool) -> void:
	monitoring = enabled
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled
