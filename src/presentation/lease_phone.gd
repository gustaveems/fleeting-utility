class_name LeasePhone
extends CanvasLayer
## PRESENTATION — LeaseLink (docs/STORY.md 8c): P opens the implant's display over the room,
## with his day, his standing and the log of his calls. He stands still while it's up. In
## the valley there is no signal. Reads DailyLife and Standing; owns nothing.

const LOCK := &"phone"
const SHOWN := 11
const NO_SIGNAL := "NO SIGNAL"
const EMPTY_LOG := "No calls yet."

@export var player: PlayerMovement
@export var daily: DailyLife
@export var standing: Standing
@export var day_cycle: DayCycle
@export var dreamscape_manager: DreamscapeManager

var is_open: bool = false

var _panel: PanelContainer
var _header: Label
var _log: Label


func _ready() -> void:
	layer = 55
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActionData.ACTION_PHONE):
		toggle()


func toggle() -> void:
	is_open = not is_open
	_panel.visible = is_open
	if player != null:
		if is_open:
			player.lock_input(LOCK)
		else:
			player.unlock_input(LOCK)
	if is_open:
		_refresh()


func header_text() -> String:
	return _header.text


func log_text() -> String:
	return _log.text


func _no_signal() -> bool:
	return dreamscape_manager != null and dreamscape_manager.in_dreamscape()


func _refresh() -> void:
	if _no_signal():
		_header.text = "LEASELINK  ·  " + NO_SIGNAL
		_log.text = ""
		return
	var day := day_cycle.day if day_cycle != null else 1
	var rank := "%d%%" % roundi(standing.standing) if standing != null else "—"
	_header.text = "LEASELINK  ·  DAY %d  ·  STANDING %s" % [day, rank]
	var lines: Array[String] = []
	var entries: Array = daily.call_log.slice(-SHOWN) if daily != null else []
	for entry: Array in entries:
		lines.append("Day %d  %s: %s" % [entry[0], entry[1], entry[2]])
	_log.text = EMPTY_LOG if lines.is_empty() else "\n".join(lines)


func _build() -> void:
	var hint := Label.new()
	hint.name = "PhoneHint"
	hint.text = "[P] LeaseLink"
	hint.theme = UiTheme.get_theme()
	hint.position = Vector2(20, 690)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82, 0.45))
	add_child(hint)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "LeaseLink"
	_panel.theme = UiTheme.get_theme()
	_panel.custom_minimum_size = Vector2(640, 440)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	_header.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(_header)
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 15)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(600, 0)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_log)
	var close := Label.new()
	close.text = "[P] Close"
	close.modulate = UiTheme.DIM
	close.add_theme_font_size_override("font_size", 13)
	column.add_child(close)
