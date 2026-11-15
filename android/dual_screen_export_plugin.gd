@tool
class_name DualScreenExportPlugin
extends EditorExportPlugin
## Adds bin/dual-screen-android-<debug|release>.aar to Android Gradle builds.


func _get_name() -> String:
	return "DualScreenAndroid"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["dual_screen/android/bin/dual-screen-android-%s.aar" % ("debug" if debug else "release")])
