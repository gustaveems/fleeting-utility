class_name CampaignBoard
extends Node3D
## PRESENTATION — the Heritage campaign's billboard (Ticket-21): his lent canvas,
## polished by the brand (the same seed and composition, brighter and coherent, the
## smear and greyness gone), under the brand's name. Built facing +Z, hidden until
## show_work(). `board_scale` sizes it for the place (a skyline, a park path).

## The brand's fix: at least this vivid and coherent, never smeared or flat.
const POLISH_VIVIDNESS := 0.92
const POLISH_COHERENCE := 0.9
const GOLD := Color(0.95, 0.78, 0.35)

var board_scale: float = 1.0
## Freestanding: two posts this tall (metres) down to the ground; 0 = none (mounted).
var post_height: float = 0.0
## What the board shows (tests read it): the polished parameters.
var shown: Dictionary = {}

var _work: PaintedWork


func _ready() -> void:
	scale = Vector3.ONE * board_scale
	var back := MeshInstance3D.new()
	back.name = "Backing"
	var b := BoxMesh.new()
	b.size = Vector3(PaintedWork.SIZE.x + 0.2, PaintedWork.SIZE.y + 0.42, 0.04)
	back.mesh = b
	back.position = Vector3(0, -0.1, -0.03)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06)
	m.emission_enabled = true
	m.emission = Color(0.08, 0.07, 0.05)
	back.material_override = m
	add_child(back)
	_work = PaintedWork.new()
	_work.name = "Campaign"
	add_child(_work)
	var brand := Label3D.new()
	brand.name = "Brand"
	brand.text = CampaignScript.BRAND
	brand.font_size = 48
	brand.pixel_size = 0.0018
	brand.modulate = GOLD
	brand.outline_size = 0
	brand.position = Vector3(0, -PaintedWork.SIZE.y * 0.5 - 0.09, 0.0)
	add_child(brand)
	var tag := Label3D.new()
	tag.name = "Tagline"
	tag.text = CampaignScript.TAGLINE
	tag.font_size = 32
	tag.pixel_size = 0.0012
	tag.modulate = GOLD.darkened(0.3)
	tag.outline_size = 0
	tag.position = Vector3(0, -PaintedWork.SIZE.y * 0.5 - 0.2, 0.0)
	add_child(tag)
	if post_height > 0.0:
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.12, 0.12, 0.13)
		steel.metallic = 0.7
		var length := post_height / board_scale
		for x in [-0.3, 0.3]:
			var post := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(0.03, length, 0.03)
			post.mesh = pb
			post.material_override = steel
			post.position = Vector3(x, -length * 0.5, -0.06)
			add_child(post)
	visible = false


## His canvas, as the brand would sell it.
static func polish(work: Dictionary) -> Dictionary:
	return {
		"seed": float(work.get("seed", 7.0)),
		"vividness": maxf(float(work.get("vividness", 0.5)), POLISH_VIVIDNESS),
		"smear": 0.0,
		"flatness": 0.0,
		"coherence": maxf(float(work.get("coherence", 0.2)), POLISH_COHERENCE),
	}


func show_work(work: Dictionary) -> void:
	shown = polish(work)
	_work.from_dict(shown)
	visible = true


func hide_work() -> void:
	visible = false
