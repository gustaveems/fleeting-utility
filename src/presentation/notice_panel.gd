class_name NoticePanel
extends CanvasLayer
## PRESENTATION — a sheet of paper held up to read (docs/STORY.md 8a). He stands still while
## it's open; E puts it down.

signal closed

const LOCK := &"notice"
const PAPER := Color(0.86, 0.84, 0.78)
const INK := Color(0.12, 0.11, 0.1)

@export var player: PlayerMovement
@export var interaction: InteractionController

var is_open: bool = false

var _sheet: PanelContainer
var _from: Label
var _title: Label
var _body: Label
var _armed: bool = false


func _ready() -> void:
	layer = 60
	_build()
	_sheet.visible = false


func _process(_delta: float) -> void:
	if not is_open:
		return
	# The E that opened it is still down: wait for a fresh press.
	if not Input.is_action_pressed(InputActionData.ACTION_INTERACT):
		_armed = true
	elif _armed:
		close()


func open(notice: Array) -> void:
	_from.text = str(notice[0])
	_title.text = str(notice[1])
	_body.text = str(notice[2])
	_sheet.visible = true
	is_open = true
	_armed = false
	if player != null:
		player.lock_input(LOCK)
	if interaction != null:
		interaction.lock(LOCK)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_sheet.visible = false
	if player != null:
		player.unlock_input(LOCK)
	if interaction != null:
		interaction.unlock(LOCK)
	closed.emit()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.rotation_degrees = -1.2
	_sheet.custom_minimum_size = Vector2(520, 0)
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.set_content_margin_all(34)
	paper.shadow_color = Color(0, 0, 0, 0.6)
	paper.shadow_size = 14
	_sheet.add_theme_stylebox_override("panel", paper)
	center.add_child(_sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_sheet.add_child(column)
	_from = _line(column, 13, Color(0.42, 0.38, 0.32))
	_title = _line(column, 25, INK)
	_body = _line(column, 17, INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(450, 0)
	var hint := _line(column, 13, Color(0.42, 0.38, 0.32))
	hint.text = "[E] Put it down"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _line(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
