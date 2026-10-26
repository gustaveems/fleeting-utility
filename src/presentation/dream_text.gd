class_name DreamText
extends CanvasLayer
## PRESENTATION — the meaning, as text (Ticket-20). In the dream, a reach writes half a
## sentence, holds, and unwrites it from the end ("They raised their arms because—"),
## then "It's gone." In the dual visions, each valley flash shows one lost sentence
## whole, in gold: the meaning stays. Listens to DreamMemory and DualVisionController.
##
## Layer 45: above the dream fade (30), under the dream HUD (50).

const REACH_COLOR := Color(1.0, 0.95, 0.86)
const STAYS_COLOR := Color(1.0, 0.82, 0.45)

@export var dream_memory: DreamMemory
@export var dual_vision: DualVisionController

## What is on screen now (tests read it).
var shown: String = ""

var _label: Label
var _start: String = ""
var _t: float = -1.0
var _vision_index: int = 0
var _fade_out: float = 0.0


func _ready() -> void:
	layer = 45
	_build()
	if dream_memory != null:
		dream_memory.reaching.connect(_on_reaching)
	if dual_vision != null:
		dual_vision.valley_phase_active.connect(_on_valley_phase)
		dual_vision.visions_ended.connect(_on_visions_ended)


func _on_reaching(start: String) -> void:
	_start = start
	_t = 0.0
	_label.add_theme_color_override("font_color", REACH_COLOR)


func _on_valley_phase(active: bool) -> void:
	if not active or dream_memory == null:
		return
	var lines := dream_memory.lost_fragments()
	if lines.is_empty():
		return
	_t = -1.0
	_fade_out = 0.0
	_show(lines[mini(_vision_index, lines.size() - 1)], 1.0, STAYS_COLOR)
	_vision_index += 1


func _on_visions_ended() -> void:
	_vision_index = 0
	if not shown.is_empty():
		_fade_out = 2.5


func _process(delta: float) -> void:
	if _fade_out > 0.0:
		_fade_out -= delta
		_label.modulate.a = clampf(_fade_out / 1.0, 0.0, 1.0)
		if _fade_out <= 0.0:
			_show("", 0.0, STAYS_COLOR)
	if _t < 0.0:
		return
	_t += delta
	var w := DreamMemoryScript.WRITE_SECONDS
	var h := DreamMemoryScript.HOLD_SECONDS
	var e := DreamMemoryScript.ERASE_SECONDS
	var g := DreamMemoryScript.GONE_SECONDS
	var text := _start + "—"
	if _t < w:
		_show(text.left(int(text.length() * _t / w)), 1.0, REACH_COLOR)
	elif _t < w + h:
		_show(text, 1.0, REACH_COLOR)
	elif _t < w + h + e:
		# Unwritten from the end: the meaning goes first, then the words that led to it.
		var keep := int(text.length() * (1.0 - (_t - w - h) / e))
		_show(text.left(keep) + "—" if keep > 0 else "", 1.0, REACH_COLOR)
	elif _t < w + h + e + g:
		var k := (_t - w - h - e) / g
		_show(DreamMemoryScript.GONE, sin(k * PI), REACH_COLOR.darkened(0.25))
	else:
		_t = -1.0
		_show("", 0.0, REACH_COLOR)


func _show(text: String, alpha: float, color: Color) -> void:
	shown = text
	_label.text = text
	_label.modulate.a = alpha
	_label.add_theme_color_override("font_color", color)


func _build() -> void:
	_label = Label.new()
	_label.name = "DreamLine"
	_label.theme = UiTheme.get_theme()
	_label.anchor_left = 0.1
	_label.anchor_right = 0.9
	_label.anchor_top = 0.36
	_label.anchor_bottom = 0.46
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
