class_name Easel
extends Interactable
## PRESENTATION — mastery in vain (Ticket-14, loop 2). "[E] Hold to paint".
##
## Holding E lays paint; releasing pauses. Base 4 s per work; High-Focus halves it and
## a crash doubles it, like the bench. The wet canvas on the easel paints his state
## (see PaintedWork). Finished works hang on the west wall, three hooks.
##
## The verdict is never satisfied. Skill rises with every work (the paintings do get
## better), but nothing is ever good enough, and every morning the lease reclaims the
## wall (DayCycle.morning). Skill is his and outlives the works, even a renewed lease.

## Emitted with his verdict when a work is finished (the HUD shows it).
signal work_finished(verdict: String)
## Emitted when the lease clears the wall at morning.
signal works_reclaimed
## Emitted every brush stroke while painting (audio).
signal stroke

const EASEL_MODEL := "res://assets/third_party/polypizza/easel/easel.glb"
const VERDICT_LOW := "It's nothing. A smear."
const VERDICT_MID := "Closer. Still wrong."
const VERDICT_HIGH := "Technically fine. It means nothing."
const VERDICTS: Array[String] = [VERDICT_LOW, VERDICT_MID, VERDICT_HIGH]
const RECLAIM_TEXT := "The lease does not permit alterations. Your works have been removed."
const FULL_TEXT := "No more wall. The lease allows three."

const BASE_PAINT_SECONDS := 4.0
const SKILL_PER_WORK := 0.08
const STROKE_SECONDS := 0.35

## Wall hooks (room coordinates): the inside face of the west wall, facing +X.
const HOOKS: Array[Vector3] = [
	Vector3(-4.42, 0.78, -0.1), Vector3(-4.42, 0.78, 1.1), Vector3(-4.42, 0.78, 2.3)
]

@export var state_data: PlayerStateData
@export var day_cycle: DayCycle

## 0..1, rises with practice; never buys satisfaction.
var skill: float = 0.0
## 0..1 progress of the canvas on the easel.
var progress: float = 0.0

var _works: Array[PaintedWork] = []
var _wet: PaintedWork
var _stroke_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	prompt_text = "[E] Hold to paint"
	super()
	_rng.randomize()
	_build()
	if day_cycle != null:
		day_cycle.morning.connect(func(_day: int): reclaim())
		day_cycle.cycle_reset.connect(_clear_works)


func _process(delta: float) -> void:
	if not is_player_near:
		return
	var holding := Input.is_action_pressed(InputActionData.ACTION_INTERACT) and can_interact()
	if holding:
		progress = minf(progress + delta / _paint_seconds(), 1.0)
		_update_wet()
		_stroke_timer -= delta
		if _stroke_timer <= 0.0:
			_stroke_timer = STROKE_SECONDS
			stroke.emit()
		if progress >= 1.0:
			_finish()
	refresh_prompt()


func can_interact() -> bool:
	if interaction_controller != null and interaction_controller.is_locked:
		return false
	return _works.size() < HOOKS.size()


func current_prompt() -> String:
	if not can_interact():
		return blocked_prompt()
	if progress > 0.0:
		return "Painting… %d%%" % int(progress * 100.0)
	return prompt_text


func blocked_prompt() -> String:
	if _works.size() >= HOOKS.size():
		return FULL_TEXT
	return ""  # locked by a compulsion: the compulsion's own prompt shows


## A press without holding does nothing; painting is a hold (see _process).
func try_interact() -> bool:
	return false


func hung_works() -> Array[PaintedWork]:
	return _works.duplicate()


## The lease clears the wall (morning).
func reclaim() -> void:
	if _works.is_empty():
		return
	_clear_works()
	works_reclaimed.emit()


## Persistence.
func snapshot() -> Dictionary:
	var works := []
	for w in _works:
		works.append(w.to_dict())
	return {"skill": skill, "works": works}


func restore(data: Dictionary) -> void:
	skill = clampf(float(data.get("skill", 0.0)), 0.0, 1.0)
	_clear_works()
	for d in data.get("works", []):
		var w := _hang()
		if w != null:
			w.from_dict(d)


## ----- INTERNALS -------------------------------------------------------------------------


func _paint_seconds() -> float:
	if state_data == null:
		return BASE_PAINT_SECONDS
	if state_data.is_crashed():
		return BASE_PAINT_SECONDS * 2.0
	if state_data.is_high_focus():
		return BASE_PAINT_SECONDS * 0.5
	return BASE_PAINT_SECONDS


func _state_params() -> Dictionary:
	var chem := state_data.chemical_level if state_data != null else 0.5
	var overload := state_data.sensory_overload if state_data != null else 0.0
	var crash := clampf((overload - 50.0) / 50.0, 0.0, 1.0)
	var focus := 1.0 if state_data != null and state_data.is_high_focus() else chem
	return {
		"vividness": clampf(0.25 + chem * 0.75, 0.0, 1.0),
		"smear": crash,
		"flatness": 1.0 if chem <= 0.0 else 0.0,
		"coherence": clampf(0.15 + skill * 0.85, 0.0, 1.0),
		"focus": focus,
		"crash": crash,
	}


func _update_wet() -> void:
	var p := _state_params()
	_wet.vividness = p["vividness"]
	_wet.smear = p["smear"]
	_wet.flatness = p["flatness"]
	_wet.coherence = p["coherence"]
	_wet.apply_params(progress)


func _finish() -> void:
	var p := _state_params()
	var quality: float = skill * 0.6 + float(p["focus"]) * 0.4 - float(p["crash"]) * 0.3
	var work := _hang()
	work.seed_value = _wet.seed_value
	work.vividness = p["vividness"]
	work.smear = p["smear"]
	work.flatness = p["flatness"]
	work.coherence = p["coherence"]
	work.apply_params()
	skill = minf(skill + SKILL_PER_WORK, 1.0)
	progress = 0.0
	_wet.seed_value = float(_rng.randi_range(1, 99999))
	_wet.apply_params(0.0)
	var verdict := VERDICT_LOW
	if quality >= 0.55:
		verdict = VERDICT_HIGH
	elif quality >= 0.3:
		verdict = VERDICT_MID
	work_finished.emit(verdict)


func _hang() -> PaintedWork:
	if _works.size() >= HOOKS.size() or get_parent() == null:
		return null
	var work := PaintedWork.new()
	work.name = "Work_%d" % _works.size()
	# Hooks are room coordinates; the easel's parent is the apartment root.
	get_parent().add_child(work)
	work.position = HOOKS[_works.size()]
	work.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_works.append(work)
	return work


func _clear_works() -> void:
	for w in _works:
		if is_instance_valid(w):
			w.queue_free()
	_works.clear()


func _build() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.3
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 1.0, 0.0)
	add_child(shape)

	# The real easel (Poly Pizza "Easel Large Leaning" by reyshapes, CC0), scaled from its
	# 7 m model to ~1.3 m; the box legs are the fallback.
	var model := CityKit.prop(EASEL_MODEL, self, Vector3(0.0, 0.0, -0.05), 180.0, 0.0)
	if model != null:
		model.scale = Vector3.ONE * 0.19
		_stain(model, _dark_wood())
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.22, 0.15)
	# Legs stay behind the canvas plane (z 0.12), or they show through the paint.
	for leg in (
		[]
		if model != null
		else [Vector3(-0.3, 0.6, 0.0), Vector3(0.3, 0.6, 0.0), Vector3(0.0, 0.6, -0.25)]
	):
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.04, 1.2, 0.04)
		m.mesh = b
		m.material_override = wood
		m.position = leg
		add_child(m)

	_wet = PaintedWork.new()
	_wet.name = "WetCanvas"
	_wet.position = Vector3(0.0, 1.05, 0.12)
	_wet.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_wet.seed_value = float(_rng.randi_range(1, 99999))
	add_child(_wet)
	_wet.apply_params(0.0)


## Old dark wood over the model's pale baked colours.
func _dark_wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.15, 0.1)
	m.roughness = 0.85
	return m


func _stain(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_stain(c, mat)
