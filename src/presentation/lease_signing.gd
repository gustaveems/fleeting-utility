class_name LeaseSigning
extends CanvasLayer
## PRESENTATION — the lease signing (Ticket-15 Phase E): the hand-off from the prologue
## film into the game. The lease lies over the bare room; he can't move until he signs.
## Hold E to sign. Every clause is a mechanic he is about to live under.
##
## Shown only when the prologue hands over (`pending`, set by Prologue.finish()), never
## on Continue and never when a test boots the game directly.

signal signed

const LOCK := &"lease_signing"
const HOLD_SECONDS := 1.2
const TITLE := "RESIDENTIAL LEASE · UNIT 7-14B · BLOCK 31"
const CLAUSES := [
	"1. The Unit is provided as is. Deterioration is the Tenant's responsibility.",
	"2. The Tenant shall remain productive. Output is reviewed at the Lessor's discretion.",
	"3. Works produced on the premises are property of the Lessor.",
	"4. Sanctioned focus products are available. Unsanctioned compounds void this agreement.",
	"5. Renewal is at the Lessor's discretion. Terms may change without notice.",
	"6. The Tenant shall remain on their side of the line.",
]

## Set by the prologue as it hands over to the game; cleared once shown.
static var pending: bool = false

@export var player: PlayerMovement
@export var interaction: InteractionController

var is_open: bool = false
var is_signed: bool = false

var _held: float = 0.0
## E still held from skipping the prologue must not sign: wait for a fresh press.
var _armed: bool = false
var _root: Control
var _bar: ProgressBar
var _hint: Label


func _ready() -> void:
	layer = 30
	_build()
	_root.visible = false
	if pending:
		pending = false
		open()


func open() -> void:
	is_open = true
	is_signed = false
	_held = 0.0
	_armed = false
	_root.visible = true
	_root.modulate.a = 1.0
	if player != null:
		player.lock_input(LOCK)
	if interaction != null:
		interaction.lock(LOCK)


func _process(delta: float) -> void:
	if not is_open or is_signed:
		return
	var down := Input.is_action_pressed(InputActionData.ACTION_INTERACT)
	if not down:
		_armed = true
	if down and _armed:
		_held += delta
	else:
		_held = maxf(_held - delta * 2.0, 0.0)
	_bar.value = _held / HOLD_SECONDS
	if _held >= HOLD_SECONDS:
		_sign()


func _sign() -> void:
	is_signed = true
	_hint.text = "Signed."
	if player != null:
		player.unlock_input(LOCK)
	if interaction != null:
		interaction.unlock(LOCK)
	signed.emit()
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_property(_root, "modulate:a", 0.0, 1.2)
	t.tween_callback(_close)


func _close() -> void:
	_root.visible = false
	is_open = false


func _build() -> void:
	var theme := UiTheme.get_theme()
	_root = Control.new()
	_root.name = "Lease"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	# The document: off-white paper, small print.
	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.84, 0.78)
	style.set_content_margin_all(28)
	paper.add_theme_stylebox_override("panel", style)
	paper.anchor_left = 0.27
	paper.anchor_right = 0.73
	paper.anchor_top = 0.1
	paper.anchor_bottom = 0.9
	_root.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	paper.add_child(col)
	var ink := Color(0.12, 0.11, 0.1)
	col.add_child(_label(TITLE, 20, ink, theme))
	col.add_child(_label(PrologueScript.LEASE_TEXT.replace("\n", " · "), 13, ink, theme))
	for clause in CLAUSES:
		col.add_child(_label(clause, 15, ink, theme))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_label("Tenant signature: ______________________", 15, ink, theme))
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	col.add_child(_bar)
	_hint = _label("Hold E to sign", 16, Color(0.45, 0.1, 0.08), theme)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)


func _label(text: String, size: int, color: Color, theme: Theme) -> Label:
	var l := Label.new()
	l.theme = theme
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
