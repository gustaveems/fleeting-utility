class_name SignType
extends RefCounted
## PRESENTATION — the lettering on the world's signs (playtest 2026-10-30: "the lettering
## on the buildings is weird and ugly": every Label3D was Godot's default UI font, huge).
## A condensed signage face from the fonts each OS ships (DIN Condensed / Avenir Next
## Condensed on macOS, Bahnschrift on Windows), nothing to download or redistribute.
##
##   SignType.dress(label)          painted or printed lettering: the face, a thin edge
##   SignType.neon(label, color)    a lit sign: the letters past white (the scene's glow
##                                  blooms them, softly), on a dark board sized to the
##                                  text so it hangs on something (2026-11-03: a hard
##                                  22 px outline round floating letters read as janky)

## How far past white a neon tube burns (bloom starts at 1).
const NEON_GAIN := 1.6
## The board's margin round the text, as a share of the line height.
const BOARD_PAD := 0.35

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


static func neon(label: Label3D, color: Color, board: bool = true) -> void:
	dress(label)
	label.outline_size = 0
	# Saturated, a little past white: the colour survives the tonemap and still blooms.
	label.modulate = Color(color.r * NEON_GAIN, color.g * NEON_GAIN, color.b * NEON_GAIN, 1.0)
	if board:
		_board(label)


## A dark sign board behind the text (the label faces +Z; the board sits just behind).
static func _board(label: Label3D) -> void:
	var size := font().get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, label.font_size
	)
	var line := float(label.font_size) * label.pixel_size
	var panel := MeshInstance3D.new()
	panel.name = "Board"
	var box := BoxMesh.new()
	box.size = Vector3(
		size.x * label.pixel_size + line * BOARD_PAD * 2.0,
		size.y * label.pixel_size + line * BOARD_PAD,
		line * 0.12
	)
	panel.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.035)
	mat.roughness = 0.45
	mat.metallic = 0.5
	panel.material_override = mat
	panel.position = Vector3(0, 0, -box.size.z * 0.5 - 0.01)
	label.add_child(panel)
