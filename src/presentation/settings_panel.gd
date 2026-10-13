class_name SettingsPanel
extends PanelContainer
## PRESENTATION — settings UI, shared by the main menu and the pause menu. Every control
## writes through GameSettings (persisted + applied at once), so a change made from the
## pause menu is felt immediately in-game.
##
##   Audio          Master · Ambience · Effects · Interface volume
##   Accessibility  Screen motion (tremor/shake) · Distortion (blur/colour split) ·
##                  Meter colours (Default / Colour-blind / High contrast)
##   Display        Fullscreen

signal closed

const BUS_LABELS := {
	&"Master": "Master volume",
	&"Ambience": "Ambience",
	&"SFX": "Effects",
	&"UI": "Interface",
}
const PALETTE_LABELS := ["Default", "Colour-blind (Okabe-Ito)", "High contrast"]

var settings: GameSettings

var _first_focus: Control


func _ready() -> void:
	settings = GameSettings.current()
	theme = UiTheme.get_theme()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(UiTheme.title("SETTINGS", 30))
	root.add_child(_section("Audio"))
	for bus in GameSettings.VOLUME_BUSES:
		root.add_child(
			_slider_row(
				BUS_LABELS.get(bus, str(bus)),
				"Slider_%s" % bus,
				settings.volumes[bus],
				func(v: float): settings.set_volume(bus, v)
			)
		)
	root.add_child(_section("Accessibility"))
	root.add_child(
		_slider_row(
			"Screen motion", "Slider_Motion", settings.motion_scale, settings.set_motion_scale
		)
	)
	root.add_child(
		_slider_row(
			"Distortion",
			"Slider_Distortion",
			settings.distortion_scale,
			settings.set_distortion_scale
		)
	)
	root.add_child(_palette_row())
	root.add_child(_section("Display"))
	var fullscreen := CheckButton.new()
	fullscreen.name = "Toggle_Fullscreen"
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = settings.fullscreen
	fullscreen.toggled.connect(settings.set_fullscreen)
	root.add_child(fullscreen)

	var back := UiTheme.button("Back", "Button_Back")
	back.pressed.connect(func(): closed.emit())
	root.add_child(back)


## Keyboard/gamepad entry point.
func focus_first() -> void:
	if _first_focus != null:
		_first_focus.grab_focus()


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", UiTheme.ACCENT)
	label.add_theme_font_size_override("font_size", 16)
	return label


func _slider_row(text: String, node_name: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(56, 0)
	readout.text = "%d%%" % int(round(value * 100.0))
	row.add_child(readout)
	slider.value_changed.connect(
		func(v: float):
			readout.text = "%d%%" % int(round(v * 100.0))
			on_change.call(v)
	)
	if _first_focus == null:
		_first_focus = slider
	return row


func _palette_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = "Meter colours"
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.name = "Option_MeterPalette"
	for i in PALETTE_LABELS.size():
		option.add_item(PALETTE_LABELS[i], i)
	option.selected = int(settings.meter_palette)
	option.item_selected.connect(
		func(i: int): settings.set_meter_palette(i as GameSettings.MeterPalette)
	)
	row.add_child(option)
	return row
