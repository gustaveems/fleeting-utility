class_name EndCard
extends CanvasLayer
## PRESENTATION — the card after each scarred reset: the cycle ends, and the player
## chooses to renew the lease or walk away (LeaseRenewal does either).
##
## Shown whenever the arc reaches SCARRED, live or by continuing a save that is already
## there. Before this existed, the reset left the player in a dark room with nothing
## left to do (playtest 2026-10-14). The world is paused behind the card.

const TITLE := "The lease renews."
const EPILOGUE := "He let the lease lapse. Someone else moved in by Monday."

@export var game_flow: GameFlow
@export var lease_renewal: LeaseRenewal
@export var entropy_data: WorkspaceEntropyData

## Seconds after the reset before the card: lets the flavor line land first.
@export var show_delay: float = 4.0
@export var epilogue_seconds: float = 4.0

var is_open: bool = false

var _dim: ColorRect
var _center: CenterContainer
var _column: VBoxContainer
var _subtitle: Label
var _buttons: VBoxContainer
var _epilogue: Label
var _renew: Button


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_visible(false)
	if game_flow != null:
		game_flow.phase_changed.connect(_on_phase_changed)


func _exit_tree() -> void:
	if is_open and is_inside_tree():
		get_tree().paused = false


func open() -> void:
	is_open = true
	var cycle := game_flow.loops_completed if game_flow != null else 1
	_subtitle.text = "Cycle %d complete. The room remembers." % cycle
	_buttons.visible = true
	_epilogue.visible = false
	_set_visible(true)
	get_tree().paused = true
	_renew.grab_focus()


func renew() -> void:
	_close()
	if lease_renewal != null:
		lease_renewal.renew()


func walk_away() -> void:
	_buttons.visible = false
	_epilogue.visible = true
	await get_tree().create_timer(epilogue_seconds).timeout
	_close()
	if lease_renewal != null:
		lease_renewal.walk_away()


## The entropy growth rate the next cycle would start with (the scar carries).
func renew_preview_rate() -> float:
	return entropy_data.entropy_growth_rate if entropy_data != null else 0.0


func _close() -> void:
	is_open = false
	_set_visible(false)
	if is_inside_tree():
		get_tree().paused = false


func _on_phase_changed(_from: GameFlow.Phase, to: GameFlow.Phase) -> void:
	if to != GameFlow.Phase.SCARRED or is_open:
		return
	await get_tree().create_timer(show_delay).timeout
	if game_flow.phase == GameFlow.Phase.SCARRED and not is_open:
		open()


func _set_visible(shown: bool) -> void:
	_dim.visible = shown
	_center.visible = shown


func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.88)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.theme = UiTheme.get_theme()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 16)
	_center.add_child(_column)
	_column.add_child(UiTheme.title(TITLE, 48))
	_subtitle = UiTheme.title("", 20)
	_subtitle.modulate = UiTheme.DIM
	_column.add_child(_subtitle)
	_column.add_child(Control.new())

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_column.add_child(_buttons)
	_renew = UiTheme.button("Renew the lease", "Button_Renew")
	_renew.pressed.connect(renew)
	_buttons.add_child(_renew)
	var leave := UiTheme.button("Walk away (ends the story)", "Button_WalkAway")
	leave.pressed.connect(walk_away)
	_buttons.add_child(leave)

	_epilogue = UiTheme.title(EPILOGUE, 22)
	_epilogue.name = "Epilogue"
	_column.add_child(_epilogue)
