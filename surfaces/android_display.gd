class_name AndroidDisplay
extends Node
## The second display of an Android handheld, through the DualScreenAndroid plugin. Used by Screens in ANDROID mode,
## same job as a ScreenPresenter: show one screen of the current DualScene, send its touch back into it.
##
## Transports (see docs/DECISIONS.md for which one won on the device):
## READBACK  copy the viewport image to the plugin after each redraw. One GPU readback per redraw.
## GL        give the plugin the viewport's GL texture id once, it draws it each frame. No copy.

enum Transport { READBACK, GL }

const PLUGIN: String = "DualScreenAndroid"
const TOUCH_DOWN: int = 0
const TOUCH_UP: int = 1
const TOUCH_MOVE: int = 2

var transport: Transport = Transport.READBACK
## Frames sent by Godot (READBACK only), for the bench.
var frames_sent: int = 0

var _plugin: Object
var _scene: DualScene
var _screen: DualScene.Screen = DualScene.Screen.BOTTOM
var _dirty: bool = true
var _gl_handle: int = 0
var _opened_size: Vector2i = Vector2i.ZERO


## True on Android with the plugin exported and a second display connected.
static func available() -> bool:
	if not Engine.has_singleton(PLUGIN):
		return false
	var plugin: Object = Engine.get_singleton(PLUGIN)
	return int(plugin.call("secondDisplayId")) >= 0


func _ready() -> void:
	_plugin = Engine.get_singleton(PLUGIN)
	_plugin.connect("second_touch", _on_second_touch)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	var setting: String = ProjectSettings.get_setting("dual_screen/android/transport", "readback")
	open(Transport.GL if setting == "gl" else Transport.READBACK)


## (Re)opens the second display for the current screen's size. Also used to switch transport.
func open(new_transport: Transport) -> void:
	transport = new_transport
	_opened_size = Screens.screen_size(_screen) if _scene == null else _scene.viewport(_screen).size
	_plugin.call("open", _opened_size.x, _opened_size.y, int(transport))
	_refresh()


func show_screen(scene: DualScene, screen: DualScene.Screen) -> void:
	if _scene != null and is_instance_valid(_scene) and _scene.redraw_requested.is_connected(_on_redraw_requested):
		_scene.redraw_requested.disconnect(_on_redraw_requested)
	_scene = scene
	_screen = screen
	if scene != null:
		scene.redraw_requested.connect(_on_redraw_requested)
		if scene.viewport(screen).size != _opened_size:
			open(transport) # a swap on a device whose screens differ in size
			return
	_refresh()


## Frames that actually appeared on the second display (counted by the plugin).
func frames_shown() -> int:
	return int(_plugin.call("framesShown"))


func _refresh() -> void:
	_dirty = true
	if transport != Transport.GL:
		_plugin.call("setTexture", 0, false)
		return
	if _scene == null or not is_instance_valid(_scene):
		_plugin.call("setTexture", 0, false)
		return
	_gl_handle = 0 # asked for again after the next frame: the render target may not exist yet


func _send_gl_texture() -> void:
	# Not get_texture().get_rid(): that is a proxy whose GL id is copied before the render target exists (0).
	var rid: RID = RenderingServer.viewport_get_texture(_scene.viewport(_screen).get_viewport_rid())
	_gl_handle = RenderingServer.texture_get_native_handle(rid)
	if _gl_handle == 0:
		return
	# Godot's render targets are stored bottom-up in GL.
	_plugin.call("setTexture", _gl_handle, true)
	_plugin.call("setContinuous", _scene.redraw_mode(_screen) == DualScene.Redraw.ALWAYS)


func _on_redraw_requested(screen: DualScene.Screen) -> void:
	if screen != _screen:
		return
	_dirty = true
	if transport == Transport.GL:
		# Also called when the redraw mode changes, so keep the plugin's mode in step.
		_plugin.call("setContinuous", _scene.redraw_mode(_screen) == DualScene.Redraw.ALWAYS)
		_plugin.call("requestDraw")


func _on_frame_post_draw() -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	if transport == Transport.GL:
		if _gl_handle == 0:
			_send_gl_texture()
		return
	if _scene.redraw_mode(_screen) == DualScene.Redraw.ON_CHANGE and not _dirty:
		return
	_dirty = false
	var image: Image = _scene.viewport(_screen).get_texture().get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		# HACK: allocates; the viewport texture is RGB8 when not transparent. Bench decides if READBACK stays.
		image.convert(Image.FORMAT_RGBA8)
	_plugin.call("pushFrame", image.get_data())
	frames_sent += 1


func _on_second_touch(action: int, index: int, x: float, y: float) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	var event: InputEvent
	if action == TOUCH_MOVE:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = index
		drag.position = Vector2(x, y)
		event = drag
	else:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = index
		touch.pressed = action == TOUCH_DOWN
		touch.position = Vector2(x, y)
		event = touch
	var target: SubViewport = _scene.viewport(_screen)
	target.push_input(ScreenPresenter._to_scene_space(event, target, Vector2.ZERO), true)
	_scene.request_redraw(_screen)
