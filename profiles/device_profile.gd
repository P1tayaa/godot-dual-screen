class_name DeviceProfile
extends Resource
## A dual-screen device: both screens, where they sit relative to each other, which one Android starts on.
## Profiles live in data/devices/. The player can adjust gap and offset in the device settings scene.

@export var id: StringName = &""
## Device name as sold (a proper noun, not translated).
@export var display_name: String = ""
## `OS.get_model_name()` values that select this profile automatically.
@export var model_names: PackedStringArray = []
@export var top: ScreenSpec
@export var bottom: ScreenSpec
## Distance from the lower edge of the top screen to the upper edge of the bottom screen, device opened flat.
@export var gap_mm: float = 20.0
## Horizontal shift of the top screen's centre against the bottom screen's centre (positive = right).
@export var offset_mm: float = 0.0
## Android: true when the display the app starts on is the top screen.
@export var main_display_is_top: bool = true


func spec(screen: DualScene.Screen) -> ScreenSpec:
	return top if screen == DualScene.Screen.TOP else bottom


## A screen's area on the "desk", in millimetres: origin at the bottom screen's top-left corner, y down.
## The top screen sits above it, `gap_mm` higher, centred plus `offset_mm`.
func rect_mm(screen: DualScene.Screen) -> Rect2:
	if screen == DualScene.Screen.BOTTOM:
		return Rect2(Vector2.ZERO, bottom.size_mm)
	var x: float = (bottom.size_mm.x - top.size_mm.x) / 2.0 + offset_mm
	return Rect2(Vector2(x, -gap_mm - top.size_mm.y), top.size_mm)


## Both screens and the gap between them, in desk millimetres.
func union_rect_mm() -> Rect2:
	return rect_mm(DualScene.Screen.TOP).merge(rect_mm(DualScene.Screen.BOTTOM))
