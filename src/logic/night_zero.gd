class_name NightZero
extends Node3D
## LOGIC — Night Zero, the first evening (docs/STORY.md N1–N9; Ticket-16). Phase 1:
## after he signs the lease (only when arriving from the prologue), the friend is in the
## room, the boxes are by the door, and he carries them to the west wall while the
## friend talks (the controls tutorial). Then the invitation. Phase 2 (the car, the
## dinner, the gift, the walk home) will continue from `finished`; for now Day 1 begins.
##
## Lives under the apartment WorldRoot, so everything it spawns pauses with the room.

signal started
signal box_placed(count: int)
signal finished

const LOCK := &"night_zero"
const BOX_COUNT := 3
## A new game's room is freshly leased: cleaner than the demo seed a direct boot uses
## (38), so the betrayal threshold (70) lands around day 6 with the days' pacing.
const NEW_GAME_ENTROPY := 20.0
## Where the boxes wait (by the door) and where they go (the west wall), room-local.
## (Out of the door's sensor, which reaches 1.4 m into the room.)
const BOX_SPOTS: Array[Vector3] = [
	Vector3(-1.2, 0, -1.7), Vector3(1.1, 0, -1.8), Vector3(1.6, 0, -1.1)
]
const FRIEND_AT := Vector3(0.6, 0, -0.6)
const DROP_ZONE := Rect2(Vector2(-4.2, -1.3), Vector2(1.5, 2.1))
## The room is a diorama: people at the player's avatar scale.
const PERSON_SCALE := 0.47

@export var player: PlayerMovement
@export var interaction: InteractionController
@export var head_call: HeadCall
@export var hud: CoreHud
@export var entropy_data: WorkspaceEntropyData
## The evening (Phase 2) the chapter continues into; empty ends Night Zero here (tests).
@export var evening_scene_path: String = ""

var is_running: bool = false
var placed: int = 0
var friend: StreetFigure
var boxes: Array[MovingBox] = []

var _carrying: MovingBox
var _picked_frame: int = -1


## Begin the chapter (LeaseSigning.signed, arriving from the prologue).
func start() -> void:
	if is_running:
		return
	is_running = true
	placed = 0
	if entropy_data != null:
		entropy_data.entropy = NEW_GAME_ENTROPY
		entropy_data.entropy_changed.emit(entropy_data.entropy)
	friend = StreetFigure.new()
	friend.name = "Friend"
	friend.dress = StreetFigure.Dress.FRIEND
	friend.pose = StreetFigure.Pose.HUDDLE  # talking
	friend.position = FRIEND_AT
	friend.rotation_degrees.y = 200.0
	friend.scale = Vector3.ONE * PERSON_SCALE
	add_child(friend)
	for at in BOX_SPOTS:
		var box := MovingBox.new()
		box.player = player
		box.interaction_controller = interaction
		box.position = at
		box.picked_up.connect(_on_picked_up)
		add_child(box)
		boxes.append(box)
	_mark_drop_zone()
	if head_call != null:
		head_call.play(NightZeroScript.MOVE_IN_START, false)
	if hud != null:
		hud.show_line(NightZeroScript.MOVE_IN_OBJECTIVE)
	started.emit()


## Home from the evening: the boxes are where he stacked them, Day 1 begins, and the
## friend's gift is in his bag (whether he took it or not).
func restore_moved_in(gift_refused: bool) -> void:
	if entropy_data != null:
		entropy_data.entropy = NEW_GAME_ENTROPY
		entropy_data.entropy_changed.emit(entropy_data.entropy)
	for at in BOX_SPOTS.size():
		var box := MovingBox.new()
		box.position = Vector3(DROP_ZONE.position.x + 0.4 + at * 0.45, 0, DROP_ZONE.get_center().y)
		box.placed = true
		add_child(box)
	if hud != null:
		hud.show_line(NightZeroScript.HOME_LINE)
		if gift_refused:
			await get_tree().create_timer(3.0, false).timeout
			hud.show_line(NightZeroScript.BAG_LINE)


## Put down whatever he's carrying, where he stands (tests drive this directly).
func drop_carried() -> void:
	if _carrying == null:
		return
	var box := _carrying
	_carrying = null
	_set_carry_pose(false)
	var at := to_local(player.global_position) + _facing() * 0.45
	at.y = 0.0
	box.position = at
	box.carried = false
	for b in boxes:
		b.hands_free = true
	if DROP_ZONE.has_point(Vector2(at.x, at.z)):
		box.placed = true
		box.refresh_prompt()
		placed += 1
		box_placed.emit(placed)
		if placed >= BOX_COUNT:
			_invitation()
		elif head_call != null:
			head_call.play(NightZeroScript.MOVE_IN_PER_BOX[placed - 1], false)


func _process(_delta: float) -> void:
	if _carrying == null:
		return
	# The box rides in his arms.
	_carrying.position = to_local(player.global_position) + _facing() * 0.22 + Vector3(0, 0.38, 0)
	var put_down := Input.is_action_just_pressed(InputActionData.ACTION_INTERACT)
	if put_down and Engine.get_process_frames() != _picked_frame:
		if interaction == null or not interaction.is_locked:
			drop_carried()


func _on_picked_up(box: MovingBox) -> void:
	_carrying = box
	_picked_frame = Engine.get_process_frames()
	box.carried = true
	for b in boxes:
		b.hands_free = false
	_set_carry_pose(true)


func _invitation() -> void:
	player.lock_input(LOCK)
	if head_call == null:
		_finish()
		return
	head_call.play(NightZeroScript.INVITATION, false)
	await head_call.finished
	_finish()


func _finish() -> void:
	if not evening_scene_path.is_empty():
		is_running = false
		finished.emit()
		get_tree().change_scene_to_file.call_deferred(evening_scene_path)
		return
	if hud != null:
		hud.show_line(NightZeroScript.PHASE_ONE_END)
	if friend != null:
		friend.queue_free()
		friend = null
	player.unlock_input(LOCK)
	is_running = false
	finished.emit()


func _set_carry_pose(on: bool) -> void:
	var body := player.body_visual as StreetFigure
	if body != null:
		body.carrying = on


func _facing() -> Vector3:
	return player.facing_direction()


## Painter's tape on the floor where the boxes go.
func _mark_drop_zone() -> void:
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.9, 0.75, 0.2)
	var r := DROP_ZONE
	var y := 0.01
	var edges := [
		[Vector3(r.get_center().x, y, r.position.y), Vector3(r.size.x, 0.005, 0.04)],
		[Vector3(r.get_center().x, y, r.end.y), Vector3(r.size.x, 0.005, 0.04)],
		[Vector3(r.position.x, y, r.get_center().y), Vector3(0.04, 0.005, r.size.y)],
		[Vector3(r.end.x, y, r.get_center().y), Vector3(0.04, 0.005, r.size.y)],
	]
	for e in edges:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = e[1]
		mi.mesh = b
		mi.material_override = tape
		mi.position = e[0]
		add_child(mi)
