class_name DreamscapeHud
extends CanvasLayer
## PRESENTATION — the dream's countdown ("Fading memory: 27s"), top-right, shown only in
## the dreamscape (Ticket-05 Task 3).
##
## Everything else this HUD used to draw now belongs to CoreHud: the meters (its debug
## chemical/entropy labels overlapped them) and the interaction prompts (its separate
## "Interact to Return" duplicated the "[E] Remember" prompt).
##
## Layer 50: above post-FX (4), vignette (6) and the dream fade (30).

const MARGIN := 20.0

@export var dreamscape_manager: DreamscapeManager

var _timer_label: Label


func _ready() -> void:
	layer = 50

	# Top-right strip: anchored to the right edge so it holds at any window size.
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.anchor_left = 1.0
	_timer_label.anchor_right = 1.0
	_timer_label.offset_left = -400.0
	_timer_label.offset_right = -MARGIN
	_timer_label.offset_top = MARGIN
	_timer_label.offset_bottom = MARGIN + 34.0
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.9))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.visible = false
	add_child(_timer_label)

	if dreamscape_manager != null:
		dreamscape_manager.timer_updated.connect(_on_timer_updated)
		dreamscape_manager.transition_completed.connect(_on_transition_completed)


func _on_timer_updated(seconds: float) -> void:
	_timer_label.text = "Fading memory: %ds" % int(seconds)


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	_timer_label.visible = now_in_dreamscape
