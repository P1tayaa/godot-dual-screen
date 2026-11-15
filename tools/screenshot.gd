class_name ScreenshotTool
extends SceneTree
## Renders a scene in the stacked layout and saves the window as PNG (needs a display, not --headless):
##   $GODOT_PATH --path . --script res://addons/dual_screen/tools/screenshot.gd -- --screens=single --scene=res://scenes/home/home.tscn \
##       --out=/tmp/shot.png [--frames=30] [--press=ui_down,ui_down]

var _frames_left: int = 30
var _out: String = "user://screenshot.png"
var _presses: PackedStringArray = []
var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var scene_path: String = ""
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--scene="):
				scene_path = arg.trim_prefix("--scene=")
			elif arg.begins_with("--out="):
				_out = arg.trim_prefix("--out=")
			elif arg.begins_with("--frames="):
				_frames_left = arg.trim_prefix("--frames=").to_int()
			elif arg.begins_with("--press="):
				_presses = arg.trim_prefix("--press=").split(",", false)
		# Loaded at run time: the Screens autoload does not exist when this script compiles.
		var screens: Node = root.get_node("Screens")
		screens.call("change_scene", scene_path)
		return false
	for action: String in _presses:
		var press: InputEventAction = InputEventAction.new()
		press.action = action
		press.pressed = true
		Input.parse_input_event(press)
		var release: InputEventAction = press.duplicate() as InputEventAction
		release.pressed = false
		Input.parse_input_event(release)
	_presses.clear()
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var image: Image = root.get_texture().get_image()
	image.save_png(_out)
	print("saved %s %s" % [_out, image.get_size()])
	return true
