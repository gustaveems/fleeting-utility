class_name NoticeEnvelope
extends Interactable
## PRESENTATION — the white envelope on the floor inside his door (docs/STORY.md 8a). Only
## there, and only readable, while DailyLife holds a notice.

@export var daily: DailyLife
@export var panel: NoticePanel

var _paper: MeshInstance3D


func _ready() -> void:
	prompt_text = DailyLifeScript.NOTICE_PROMPT
	super()
	_build()
	if daily != null:
		daily.notice_arrived.connect(_sync)
	_sync()


func can_interact() -> bool:
	return daily != null and daily.has_notice()


func is_showing() -> bool:
	return _paper != null and _paper.visible


func _on_interacted() -> void:
	var notice := daily.notice()
	daily.read_notice()
	_sync()
	if panel != null:
		panel.open(notice)


func _sync() -> void:
	if _paper != null:
		_paper.visible = can_interact()


func _build() -> void:
	var zone := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.2, 0.9)
	zone.shape = box
	zone.position = Vector3(0, 0.6, 0)
	add_child(zone)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.9, 0.84)
	mat.roughness = 0.7
	_paper = MeshInstance3D.new()
	_paper.name = "Envelope"
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.2, 0.006, 0.13)
	_paper.mesh = sheet
	_paper.material_override = mat
	_paper.position = Vector3(0, 0.012, 0)
	_paper.rotation_degrees.y = 24.0
	add_child(_paper)
