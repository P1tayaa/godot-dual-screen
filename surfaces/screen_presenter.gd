class_name ScreenPresenter
extends TextureRect
## Shows one screen of a DualScene on a surface (the main window, or the desktop bottom window) and sends the
## touch input it receives into that screen's viewport. Centred at 1:1 (a swap on a device with two screen sizes
## letterboxes the smaller one).
## Only touch is forwarded: a viewport outside a container has no hover, so mouse clicks would not reach buttons.
## On desktop the mouse emulates touch (project setting), on Android touch is native.

var _scene: DualScene
var _screen: DualScene.Screen = DualScene.Screen.TOP


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_screen(scene: DualScene, screen: DualScene.Screen) -> void:
	_scene = scene
	_screen = screen
	texture = scene.viewport(screen).get_texture() if scene != null else null


func shown_screen() -> DualScene.Screen:
	return _screen


func _gui_input(event: InputEvent) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	# _gui_input positions are local to this rect; the texture sits centred in it.
	var target: SubViewport = _scene.viewport(_screen)
	var margin: Vector2 = (size - Vector2(target.size)) / 2.0
	target.push_input(_to_scene_space(event, target, margin), true)
	_scene.request_redraw(_screen)
	accept_event()


## Texture pixels to the scene's own coordinates: minus the centring margin, and divided by the viewport's pixel
## scale (push_input does not apply size_2d_override). Shared with AndroidDisplay.
static func _to_scene_space(event: InputEvent, target: SubViewport, margin: Vector2) -> InputEvent:
	var out: InputEvent = event.duplicate()
	var scale: Vector2 = Vector2(target.size_2d_override) / Vector2(target.size) \
		if target.size_2d_override != Vector2i.ZERO else Vector2.ONE
	if out is InputEventScreenTouch:
		(out as InputEventScreenTouch).position = ((out as InputEventScreenTouch).position - margin) * scale
	elif out is InputEventScreenDrag:
		var drag: InputEventScreenDrag = out as InputEventScreenDrag
		drag.position = (drag.position - margin) * scale
		drag.relative *= scale
		drag.velocity *= scale
	return out
