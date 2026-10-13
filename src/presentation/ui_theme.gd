class_name UiTheme
extends RefCounted
## PRESENTATION — the menus' look: leased, worn, minimal. Near-black panels, a thin
## nicotine-yellow rule, off-white text. A bright focus ring on every control, because
## the menus are fully keyboard/gamepad navigable (accessibility).

const INK := Color(0.88, 0.86, 0.80)
const DIM := Color(0.55, 0.53, 0.48)
const ACCENT := Color(0.86, 0.74, 0.46)
const PANEL := Color(0.05, 0.05, 0.055, 0.92)
const EDGE := Color(0.36, 0.33, 0.27)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20

	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_stylebox("normal", "Button", _box(PANEL, EDGE, 1))
	t.set_stylebox("hover", "Button", _box(Color(0.10, 0.10, 0.10, 0.95), ACCENT, 1))
	t.set_stylebox("pressed", "Button", _box(Color(0.16, 0.14, 0.10, 0.95), ACCENT, 1))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(PANEL, Color(0.2, 0.2, 0.2), 1))

	for control in ["CheckButton", "OptionButton", "HSlider"]:
		t.set_stylebox("focus", control, _box(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("normal", "OptionButton", _box(PANEL, EDGE, 1))
	t.set_stylebox("hover", "OptionButton", _box(PANEL, ACCENT, 1))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, EDGE, 1, 24))
	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.5
	box.content_margin_bottom = margin * 0.5
	return box


## A centred title label.
static func title(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


## A menu button with a stable node name for tests and keyboard focus chains.
static func button(text: String, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(320, 48)
	return b
