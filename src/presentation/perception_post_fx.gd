class_name PerceptionPostFX
extends CanvasLayer
## PRESENTATION LAYER — owns the screen-space perception pass.
##
## Thin by design: this class is the boundary between logic and pixels. It subscribes to
## PerceptionDirector intensities and SoftBoundaryModel proximity and forwards them as
## shader uniforms. It contains no game rules and no interpretation — if a future ticket
## needs "blurrier when Sensory Overload is high", the meter feeds crash_intensity, it
## does not add a second uniform path through here.
##
## A ColorRect under a dedicated CanvasLayer rather than a Camera3D attribute/Environment
## effect because all three effects (blur, chromatic aberration, vignette) are one shader
## and must blend together; see assets/shaders/perception_post.gdshader for the reasoning.

const SHADER := preload("res://assets/shaders/perception_post.gdshader")

## Above the world and the dev HUD's peers; low enough to stay under future modal UI.
@export var fx_layer: int = 5

var _rect: ColorRect
var _material: ShaderMaterial

var _crash_intensity: float = 0.0
var _focus_intensity: float = 0.0
var _edge_proximity: float = 0.0
var _dirty: bool = true


func _ready() -> void:
	layer = fx_layer
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "PerceptionPass"
	_rect.material = _material
	# A full-rect Control on top of the view would otherwise swallow every mouse click
	# before Ticket-03's crafting interactions ever see one.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	_push()


func set_crash_intensity(intensity: float) -> void:
	_crash_intensity = clampf(intensity, 0.0, 1.0)
	_dirty = true


func set_focus_intensity(intensity: float) -> void:
	_focus_intensity = clampf(intensity, 0.0, 1.0)
	_dirty = true


func set_edge_proximity(proximity: float) -> void:
	_edge_proximity = clampf(proximity, 0.0, 1.0)
	_dirty = true


## Uniforms are pushed once per frame rather than per setter call, because the crash
## intensity ramp fires a signal every single frame of its transition.
func _process(_delta: float) -> void:
	if _dirty:
		_push()
		_dirty = false


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("crash_intensity", _crash_intensity)
	_material.set_shader_parameter("focus_intensity", _focus_intensity)
	_material.set_shader_parameter("edge_proximity", _edge_proximity)
