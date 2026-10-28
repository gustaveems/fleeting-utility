class_name PrologueCity
extends Node3D
## PRESENTATION — the prologue's city, district by district (Ticket-15 Phase B, the plan in
## PrologueCityPlan; docs/references/city_plan_v1.png). Replaces Phase A's random towers:
##
##   A  the town      a shuttered main street of brick shops beside the line, the car park
##                    with the fenced stone, the dead mall, the depot, the leased fields
##   B  the ridge     the tunnel cuts through it
##   C  the edge      an old grid of low blocks; the ring highway on stilts
##   D  the canyon    two walls of megatowers flanking the line, cross streets every 90 m,
##                    the old low blocks crammed beneath them
##   E  the canal     quays, two bridges, Colossus Plaza (the reveal's view), the Heritage
##                    Quarter upstream, warehouses on the far bank
##   F  low blocks    dense blocks and neon down to Block 31 (the avenue is PrologueAvenue)
##
## Every tall thing keeps off the shots' sightlines and the billboards (handed in by the
## Prologue). Massing is one MultiMesh (per-instance colour), neon another; the town's
## shopfronts are Downtown kit facades. Seeded: the same city every run.

const MASS_TINTS := {
	"town": Color(0.55, 0.46, 0.36),
	"edge": Color(0.36, 0.37, 0.38),
	"tower": Color(0.2, 0.26, 0.28),
	"tower_hi": Color(0.33, 0.41, 0.43),
	"low": Color(0.34, 0.36, 0.36),
	"block": Color(0.24, 0.2, 0.22),
}

var curve: Curve3D
var sightlines: Array[PackedVector2Array] = []
var boards: Array[Vector3] = []
var colossus: Vector3
var avenue_clear: Rect2

var _rng := RandomNumberGenerator.new()
var _mass: Array[Transform3D] = []
var _mass_colors: Array[Color] = []
var _neon: Array[Transform3D] = []
var _neon_colors: Array[Color] = []
var _kit := CityKit.new()


## Build it all (the Prologue hands over its curve and sightlines first).
func build() -> void:
	_rng.seed = 2026
	_town()
	_ridge()
	_edge()
	_canyon()
	_canal()
	_low_blocks()
	_skyline()
	_commit()


## ----- A. THE TOWN ---------------------------------------------------------------------


func _town() -> void:
	var s: Array = PrologueCityPlan.MAIN_STREET
	_flat(s[0], s[1], s[2], s[3], 0.07, Color(0.22, 0.2, 0.19))
	var lot: Array = PrologueCityPlan.STONE_LOT
	_flat(lot[0], lot[1], lot[2], lot[3], 0.07, Color(0.27, 0.26, 0.25))
	for x in range(int(lot[0]) + 4, int(lot[1]), 5):  # faded stall lines
		_flat(x, x + 0.2, lot[2] + 1.0, lot[2] + 6.0, 0.08, Color(0.6, 0.58, 0.5))
	var k := 0
	for row: Array in PrologueCityPlan.SHOP_ROWS:
		var face_z: float = row[0]
		var out := float(row[1])
		var depth: float = row[2]
		var x := float(s[0]) + 2.0
		while x + PrologueCityPlan.SHOP_WIDTH < float(s[1]):
			var x0 := x
			x += PrologueCityPlan.SHOP_WIDTH + 1.0
			if out > 0.0 and x0 + PrologueCityPlan.SHOP_WIDTH > lot[0] and x0 < lot[1]:
				continue  # the car park with the stone
			k += 1
			var h := 6.0 + float(k % 2) * 3.0
			var centre := Vector3(
				x0 + PrologueCityPlan.SHOP_WIDTH * 0.5, h * 0.5, face_z - out * depth * 0.5
			)
			_box(centre, Vector3(PrologueCityPlan.SHOP_WIDTH, h, depth), MASS_TINTS["town"])
			# The street face: brick shopfronts, two or three floors.
			var origin := Vector3(x0 if out > 0.0 else x0 + PrologueCityPlan.SHOP_WIDTH, 0, face_z)
			var outward := Vector3(0, 0, out)
			_kit.facade(origin, outward, 6, int(h / CityKit.FLOOR), CityKit.Style.BRICK, k)
			# Shuttered: a grey roller over the shop window, and a dead sign over it.
			_box(
				Vector3(centre.x, 1.4, face_z + out * 0.08),
				Vector3(PrologueCityPlan.SHOP_WIDTH * 0.7, 2.6, 0.06),
				Color(0.42, 0.42, 0.42)
			)
			var sign_text: String = PrologueCityPlan.TOWN_SIGNS[
				k % PrologueCityPlan.TOWN_SIGNS.size()
			]
			if not sign_text.is_empty():
				_label(sign_text, Vector3(centre.x, 3.3, face_z + out * 0.12), out, 0.02)
	var mall: Array = PrologueCityPlan.DEAD_MALL
	_box(mall[0], mall[1], Color(0.55, 0.47, 0.38))
	_label("M A L L", mall[0] + Vector3(0, 2.5, mall[1].z * 0.5 + 0.1), 1.0, 0.06)
	var park: Array = PrologueCityPlan.MALL_PARKING
	_flat(park[0], park[1], park[2], park[3], 0.07, Color(0.24, 0.23, 0.22))
	var depot: Array = PrologueCityPlan.DEPOT
	_box(depot[0], depot[1], Color(0.5, 0.52, 0.54))
	_box(
		depot[0] + Vector3(0, depot[1].y * 0.5 + 0.4, 0),
		depot[1] * Vector3(1.02, 0, 1.02) + Vector3(0, 0.8, 0),
		Color(0.36, 0.38, 0.4)
	)
	_label("LOGISTICS · DEPOT 4", depot[0] + Vector3(0, 3.5, depot[1].z * 0.5 + 0.1), 1.0, 0.05)
	var yard: Array = PrologueCityPlan.DEPOT_YARD
	_flat(yard[0], yard[1], yard[2], yard[3], 0.07, Color(0.3, 0.3, 0.3))
	for f: Array in PrologueCityPlan.FIELDS:
		_field(f[0], f[1], f[2], f[3])
	_label("AGRI-LEASE · PRIVATE CROP", Vector3(-480, 3.2, 69.5), -1.0, 0.04)
	for b: Array in PrologueCityPlan.TOWN_BOARDS:
		_peeling_board(Vector3(b[0], 0, b[1]), b[2])


## A leased field: furrowed dirt, a fence round it.
func _field(x0: float, z0: float, w: float, d: float) -> void:
	_flat(x0, x0 + w, z0, z0 + d, 0.06, Color(0.36, 0.3, 0.18))
	for k in int(w / 4.0):
		var x := x0 + 2.0 + k * 4.0
		_flat(x, x + 1.2, z0 + 1.0, z0 + d - 1.0, 0.065, Color(0.3, 0.34, 0.16))
	var post := Color(0.25, 0.24, 0.22)
	for k in int(w / 8.0) + 1:
		for z in [z0, z0 + d]:
			_box(Vector3(x0 + k * 8.0, 0.8, z), Vector3(0.15, 1.6, 0.15), post)
	for k in int(d / 8.0) + 1:
		for x in [x0, x0 + w]:
			_box(Vector3(x, 0.8, z0 + k * 8.0), Vector3(0.15, 1.6, 0.15), post)
	for z in [z0, z0 + d]:
		_box(Vector3(x0 + w * 0.5, 1.3, z), Vector3(w, 0.05, 0.05), post)
	for x in [x0, x0 + w]:
		_box(Vector3(x, 1.3, z0 + d * 0.5), Vector3(0.05, 0.05, d), post)


## The city's billboards, older: a dirty panel on two legs, the slogan faded.
func _peeling_board(at: Vector3, text: String) -> void:
	for x in [-5.0, 5.0]:
		_box(at + Vector3(x, 4.0, 0), Vector3(0.3, 8.0, 0.3), Color(0.2, 0.2, 0.2))
	_box(at + Vector3(0, 9.5, 0), Vector3(14.0, 4.0, 0.3), Color(0.5, 0.45, 0.38))
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.03
	l.modulate = Color(0.65, 0.55, 0.5, 0.75)
	l.outline_size = 0
	l.position = at + Vector3(0, 9.5, -0.2)
	l.rotation_degrees.y = 180.0
	add_child(l)


## ----- B. THE RIDGE ---------------------------------------------------------------------


func _ridge() -> void:
	var r: Array = PrologueCityPlan.RIDGE
	var zr: Array = PrologueCityPlan.Z_RANGE
	var h := PrologueCityPlan.RIDGE_HEIGHT
	var half := PrologueCityPlan.TUNNEL_HALF
	var cx := (float(r[0]) + float(r[1])) * 0.5
	var w := float(r[1]) - float(r[0])
	var rock := Color(0.2, 0.17, 0.14)
	var north := float(zr[0])
	var south := float(zr[1])
	_box(Vector3(cx, h * 0.5, (north - half) * 0.5), Vector3(w, h, -half - north), rock)
	_box(Vector3(cx, h * 0.5, (south + half) * 0.5), Vector3(w, h, south - half), rock)
	var ceiling := PrologueCityPlan.TUNNEL_CEILING
	_box(Vector3(cx, (h + ceiling) * 0.5, 0), Vector3(w, h - ceiling, half * 2.0), rock)


## ----- C. THE CITY'S EDGE ----------------------------------------------------------------


func _edge() -> void:
	var e: Array = PrologueCityPlan.EDGE
	var zr: Array = PrologueCityPlan.Z_RANGE
	var step := PrologueCityPlan.EDGE_STEP
	var size := PrologueCityPlan.EDGE_BLOCK
	var x := float(e[0])
	while x + size <= float(e[1]):
		var z := float(zr[0])
		while z + size <= float(zr[1]):
			var c := Vector3(x + size * 0.5, 0, z + size * 0.5)
			if absf(c.x - PrologueCityPlan.RING_X) > size * 0.5 + 6.0 and _clear_of_track(c, 18.0):
				var h := _rng.randf_range(10, 22)
				_box(c + Vector3(0, h * 0.5, 0), Vector3(size, h, size), MASS_TINTS["edge"])
			z += step
		x += step
	# The ring highway on stilts, under the line.
	var deck := PrologueCityPlan.RING_DECK
	var length := float(zr[1]) - float(zr[0])
	_box(Vector3(PrologueCityPlan.RING_X, deck, 0), Vector3(12, 1.0, length), Color(0.3, 0.3, 0.31))
	var z2 := float(zr[0])
	while z2 < float(zr[1]):
		_box(
			Vector3(PrologueCityPlan.RING_X, deck * 0.5, z2),
			Vector3(2, deck, 2),
			Color(0.26, 0.26, 0.27)
		)
		z2 += 30.0


## ----- D. THE MONOLITH CANYON --------------------------------------------------------------


func _canyon() -> void:
	var wd: Array = PrologueCityPlan.WALLS_D
	var d := float(wd[0])
	while d < float(wd[1]):
		var span := fmod(d - float(wd[0]), PrologueCityPlan.CROSS_STREET_EVERY)
		if span >= PrologueCityPlan.CROSS_STREET_WIDTH:
			var f := _frame_at(d)
			for side in [-1.0, 1.0]:
				for w in 2:
					var lateral: float = PrologueCityPlan.WALL_LATERAL[w]
					var foot: float = PrologueCityPlan.WALL_FOOTPRINT[w]
					var at: Vector3 = f.origin + f.basis.x * side * lateral
					at.y = 0.0
					if not _may_stand(at, 13.0):
						continue
					var hr: Array = PrologueCityPlan.WALL_HEIGHT[w]
					var h := _rng.randf_range(hr[0], hr[1])
					var tint: Color = MASS_TINTS["tower"].lerp(MASS_TINTS["tower_hi"], _rng.randf())
					_tower(at, Vector3(foot, h, foot), f.basis, tint)
		d += PrologueCityPlan.WALL_FOOTPRINT[1] + 2.0
	# The old low blocks crammed beneath and between.
	var cell := PrologueCityPlan.LOW_CELL
	var zr: Array = PrologueCityPlan.Z_RANGE
	var cx := float(PrologueCityPlan.CANYON[0])
	var i := 0
	while cx < float(PrologueCityPlan.CANYON[1]):
		var z := float(zr[0])
		var j := 0
		while z < float(zr[1]):
			if i % 3 != 2 and j % 3 != 2 and _rng.randf() < 0.75:
				var c := Vector3(cx + cell * 0.5, 0, z + cell * 0.5)
				if _clear_of_track(c, 14.0) and _clear_of_canal(c):
					var lh: Array = PrologueCityPlan.LOW_HEIGHT
					var h := _rng.randf_range(lh[0], lh[1])
					_box(
						c + Vector3(0, h * 0.5, 0),
						Vector3(cell - 1.5, h, cell - 1.5),
						MASS_TINTS["low"].darkened(_rng.randf() * 0.25)
					)
			z += cell
			j += 1
		cx += cell
		i += 1


## A megatower: the massing, turned with the line, a lit crown.
func _tower(at: Vector3, size: Vector3, along: Basis, tint: Color) -> void:
	var yaw := atan2(along.z.x, along.z.z)
	var b := Basis().rotated(Vector3.UP, yaw)
	_mass.append(Transform3D(b.scaled(size), at + Vector3(0, size.y * 0.5, 0)))
	_mass_colors.append(tint)
	if _rng.randf() < 0.5:
		_neon.append(
			Transform3D(
				b.scaled(Vector3(size.x * 1.02, 0.6, size.z * 1.02)),
				at + Vector3(0, size.y - 3.0, 0)
			)
		)
		_neon_colors.append(Color(0.6, 0.9, 0.95))


## ----- E. THE COLOSSUS CANAL ----------------------------------------------------------------


func _canal() -> void:
	var cx := colossus.x
	var half := PrologueCityPlan.CANAL_HALF
	var zr: Array = PrologueCityPlan.Z_RANGE
	var length := float(zr[1]) - float(zr[0])
	var water := MeshInstance3D.new()
	water.name = "Canal"
	var plane := PlaneMesh.new()
	plane.size = Vector2(half * 2.0, length)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.08, 0.15, 0.2)
	wm.metallic = 0.6
	wm.roughness = 0.12
	water.material_override = wm
	water.position = Vector3(cx, 0.15, 0)
	add_child(water)
	for side in [-1.0, 1.0]:  # the quay walls
		_box(
			Vector3(cx + side * (half + 0.5), 0.8, 0),
			Vector3(1.0, 1.6, length),
			Color(0.42, 0.4, 0.37)
		)
	for bz: float in PrologueCityPlan.BRIDGES_Z:
		_box(Vector3(cx, 3.0, bz), Vector3(half * 2.0 + 8.0, 0.8, 8.0), Color(0.45, 0.44, 0.42))
		for rz in [-3.8, 3.8]:
			_box(
				Vector3(cx, 3.9, bz + rz),
				Vector3(half * 2.0 + 8.0, 1.0, 0.2),
				Color(0.2, 0.2, 0.21)
			)
	var p: Array = PrologueCityPlan.PLAZA
	_flat(cx + p[0], cx + p[1], p[2], p[3], 0.1, Color(0.62, 0.58, 0.5))
	for k in 5:
		var lamp := CityKit.prop(
			CityKit.polyhaven("street_lamp_01"),
			self,
			Vector3(cx + p[1] - 3.0, 0, p[2] + 10.0 + k * 22.0),
			0.0,
			220.0
		)
		if lamp != null:
			lamp.scale = Vector3.ONE * 1.6
	var hq: Array = PrologueCityPlan.HERITAGE
	_flat(cx + hq[0], cx + hq[1], hq[2], hq[3], 0.1, Color(0.7, 0.66, 0.58))
	var pavilion_z := float(hq[2]) + 6.0
	var n := 0
	while pavilion_z + 18.0 < float(hq[3]):
		var h := 8.0 + float(n % 2) * 3.0
		var at := Vector3(cx + hq[1] - 12.0, h * 0.5, pavilion_z + 9.0)
		_box(at, Vector3(20, h, 18), Color(0.78, 0.72, 0.6))
		# Facing +X the modules run toward −Z: start at the pavilion's far (south) end.
		_kit.facade(
			Vector3(cx + hq[1] - 2.0, 0, pavilion_z + 18.0),
			Vector3.RIGHT,
			9,
			int(h / CityKit.FLOOR),
			CityKit.Style.METAL,
			70 + n
		)
		pavilion_z += 22.0
		n += 1
	_label(
		"HERITAGE QUARTER",
		Vector3(cx + hq[1] - 1.5, 11.0, (hq[2] + hq[3]) * 0.5),
		0.0,
		0.08,
		Color(0.95, 0.78, 0.4),
		true
	)
	var wh: Array = PrologueCityPlan.WAREHOUSES
	var wz := float(wh[2])
	while wz + 40.0 <= float(wh[3]):
		_box(
			Vector3(cx + (wh[0] + wh[1]) * 0.5, 6.0, wz + 20.0),
			Vector3(wh[1] - wh[0], 12.0, 36.0),
			Color(0.4, 0.38, 0.36)
		)
		wz += 44.0


## ----- F. THE LOW BLOCKS -------------------------------------------------------------------


func _low_blocks() -> void:
	var lb: Array = PrologueCityPlan.LOW_BLOCKS
	var zr: Array = PrologueCityPlan.Z_RANGE
	var size := PrologueCityPlan.LOW_BLOCK
	var x := float(lb[0])
	while x + size <= float(lb[1]):
		var z := float(zr[0])
		while z + size <= float(zr[1]):
			var c := Vector3(x + size * 0.5, 0, z + size * 0.5)
			var near_avenue := avenue_clear.grow(6.0).has_point(Vector2(c.x, c.z))
			if not near_avenue and _rng.randf() < 0.8 and _may_stand(c, 14.0):
				var hr: Array = PrologueCityPlan.LOW_BLOCK_HEIGHT
				var h := _rng.randf_range(hr[0], hr[1])
				_box(
					c + Vector3(0, h * 0.5, 0),
					Vector3(size, h, size),
					MASS_TINTS["block"].lightened(_rng.randf() * 0.12)
				)
				if _rng.randf() < 0.45:  # a neon sign on the face toward the line
					var face := _toward_track(c)
					var at := (
						c + face * (size * 0.5 + 0.2) + Vector3(0, _rng.randf_range(5, h - 2), 0)
					)
					var col: Color = PrologueCityPlan.NEON[
						_rng.randi() % PrologueCityPlan.NEON.size()
					]
					var b := Basis.looking_at(face, Vector3.UP)
					_neon.append(
						Transform3D(b.scaled(Vector3(_rng.randf_range(4, 9), 1.4, 0.2)), at)
					)
					_neon_colors.append(col)
			z += PrologueCityPlan.LOW_BLOCK_STEP
		x += PrologueCityPlan.LOW_BLOCK_STEP


## ----- THE SKYLINE ----------------------------------------------------------------------------


func _skyline() -> void:
	var length := curve.get_baked_length()
	var d := PrologueScript.TUNNEL_END + 10.0
	var lat: Array = PrologueCityPlan.SKYLINE_LATERAL
	var hr: Array = PrologueCityPlan.SKYLINE_HEIGHT
	while d < length:
		var f := _frame_at(d)
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.5:
				continue
			var at: Vector3 = f.origin + f.basis.x * side * _rng.randf_range(lat[0], lat[1])
			at.y = 0.0
			if not _may_stand(at, 13.0):
				continue
			var h := _rng.randf_range(hr[0], hr[1])
			if d > PrologueScript.LOW_BLOCKS_START:
				h *= 0.45
			var s := Vector3(_rng.randf_range(14, 30), h, _rng.randf_range(14, 30))
			_mass.append(
				Transform3D(
					Basis().rotated(Vector3.UP, _rng.randf_range(0, 0.3)).scaled(s),
					at + Vector3(0, h * 0.5, 0)
				)
			)
			_mass_colors.append(MASS_TINTS["tower"].lerp(MASS_TINTS["tower_hi"], _rng.randf()))
		d += 14.0


## ----- HELPERS ----------------------------------------------------------------------------


func _commit() -> void:
	_multimesh("Massing", _mass, _mass_colors, false)
	_multimesh("Neon", _neon, _neon_colors, true)
	_kit.build(self)


func _multimesh(
	node_name: String, xfs: Array[Transform3D], colors: Array[Color], glow: bool
) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)


func _box(centre: Vector3, size: Vector3, color: Color) -> void:
	_mass.append(Transform3D(Basis().scaled(size), centre))
	_mass_colors.append(color)


## A flat patch on the ground (roads, lots, plazas, furrows), `y` its height.
func _flat(x0: float, x1: float, z0: float, z1: float, y: float, color: Color) -> void:
	_box(
		Vector3((x0 + x1) * 0.5, y * 0.5, (z0 + z1) * 0.5),
		Vector3(absf(x1 - x0), y, absf(z1 - z0)),
		color
	)


## A sign. `facing` +1 faces +Z, −1 −Z, 0 faces +X (with `east` true).
func _label(
	text: String,
	at: Vector3,
	facing: float,
	pixel: float,
	color := Color(0.7, 0.6, 0.5),
	east := false
) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.position = at
	if east:
		l.rotation_degrees.y = 90.0
	elif facing < 0.0:
		l.rotation_degrees.y = 180.0
	add_child(l)


func _frame_at(d: float) -> Transform3D:
	var length := curve.get_baked_length()
	var p := curve.sample_baked(clampf(d, 0.0, length), true)
	var ahead := curve.sample_baked(clampf(d + 2.0, 0.0, length), true)
	if ahead.distance_to(p) < 0.01:
		ahead = p + (p - curve.sample_baked(clampf(d - 2.0, 0.0, length), true))
	var forward := (ahead - p).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward), p)


func _clear_of_track(at: Vector3, margin: float) -> bool:
	var p := curve.get_closest_point(Vector3(at.x, 10.0, at.z))
	return Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) >= margin


## Off the water, the quays, and the canal's own places (the plaza, the Heritage Quarter).
func _clear_of_canal(at: Vector3) -> bool:
	if absf(at.x - colossus.x) <= PrologueCityPlan.CANAL_HALF + 6.0:
		return false
	for r: Array in [PrologueCityPlan.PLAZA, PrologueCityPlan.HERITAGE]:
		var rx0: float = colossus.x + float(r[0]) - 4.0
		var rx1: float = colossus.x + float(r[1]) + 4.0
		if at.x > rx0 and at.x < rx1 and at.z > float(r[2]) - 4.0 and at.z < float(r[3]) + 4.0:
			return false
	return true


## A tall thing may stand here: off the track, the canal, the colossus, the avenue, and
## every shot's sightline and billboard.
func _may_stand(at: Vector3, margin: float) -> bool:
	if not _clear_of_track(at, margin) or not _clear_of_canal(at):
		return false
	if Vector2(at.x, at.z).distance_to(Vector2(colossus.x, colossus.z)) < 42.0:
		return false
	if avenue_clear.has_point(Vector2(at.x, at.z)):
		return false
	var p := Vector2(at.x, at.z)
	for line in sightlines:
		var c := Geometry2D.get_closest_point_to_segment(p, line[0], line[1])
		if c.distance_to(p) < 22.0:
			return false
	for b in boards:
		if p.distance_to(Vector2(b.x, b.z)) < 20.0:
			return false
	return true


## The horizontal direction from `at` toward the nearest point of the line.
func _toward_track(at: Vector3) -> Vector3:
	var p := curve.get_closest_point(Vector3(at.x, 10.0, at.z))
	var v := Vector3(p.x - at.x, 0, p.z - at.z)
	if absf(v.x) > absf(v.z):
		return Vector3(signf(v.x), 0, 0)
	return Vector3(0, 0, signf(v.z))
