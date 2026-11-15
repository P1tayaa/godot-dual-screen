class_name ScreensService
extends Node
## Autoload "Screens". Owns the current DualScene, the device profile, and decides where the two screens appear:
## SINGLE   both stacked in one window (phones, web, editor-embedded game, headless tests)
## DESKTOP  two OS windows
## ANDROID  the app's display + the second display through the Android plugin
## Also: screen swap, `home` action, and routing keys/gamepad to both screens when they are shown outside their
## containers.

signal scene_changed(scene: DualScene)
signal swapped_changed(swapped: bool)
## Gap or offset changed (calibration). Scenes with a physical layout move their cameras.
signal layout_changed

enum Mode { SINGLE, DESKTOP, ANDROID }

const SETTINGS_PATH: String = "user://dual_screen.cfg"
const DEVICES_DIR: String = "res://addons/dual_screen/profiles/devices"

var mode: Mode = Mode.SINGLE
var current: DualScene
var swapped: bool = false
var profile: DeviceProfile

var _main_presenter: ScreenPresenter
var _second_window: Window
var _second_presenter: ScreenPresenter
var _android_display: AndroidDisplay
var _pixel_scale: int = 1


func _ready() -> void:
	profile = _load_profile()
	mode = _pick_mode()
	if mode != Mode.SINGLE:
		_main_presenter = ScreenPresenter.new()
		add_child(_main_presenter)
	if mode == Mode.DESKTOP:
		_open_desktop_window()
	elif mode == Mode.ANDROID:
		_android_display = AndroidDisplay.new()
		_android_display.name = "AndroidDisplay"
		add_child(_android_display)
	_size_surfaces()


## Game pixel size of a screen's content (from the device profile).
func screen_size(screen: DualScene.Screen) -> Vector2i:
	return profile.spec(screen).base_size


## Frees the current scene and shows the one at `path`.
func change_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	var scene: DualScene = packed.instantiate() as DualScene
	get_tree().root.add_child(scene) # its _ready calls attach()


func go_home() -> void:
	var home: String = ProjectSettings.get_setting("dual_screen/home_scene", "")
	if home != "" and (current == null or current.scene_file_path != home):
		change_scene(home)


## Called by every DualScene in _ready, so the main scene and F6 runs are picked up too.
func attach(scene: DualScene) -> void:
	if current == scene:
		return
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = scene
	scene.tree_exiting.connect(_on_scene_exiting.bind(scene))
	scene.set_external(mode != Mode.SINGLE)
	if mode != Mode.SINGLE and scene.pixel_scale != _pixel_scale:
		_pixel_scale = scene.pixel_scale
		_size_surfaces()
	_apply_layout()
	scene_changed.emit(scene)


func swap() -> void:
	swapped = not swapped
	_apply_layout()
	swapped_changed.emit(swapped)


## Which screen the main surface (main window, the app's Android display) shows right now.
func main_screen() -> DualScene.Screen:
	return _main_display_role() if not swapped else _other(_main_display_role())


## All profiles in data/devices/.
func profiles() -> Array[DeviceProfile]:
	var out: Array[DeviceProfile] = []
	for file: String in ResourceLoader.list_directory(DEVICES_DIR):
		if file.ends_with(".tres"):
			out.append(load(DEVICES_DIR.path_join(file)) as DeviceProfile)
	return out


## Live change of gap and offset (calibration). Call save_profile() to keep it.
func set_layout(gap_mm: float, offset_mm: float) -> void:
	profile.gap_mm = gap_mm
	profile.offset_mm = offset_mm
	layout_changed.emit()


## Switches device. Screen sizes may change, so surfaces are resized and the current scene reloaded.
func use_profile(new_profile: DeviceProfile) -> void:
	profile = new_profile.duplicate(true) as DeviceProfile
	_size_surfaces()
	if current != null:
		change_scene(current.scene_file_path)


## Saves the device choice and its gap/offset to user://.
func save_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("device", "id", String(profile.id))
	config.set_value("device", "gap_mm", profile.gap_mm)
	config.set_value("device", "offset_mm", profile.offset_mm)
	config.save(SETTINGS_PATH)


func _input(event: InputEvent) -> void:
	if _handle_global_action(event):
		get_viewport().set_input_as_handled()
		return
	if mode != Mode.SINGLE:
		push_keys(event)


## Sends non-pointer input (keys, gamepad, actions) to both screens. Pointer input goes through the presenters.
func push_keys(event: InputEvent) -> void:
	if current == null or event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return
	for screen: DualScene.Screen in [DualScene.Screen.TOP, DualScene.Screen.BOTTOM]:
		current.viewport(screen).push_input(event)
		current.request_redraw(screen)


func _handle_global_action(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("swap_screens"):
		swap()
		return true
	if event.is_action_pressed("home"):
		go_home.call_deferred()
		return true
	return false


func _apply_layout() -> void:
	if current == null:
		return
	if mode == Mode.SINGLE:
		current.set_stacked_order(swapped)
		return
	var on_main: DualScene.Screen = main_screen()
	_main_presenter.show_screen(current, on_main)
	if _second_presenter != null:
		_second_presenter.show_screen(current, _other(on_main))
	if _android_display != null:
		_android_display.show_screen(current, _other(on_main))


## Window sizes follow the physical displays: each display keeps the size of the screen it shows unswapped.
func _size_surfaces() -> void:
	var top: Vector2i = screen_size(DualScene.Screen.TOP)
	var bottom: Vector2i = screen_size(DualScene.Screen.BOTTOM)
	var window: Window = get_window()
	if mode == Mode.SINGLE:
		window.content_scale_size = Vector2i(maxi(top.x, bottom.x), top.y + bottom.y)
		return
	var main_size: Vector2i = screen_size(_main_display_role())
	var second_size: Vector2i = screen_size(_other(_main_display_role()))
	# A scene with pixel_scale renders bigger viewports: give the windows the same pixels so presenters stay 1:1.
	window.content_scale_size = main_size * _pixel_scale
	if mode == Mode.DESKTOP:
		window.size = main_size * 2
		_second_window.size = second_size * 2
		_second_window.content_scale_size = second_size * _pixel_scale
		var below: bool = _main_display_role() == DualScene.Screen.TOP
		_second_window.position = window.position + Vector2i(0, (main_size.y * 2 + 40) * (1 if below else -1))


func _main_display_role() -> DualScene.Screen:
	if mode == Mode.ANDROID:
		return DualScene.Screen.TOP if profile.main_display_is_top else DualScene.Screen.BOTTOM
	return DualScene.Screen.TOP # desktop: the main window is the top screen


func _other(screen: DualScene.Screen) -> DualScene.Screen:
	return DualScene.Screen.BOTTOM if screen == DualScene.Screen.TOP else DualScene.Screen.TOP


func _on_scene_exiting(scene: DualScene) -> void:
	if current != scene:
		return
	current = null
	if _main_presenter != null:
		_main_presenter.show_screen(null, DualScene.Screen.TOP)
	if _second_presenter != null:
		_second_presenter.show_screen(null, DualScene.Screen.BOTTOM)
	if _android_display != null:
		_android_display.show_screen(null, DualScene.Screen.BOTTOM)


## Saved choice, else the profile whose model name matches this device, else the project default.
func _load_profile() -> DeviceProfile:
	var all: Array[DeviceProfile] = profiles()
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_id: StringName = StringName(config.get_value("device", "id", ""))
		for p: DeviceProfile in all:
			if p.id == saved_id:
				var chosen: DeviceProfile = p.duplicate(true) as DeviceProfile
				chosen.gap_mm = config.get_value("device", "gap_mm", p.gap_mm)
				chosen.offset_mm = config.get_value("device", "offset_mm", p.offset_mm)
				return chosen
	var model: String = OS.get_model_name()
	for p: DeviceProfile in all:
		if p.model_names.has(model):
			return p.duplicate(true) as DeviceProfile
	var fallback: DeviceProfile = load(ProjectSettings.get_setting("dual_screen/default_profile", DEVICES_DIR + "/rg_ds.tres"))
	return fallback.duplicate(true) as DeviceProfile


func _pick_mode() -> Mode:
	var setting: String = ProjectSettings.get_setting("dual_screen/screen/mode", "auto")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screens="):
			setting = arg.trim_prefix("--screens=")
	match setting:
		"single":
			return Mode.SINGLE
		"desktop":
			return Mode.DESKTOP
	# auto
	if OS.get_name() == "Android":
		return Mode.ANDROID if AndroidDisplay.available() else Mode.SINGLE
	if Engine.is_embedded_in_editor():
		return Mode.SINGLE
	if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return Mode.DESKTOP
	return Mode.SINGLE


func _open_desktop_window() -> void:
	_second_window = Window.new()
	_second_window.title = "%s (2)" % ProjectSettings.get_setting("application/config/name", "")
	_second_window.visible = false # force_native can only change on a hidden window
	_second_window.force_native = true
	_second_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_second_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_second_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	_second_window.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_second_window.close_requested.connect(get_tree().quit)
	# Keys pressed while the second window has focus still reach both screens.
	_second_window.window_input.connect(_on_second_window_input)
	add_child(_second_window)
	_second_presenter = ScreenPresenter.new()
	_second_window.add_child(_second_presenter)
	_second_window.show()


func _on_second_window_input(event: InputEvent) -> void:
	if not _handle_global_action(event):
		push_keys(event)
