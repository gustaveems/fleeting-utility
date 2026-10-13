class_name PauseMenu
extends CanvasLayer
## PRESENTATION — Esc pauses the game (Ticket-13): Resume · Settings · Quit to Menu ·
## Quit Game. Runs while the tree is paused (PROCESS_MODE_ALWAYS).
##
## Pausing freezes the world, its tweens, audio players and pause-aware timers. Quitting
## (to the menu or the desktop) saves first if the game is at a checkpoint (see
## Persistence); mid-sequence quits resume at the last checkpoint.

signal pause_changed(paused: bool)

## Loaded by path at quit time: a preload would make the boot scene and the game scene
## preload each other.
const MENU_SCENE_PATH := "res://scenes/boot.tscn"

@export var persistence: Persistence

var is_open: bool = false

var _dim: ColorRect
var _menu: VBoxContainer
var _settings: SettingsPanel
var _center: CenterContainer


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if _settings.visible:
			_show_settings(false)
		else:
			toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_set_open(not is_open)


func open() -> void:
	_set_open(true)


func close() -> void:
	_set_open(false)


func quit_to_menu() -> void:
	if persistence != null:
		persistence.save_if_at_checkpoint()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func quit_game() -> void:
	if persistence != null:
		persistence.save_if_at_checkpoint()
	get_tree().quit()


func _set_open(open_menu: bool) -> void:
	is_open = open_menu
	_dim.visible = open_menu
	_center.visible = open_menu
	_show_settings(false)
	if is_inside_tree():
		get_tree().paused = open_menu
	if open_menu:
		(_menu.get_child(1) as Control).grab_focus()
	pause_changed.emit(open_menu)


func _show_settings(show_it: bool) -> void:
	_settings.visible = show_it
	_menu.visible = not show_it and is_open
	if show_it:
		_settings.focus_first()
	elif is_open:
		(_menu.get_child(1) as Control).grab_focus()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.theme = UiTheme.get_theme()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 12)
	_center.add_child(_menu)
	_menu.add_child(UiTheme.title("PAUSED", 34))
	var resume := UiTheme.button("Resume", "Button_Resume")
	resume.pressed.connect(close)
	_menu.add_child(resume)
	var settings := UiTheme.button("Settings", "Button_Settings")
	settings.pressed.connect(_show_settings.bind(true))
	_menu.add_child(settings)
	var to_menu := UiTheme.button("Quit to Menu", "Button_QuitToMenu")
	to_menu.pressed.connect(quit_to_menu)
	_menu.add_child(to_menu)
	var to_desktop := UiTheme.button("Quit Game", "Button_QuitGame")
	to_desktop.pressed.connect(quit_game)
	_menu.add_child(to_desktop)

	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	_settings.closed.connect(_show_settings.bind(false))
	_center.add_child(_settings)
