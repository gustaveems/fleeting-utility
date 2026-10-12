class_name DevHud
extends CanvasLayer
## PRESENTATION LAYER — read-only instrumentation for Ticket-01 acceptance.
##
## Not diegetic UI and not the final HUD. It exists so the two things this ticket is
## supposed to prove — that every step lands on a 1m cell and that the profile swap
## actually changes turn/step timing — are observable without a profiler attached. It
## only ever *reads* logic objects; if it starts setting anything, the separation is
## already broken.
##
## Remove or gate behind a debug flag once Ticket-02's Sensory Overload meter ships as
## in-world UI.

var _label: Label
var _mover: GridMover
var _turn: TurnController
var _perception: PerceptionDirector
var _boundary: SoftBoundaryModel
var _grid: WorkspaceGridData

## Ticket-02 additions — optional. If bind_state_machine() is never called these stay
## null and the readout simply omits the chemical/entropy lines, so the Ticket-01
## pipeline keeps working unmodified.
var _state_machine: PlayerStateMachine


func _ready() -> void:
	# Below the post-FX layer: the readout must stay crisp even deep in a crash, or it
	# cannot be used to judge the crash.
	layer = 10
	_label = Label.new()
	_label.name = "Ticket01Readout"
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85, 0.9))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func bind(
	mover: GridMover,
	turn: TurnController,
	perception: PerceptionDirector,
	boundary: SoftBoundaryModel,
	grid: WorkspaceGridData
) -> void:
	_mover = mover
	_turn = turn
	_perception = perception
	_boundary = boundary
	_grid = grid


## Ticket-02: hand the HUD the state machine so the chemical/entropy meters are
## observable while tuning. Read-only, same as everything else here.
func bind_state_machine(state_machine: PlayerStateMachine) -> void:
	_state_machine = state_machine


func _process(_delta: float) -> void:
	if _label == null or _mover == null:
		return
	_label.text = _format()


func _format() -> String:
	var cell := _mover.cell()
	var facing := _turn.facing()
	var turn_state := "committed"
	if _turn.turning():
		turn_state = "turning -> %s" % WorkspaceGridData.facing_name(_turn.requested_facing())
	var step_state := "settled"
	if _mover.stepping():
		step_state = "in flight"
	var lines: Array[String] = [
		"FLEETING UTILITY  //  Ticket-02",
		"state        %s" % _perception.state_name(),
		(
			"cell         (%d, %d)   footprint (%d x %d)   1 cell = %.2fm"
			% [cell.x, cell.y, _grid.width_cells, _grid.depth_cells, _grid.cell_size]
		),
		(
			"facing       %s (%s)  %s"
			% [
				WorkspaceGridData.facing_name(facing),
				WorkspaceGridData.facing_screen_hint(facing),
				turn_state
			]
		),
		"step         %s  alpha %.2f" % [step_state, _mover.step_alpha()],
		"crash        %.2f    edge %.2f" % [_perception.crash_intensity(), _boundary.proximity()],
	]

	# Ticket-02 meter lines — only when the state machine is bound (pipeline-dependent).
	if _state_machine != null and _state_machine.state_data != null:
		var data := _state_machine.state_data
		lines.append(
			(
				"chem         %.2f  focus:%s  overload %.1f"
				% [
					data.chemical_level,
					"ON" if data.is_high_focus() else "off",
					data.sensory_overload
				]
			)
		)
		if _state_machine.entropy_data != null:
			lines.append(
				(
					"entropy      %.1f   feed +%.2f/s"
					% [
						_state_machine.entropy_data.entropy,
						(
							_state_machine.entropy_data.entropy
							* _state_machine.entropy_data.overload_feed_ratio
						)
					]
				)
			)
	lines.append("")
	lines.append("WASD/arrows  step one cell   (iso: W = up-right)")
	lines.append("Tab          toggle HIGH-FOCUS / CRASH")
	lines.append("G            toggle cell grid")
	return "\n".join(lines)
