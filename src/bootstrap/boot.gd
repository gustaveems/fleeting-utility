class_name Boot
extends Control
## BOOT — the main scene (scenes/boot.tscn): a short splash, then the main menu.
##
## SPLASH
## ------
## The splash draws first, then the ~0.5 s of placeholder sound synthesis
## (ProceduralAudio.default_bank, cached for the run) happens behind it. The game scene
## then starts without that hitch. The player's settings are applied here too, so the
## menu already plays at their volumes.
##
## MENU
## ----
##   Continue   only when a save exists (Persistence auto-loads it as the game boots)
##   New Game   asks before erasing an existing save
##   Settings   the shared SettingsPanel
##   Quit
## Fully keyboard/gamepad navigable; focus lands on the first live button.

signal menu_ready

const GAME_SCENE := preload("res://scenes/workspace.tscn")
const PROLOGUE_SCENE_PATH := "res://scenes/prologue.tscn"
const TAGLINE := "The utility is fleeting. The lease renews."

var _menu: VBoxContainer
var _confirm: VBoxContainer
var _settings: SettingsPanel
var _continue: Button
var _new_game: Button
var _title: Label
var _tagline: Label
var _ambience: AudioStreamPlayer
var _flicker_time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_build_background()
	var splash := UiTheme.title("…", 28)
	splash.name = "Splash"
	splash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	splash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	splash.modulate = UiTheme.DIM
	add_child(splash)
	# Let the splash reach the screen before the synthesis stalls the main thread.
	await get_tree().process_frame
	await get_tree().process_frame
	AudioBuses.register()
	var bank := ProceduralAudio.default_bank()
	# Phase D: the real bank and the game's voices, rendered once behind the splash.
	RealSounds.bank()
	VoiceSynth.warm(VoiceSynth.GAME_VOICES)
	GameSettings.current().apply_engine()
	_start_ambience(bank)
	splash.queue_free()
	_build_menu()
	menu_ready.emit()


func _process(delta: float) -> void:
	# The title hums like a tube on its way out: steady, with rare dropouts.
	if _title == null:
		return
	_flicker_time -= delta
	if _flicker_time <= 0.0:
		_title.modulate.a = 1.0
		if randf() < 1.1 * delta:  # ~one dropout a second
			_title.modulate.a = 0.35
			_flicker_time = randf_range(0.04, 0.12)


## ----- ACTIONS -------------------------------------------------------------------------


func continue_game() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)


func new_game() -> void:
	if Persistence.save_exists():
		_show(_confirm)
		return
	_start_fresh()


## A new game starts with the prologue film (Ticket-15), which ends in the game.
func _start_fresh() -> void:
	Persistence.delete_save()
	get_tree().change_scene_to_file(PROLOGUE_SCENE_PATH)


## ----- BUILD ---------------------------------------------------------------------------


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.03)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
// Sickly near-black with a slow, uneven bloom and fine grain: the apartment at 4 a.m.
void fragment() {
	vec2 uv = UV - vec2(0.5, 0.55);
	float glow = 0.06 * exp(-dot(uv, uv) * 4.0) * (0.9 + 0.1 * sin(TIME * 0.7));
	float grain = fract(sin(dot(UV * 731.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = vec3(0.03, 0.032, 0.028) + vec3(0.36, 0.38, 0.22) * glow;
	COLOR = vec4(col + (grain - 0.5) * 0.025, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat
	add_child(bg)


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	_title = UiTheme.title("FLEETING UTILITY", 60)
	_title.name = "Title"
	column.add_child(_title)
	_tagline = UiTheme.title(TAGLINE, 18)
	_tagline.modulate = UiTheme.DIM
	column.add_child(_tagline)
	column.add_child(Control.new())

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 10)
	column.add_child(_menu)
	_continue = UiTheme.button("Continue", "Button_Continue")
	_continue.pressed.connect(continue_game)
	_continue.visible = Persistence.save_exists()
	_menu.add_child(_continue)
	_new_game = UiTheme.button("New Game", "Button_NewGame")
	_new_game.pressed.connect(new_game)
	_menu.add_child(_new_game)
	var settings := UiTheme.button("Settings", "Button_Settings")
	settings.pressed.connect(func(): _show(_settings))
	_menu.add_child(settings)
	var quit := UiTheme.button("Quit", "Button_Quit")
	quit.pressed.connect(func(): get_tree().quit())
	_menu.add_child(quit)

	_confirm = VBoxContainer.new()
	_confirm.name = "ConfirmNewGame"
	_confirm.add_theme_constant_override("separation", 10)
	column.add_child(_confirm)
	_confirm.add_child(UiTheme.title("Erase your progress and start over?", 20))
	var yes := UiTheme.button("Erase and start over", "Button_ConfirmErase")
	yes.pressed.connect(_start_fresh)
	_confirm.add_child(yes)
	var no := UiTheme.button("Keep my progress", "Button_CancelErase")
	no.pressed.connect(func(): _show(_menu))
	_confirm.add_child(no)

	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	_settings.closed.connect(func(): _show(_menu))
	column.add_child(_settings)
	_show(_menu)


## Show exactly one of the menu / confirm / settings panels and focus it. The title
## steps aside for the settings panel, which needs the height at 720p.
func _show(panel: Control) -> void:
	for p in [_menu, _confirm, _settings]:
		p.visible = p == panel
	_title.visible = panel != _settings
	_tagline.visible = panel != _settings
	if panel == _menu:
		(_continue if _continue.visible else _new_game).grab_focus()
	elif panel == _settings:
		_settings.focus_first()
	else:
		(_confirm.get_child(2) as Control).grab_focus()  # "Keep my progress": the safe default


func _start_ambience(bank: SoundBank) -> void:
	var cue := bank.cue(SoundBank.ROOM_TONE)
	if cue == null:
		return
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "MenuAmbience"
	_ambience.stream = cue.stream
	_ambience.bus = AudioBuses.AMBIENCE
	_ambience.volume_db = cue.volume_db - 4.0
	add_child(_ambience)
	_ambience.play()
