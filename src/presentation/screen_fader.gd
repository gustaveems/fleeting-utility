class_name ScreenFader
extends CanvasLayer
## PRESENTATION — a blink to black that hides an instant world swap.
##
## blink() snaps the screen black on this frame and fades it back in. The caller swaps
## worlds in the same frame, so the swap is never seen and nothing has to await. Used
## for the corporate-park walk, whose transitions used to be bare hard cuts: spamming
## E threw the player into the dark ransacked room with no sense of what had happened
## (playtest 2026-10-14). The dream keeps its own white fade.
##
## Layer 31: above post-FX (4) and the dream fade (30), below the HUD (50), so the
## arrival line shows over the black.

@export var hold_seconds: float = 0.35
@export var fade_seconds: float = 0.9

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 31
	_rect = ColorRect.new()
	_rect.name = "Black"
	_rect.color = Color.BLACK
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 0.0
	add_child(_rect)


func blink() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_rect, "modulate:a", 0.0, fade_seconds)


func is_black() -> bool:
	return _rect.modulate.a > 0.5
