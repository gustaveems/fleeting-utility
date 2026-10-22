class_name ChoicePanel
extends CanvasLayer
## PRESENTATION — the dialogue choice box (Night Zero's dinner and gift). Options listed
## low on screen; pick with the number keys, or up/down then E / Enter.

signal chosen(index: int)

const SELECTED := Color(0.95, 0.78, 0.45)
const IDLE := Color(0.78, 0.78, 0.74)

var is_open: bool = false
var selected: int = 0

var _box: VBoxContainer
var _labels: Array[Label] = []


func _ready() -> void:
	layer = 36
	_box = VBoxContainer.new()
	_box.anchor_left = 0.3
	_box.anchor_right = 0.7
	_box.anchor_top = 0.62
	_box.anchor_bottom = 0.76
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	_box.visible = false


func open(options: Array[String]) -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	for i in options.size():
		var l := Label.new()
		l.theme = UiTheme.get_theme()
		l.text = "%d.  %s" % [i + 1, options[i]]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		_box.add_child(l)
		_labels.append(l)
	selected = 0
	is_open = true
	_box.visible = true
	_refresh()


## Pick option `index` (input, scripted sequences and tests).
func choose(index: int) -> void:
	if not is_open or index < 0 or index >= _labels.size():
		return
	is_open = false
	_box.visible = false
	chosen.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			choose(k - KEY_1)
			return
	if event.is_action_pressed("ui_down"):
		selected = (selected + 1) % _labels.size()
		_refresh()
	elif event.is_action_pressed("ui_up"):
		selected = (selected - 1 + _labels.size()) % _labels.size()
		_refresh()
	elif (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed(InputActionData.ACTION_INTERACT)
	):
		choose(selected)


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].add_theme_color_override("font_color", SELECTED if i == selected else IDLE)
