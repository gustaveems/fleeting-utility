class_name DayCard
extends CanvasLayer
## PRESENTATION — "DAY 4" over the room as he wakes: a quiet beat between one day's loop and
## the next. Waits out the wake's fade, then fades in and out.

const WAIT := 1.4
const FADE := 0.9
const HOLD := 1.6

@export var day_cycle: DayCycle

var _label: Label


func _ready() -> void:
	layer = 48
	_label = UiTheme.title("", 44)
	_label.name = "DayCard"
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position.y = 190
	_label.modulate.a = 0.0
	add_child(_label)
	if day_cycle != null:
		day_cycle.morning.connect(show_day)


func text() -> String:
	return _label.text


func show_day(day: int) -> void:
	_label.text = "DAY %d" % day
	var fade := create_tween()
	fade.tween_interval(WAIT)
	fade.tween_property(_label, "modulate:a", 0.85, FADE)
	fade.tween_interval(HOLD)
	fade.tween_property(_label, "modulate:a", 0.0, FADE)
