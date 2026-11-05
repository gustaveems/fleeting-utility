class_name Storefront
extends RefCounted
## PRESENTATION — a lit shop behind an open bay of the boulevard's ground floor (playtest
## 2026-11-05: "the shopfronts are black": dark glass over a solid block). The kit's facade
## leaves the bay open (`CityKit.facade(..., skip_ground)`), the massing is hollowed
## behind it, and this builds the room: a tiled floor, panelled walls, a warm ceiling,
## the brand in neon and a window display by kind.
##
##   LIGHTING    chandeliers hung over brass vases on plinths
##   FURNITURE   a lounge chair and an armchair on a dais, a wall of wine
##   FASHION     two faceless mannequins on a dais
##
## Real metres in the parent's space. The room's origin is the middle of its opening on
## the street plane; it opens toward +X and runs back toward −X, `width` along Z.

enum Kind { LIGHTING, FURNITURE, FASHION }

const DEPTH := 5.0
const HEIGHT := CityKit.FLOOR
const FLOOR_Y := 0.18
## One light a shop (no shadows): the street's own lamps do the rest.
const LIGHT_ENERGY := 1.0
const WINE := "wine_bottles_01"

static var _tile_material: StandardMaterial3D


## Build one shop; `tag` numbers it. Returns its root (named `Storefront_<tag>`, with the
## `kind` and `width` as meta and the light and the window display as children).
static func build(
	parent: Node3D, street: Vector3, width: float, brand: String, neon: Color, kind: Kind, tag: int
) -> Node3D:
	var room := Node3D.new()
	room.name = "Storefront_%d" % tag
	room.position = street
	room.set_meta("kind", int(kind))
	room.set_meta("width", width)
	parent.add_child(room)
	_shell(room, width)
	_frame(room, width)
	var sign := Label3D.new()
	SignType.dress(sign)
	sign.text = brand
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.modulate = neon
	sign.position = Vector3(-0.9, HEIGHT - 0.75, 0)
	sign.rotation_degrees.y = 90.0
	room.add_child(sign)
	SignType.neon(sign, neon)
	var light := OmniLight3D.new()
	light.name = "ShopLight"
	light.light_color = Color(1.0, 0.86, 0.66)
	light.light_energy = LIGHT_ENERGY
	light.omni_range = 7.5
	light.position = Vector3(-2.2, HEIGHT - 0.5, 0)
	room.add_child(light)
	var display := Node3D.new()
	display.name = "Display"
	room.add_child(display)
	match kind:
		Kind.LIGHTING:
			_lighting(display, width)
		Kind.FURNITURE:
			_furniture(display, width)
		Kind.FASHION:
			_fashion(display, width)
	return room


## Floor, walls and a glowing ceiling, drawn from inside (no back-face culling).
static func _shell(room: Node3D, width: float) -> void:
	var wall := _flat(Color(0.4, 0.33, 0.26), 0.85)
	var panel := _flat(Color(0.2, 0.13, 0.09), 0.5)
	var ceiling := _flat(Color(0.9, 0.78, 0.6), 0.9, Color(1.0, 0.78, 0.5), 0.55)
	var strip := _flat(Color(1, 1, 1), 0.5, Color(1.0, 0.88, 0.66), 3.0)
	_box(room, Vector3(-DEPTH * 0.5, FLOOR_Y - 0.02, 0), Vector3(DEPTH, 0.04, width), _tiles())
	_box(room, Vector3(-DEPTH + 0.05, HEIGHT * 0.5, 0), Vector3(0.1, HEIGHT, width), wall)
	# A dark wainscot along the back wall, the lit plaster above it.
	_box(room, Vector3(-DEPTH + 0.12, 0.55, 0), Vector3(0.06, 0.75, width - 0.2), panel)
	for end in [-1.0, 1.0]:
		var z: float = end * (width * 0.5 - 0.05)
		_box(room, Vector3(-DEPTH * 0.5, HEIGHT * 0.5, z), Vector3(DEPTH, HEIGHT, 0.1), wall)
	_box(room, Vector3(-DEPTH * 0.5, HEIGHT - 0.04, 0), Vector3(DEPTH, 0.08, width), ceiling)
	_box(room, Vector3(-1.6, HEIGHT - 0.09, 0), Vector3(0.25, 0.02, width * 0.85), strip)
	_box(room, Vector3(-3.6, HEIGHT - 0.09, 0), Vector3(0.25, 0.02, width * 0.85), strip)


## The opening: a dark header (the sign band), a plinth, a mullion at every module edge
## and a pane of faint glass for the street's lights to slide across.
static func _frame(room: Node3D, width: float) -> void:
	var steel := _flat(Color(0.06, 0.06, 0.07), 0.35)
	var glass := _flat(Color(0.75, 0.88, 0.95, 0.1), 0.05)
	glass.metallic_specular = 1.0
	_box(room, Vector3(0.02, HEIGHT - 0.2, 0), Vector3(0.26, 0.4, width), steel)
	_box(room, Vector3(0.02, FLOOR_Y + 0.1, 0), Vector3(0.2, 0.2, width), steel)
	var edge := -width * 0.5
	while edge <= width * 0.5 + 0.01:
		_box(room, Vector3(0.02, HEIGHT * 0.5, edge), Vector3(0.12, HEIGHT, 0.08), steel)
		edge += CityKit.MODULE
	_box(room, Vector3(-0.12, HEIGHT * 0.5 - 0.1, 0), Vector3(0.02, HEIGHT - 0.6, width), glass)


## Two chandeliers on cords over brass vases on white plinths. The game camera looks
## down through the glass, so a display lives in the front two metres: anything deeper (or
## high against the ceiling) is hidden by the sign band.
static func _lighting(display: Node3D, width: float) -> void:
	var plinth := _flat(Color(0.9, 0.88, 0.84), 0.4)
	var cord := _flat(Color(0.05, 0.05, 0.05), 0.6)
	for k in 2:
		var z := (k - 0.5) * width * 0.5
		_box(display, Vector3(-1.4, HEIGHT - 0.45, z), Vector3(0.02, 0.9, 0.02), cord)
		var lamp := CityKit.prop(
			CityKit.polyhaven("Chandelier_03"), display, Vector3(-1.4, HEIGHT - 0.9, z), 0.0, 60.0
		)
		if lamp != null:
			lamp.scale = Vector3.ONE * 1.5
		_box(display, Vector3(-0.8, 0.5, z + 0.9), Vector3(0.45, 0.64, 0.45), plinth)
		var vase := CityKit.prop(
			CityKit.polyhaven("brass_vase_04"), display, Vector3(-0.8, 0.82, z + 0.9), 0.0, 60.0
		)
		if vase != null:
			vase.scale = Vector3.ONE * 2.6


## A lounge chair and an armchair on a lit dais, a table of wine in front of them.
static func _furniture(display: Node3D, width: float) -> void:
	var dais := _flat(Color(0.5, 0.12, 0.14), 0.9)
	var glow := _flat(Color(1, 0.8, 0.5), 0.5, Color(1.0, 0.8, 0.5), 2.0)
	_box(display, Vector3(-1.7, FLOOR_Y + 0.05, 0), Vector3(2.4, 0.1, width - 1.0), dais)
	_box(display, Vector3(-0.48, FLOOR_Y + 0.07, 0), Vector3(0.03, 0.04, width - 1.0), glow)
	CityKit.prop(
		CityKit.polyhaven("mid_century_lounge_chair"),
		display,
		Vector3(-1.9, FLOOR_Y + 0.1, -width * 0.22),
		70.0,
		60.0
	)
	CityKit.prop(
		CityKit.polyhaven("ArmChair_01"),
		display,
		Vector3(-1.9, FLOOR_Y + 0.1, width * 0.22),
		110.0,
		60.0
	)
	var oak := _flat(Color(0.22, 0.14, 0.09), 0.5)
	_box(display, Vector3(-0.8, 0.45, 0), Vector3(0.5, 0.06, width - 1.4), oak)
	var bottles: Array[Transform3D] = []
	var z := -width * 0.5 + 0.9
	while z < width * 0.5 - 0.8:
		bottles.append(Transform3D(Basis(), Vector3(-0.8, 0.48, z)))
		z += 0.28
	Forest.plant(display, CityKit.polyhaven(WINE), bottles)


## Two mannequins on a dais, lit from the ceiling.
static func _fashion(display: Node3D, width: float) -> void:
	var dais := _flat(Color(0.92, 0.9, 0.86), 0.3)
	_box(display, Vector3(-2.2, FLOOR_Y + 0.07, 0), Vector3(2.4, 0.14, width - 1.0), dais)
	for k in 2:
		var figure := StreetFigure.new()
		figure.name = "Mannequin_%d" % k
		figure.dress = StreetFigure.Dress.SUIT
		figure.pose = StreetFigure.Pose.STAND
		figure.veiled = true
		figure.position = Vector3(-2.2, FLOOR_Y + 0.14, (k - 0.5) * width * 0.4)
		figure.rotation_degrees.y = -90.0
		display.add_child(figure)


static func _tiles() -> StandardMaterial3D:
	if _tile_material != null:
		return _tile_material
	var m := _flat(Color(0.8, 0.78, 0.74), 0.35)
	var color := CityKit.surface("Tiles141", "Color")
	if ResourceLoader.exists(color):
		m.albedo_texture = load(color)
		m.normal_enabled = true
		m.normal_texture = load(CityKit.surface("Tiles141", "NormalGL"))
		m.roughness_texture = load(CityKit.surface("Tiles141", "Roughness"))
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.5
	_tile_material = m
	return m


static func _flat(
	c: Color, roughness: float, glow: Color = Color.BLACK, energy: float = 0.0
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
