@tool
class_name DualScreenPlugin
extends EditorPlugin
## Enabling the plugin sets a project up: the Screens autoload, the input actions the core uses, the addon's
## translations and the project settings the core relies on. Existing values are left alone.
## Also hands the Android AAR to Gradle exports.

const ROOT: String = "res://addons/dual_screen/"
const AUTOLOAD: String = "Screens"
## action -> [physical keycode, joypad button]
const ACTIONS: Dictionary[String, Array] = {
	"swap_screens": [KEY_Q, JOY_BUTTON_BACK],
	"home": [KEY_H, JOY_BUTTON_START],
	"toggle_mode": [KEY_C, JOY_BUTTON_Y],
}
## Settings the core needs. Only written when the project has no value yet.
const SETTINGS: Dictionary[String, Variant] = {
	"dual_screen/screen/mode": "auto",
	"dual_screen/default_profile": ROOT + "profiles/devices/rg_ds.tres",
	"dual_screen/android/transport": "gl",
	"input_devices/pointing/emulate_touch_from_mouse": true,
	"input_devices/sensors/enable_accelerometer": true,
	"input_devices/sensors/enable_gravity": true,
	"input_devices/sensors/enable_gyroscope": true,
	"rendering/renderer/rendering_method": "gl_compatibility",
	"rendering/renderer/rendering_method.mobile": "gl_compatibility",
	"rendering/textures/canvas_textures/default_texture_filter": 0,
	"rendering/textures/vram_compression/import_etc2_astc": true,
	"gui/theme/custom": ROOT + "theme/main_theme.tres",
}

var _export_plugin: DualScreenExportPlugin


func _enter_tree() -> void:
	_export_plugin = DualScreenExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD, ROOT + "screens.gd")
	for name: String in ACTIONS:
		_add_action(name, ACTIONS[name][0], ACTIONS[name][1])
	for key: String in SETTINGS:
		if not ProjectSettings.has_setting(key) or key.begins_with("input_devices/pointing"):
			ProjectSettings.set_setting(key, SETTINGS[key])
	var translations: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", [])
	for file: String in [ROOT + "i18n/dual_screen.en.translation", ROOT + "i18n/dual_screen.fr.translation"]:
		if not translations.has(file):
			translations.append(file)
	ProjectSettings.set_setting("internationalization/locale/translations", translations)
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD)


func _add_action(name: String, key: Key, button: JoyButton) -> void:
	var setting: String = "input/" + name
	if ProjectSettings.has_setting(setting):
		return
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = key
	var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_event.button_index = button
	ProjectSettings.set_setting(setting, {"deadzone": 0.5, "events": [key_event, pad_event]})
