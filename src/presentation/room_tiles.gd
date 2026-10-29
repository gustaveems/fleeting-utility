class_name RoomTiles
extends RefCounted
## PRESENTATION — the apartment's floor (the look pass, 2026-10-29; the reference: the
## abandoned room in notes.md, its hex patterned tiles; the palette's tiles #8C3B3B and
## #3E4F66). A seamless hex-tile texture made once in code: rosettes of cream, oxblood and
## slate blue, dark grout, every tile a shade off, a few cracked or gone to bare concrete.
##
##   floor_material.albedo_texture = RoomTiles.texture()
##   floor_material.uv1_scale = RoomTiles.uv_scale(period_m)   (triplanar)

## Hex size in pixels (centre to corner), columns and row-pairs per texture: the tiling
## repeats exactly, so the texture is seamless.
const HEX := 16.0
const COLUMNS := 8
const ROW_PAIRS := 4
const GROUT := 2.2
## The palette's tiles, worn down a step (the room is old; at the camera's distance the
## full colours read as a checkerboard).
const CREAM := Color("#A69878")
const OXBLOOD := Color("#7A3B37")
const SLATE := Color("#3E4C5C")
const GROUT_COLOR := Color(0.16, 0.15, 0.14)
const BARE := Color(0.32, 0.3, 0.27)
## The rosette: which colour each tile takes, by (column + 2·row) mod 6.
const PATTERN: Array[Color] = [CREAM, OXBLOOD, CREAM, SLATE, CREAM, OXBLOOD]

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_paint())
	return _texture


## uv1_scale for a triplanar floor so one texture spans `period` metres, hexes not squashed
## (the texture is wider than it is tall).
static func uv_scale(period: float) -> Vector3:
	var size := _size()
	return Vector3(1.0 / period, 1.0, (1.0 / period) * size.x / size.y)


static func _size() -> Vector2i:
	var w := sqrt(3.0) * HEX
	return Vector2i(roundi(w * COLUMNS), roundi(3.0 * HEX * ROW_PAIRS))


static func _paint() -> Image:
	var size := _size()
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var w := float(size.x) / COLUMNS  # the exact column pitch the texture repeats on
	var row_h := float(size.y) / (ROW_PAIRS * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var shade: Dictionary = {}
	for c in COLUMNS:
		for r in ROW_PAIRS * 2:
			var bare := rng.randf() < 0.035
			shade[Vector2i(c, r)] = [rng.randf_range(0.86, 1.06), bare, rng.randf() < 0.05]
	for y in size.y:
		for x in size.x:
			var best := 1e9
			var second := 1e9
			var tile := Vector2i.ZERO
			var r0 := floori(y / row_h)
			for r in range(r0 - 1, r0 + 2):
				var offset := w * 0.5 if posmod(r, 2) == 1 else 0.0
				var c0 := roundi((x - offset) / w)
				for c in range(c0 - 1, c0 + 2):
					var centre := Vector2(c * w + offset, r * row_h)
					var dist := Vector2(x, y).distance_to(centre)
					if dist < best:
						second = best
						best = dist
						tile = Vector2i(posmod(c, COLUMNS), posmod(r, ROW_PAIRS * 2))
					elif dist < second:
						second = dist
			var col: Color
			if second - best < GROUT:
				col = GROUT_COLOR
			else:
				var s: Array = shade[tile]
				col = BARE if s[1] else PATTERN[posmod(tile.x + 2 * tile.y, PATTERN.size())]
				col = col * float(s[0])
				# A hairline crack across a few, and grime toward the grout.
				if s[2] and absf((x + y) % 23 - 11) < 0.6:
					col = col.darkened(0.45)
				col = col.darkened(clampf(0.25 - (second - best) * 0.02, 0.0, 0.25))
			img.set_pixel(x, y, col)
	return img
