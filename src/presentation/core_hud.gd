class_name CoreHud
extends CanvasLayer
## PRESENTATION LAYER — CanvasLayer wrapper for the Core HUD (Ticket-07).
##
## Ensures the UI renders above the 3D world and post-processing effects (Layer 50).
## The actual UI elements live in HudUI, which this node instantiates as a child.
##
## This separation exists so the CanvasLayer properties (layer, follow viewport) can be
## tuned independently of the UI layout logic. The exports are forwarded to HudUI in
## _ready() so the bootstrap can wire references before the child exists.

@export var state_machine: PlayerStateMachine
@export var interaction_controller: InteractionController
@export var dreamscape_manager: DreamscapeManager
@export var endgame_loop_manager: EndgameLoopManager

var _ui: HudUI


func _ready() -> void:
	layer = 50
	_ui = HudUI.new()
	_ui.name = "HudUI"
	_ui.state_machine = state_machine
	_ui.interaction_controller = interaction_controller
	_ui.dreamscape_manager = dreamscape_manager
	_ui.endgame_loop_manager = endgame_loop_manager
	add_child(_ui)


## Show a narrative line on the HUD (statue reveal, betrayal, loop text).
func show_line(text: String) -> void:
	if _ui != null:
		_ui.show_line(text)


func set_meter_palette(palette: GameSettings.MeterPalette) -> void:
	if _ui != null:
		_ui.set_meter_palette(palette)


func set_day(day: int) -> void:
	if _ui != null:
		_ui.set_day(day)
