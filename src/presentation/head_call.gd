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
## Caller colours: the friend cyan, the corporation gold.
const CALLER_COLORS := {"FOCUS+ CARE": Color(0.95, 0.75, 0.3)}
## A call that pauses this long between lines is a new call (its timer restarts).
const CALL_GAP := 1.0
const SPEAKER_COLOR := Color(0.95, 0.78, 0.45)
const HIM_COLOR := Color(0.75, 0.75, 0.72)

var is_playing: bool = false
## E skips to the next line (the evening; never the prologue's film).
var allow_skip: bool = false

var _card: PanelContainer
var _card_style: StyleBoxFlat
var _ring: Panel
var _ring_style: StyleBoxFlat
var _caller: Label
var _timer: Label
var _call_seconds: float = 0.0
var _card_hidden_for: float = 99.0
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
		var speaker := str(lines[0][0])
		# He answers inside the call: the card keeps the caller's name and timer.
		if speaker != NightZeroScript.HIM and speaker != NightZeroScript.THOUGHT:
			if speaker != _caller.text or _card_hidden_for > CALL_GAP:
				_call_seconds = 0.0
			_caller.text = speaker
			_tint(CALLER_COLORS.get(speaker, CALL_COLOR))
	_next()


## The line on screen now as [speaker, text, seconds], or [] (the voice under it: Phase D).
func current_line() -> Array:
	if not is_playing or _index < 0 or _index >= _lines.size():
		return []
	return _lines[_index]


## A head call (the caller card is up), not people talking in the room.
func is_call() -> bool:
	return _card.visible


## Skip to the end (scripted sequences, tests).
func stop() -> void:
	if not is_playing:
		return
	is_playing = false
	_card.visible = false
	_subtitle.visible = false
	finished.emit()


func _process(delta: float) -> void:
	_card_hidden_for = 0.0 if _card.visible else _card_hidden_for + delta
	if not is_playing:
		return
	_t += delta
	if _card.visible:
		_call_seconds += delta
		_timer.text = "%02d:%02d" % [int(_call_seconds) / 60, int(_call_seconds) % 60]
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		_ring_style.border_width_left = 2 + int(pulse * 3)
		_ring_style.border_width_right = _ring_style.border_width_left
		_ring_style.border_width_top = _ring_style.border_width_left
		_ring_style.border_width_bottom = _ring_style.border_width_left
	for i in _bars.size():
		_bars[i].custom_minimum_size.y = 6.0 + absf(sin(_t * (7.0 + i * 1.7) + i)) * 18.0
	_left -= delta
	var skip := allow_skip and Input.is_action_just_pressed(InputActionData.ACTION_INTERACT)
	if _left <= 0.0 or skip:
		_next()


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		stop()
		return
	var line: Array = _lines[_index]
	var speaker := str(line[0])
	var thought := speaker == NightZeroScript.THOUGHT
	_subtitle.text = "( %s )" % line[1] if thought else "%s:  %s" % [speaker, line[1]]
	var him := speaker == NightZeroScript.HIM or thought
	_subtitle.add_theme_color_override("font_color", HIM_COLOR if him else SPEAKER_COLOR)
	_subtitle.visible = true
	_left = float(line[2])
	line_shown.emit(_index)


func _build() -> void:
	var theme := UiTheme.get_theme()
	_card = PanelContainer.new()
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.02, 0.03, 0.05, 0.88)
	_card_style.set_border_width_all(1)
	_card_style.set_corner_radius_all(14)
	_card_style.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -190
	_card.offset_right = 190
	_card.offset_top = 64
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_card.add_child(row)
	# The pulsing ring: someone is in your head.
	_ring = Panel.new()
	_ring.custom_minimum_size = Vector2(38, 38)
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ring_style = StyleBoxFlat.new()
	_ring_style.bg_color = Color(0, 0, 0, 0)
	_ring_style.set_corner_radius_all(19)
	_ring_style.set_border_width_all(2)
	_ring.add_theme_stylebox_override("panel", _ring_style)
	row.add_child(_ring)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_caller = Label.new()
	_caller.theme = theme
	_caller.add_theme_font_size_override("font_size", 18)
	col.add_child(_caller)
	var via := Label.new()
	via.theme = theme
	via.text = "LeaseLink · in-head call"
	via.add_theme_font_size_override("font_size", 11)
	via.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	col.add_child(via)
	var meter := HBoxContainer.new()
	meter.alignment = BoxContainer.ALIGNMENT_CENTER
	meter.add_theme_constant_override("separation", 3)
	row.add_child(meter)
	for i in 7:
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(3, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.add_child(bar)
		_bars.append(bar)
	_timer = Label.new()
	_timer.theme = theme
	_timer.add_theme_font_size_override("font_size", 14)
	_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_timer)
	_tint(CALL_COLOR)
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


func _tint(c: Color) -> void:
	_card_style.border_color = c
	_ring_style.border_color = c
	_caller.add_theme_color_override("font_color", c)
	_timer.add_theme_color_override("font_color", c.darkened(0.2))
	for bar in _bars:
		bar.color = c
