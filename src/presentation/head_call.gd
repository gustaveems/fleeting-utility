class_name HeadCall
extends CanvasLayer
## PRESENTATION — calls straight into his head (canon 2026-10-21: an implant, leased like
## everything else; voices only, no faces). A caller card slides in with a pulsing voice
## meter while the line plays as a subtitle. The same overlay also subtitles people
## talking in person (play(lines, false): no caller card).
##
##   head_call.play(NightZeroScript.CALL_ARRIVAL)      # await head_call.finished
##
## Lines are [speaker, text, seconds]. Speaker HIM is shown in a muted colour.

signal finished
signal line_shown(index: int)

const CALL_COLOR := Color(0.2, 0.84, 0.9)
const SPEAKER_COLOR := Color(0.95, 0.78, 0.45)
const HIM_COLOR := Color(0.75, 0.75, 0.72)

var is_playing: bool = false

var _card: PanelContainer
var _caller: Label
var _bars: Array[ColorRect] = []
var _subtitle: Label
var _lines: Array = []
var _index: int = -1
var _left: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	layer = 35
	_build()
	_card.visible = false
	_subtitle.visible = false


## Play `lines`; `as_call` shows the incoming-call card (a head call) instead of plain
## in-person subtitles.
func play(lines: Array, as_call: bool = true) -> void:
	_lines = lines
	_index = -1
	is_playing = true
	_card.visible = as_call
	if as_call and not lines.is_empty():
		_caller.text = "INCOMING · " + str(lines[0][0])
	_next()


## Skip to the end (scripted sequences, tests).
func stop() -> void:
	if not is_playing:
		return
	is_playing = false
	_card.visible = false
	_subtitle.visible = false
	finished.emit()


func _process(delta: float) -> void:
	if not is_playing:
		return
	_t += delta
	for i in _bars.size():
		_bars[i].custom_minimum_size.y = 6.0 + absf(sin(_t * (7.0 + i * 1.7) + i)) * 18.0
	_left -= delta
	if _left <= 0.0:
		_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		stop()
		return
	var line: Array = _lines[_index]
	var speaker := str(line[0])
	_subtitle.text = "%s:  %s" % [speaker, line[1]]
	var him := speaker == NightZeroScript.HIM
	_subtitle.add_theme_color_override("font_color", HIM_COLOR if him else SPEAKER_COLOR)
	_subtitle.visible = true
	_left = float(line[2])
	line_shown.emit(_index)


func _build() -> void:
	var theme := UiTheme.get_theme()
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.85)
	style.border_color = CALL_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", style)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -170
	_card.offset_right = 170
	_card.offset_top = 70
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_card.add_child(row)
	_caller = Label.new()
	_caller.theme = theme
	_caller.add_theme_font_size_override("font_size", 16)
	_caller.add_theme_color_override("font_color", CALL_COLOR)
	row.add_child(_caller)
	var meter := HBoxContainer.new()
	meter.alignment = BoxContainer.ALIGNMENT_CENTER
	meter.add_theme_constant_override("separation", 3)
	row.add_child(meter)
	for i in 7:
		var bar := ColorRect.new()
		bar.color = CALL_COLOR
		bar.custom_minimum_size = Vector2(3, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.add_child(bar)
		_bars.append(bar)
	_subtitle = Label.new()
	_subtitle.theme = theme
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.anchor_left = 0.12
	_subtitle.anchor_right = 0.88
	_subtitle.anchor_top = 0.78
	_subtitle.anchor_bottom = 0.86
	_subtitle.add_theme_font_size_override("font_size", 21)
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_subtitle)
