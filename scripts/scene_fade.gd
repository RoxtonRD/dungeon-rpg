## Autoload "Fade". Smooth scene changes: fade to black, swap, fade back in.
## Use Fade.change_scene(path) anywhere change_scene_to_file was used.
## Lives on a high CanvasLayer so it covers every screen; input is blocked
## while the fade runs so double-taps can't fire mid-transition.
extends CanvasLayer

const DURATION := 0.15

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var out_tween := create_tween()
	out_tween.tween_property(_rect, "modulate:a", 1.0, DURATION)
	await out_tween.finished
	get_tree().change_scene_to_file(path)
	var in_tween := create_tween()
	in_tween.tween_property(_rect, "modulate:a", 0.0, DURATION)
	await in_tween.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
