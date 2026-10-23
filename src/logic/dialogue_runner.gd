class_name DialogueRunner
extends Node
## LOGIC — plays a list of dialogue steps (format in NightZeroScript): lines and thoughts
## through HeadCall, choices through ChoicePanel. Records every choice by key and counts
## how the night leans (honest vs fit), for the verdict steps and anything later.
##
##   await runner.run(NightZeroScript.DINNER)

signal finished
signal choice_made(key: String, tag: String)

@export var head_call: HeadCall
@export var choices_ui: ChoicePanel
## Locked while a choice is open, so E picks the option and doesn't also press the bench.
@export var interaction: InteractionController

## key → tag of every choice made ("work" → "honest", "gift" → "refused"...).
var choices: Dictionary = {}
var honest: int = 0
var fit: int = 0
var is_running: bool = false
var awaiting_choice: bool = false

var _cancelled: bool = false
var _as_call: bool = false


## `as_call`: lines come as a head call (the caller card), not in-person subtitles.
func run(steps: Array, as_call: bool = false) -> void:
	_as_call = as_call
	_cancelled = false
	is_running = true
	await _steps(steps)
	is_running = false
	finished.emit()


## Stop mid-script (a film segment ending under its lines). run() then finishes.
func cancel() -> void:
	_cancelled = true
	if head_call != null:
		head_call.stop()


## A plain menu (the door: where to go). Returns the picked index; records nothing.
func ask(labels: Array[String]) -> int:
	awaiting_choice = true
	if interaction != null:
		interaction.lock(&"dialogue_choice")
	choices_ui.open(labels)
	var index: int = await choices_ui.chosen
	if interaction != null:
		interaction.unlock(&"dialogue_choice")
	awaiting_choice = false
	return index


func _steps(steps: Array) -> void:
	for step: Dictionary in steps:
		if _cancelled:
			return
		if step.has("say"):
			await _line(step["say"])
		elif step.has("think"):
			var t: Array = step["think"]
			await _line([NightZeroScript.THOUGHT, t[0], t[1]])
		elif step.has("choose"):
			await _choose(step["choose"])
		elif step.has("verdict"):
			var v: Dictionary = step["verdict"]
			await _steps(v["honest"] if honest > fit else v["fit"])


func _line(line: Array) -> void:
	if head_call == null:
		return
	head_call.play([line], _as_call and line[0] != NightZeroScript.THOUGHT)
	await head_call.finished


func _choose(spec: Dictionary) -> void:
	var options: Array = spec["options"]
	var labels: Array[String] = []
	for o: Dictionary in options:
		labels.append(str(o["text"]))
	awaiting_choice = true
	if interaction != null:
		interaction.lock(&"dialogue_choice")
	choices_ui.open(labels)
	var index: int = await choices_ui.chosen
	if interaction != null:
		interaction.unlock(&"dialogue_choice")
	awaiting_choice = false
	var picked: Dictionary = options[index]
	var tag := str(picked["tag"])
	choices[str(spec["key"])] = tag
	if tag == "honest":
		honest += 1
	elif tag == "fit":
		fit += 1
	choice_made.emit(str(spec["key"]), tag)
	await _steps(picked.get("reply", []))
