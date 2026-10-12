extends SceneTree
## Ticket-07 functional verifier. Loads the REAL main scene and drives the real
## signals — no stubs, no re-implementations.
##
## Headless -s truth (learned Ticket-05): this script IS the tree (no get_tree()), and
## _process is unthrottled, so all waits use create_timer()/awaited signals, never frames.
##
## Node paths verified against the live runtime tree (tools/_tree_probe.gd):
## BenchArea is a child of Apartment, NOT a direct child of Workspace.

var _ws: Node
var _sm: PlayerStateMachine
var _sd: PlayerStateData
var _ed: WorkspaceEntropyData
var _dm: DreamscapeManager
var _ic: InteractionController
var _atmo: AtmosphereController
var _player: PlayerMovement
var _bench: CraftingBench
var _grid: SpatialGrid
var _core: CanvasLayer
var _ui: HudUI
var _endgame: Node

var _pass := 0
var _fail := 0

## Meters captured AT THE INSTANT loop_reset fires, so later decay cannot skew them.
var _chem_at_reset := -1.0
var _ovl_at_reset := -1.0
var _loop_seen := false

## Wall-clock ms between force_return_to_workspace() and the loop_reset emission.
var _reset_ms := -1
var _t0_ms := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/workspace.tscn")
	_ws = scene.instantiate()
	root.add_child(_ws)
	await create_timer(0.5).timeout

	_collect()
	await _test_hud_boot()
	await _test_meter_updates()
	await _test_interaction_prompt()
	await _test_dreamscape_hide()
	await _test_climax_and_scarred_reset()

	print("\n========================================")
	print(" TICKET-07 VERIFY  %d PASS / %d FAIL" % [_pass, _fail])
	print("========================================")
	quit(1 if _fail > 0 else 0)


func _collect() -> void:
	_sm = _ws.get_node_or_null("PlayerStateMachine")
	_dm = _ws.get_node_or_null("DreamscapeManager")
	_ic = _ws.get_node_or_null("InteractionController")
	_player = _ws.get_node_or_null("Player")
	_bench = _ws.get_node_or_null("Apartment/BenchArea/CraftingBench")
	_grid = _ws.get_node_or_null("Apartment/BenchArea/SpatialGrid")
	_atmo = _ws.get_node_or_null("Apartment/AtmosphereController")
	_ed = _sm.entropy_data if _sm != null else null
	_sd = _sm.state_data if _sm != null else null
	_core = _ws.get_node_or_null("CoreHud")
	_endgame = _ws.get_node_or_null("EndgameLoopManager")
	if _core != null:
		_ui = _core.get_node_or_null("HudUI")


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


# ---------------------------------------------------------------- 1. HUD boot
func _test_hud_boot():
	print("\n--- 1. Core HUD exists in the tree ---")
	_check("CoreHud node present", _core != null)
	_check("CoreHud is CanvasLayer", _core is CanvasLayer)
	_check("CoreHud.layer == 50", _core != null and _core.layer == 50)
	_check("HudUI child present", _ui != null)
	var mc: Control = _ui.get_node_or_null("MeterCluster")
	_check("MeterCluster present", mc != null)
	_check("MeterCluster visible at boot", mc != null and mc.visible)
	_check("EndgameLoopManager node present", _endgame != null)
	_check("CraftingBench found at Apartment/BenchArea", _bench != null)
	_check("SpatialGrid found at Apartment/BenchArea", _grid != null)

	# The critical question: did CoreHud receive non-null refs at _ready() time?
	_check("HudUI.interaction_controller wired (NOT null)", _ui.interaction_controller != null)
	_check("HudUI.endgame_loop_manager wired (NOT null)", _ui.endgame_loop_manager != null)


# ---------------------------------------------------------------- 2. meters live
func _test_meter_updates():
	print("\n--- 2. Meters update in real time from PlayerStateData ---")
	var cl: Label = _ui.get_node_or_null("MeterCluster/ChemicalLabel")
	var ol: Label = _ui.get_node_or_null("MeterCluster/OverloadLabel")
	var cb: ProgressBar = _ui.get_node_or_null("MeterCluster/ChemicalMeter")
	var ob: ProgressBar = _ui.get_node_or_null("MeterCluster/OverloadMeter")
	_check("ChemicalLabel found", cl != null)
	_check("OverloadLabel found", ol != null)
	_check("ChemicalMeter is ProgressBar", cb != null)
	_check("OverloadMeter is ProgressBar", ob != null)
	if cl == null or cb == null or ol == null or ob == null:
		return

	_sd.chemical_level = 0.85
	_sd.sensory_overload = 40.0
	_sd.state_changed.emit(_sd)
	await create_timer(0.1).timeout
	_check("chem label reads 85%% (got %s)" % cl.text, cl.text == "FOCUS: 85%")
	_check("chem bar value == 0.85", is_equal_approx(cb.value, 0.85))
	_check("overload label reads 40%% (got %s)" % ol.text, ol.text == "OVERLOAD: 40%")

	var hi: Color = (cb.get_theme_stylebox("fill") as StyleBoxFlat).bg_color
	_sd.chemical_level = 0.05
	_sd.state_changed.emit(_sd)
	await create_timer(0.1).timeout
	var lo: Color = (cb.get_theme_stylebox("fill") as StyleBoxFlat).bg_color
	_check("chem bar green-dominant when high (g=%.2f r=%.2f)" % [hi.g, hi.r], hi.g > hi.r)
	_check("chem bar red-dominant when low (r=%.2f g=%.2f)" % [lo.r, lo.g], lo.r > lo.g)

	_sd.sensory_overload = 95.0
	_sd.state_changed.emit(_sd)
	await create_timer(0.1).timeout
	var hot: Color = (ob.get_theme_stylebox("fill") as StyleBoxFlat).bg_color
	_check("overload bar red-dominant at 95 (r=%.2f b=%.2f)" % [hot.r, hot.b], hot.r > hot.b)

	# Natural depletion must move the label with no manual emit at all.
	_sd.chemical_level = 0.50
	_sd.state_changed.emit(_sd)
	var before_text := cl.text
	await create_timer(1.2).timeout
	_check(
		"passive depletion moves label (%s -> %s)" % [before_text, cl.text], cl.text != before_text
	)


# ---------------------------------------------------------------- 3. prompt
func _test_interaction_prompt():
	print("\n--- 3. Interaction prompt appears / disappears ---")
	if _ic == null:
		_check("InteractionController exists", false)
		return
	var pc: CenterContainer = _ui.get_node_or_null("PromptContainer")
	_check("PromptContainer present", pc != null)
	_check("prompt hidden at boot", pc != null and not pc.visible)

	_ic.set_target("[E] Return")
	await create_timer(0.1).timeout
	_check("prompt VISIBLE after set_target", pc != null and pc.visible)
	var pl: Label = _ui.get_node_or_null("PromptContainer/InteractionPrompt")
	var pl_text := pl.text if pl != null else "?"
	_check("prompt text is '[E] Return' (got %s)" % pl_text, pl != null and pl.text == "[E] Return")

	_ic.clear_target()
	await create_timer(0.1).timeout
	_check("prompt HIDDEN after clear_target", pc != null and not pc.visible)

	# The real producer path: DreamscapeManager drives set_target on statue proximity.
	_dm.set_statue_proximity(true)
	await create_timer(0.1).timeout
	_check("statue proximity -> prompt via DreamscapeManager", pc != null and pc.visible)
	_dm.set_statue_proximity(false)
	await create_timer(0.1).timeout


# ---------------------------------------------------------------- 4. dreamscape
func _test_dreamscape_hide():
	print("\n--- 4. HUD hides in the dreamscape ---")
	var mc: Control = _ui.get_node_or_null("MeterCluster")
	var fl: Label = _ui.get_node_or_null("FadingMemoryLabel")
	_check("FadingMemoryLabel present", fl != null)
	_check("FadingMemoryLabel hidden in apartment", fl != null and not fl.visible)

	var in_dream := [false]
	_dm.transition_completed.connect(
		func(now_in_dream: bool):
			if now_in_dream:
				in_dream[0] = true
	)
	_sd.chemical_level = 0.0
	_sd.sensory_overload = 100.0
	_sd.state_changed.emit(_sd)
	await create_timer(6.0).timeout

	_check("collapse triggered the dreamscape", in_dream[0])
	_check("meters HIDDEN in dream", mc != null and not mc.visible)
	_check("'Fading Memory' SHOWN in dream", fl != null and fl.visible)


# ---------------------------------------------------------------- 5. scarred reset
func _test_climax_and_scarred_reset():
	print("\n--- 5. Climax -> 5s pause -> Scarred Reset ---")
	if not _dm.in_dreamscape():
		_check("in dreamscape before forced return", false)
		return
	_check("in dreamscape before forced return", true)

	# Snapshot the meters the instant the reset lands, so later decay cannot skew them.
	_endgame.loop_reset.connect(_on_loop_reset_snapshot)

	var before_rate := _ed.entropy_growth_rate
	var bench_pos := _bench.global_position if _bench != null else Vector3.ZERO
	_t0_ms = Time.get_ticks_msec()

	_dm.force_return_to_workspace()
	await create_timer(8.0).timeout

	# Measured at the emission itself, not after the full wait.
	var elapsed := _reset_ms / 1000.0 if _reset_ms > 0 else -1.0

	_check(
		"chemical reset to 0.50 at loop_reset (got %.2f)" % _chem_at_reset,
		is_equal_approx(_chem_at_reset, 0.5)
	)
	_check(
		"overload reset to 20.0 at loop_reset (got %.1f)" % _ovl_at_reset,
		is_equal_approx(_ovl_at_reset, 20.0)
	)
	_check("withdrawal cleared", not _player.is_in_withdrawal)
	_check("movement input unlocked", not _player.input_locked)
	_check("interactions remain LOCKED", _ic.is_locked)
	_check("CraftingBench hidden", _bench != null and not _bench.visible)
	_check("SpatialGrid hidden", _grid != null and not _grid.visible)
	_check(
		"entropy rate +50%% (%.3f -> %.3f)" % [before_rate, _ed.entropy_growth_rate],
		is_equal_approx(_ed.entropy_growth_rate, before_rate * 1.5)
	)
	_check("loop_reset signal emitted", _loop_seen)
	_check(
		"loop_reset landed in 5.0-8.0s window (%.1fs)" % elapsed,
		_loop_seen and elapsed >= 5.0 and elapsed <= 8.0
	)
	_check("atmosphere is SUBDUED", _atmo.is_subdued_mode())
	_check("atmosphere NOT clinical anymore", not _atmo.is_clinical_mode())

	var env := _atmo.world_environment.environment
	_check(
		"subdued ambient energy == 0.1 (got %.2f)" % env.ambient_light_energy,
		is_equal_approx(env.ambient_light_energy, 0.1)
	)
	_check(
		"subdued key energy == 0.5 (got %.2f)" % _atmo.key_light.light_energy,
		is_equal_approx(_atmo.key_light.light_energy, 0.5)
	)
	var ac := env.ambient_light_color
	_check(
		"subdued ambient grey-green (r=%.2f g=%.2f b=%.2f)" % [ac.r, ac.g, ac.b],
		ac.g > ac.b and ac.g >= ac.r
	)

	# visibility vs collision: is the hidden bench still solid?
	if _bench == null:
		_check("bench collision probe skipped (bench null)", false)
	else:
		var space := _player.get_world_3d().direct_space_state
		var sha := SphereShape3D.new()
		sha.radius = 0.15
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sha
		q.transform = Transform3D(Basis(), bench_pos + Vector3(0.0, 0.5, 0.0))
		q.collide_with_areas = false
		var hits := space.intersect_shape(q, 8)
		var hit_bench := false
		var names: Array[String] = []
		for h in hits:
			var col: Object = h.get("collider")
			if col == null:
				continue
			names.append("%s(%s)" % [col.get_name(), col.get_class()])
			if col == _bench or col.get_parent() == _bench:
				hit_bench = true
		print(
			"      colliders at bench origin: ", ", ".join(names) if names.size() > 0 else "<none>"
		)
		_check("hidden bench has NO collision (walk-through works)", not hit_bench)

	var flavor: Node = _ui.get_node_or_null("FlavorLayer")
	_check("FlavorLayer created by loop_reset", flavor != null)


func _on_loop_reset_snapshot(_t: String) -> void:
	_loop_seen = true
	_reset_ms = Time.get_ticks_msec() - _t0_ms
	_chem_at_reset = _sd.chemical_level
	_ovl_at_reset = _sd.sensory_overload
