class_name SoftBoundaryPresentation
extends Node
## PRESENTATION LAYER — turns SoftBoundaryModel's 0..1 proximity into visible fog.
##
## Constraint #6 is the whole reason this class exists: the workspace has an edge, and
## that edge must be communicated atmospherically rather than by a collider. As the
## player approaches the leased room's limit the air itself thickens — fog density and
## volumetric scatter climb, the key light dies, and PerceptionPostFX closes its
## vignette. The player is not stopped by geometry; they are discouraged by the room
## becoming unreadable, which is also thematically exact for a space that was never his.
##
## It mutates the shared Environment resource rather than owning one, so lighting stays
## authored in one place (GameBootstrap) and this stays a pure modifier. Note that
## volumetric fog is a Forward+/Mobile feature: on the Compatibility backend the
## `volumetric_*` values are inert and the effect degrades to plain fog + vignette,
## which still satisfies the constraint.

## Fog density at the room's centre (clean air, medicated or not).
@export var base_fog_density: float = 0.006

## Fog density at the wall. Forward+ default scene units.
@export var max_fog_density: float = 0.085

@export var base_volumetric_density: float = 0.015
@export var max_volumetric_density: float = 0.16

## Key light energy multiplier at the edge — the room dims as its limits assert themselves.
@export var min_light_multiplier: float = 0.45

var _environment: Environment
var _light: DirectionalLight3D
var _light_base_energy: float = 1.0
var _proximity: float = 0.0


## Called once by GameBootstrap after the world exists.
func bind(environment: Environment, light: DirectionalLight3D) -> void:
	_environment = environment
	_light = light
	if _light != null:
		_light_base_energy = _light.light_energy


func set_proximity(proximity: float) -> void:
	_proximity = clampf(proximity, 0.0, 1.0)
	_apply()


func _apply() -> void:
	if _environment != null:
		_environment.fog_density = lerpf(base_fog_density, max_fog_density, _proximity)
		_environment.volumetric_fog_density = lerpf(
			base_volumetric_density, max_volumetric_density, _proximity
		)
	if _light != null:
		_light.light_energy = _light_base_energy * lerpf(1.0, min_light_multiplier, _proximity)
