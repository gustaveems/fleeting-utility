extends Node
## TEMPORARY verification autoload for Ticket-07 Task 3 — controlled lighting photometry.
## Register under [autoload] ONLY for the capture run, then remove it again.
##
## Why this is written the way it is:
##   1. get_viewport().get_texture().get_image() returns the PREVIOUSLY composited frame.
##      Changing lighting and capturing in the same call photographs the OLD look. Every
##      capture below is preceded by a multi-frame settle.
##   2. A real climax drags in the 3.5 s fade, the white DreamFade ColorRect and the
##      ambulance flash — all of which contaminate luminance stats. So the four looks are
##      sampled from a SETTLED APARTMENT, driven directly, one variable at a time.
##   3. The DreamFade rect is forced transparent before every shot; a half-alpha white
##      veil over the whole frame would otherwise dominate the measurement.

const OUT_DIR := "res://.qwen/tmp/"
const SETTLE := 8

## Ticket-06 (pre-fix) clinical constants, as authored before Task 3.
const OLD_KEY_ENERGY := 3.2
const OLD_KEY_COLOR := Color(0.90, 0.95, 1.0)
const OLD_AMBIENT_COLOR := Color(0.8, 0.9, 1.0)
const OLD_AMBIENT_ENERGY := 0.95
const OLD_BG_COLOR := Color(0.80, 0.86, 0.92)

var _frames := 0
var _ws: Node
var _atmo: AtmosphereController
var _env: Environment
var _key: DirectionalLight3D
var _fade_alpha := -1.0
var _step := 0


func _ready() -> void:
	_ws = get_node("/root/Workspace")


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10:
		_gather()
	if _frames == 25 and _step == 0:
		_step = 1
		_run()


func _gather() -> void:
	_atmo = _ws.get_node("Apartment/AtmosphereController")
	_env = _atmo.world_environment.environment
	_key = _atmo.key_light
	# Remember the fade rect's alpha so the shot is never veiled by it.
	var layer := _ws.get_node("DreamscapeManager/DreamFade")
	_fade_alpha = (layer.get_node("FadeRect") as ColorRect).modulate.a
	print("PHOTOMETRY: refs gathered (fade alpha %.2f)" % _fade_alpha)


func _run() -> void:
	var fade := _ws.get_node("DreamscapeManager/DreamFade/FadeRect") as ColorRect
	fade.modulate.a = 0.0

	# ---- 0. reference: clean apartment, NORMAL mode (what "readable" should look like)
	_atmo.set_clinical_mode(false)
	_atmo.set_subdued_mode(false)
	_atmo.entropy_data.entropy = 10.0
	_atmo.entropy_data.entropy_changed.emit(10.0)
	await _settle()
	_dump("REF normal(clean)")
	_shot("t07_0_ref_normal.png")

	# ---- A. OLD clinical: Ticket-06 constants.
	# set_clinical_mode(true) FIRST, so _process() early-returns (mode != NORMAL).
	# Writing the constants while mode is NORMAL gets them clobbered by the per-frame
	# _apply_atmosphere() creep — that is what invalidated the first attempt at this row.
	_atmo.set_clinical_mode(true)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.ambient_light_color = OLD_AMBIENT_COLOR
	_env.ambient_light_energy = OLD_AMBIENT_ENERGY
	_env.background_color = OLD_BG_COLOR
	_env.fog_density = 0.0
	_env.volumetric_fog_density = 0.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 0.55
	_key.light_energy = OLD_KEY_ENERGY
	_key.light_color = OLD_KEY_COLOR
	_key.shadow_enabled = false
	await _settle()
	_dump("A OLD clinical")
	_shot("t07_A_old_clinical.png")

	# ---- B. NEW clinical: the real Ticket-07 path, via the controller.
	# Must toggle through NORMAL: set_clinical_mode(true) early-returns when the mode is
	# already CLINICAL, which would leave A's hand-written constants in place.
	_atmo.set_clinical_mode(false)
	await _settle()
	_atmo.set_clinical_mode(true)
	await _settle()
	_dump("B NEW clinical")
	_shot("t07_B_new_clinical.png")

	# ---- C. SUBDUED: the real Ticket-07 post-reset path, via the controller
	_atmo.set_subdued_mode(true)
	await _settle()
	_dump("C SUBDUED")
	_shot("t07_C_subdued.png")

	print("PHOTOMETRY: done")
	get_tree().quit()


func _dump(tag: String) -> void:
	print(
		(
			"   [%s] tone=%d expo=%.2f ambE=%.2f keyE=%.2f shadow=%s bias=%.3f"
			% [
				tag,
				_env.tonemap_mode,
				_env.tonemap_exposure,
				_env.ambient_light_energy,
				_key.light_energy,
				str(_key.shadow_enabled),
				_key.shadow_bias
			]
		)
	)


func _settle() -> void:
	for _i in SETTLE:
		await get_tree().process_frame


func _shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("headless: no render target")
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_warning("null image")
		return
	img.save_png(OUT_DIR + path)
	_report(path, img)


## Photometry. The load-bearing number for "can I see the walls" is not mean luminance
## but the SPREAD between p05 and p95: a blown-out frame compresses everything toward 1.0
## and loses all local contrast, so geometry disappears even if mean looks merely "bright".
func _report(name: String, img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var lum := PackedFloat32Array()
	lum.resize(n)
	var total := 0.0
	var near_white := 0
	var pure := 0
	var dark := 0
	var i := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			lum[i] = l
			total += l
			if l > 0.90:
				near_white += 1
			if c.r >= 0.999 and c.g >= 0.999 and c.b >= 0.999:
				pure += 1
			if l < 0.03:
				dark += 1
			i += 1
	lum.sort()
	var p05 := lum[int(n * 0.05)]
	var p50 := lum[int(n * 0.5)]
	var p95 := lum[int(n * 0.95)]
	print(
		(
			"  >> %-24s mean=%.3f p05=%.3f p50=%.3f p95=%.3f spread=%.3f"
			% [name, total / float(n), p05, p50, p95, p95 - p05]
		)
	)
	print(
		(
			"     %-24s white>90%%=%.1f%% pure=%.2f%% crushed<3%%=%.1f%%"
			% ["", 100.0 * near_white / n, 100.0 * pure / n, 100.0 * dark / n]
		)
	)
