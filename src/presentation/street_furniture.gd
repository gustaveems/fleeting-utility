class_name StreetFurniture
extends RefCounted

## street_lamp_02 is 1.7 m as modelled; the pavement's lamps (street_lamp_01) are about 3 m.
const LAMP_02_SCALE := 1.8
const COATS: Array[Color] = [
	Color(0.14, 0.15, 0.2),
	Color(0.32, 0.12, 0.15),
	Color(0.13, 0.27, 0.27),
	Color(0.4, 0.42, 0.45),
	Color(0.2, 0.17, 0.27),
	Color(0.58, 0.56, 0.52),
	Color(0.1, 0.1, 0.11),
]
const TROUSERS: Array[Color] = [
	Color(0.08, 0.08, 0.1), Color(0.16, 0.16, 0.2), Color(0.25, 0.23, 0.22), Color(0.12, 0.17, 0.27)
]
const LITTER_CANS := 26
const LITTER_PACKS := 44
const RAT_RUN := 3.5
const RAT_SPEED := 2.6
## PRESENTATION — the pavement's street furniture on the evening walk (playtest 2026-11-05:
## the far shops are lit; the street needed things in it): a hydrant, a bin and a manhole
## by each lamp, the clean and worn variants alternating; the far shops' bays and the cameras
## on their pillars. Built into the layout's world.


## The pavement lamp at `z` on `side`: the two models alternate down the street, the
## second raised to the first's height.
static func lamp(layout: EveningLayout, side: float, z: float) -> void:
	var row := int((EveningLayout.HALF_LENGTH - 6 - z) / 14.0)
	var model := "street_lamp_02" if row % 2 == 1 else "street_lamp_01"
	var lamp := CityKit.prop(
		CityKit.polyhaven(model),
		layout.world_root(),
		Vector3(side * 8.6, 0.16, z),
		90.0 * side,
		0.0
	)
	if lamp == null:
		return
	lamp.name = "Lamp_%s_%d_%s" % [model.right(2), row, "E" if side > 0 else "W"]
	if model == "street_lamp_02":
		lamp.scale = Vector3.ONE * LAMP_02_SCALE


## A hydrant, a bin and a manhole round the lamp at `z` on pavement `side` (±1). `number`
## names the set and picks its variants.
static func place(layout: EveningLayout, side: float, z: float, number: int) -> void:
	var lamp := int((EveningLayout.HALF_LENGTH - 6 - z) / 14.0)
	var world := layout.world_root()
	if (lamp + (0 if side > 0 else 1)) % 2 == 0:
		var hydrant := CityKit.prop(
			CityKit.polyhaven("fire_hydrant"),
			world,
			Vector3(side * 8.45, 0.17, z - 10.5),
			0.0,
			80.0
		)
		if hydrant != null:
			CityKit.one_state(hydrant, "fire_hydrant", "_aged", number % 3 == 0)
			hydrant.name = "Hydrant_%d" % number
			layout.solid(Vector3(side * 8.45, 0.55, z - 10.5), Vector3(0.4, 0.8, 0.4))
	var bin := CityKit.prop(
		CityKit.polyhaven("metal_trash_can"),
		world,
		Vector3(side * 13.0, 0.2, z - 3.5),
		float(lamp * 47 % 360),
		80.0
	)
	if bin != null:
		CityKit.one_state(bin, "metal_trash_can", "_rust", number % 2 == 0)
		bin.name = "Bin_%d" % number
		layout.solid(Vector3(side * 13.0, 0.65, z - 3.5), Vector3(0.7, 0.98, 0.7))
		if number % 2 == 0:
			var bag := CityKit.prop(
				CityKit.polyhaven("trashbag"),
				world,
				Vector3(side * 13.1, 0.18, z - 2.5),
				float(lamp * 83 % 360),
				80.0
			)
			if bag != null:
				bag.name = "Bag_%d" % number
				layout.solid(Vector3(side * 13.1, 0.5, z - 2.5), Vector3(0.7, 0.7, 0.7))
	var cover := CityKit.prop(
		CityKit.polyhaven("water_manhole_cover"),
		world,
		Vector3(side * (2.4 + (lamp % 3) * 1.6), 0.01, z - 5.0),
		float(lamp * 71 % 360),
		80.0
	)
	if cover != null:
		cover.name = "Manhole_%d" % number


## What the street's cleaners missed: cans and cigarette packets along the kerbs, and sheets
## of paper against the shopfronts. One MultiMesh a model (`Forest.plant`).
static func litter(layout: EveningLayout) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for spec: Array in [["can_rusted", LITTER_CANS], ["cigarette_pack", LITTER_PACKS]]:
		var placed: Array[Transform3D] = []
		for k in int(spec[1]):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var at := Vector3(
				side * rng.randf_range(8.2, 8.7),
				0.18,
				rng.randf_range(-EveningLayout.HALF_LENGTH, EveningLayout.HALF_LENGTH)
			)
			# On its side, rolled to the kerb.
			var basis := Basis(Vector3.RIGHT, PI * 0.5 * float(k % 2))
			basis = Basis(Vector3.UP, rng.randf() * TAU) * basis
			placed.append(Transform3D(basis, at))
		Forest.plant(layout.world_root(), CityKit.polyhaven(str(spec[0])), placed)


## One stranger's [coat, trousers]: the quarter's evening palette (camel stays the friend's).
static func coat(rng: RandomNumberGenerator) -> Array:
	var coat_colour := COATS[rng.randi() % COATS.size()]
	var legs := TROUSERS[rng.randi() % TROUSERS.size()]
	return [coat_colour.lightened(rng.randf_range(-0.06, 0.1)), legs]


## A rat working along the kerb at `z`: a dash, a stop, a dash back, and gone again behind
## the planters' shadow. Nobody on the street reacts.
static func rat(layout: EveningLayout, side: float, z: float, number: int) -> void:
	var body := CityKit.prop(
		CityKit.polyhaven("street_rat"),
		layout.world_root(),
		Vector3(side * 8.25, 0.18, z),
		0.0,
		60.0
	)
	if body == null:
		return
	body.name = "Rat_%d" % number
	body.scale = Vector3.ONE * 2.2  # the scan is a mouse's size next to a kerb
	var run := layout.create_tween().set_loops()
	for leg: Array in [[RAT_RUN, 0.0], [-RAT_RUN, PI]]:
		run.tween_property(body, "rotation:y", float(leg[1]), 0.08)
		run.tween_property(body, "position:z", z + float(leg[0]), absf(leg[0]) / RAT_SPEED)
		run.tween_interval(2.0 + number * 0.7)


## The shop's bay in a block of `modules` kit modules: (first module, how many).
static func bay(modules: int) -> Vector2i:
	var count := mini(modules - 2, 4)
	return Vector2i((modules - count) / 2, count)


## Solid ground-floor massing for modules [from, to) of the block starting at `z`.
static func ground_run(
	layout: EveningLayout, face_x: float, z: float, from: int, to: int, mat: Material
) -> void:
	if to <= from:
		return
	var length := (to - from) * CityKit.MODULE
	var middle := z - (from + to) * CityKit.MODULE * 0.5
	layout.box(
		Vector3(face_x - 8, CityKit.FLOOR * 0.5, middle), Vector3(16, CityKit.FLOOR, length), mat
	)


## The lit shop in `bay`, with its brand, and a camera on the pillar beside it.
static func open_shop(layout: EveningLayout, face_x: float, z: float, bay: Vector2i) -> void:
	var width := bay.y * CityKit.MODULE
	var middle := z - (bay.x + bay.y * 0.5) * CityKit.MODULE
	var inks: Array[Color] = [Color(0.95, 0.85, 0.6), Color(0.2, 0.84, 0.9), Color(0.95, 0.4, 0.7)]
	var brand := EveningLayout.BRANDS[(layout.shop_no + 3) % EveningLayout.BRANDS.size()]
	var kind: Storefront.Kind = layout.shop_no % Storefront.Kind.size()
	Storefront.build(
		layout.world_root(),
		Vector3(face_x, 0, middle),
		width,
		brand,
		inks[(layout.shop_no + 1) % 3],
		kind,
		layout.shop_no
	)
	layout.shop_no += 1
	# A security camera on the pillar, looking down the pavement (the corporate eye).
	var eye := CityKit.prop(
		CityKit.polyhaven("security_camera_01"),
		layout.world_root(),
		Vector3(face_x + 0.1, CityKit.FLOOR - 0.35, z - CityKit.MODULE * 0.5),
		EveningLayout.CAMERA_YAW,
		90.0
	)
	if eye != null:
		eye.name = "Camera_%d" % layout.camera_no
		layout.camera_no += 1
	# A security light over the shop, on the same pillar, throwing down onto the pavement.
	var light := CityKit.prop(
		CityKit.polyhaven("security_light"),
		layout.world_root(),
		Vector3(face_x + 0.15, CityKit.FLOOR - 0.05, middle),
		EveningLayout.CAMERA_YAW,
		90.0
	)
	if light != null:
		light.name = "SecurityLight_%d" % layout.shop_no
