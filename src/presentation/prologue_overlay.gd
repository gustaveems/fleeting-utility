class_name PrologueOverlay
extends CanvasLayer
## PRESENTATION — the prologue's 2D layer: the carriage window frame and the packed
## commuters (window shots), letterbox bars (external and walk shots), subtitles, his phone
## (the lease notification), the end title and the skip hint.

enum View { WINDOW, BARE, LETTERBOX }

const FRAME_SHADER := """
shader_type canvas_item;
// The carriage interior around a rounded window: dark everywhere except the glass,
// with a faint grime vignette on the glass itself.
uniform vec2 window_min = vec2(0.10, 0.16);
uniform vec2 window_max = vec2(0.90, 0.78);
uniform float radius = 0.05;
void fragment() {
	vec2 uv = UV;
	vec2 c = clamp(uv, window_min + radius, window_max - radius);
	float d = length(uv - c) - radius;
	float glass = 1.0 - smoothstep(0.0, 0.004, d);
	float grime = smoothstep(0.0, 0.25, length(uv - (window_min + window_max) * 0.5)) * 0.25;
	COLOR = mix(vec4(0.025, 0.025, 0.03, 1.0), vec4(0.05, 0.06, 0.06, grime), glass);
}
"""

var _frame: ColorRect
var _crowd: Control
var _bars: Control
var _subtitle: Label
var _phone: PanelContainer
var _phone_label: Label
var _title: Label
var _skip: Label
var _sway_time: float = 0.0


func _ready() -> void:
	layer = 40
	_build()
	set_view(View.LETTERBOX)
	set_phone(0.0)
	set_title(0.0)
	set_skip_progress(0.0)


func _process(delta: float) -> void:
	# The commuters sway with the carriage.
	_sway_time += delta
	if _crowd.visible:
		_crowd.position = Vector2(sin(_sway_time * 1.3) * 6.0, sin(_sway_time * 2.1) * 3.0)


## WINDOW: the carriage frame and the commuters' silhouettes · BARE: nothing (the aisle
## shot has its own 3D crowd) · LETTERBOX: cinema bars for the external shots.
func set_view(view: View) -> void:
	_frame.visible = view == View.WINDOW
	_crowd.visible = view == View.WINDOW
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
	var shader := Shader.new()
	shader.code = FRAME_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_frame = ColorRect.new()
	_frame.name = "WindowFrame"
	_frame.material = mat
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)

	# Commuters: dark shoulders and heads crowding the frame's lower edge.
	_crowd = Control.new()
	_crowd.name = "Commuters"
	_crowd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crowd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crowd)
	for spec in [
		[0.0, 0.62, 0.22, 0.5],
		[0.16, 0.7, 0.18, 0.4],
		[0.74, 0.6, 0.26, 0.55],
		[0.6, 0.74, 0.16, 0.35]
	]:
		var body := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.015, 0.015, 0.02)
		style.set_corner_radius_all(120)
		body.add_theme_stylebox_override("panel", style)
		body.anchor_left = spec[0]
		body.anchor_top = spec[1]
		body.anchor_right = spec[0] + spec[2]
		body.anchor_bottom = spec[1] + spec[3]
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crowd.add_child(body)

	# Letterbox for the external shots.
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
