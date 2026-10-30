class_name SignType
extends RefCounted
## PRESENTATION — the lettering on the world's signs (playtest 2026-10-30: "the lettering
## on the buildings is weird and ugly": every Label3D was Godot's default UI font, huge).
## A condensed signage face from the fonts each OS ships (DIN Condensed / Avenir Next
## Condensed on macOS, Bahnschrift on Windows), nothing to download or redistribute.
##
##   SignType.dress(label)          painted or printed lettering: the face, a thin edge
##   SignType.neon(label, color)    a lit tube: a hot pale core, the colour as a halo

const FACES: Array[String] = [
	"DIN Condensed",
	"Avenir Next Condensed",
	"Bahnschrift SemiCondensed",
	"Bahnschrift",
	"Arial Narrow",
	"Helvetica Neue",
	"Arial",
]

static var _font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(FACES)
		_font.font_weight = 600
		_font.font_stretch = 75
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.generate_mipmaps = true
	return _font


static func dress(label: Label3D) -> void:
	label.font = font()
	label.outline_size = maxi(label.outline_size, 4)
	label.outline_modulate = Color(0, 0, 0, 0.35)
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func neon(label: Label3D, color: Color) -> void:
	dress(label)
	label.modulate = color.lerp(Color.WHITE, 0.55)
	label.outline_size = 22
	label.outline_modulate = Color(color.r, color.g, color.b, 0.55)
