class_name PrologueOverlay
extends CanvasLayer
## PRESENTATION — the prologue's 2D layer: letterbox bars (the whole film is cinematic),
## subtitles, his phone (the lease notification), the end title and the skip hint.

enum View { BARE, LETTERBOX }

var _bars: Control
var _black: ColorRect
var _subtitle: Label
var _phone: PanelContainer
var _phone_label: Label
var _title: Label
var _skip: Label


func _ready() -> void:
	layer = 40
	_build()
	set_view(View.LETTERBOX)
	set_phone(0.0)
	set_title(0.0)
	set_skip_progress(0.0)


## Full black (the pre-warm frames before the film starts).
func set_black(on: bool) -> void:
	_black.visible = on


## BARE: nothing · LETTERBOX: cinema bars.
func set_view(view: View) -> void:
	_bars.visible = view == View.LETTERBOX


func set_subtitle(text: String) -> void:
	_subtitle.text = text
	_subtitle.visible = not text.is_empty()


## 0 = hidden, 1 = fully raised in front of him.
func set_phone(amount: float, text: String = "") -> void:
	_phone.visible = amount > 0.01
	_phone.modulate.a = clampf(amount * 1.5, 0.0, 1.0)
	_phone.position.y = lerpf(_phone_rest_y() + 260.0, _phone_rest_y(), amount)
	if not text.is_empty():
		_phone_label.text = text


func set_title(amount: float) -> void:
	_title.visible = amount > 0.01
	_title.modulate.a = amount


func set_skip_progress(amount: float) -> void:
	_skip.text = "Hold E to skip" if amount <= 0.0 else "Skipping… %d%%" % int(amount * 100.0)
	_skip.modulate.a = 0.45 if amount <= 0.0 else 1.0


func _phone_rest_y() -> float:
	return get_viewport().get_visible_rect().size.y * 0.42 if get_viewport() != null else 300.0


func _build() -> void:
	var theme := UiTheme.get_theme()
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.visible = false
	add_child(_black)
	# Letterbox: the film is shot in cinema bars throughout.
	_bars = Control.new()
	_bars.name = "Letterbox"
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bars)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.88
		bar.anchor_bottom = 0.12 if top else 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.add_child(bar)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.theme = theme
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.anchor_left = 0.1
	_subtitle.anchor_right = 0.9
	_subtitle.anchor_top = 0.88
	_subtitle.anchor_bottom = 0.98
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_subtitle)

	_phone = PanelContainer.new()
	_phone.name = "Phone"
	var phone_style := StyleBoxFlat.new()
	phone_style.bg_color = Color(0.04, 0.05, 0.06, 0.96)
	phone_style.border_color = Color(0.2, 0.84, 0.9)
	phone_style.set_border_width_all(2)
	phone_style.set_corner_radius_all(18)
	phone_style.content_margin_left = 22
	phone_style.content_margin_right = 22
	phone_style.content_margin_top = 18
	phone_style.content_margin_bottom = 18
	_phone.add_theme_stylebox_override("panel", phone_style)
	_phone.custom_minimum_size = Vector2(360, 200)
	_phone.anchor_left = 0.5
	_phone.anchor_right = 0.5
	_phone.offset_left = -180
	_phone.offset_right = 180
	add_child(_phone)
	_phone_label = Label.new()
	_phone_label.theme = theme
	_phone_label.add_theme_font_size_override("font_size", 20)
	_phone_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.97))
	_phone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phone.add_child(_phone_label)

	_title = UiTheme.title(PrologueScript.TITLE, 64)
	_title.name = "Title"
	_title.theme = theme
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)

	_skip = Label.new()
	_skip.name = "Skip"
	_skip.theme = theme
	_skip.add_theme_font_size_override("font_size", 14)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -220
	_skip.offset_right = -20
	_skip.offset_top = 16
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_skip)
