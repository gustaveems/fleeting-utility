class_name AdScreen
extends Node3D
## PRESENTATION — the leased ad panel on his wall (docs/STORY.md 8; Ticket-18): the
## billboards followed him inside. It rotates the brand's slogans until Focus+ makes an
## offer, then shows the offer, the trial, the bill. It pulses while a call is
## incoming. Listens to Promises; owns no logic.
##
## Built facing +Z; the module turns it to face into the room.

const SIZE := Vector2(1.0, 0.56)
const ROTATE_SECONDS := 6.0
const GOLD := Color(0.95, 0.75, 0.3)
const GLASS := Color(0.05, 0.06, 0.08)

@export var promises: Promises
## Ticket-24: his LeaseLink standing, in the corner, always sinking.
@export var standing: Standing

var headline: String = ""
var fine_print: String = ""

var _glass: StandardMaterial3D
var _title: Label3D
var _small: Label3D
var _glow: OmniLight3D
var _standing_label: Label3D
var _idle_index: int = 0
var _idle_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_build()
	if promises != null:
		promises.changed.connect(refresh)
	if standing != null:
		standing.changed.connect(func(_p: float): refresh())
	refresh()


func refresh() -> void:
	var pro := promises.pro if promises != null else ""
	var calling := promises != null and promises.calling
	if calling and pro == "":
		pro = "offer"
	if PromisesScript.SCREEN_PRO.has(pro):
		var spec: Array = PromisesScript.SCREEN_PRO[pro]
		headline = str(spec[0])
		if headline.contains("%d"):
			headline = headline % promises.trial_ends()
		fine_print = str(spec[1])
	else:
		headline = PromisesScript.SCREEN_IDLE[_idle_index]
		fine_print = ""
	_title.text = headline
	_small.text = fine_print
	if standing != null:
		_standing_label.text = StandingScript.SCREEN % int(round(standing.standing))


func _process(delta: float) -> void:
	_t += delta
	var calling := promises != null and promises.calling
	# An incoming offer pulses the panel; otherwise a slow, cheap flicker.
	var level := 1.4 + (0.9 * sin(_t * 6.0) if calling else 0.08 * sin(_t * 1.7))
	_glass.emission_energy_multiplier = level
	_glow.light_energy = 0.25 * level
	if promises == null or (promises.pro == "" and not calling):
		_idle_t += delta
		if _idle_t >= ROTATE_SECONDS:
			_idle_t = 0.0
			_idle_index = (_idle_index + 1) % PromisesScript.SCREEN_IDLE.size()
			refresh()


func _build() -> void:
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var fb := BoxMesh.new()
	fb.size = Vector3(SIZE.x + 0.05, SIZE.y + 0.05, 0.03)
	frame.mesh = fb
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.08, 0.08, 0.09)
	steel.metallic = 0.7
	steel.roughness = 0.4
	frame.material_override = steel
	add_child(frame)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var q := QuadMesh.new()
	q.size = SIZE
	glass.mesh = q
	glass.position.z = 0.016
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = GLASS
	_glass.emission_enabled = true
	_glass.emission = Color(0.12, 0.09, 0.05)
	_glass.roughness = 0.15
	glass.material_override = _glass
	add_child(glass)
	_title = Label3D.new()
	SignType.dress(_title)
	_title.name = "Headline"
	_title.font_size = 64
	_title.pixel_size = 0.0019
	_title.outline_size = 0
	_title.modulate = GOLD
	_title.position = Vector3(0, 0.03, 0.018)
	_title.width = SIZE.x / _title.pixel_size * 0.92
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_small = Label3D.new()
	SignType.dress(_small)
	_small.name = "FinePrint"
	_small.font_size = 32
	_small.pixel_size = 0.0016
	_small.outline_size = 0
	_small.modulate = GOLD.darkened(0.35)
	_small.position = Vector3(0, -SIZE.y * 0.38, 0.018)
	add_child(_small)
	_standing_label = Label3D.new()
	SignType.dress(_standing_label)
	_standing_label.name = "StandingLine"
	_standing_label.font_size = 32
	_standing_label.pixel_size = 0.0014
	_standing_label.outline_size = 0
	_standing_label.modulate = Color(0.2, 0.84, 0.9)
	_standing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_standing_label.position = Vector3(SIZE.x * 0.46, SIZE.y * 0.4, 0.018)
	add_child(_standing_label)
	_glow = OmniLight3D.new()
	_glow.light_color = GOLD
	_glow.omni_range = 1.4
	_glow.position = Vector3(0, 0, 0.25)
	add_child(_glow)
