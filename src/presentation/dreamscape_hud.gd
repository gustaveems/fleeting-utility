class_name DreamscapeHud
extends CanvasLayer
## PRESENTATION — HUD overlay for the dreamscape (Ticket-05 Task 3).
##
## Shows:
##   - A countdown timer ("Fading memory: 27s") in the top-right
##   - A prompt ("Interact to Return") in the center-bottom when near a memory anchor
##   - Chemical/entropy labels (hidden when in dreamscape, shown otherwise)
##
## The HUD is a CanvasLayer at layer 50 (above post-FX at 4, vignette at 6, fade at 30).

@export var dreamscape_manager: DreamscapeManager

var _timer_label: Label
var _prompt_label: Label
var _chemical_label: Label
var _entropy_label: Label


func _ready() -> void:
	layer = 50

	# Timer label (top-right).
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.position = Vector2(1100, 20)
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.9))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_timer_label)

	# Prompt label (center-bottom).
	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.position = Vector2(640, 650)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Chemical/entropy labels (top-left, hidden in dreamscape).
	_chemical_label = Label.new()
	_chemical_label.name = "ChemicalLabel"
	_chemical_label.position = Vector2(20, 20)
	_chemical_label.add_theme_font_size_override("font_size", 16)
	_chemical_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.7))
	add_child(_chemical_label)

	_entropy_label = Label.new()
	_entropy_label.name = "EntropyLabel"
	_entropy_label.position = Vector2(20, 40)
	_entropy_label.add_theme_font_size_override("font_size", 16)
	_entropy_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.7))
	add_child(_entropy_label)

	if dreamscape_manager != null:
		dreamscape_manager.timer_updated.connect(_on_timer_updated)
		dreamscape_manager.anchor_proximity_changed.connect(_on_anchor_proximity)
		dreamscape_manager.transition_completed.connect(_on_transition_completed)


func _process(_delta: float) -> void:
	# Update chemical/entropy labels when NOT in dreamscape.
	if dreamscape_manager != null and not dreamscape_manager.in_dreamscape():
		var sm := dreamscape_manager.state_machine
		if sm != null and sm.state_data != null:
			_chemical_label.text = "Chemical: %.2f" % sm.state_data.chemical_level
			_entropy_label.text = "Entropy: %.1f" % sm.entropy_data.entropy
			_chemical_label.visible = true
			_entropy_label.visible = true
		else:
			_chemical_label.visible = false
			_entropy_label.visible = false
	else:
		# In dreamscape: hide chemical/entropy (irrelevant).
		_chemical_label.visible = false
		_entropy_label.visible = false


func _on_timer_updated(seconds: float) -> void:
	_timer_label.text = "Fading memory: %ds" % int(seconds)


func _on_anchor_proximity(near: bool) -> void:
	_prompt_label.visible = near
	_prompt_label.text = "Interact to Return" if near else ""


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape:
		_timer_label.visible = true
		_prompt_label.visible = false
	else:
		_timer_label.visible = false
		_prompt_label.visible = false
