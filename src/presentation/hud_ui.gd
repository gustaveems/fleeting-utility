class_name HudUI
extends Control
## PRESENTATION LAYER — the Core HUD (Ticket-07).
##
## LAYOUT
## ------
##   Top-left (VBoxContainer):
##     - ChemicalMeter (ProgressBar) + ChemicalLabel ("FOCUS: 85%")
##     - OverloadMeter (ProgressBar) + OverloadLabel ("OVERLOAD: 40%")
##   Center-bottom (CenterContainer):
##     - InteractionPrompt ("[E] Interact") — hidden by default
##   Top-center:
##     - FadingMemoryLabel ("Fading Memory") — shown only in dreamscape
##
## SIGNAL WIRING
## -------------
##   PlayerStateMachine.state_data.state_changed  → update both meters
##   InteractionController.target_detected        → show interaction prompt
##   InteractionController.target_lost            → hide interaction prompt
##   DreamscapeManager.transition_completed       → toggle dream state (hide meters,
##                                                  show "Fading Memory")
##
## STYLING
## -------
##   ProgressBars use StyleBoxFlat with dynamic foreground colors:
##     ChemicalMeter: green (1.0) → yellow (0.5) → red (0.0)
##     OverloadMeter: blue (0.0) → red (1.0)
##   Colors are interpolated in _update_meter_colors() every time the state changes.

@export var state_machine: PlayerStateMachine
@export var interaction_controller: InteractionController
@export var dreamscape_manager: DreamscapeManager
@export var endgame_loop_manager: EndgameLoopManager

## Top-left meter cluster.
var _meter_container: VBoxContainer
var _chemical_bar: ProgressBar
var _chemical_label: Label
var _overload_bar: ProgressBar
var _overload_label: Label

## Center-bottom interaction prompt.
var _prompt_container: CenterContainer
var _prompt_label: Label

## Top-center dreamscape label.
var _fading_label: Label

## Center-screen flavor text shown briefly after the endgame loop resets.
var _flavor_layer: CanvasLayer
var _flavor_label: Label

## Internal state: true when in the dreamscape (meters hidden, "Fading Memory" shown).
var _in_dreamscape: bool = false


func _ready() -> void:
	# Fill the entire viewport.
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	_build_meter_cluster()
	_build_prompt()
	_build_fading_label()
	_connect_signals()

	# Initial read so the bars aren't empty on frame 1.
	if state_machine != null and state_machine.state_data != null:
		_update_meters(state_machine.state_data)


## ----- BUILD --------------------------------------------------------------------------


func _build_meter_cluster() -> void:
	_meter_container = VBoxContainer.new()
	_meter_container.name = "MeterCluster"
	_meter_container.position = Vector2(20, 20)
	_meter_container.add_theme_constant_override("separation", 8)
	add_child(_meter_container)

	# Chemical meter.
	_chemical_bar = ProgressBar.new()
	_chemical_bar.name = "ChemicalMeter"
	_chemical_bar.custom_minimum_size = Vector2(220, 18)
	_chemical_bar.max_value = 1.0
	_chemical_bar.value = 1.0
	_chemical_bar.show_percentage = false
	_style_bar(_chemical_bar, Color(0.35, 0.75, 0.35))
	_meter_container.add_child(_chemical_bar)

	_chemical_label = Label.new()
	_chemical_label.name = "ChemicalLabel"
	_chemical_label.add_theme_font_size_override("font_size", 14)
	_chemical_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	_chemical_label.text = "FOCUS: 100%"
	_meter_container.add_child(_chemical_label)

	# Overload meter.
	_overload_bar = ProgressBar.new()
	_overload_bar.name = "OverloadMeter"
	_overload_bar.custom_minimum_size = Vector2(220, 18)
	_overload_bar.max_value = 100.0
	_overload_bar.value = 0.0
	_overload_bar.show_percentage = false
	_style_bar(_overload_bar, Color(0.3, 0.5, 0.85))
	_meter_container.add_child(_overload_bar)

	_overload_label = Label.new()
	_overload_label.name = "OverloadLabel"
	_overload_label.add_theme_font_size_override("font_size", 14)
	_overload_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.85))
	_overload_label.text = "OVERLOAD: 0%"
	_meter_container.add_child(_overload_label)


## Create a StyleBoxFlat for the bar's background (dark grey) and foreground (tint).
## The foreground color is updated dynamically; the background stays fixed.
func _style_bar(bar: ProgressBar, initial_tint: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.14, 0.7)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3

	var fg := StyleBoxFlat.new()
	fg.bg_color = initial_tint
	fg.corner_radius_top_left = 3
	fg.corner_radius_top_right = 3
	fg.corner_radius_bottom_left = 3
	fg.corner_radius_bottom_right = 3

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


func _build_prompt() -> void:
	_prompt_container = CenterContainer.new()
	_prompt_container.name = "PromptContainer"
	_prompt_container.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_prompt_container.position.y = -80  # 80 px above the bottom edge
	_prompt_container.visible = false
	add_child(_prompt_container)

	_prompt_label = Label.new()
	_prompt_label.name = "InteractionPrompt"
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_prompt_label.text = "[E] Interact"
	_prompt_container.add_child(_prompt_label)


func _build_fading_label() -> void:
	_fading_label = Label.new()
	_fading_label.name = "FadingMemoryLabel"
	_fading_label.set_anchors_preset(PRESET_CENTER_TOP)
	_fading_label.position.y = 60
	_fading_label.add_theme_font_size_override("font_size", 28)
	_fading_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 0.9))
	_fading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fading_label.text = "Fading Memory"
	_fading_label.visible = false
	add_child(_fading_label)


## ----- SIGNAL WIRING ------------------------------------------------------------------


func _connect_signals() -> void:
	if state_machine != null and state_machine.state_data != null:
		state_machine.state_data.state_changed.connect(_update_meters)

	if interaction_controller != null:
		interaction_controller.target_detected.connect(_on_target_detected)
		interaction_controller.target_lost.connect(_on_target_lost)

	if dreamscape_manager != null:
		dreamscape_manager.transition_completed.connect(_on_dreamscape_transition)

	if endgame_loop_manager != null:
		endgame_loop_manager.loop_reset.connect(_on_loop_reset)


## ----- CALLBACKS ----------------------------------------------------------------------


## Called on every state_data.state_changed emission. Updates both bars and labels.
func _update_meters(data: PlayerStateData) -> void:
	if _chemical_bar == null or _overload_bar == null:
		return

	# Chemical: 0..1 → bar value + label.
	_chemical_bar.value = data.chemical_level
	var chem_pct := int(roundf(data.chemical_level * 100.0))
	_chemical_label.text = "FOCUS: %d%%" % chem_pct

	# Overload: 0..100 → bar value + label.
	_overload_bar.value = data.sensory_overload
	var overload_pct := int(roundf(data.sensory_overload))
	_overload_label.text = "OVERLOAD: %d%%" % overload_pct

	_update_bar_colors(data.chemical_level, data.sensory_overload)


## Chemical bar: green (1.0) → yellow (0.5) → red (0.0).
## Overload bar: blue (0.0) → red (100.0).
func _update_bar_colors(chemical: float, overload: float) -> void:
	# Chemical: lerp red→yellow→green. At 1.0 = green, at 0.5 = yellow, at 0.0 = red.
	var chem_color: Color
	if chemical >= 0.5:
		# Upper half: yellow → green.
		var t := (chemical - 0.5) / 0.5
		chem_color = Color(1.0, 0.85, 0.0).lerp(Color(0.35, 0.75, 0.35), t)
	else:
		# Lower half: red → yellow.
		var t := chemical / 0.5
		chem_color = Color(0.85, 0.25, 0.25).lerp(Color(1.0, 0.85, 0.0), t)
	_apply_fill_color(_chemical_bar, chem_color)

	# Overload: lerp blue → red. 0 = calm blue, 100 = angry red.
	var overload_t := clampf(overload / 100.0, 0.0, 1.0)
	var overload_color := Color(0.3, 0.5, 0.85).lerp(Color(0.9, 0.2, 0.15), overload_t)
	_apply_fill_color(_overload_bar, overload_color)


func _apply_fill_color(bar: ProgressBar, color: Color) -> void:
	var fill_style := bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		(fill_style as StyleBoxFlat).bg_color = color


func _on_target_detected(prompt_text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = prompt_text
	if _prompt_container != null:
		_prompt_container.visible = true


func _on_target_lost() -> void:
	if _prompt_container != null:
		_prompt_container.visible = false


func _on_dreamscape_transition(now_in_dreamscape: bool) -> void:
	_in_dreamscape = now_in_dreamscape
	if _meter_container != null:
		_meter_container.visible = not now_in_dreamscape
	if _fading_label != null:
		_fading_label.visible = now_in_dreamscape


## Ticket-07: show the endgame loop flavor text in the center of the screen for a few
## seconds, then fade it out.
func _on_loop_reset(flavor_text: String) -> void:
	if _flavor_layer != null:
		return  # Already showing.

	_flavor_layer = CanvasLayer.new()
	_flavor_layer.name = "FlavorLayer"
	add_child(_flavor_layer)

	_flavor_label = Label.new()
	_flavor_label.name = "FlavorLabel"
	_flavor_label.text = flavor_text
	_flavor_label.add_theme_font_size_override("font_size", 24)
	_flavor_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.modulate.a = 1.0

	var container := CenterContainer.new()
	container.name = "FlavorContainer"
	container.set_anchors_preset(PRESET_FULL_RECT)
	container.add_child(_flavor_label)
	_flavor_layer.add_child(container)

	# Fade out after 3 seconds.
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_flavor_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_remove_flavor)


func _remove_flavor() -> void:
	if _flavor_layer != null:
		_flavor_layer.queue_free()
		_flavor_layer = null
		_flavor_label = null
