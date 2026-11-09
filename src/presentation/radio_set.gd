class_name RadioSet
extends Interactable
## PRESENTATION — the boombox on his table (docs/STORY.md 8b): one bulletin a day through the
## shared DialogueRunner. It's company, and DailyLife takes a little off his overload.

@export var daily: DailyLife
@export var runner: DialogueRunner


func _ready() -> void:
	prompt_text = DailyLifeScript.RADIO_PROMPT
	super()
	var zone := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.2, 1.1)
	zone.shape = box
	zone.position = Vector3(0, 0.6, 0)
	add_child(zone)


func can_interact() -> bool:
	return daily != null and daily.radio_available() and (runner == null or runner.is_idle())


func blocked_prompt() -> String:
	if daily == null or daily.radio_available():
		return ""  # someone's talking: it can wait
	return DailyLifeScript.RADIO_DEAD if daily.radio_broken() else DailyLifeScript.RADIO_DONE


func _on_interacted() -> void:
	var bulletin := daily.hear_radio()
	if runner != null:
		runner.enqueue(bulletin, false)
