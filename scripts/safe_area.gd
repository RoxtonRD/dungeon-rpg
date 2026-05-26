## Autoload. Keeps a screen's content inside the device safe area — the camera
## notch / cutout at the top and the gesture or navigation bar at the bottom.
##
## The OS reports the safe area in physical screen pixels via
## DisplayServer.get_display_safe_area(). This converts those insets into the
## game's virtual canvas coordinates (base 720x1280 with canvas_items stretch)
## and applies them as offsets on the supplied content container.
##
## The full-screen Background should stay OUTSIDE the safe area (full rect) so
## the dark backdrop still paints under the notch — only the interactive
## content is inset.
##
## Orientation is locked to portrait, so the safe area does not change at
## runtime; apply() is called once per screen from its _ready().
extends Node

## Uniform padding kept *inside* the safe area, in virtual px. Matches the
## 16px margin the screens were originally authored with.
const BASE_MARGIN := 16

## Minimum insets (virtual px) enforced on mobile only, as insurance for
## devices that under-report their notch / nav bar. Desktop/editor stays at 0.
const MIN_TOP := 24
const MIN_BOTTOM := 12


## Apply safe-area-aware margins to a full-rect content container. Call once
## from a screen's _ready(), passing the container that holds the visible UI.
func apply(content: Control, base: int = BASE_MARGIN) -> void:
	_apply_one(content, base)
	# Some Android devices only report the safe area after the first frame;
	# re-apply once on the next frame to catch that case.
	if content.is_inside_tree():
		content.get_tree().process_frame.connect(
			_apply_one.bind(content, base), CONNECT_ONE_SHOT)


func _apply_one(content: Control, base: int) -> void:
	if not is_instance_valid(content):
		return
	var insets := _insets(content)
	content.offset_left = base + insets.x
	content.offset_top = base + insets.y
	content.offset_right = -(base + insets.z)
	content.offset_bottom = -(base + insets.w)


## Safe-area insets as {x=left, y=top, z=right, w=bottom} in virtual px.
## Returns all-zero on desktop / editor, where the safe area equals the window.
func _insets(content: Control) -> Vector4:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var vp := content.get_viewport_rect().size
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	var left := maxf(0.0, float(safe.position.x)) * sx
	var top := maxf(0.0, float(safe.position.y)) * sy
	var right := maxf(0.0, float(win.x - safe.end.x)) * sx
	var bottom := maxf(0.0, float(win.y - safe.end.y)) * sy
	# On mobile, never go below the minimum cushion (covers under-reporting).
	if OS.has_feature("mobile"):
		top = maxf(top, MIN_TOP)
		bottom = maxf(bottom, MIN_BOTTOM)
	return Vector4(left, top, right, bottom)
