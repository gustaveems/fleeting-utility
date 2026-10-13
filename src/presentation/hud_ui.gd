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
##   Center (FlavorLayer, created on demand):
##     - narrative lines via show_line(): loop flavor text, the statue reveal, the
##       betrayal. One line at a time; a new line replaces the current one.
##
## SIGNAL WIRING
## -------------
##   PlayerStateMachine.state_data.state_changed  → update both meters
##   InteractionController.target_detected        → show interaction prompt
##   InteractionController.target_lost            → hide interaction prompt
##   DreamscapeManager.transition_completed       → toggle dream state (hide meters,
##                                                  show "Fading Memory")
##
## ACCESSIBILITY (Ticket-13)
## -------------------------
## Meters never rely on colour alone: each carries tick marks at its gameplay thresholds
## (chemical: unmedicated 0.3, High-Focus 0.7; overload: crash 50, compulsion 80), plus
## the percentage labels. set_meter_palette() swaps the fills:
##   DEFAULT        green→yellow→red / blue→red
##   COLORBLIND     Okabe-Ito, BANDED at the thresholds rather than blended (a blue to
##                  vermillion blend goes muddy brown mid-way): chemical vermillion
##                  (unmedicated) / yellow / blue (High-Focus); overload sky blue
##                  below the crash, vermillion above. Distinct under deuteranopia,
##                  protanopia and tritanopia.
##   HIGH_CONTRAST  solid white fills on black with a white outline, larger labels
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

## Center-screen narrative line (show_line). Lives inside this HUD's CanvasLayer (50),
## above post-FX and the dream fade.
var _flavor_layer: CenterContainer
var _flavor_label: Label
var _flavor_tween: Tween

## Internal state: true when in the dreamscape (meters hidden, "Fading Memory" shown).
var _in_dreamscape: bool = false

var _palette: GameSettings.MeterPalette = GameSettings.MeterPalette.DEFAULT


func _ready() -> void:
	# Fill the entire viewport.
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
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
	_add_ticks(_chemical_bar, [0.3, 0.7])

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
	_add_ticks(_overload_bar, [0.5, 0.8])

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
	# Full-width strip anchored to the bottom edge, 40 px tall, 80 px up. Anchors plus
	# offsets, not `position`: after an anchor preset, writing position.y = -80 put the
	# prompt above the TOP of the screen.
	_prompt_container = CenterContainer.new()
	_prompt_container.name = "PromptContainer"
	_prompt_container.anchor_left = 0.0
	_prompt_container.anchor_right = 1.0
	_prompt_container.anchor_top = 1.0
	_prompt_container.anchor_bottom = 1.0
	_prompt_container.offset_top = -120.0
	_prompt_container.offset_bottom = -80.0
	_prompt_container.mouse_filter = MOUSE_FILTER_IGNORE
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
	# Full-width strip 60 px from the top; the label centres its own text.
	_fading_label.anchor_left = 0.0
	_fading_label.anchor_right = 1.0
	_fading_label.offset_top = 60.0
	_fading_label.offset_bottom = 100.0
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


## Threshold marks, as fractions of the bar. Colour-independent meaning.
func _add_ticks(bar: ProgressBar, fractions: Array) -> void:
	for f in fractions:
		var tick := ColorRect.new()
		tick.name = "Tick_%d" % int(float(f) * 100.0)
		tick.color = Color(1.0, 1.0, 1.0, 0.55)
		tick.mouse_filter = MOUSE_FILTER_IGNORE
		tick.anchor_left = float(f)
		tick.anchor_right = float(f)
		tick.anchor_top = 0.0
		tick.anchor_bottom = 1.0
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		bar.add_child(tick)


func set_meter_palette(palette: GameSettings.MeterPalette) -> void:
	_palette = palette
	var high_contrast := palette == GameSettings.MeterPalette.HIGH_CONTRAST
	for bar in [_chemical_bar, _overload_bar]:
		if bar == null:
			continue
		var bg := bar.get_theme_stylebox("background") as StyleBoxFlat
		if bg != null:
			bg.bg_color = Color.BLACK if high_contrast else Color(0.12, 0.12, 0.14, 0.7)
			bg.set_border_width_all(2 if high_contrast else 0)
			bg.border_color = Color.WHITE
	for bar in [_chemical_bar, _overload_bar]:
		for tick in bar.get_children():
			if tick is ColorRect:
				# Mid-grey reads on both a white fill and a black track.
				(tick as ColorRect).color = (
					Color(0.5, 0.5, 0.5) if high_contrast else Color(1.0, 1.0, 1.0, 0.55)
				)
	for label in [_chemical_label, _overload_label]:
		if label == null:
			continue
		label.add_theme_font_size_override("font_size", 18 if high_contrast else 14)
		label.add_theme_constant_override("outline_size", 4 if high_contrast else 0)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_color_override(
			"font_color", Color.WHITE if high_contrast else Color(0.9, 0.9, 0.9, 0.85)
		)
	if state_machine != null and state_machine.state_data != null:
		_update_meters(state_machine.state_data)


## The current fill colour of a meter (tests, tooling).
func meter_fill_color(chemical: bool) -> Color:
	var bar := _chemical_bar if chemical else _overload_bar
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat if bar != null else null
	return fill.bg_color if fill != null else Color.TRANSPARENT


## Fill colours per palette (see class doc).
func _update_bar_colors(chemical: float, overload: float) -> void:
	var overload_t := clampf(overload / 100.0, 0.0, 1.0)
	match _palette:
		GameSettings.MeterPalette.COLORBLIND:
			var vermillion := Color(0.835, 0.369, 0.0)
			var yellow := Color(0.941, 0.894, 0.259)
			var blue := Color(0.0, 0.447, 0.698)
			var chem := yellow
			if chemical < 0.3:
				chem = vermillion
			elif chemical > 0.7:
				chem = blue
			_apply_fill_color(_chemical_bar, chem)
			var crashed := overload_t >= 0.5
			_apply_fill_color(_overload_bar, vermillion if crashed else Color(0.337, 0.706, 0.914))
			return
		GameSettings.MeterPalette.HIGH_CONTRAST:
			_apply_fill_color(_chemical_bar, Color.WHITE)
			_apply_fill_color(_overload_bar, Color.WHITE)
			return
	_update_default_colors(chemical, overload)


## DEFAULT: chemical green (1.0) → yellow (0.5) → red (0.0); overload blue → red.
func _update_default_colors(chemical: float, overload: float) -> void:
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


## Ticket-07: the endgame loop flavor text.
func _on_loop_reset(flavor_text: String) -> void:
	show_line(flavor_text)


## Show a narrative line centre-screen for `hold_seconds`, then fade it out. A new line
## replaces the current one.
func show_line(text: String, hold_seconds: float = 3.0) -> void:
	if _flavor_layer == null:
		_flavor_layer = CenterContainer.new()
		_flavor_layer.name = "FlavorLayer"
		_flavor_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_flavor_layer.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_flavor_layer)
		_flavor_label = Label.new()
		_flavor_label.name = "FlavorLabel"
		_flavor_label.add_theme_font_size_override("font_size", 24)
		_flavor_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_flavor_layer.add_child(_flavor_label)
	if _flavor_tween != null:
		_flavor_tween.kill()
	_flavor_label.text = text
	_flavor_label.modulate.a = 1.0
	_flavor_tween = create_tween()
	_flavor_tween.tween_interval(hold_seconds)
	_flavor_tween.tween_property(_flavor_label, "modulate:a", 0.0, 1.5)
	_flavor_tween.tween_callback(_remove_flavor)


## The narrative line currently on screen, or "".
func displayed_line() -> String:
	return _flavor_label.text if _flavor_label != null else ""


func _remove_flavor() -> void:
	if _flavor_layer != null:
		_flavor_layer.queue_free()
		_flavor_layer = null
		_flavor_label = null
		_flavor_tween = null
