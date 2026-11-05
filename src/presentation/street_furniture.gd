class_name StreetFurniture
extends RefCounted
## PRESENTATION — the pavement's street furniture on the evening walk (playtest 2026-11-05:
## the far shops are lit; the street needed things in it): a hydrant, a bin and a manhole
## by each lamp, the clean and worn variants alternating; the far shops' bays and the cameras
## on their pillars. Built into the layout's world.


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
	var cover := CityKit.prop(
		CityKit.polyhaven("water_manhole_cover"),
		world,
		Vector3(side * (2.4 + (lamp % 3) * 1.6), 0.01, z - 5.0),
		float(lamp * 71 % 360),
		80.0
	)
	if cover != null:
		cover.name = "Manhole_%d" % number


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
