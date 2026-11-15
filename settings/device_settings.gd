class_name DeviceSettings
extends DualScene
## Pick the device profile and calibrate the physical layout. Both screens show the millimetre world (WorldGrid):
## with the right gap and offset, the blue diagonals and circle continue straight across the hinge.
## Gap and offset apply live; Save writes them to user:// (Screens.save_profile).

const GAP_STEP_MM: float = 0.5
const OFFSET_STEP_MM: float = 0.5

var _profiles: Array[DeviceProfile] = []


func _ready() -> void:
	super._ready()
	use_physical_world_2d()
	%World.add_child(WorldGrid.new())
	_profiles = Screens.profiles()
	%PrevDevice.pressed.connect(_switch_device.bind(-1))
	%NextDevice.pressed.connect(_switch_device.bind(1))
	%GapLess.pressed.connect(_nudge.bind(-GAP_STEP_MM, 0.0))
	%GapMore.pressed.connect(_nudge.bind(GAP_STEP_MM, 0.0))
	%OffsetLess.pressed.connect(_nudge.bind(0.0, -OFFSET_STEP_MM))
	%OffsetMore.pressed.connect(_nudge.bind(0.0, OFFSET_STEP_MM))
	%Save.pressed.connect(_save)
	_refresh()


func _switch_device(step: int) -> void:
	var index: int = 0
	for i: int in _profiles.size():
		if _profiles[i].id == Screens.profile.id:
			index = i
	Screens.use_profile(_profiles[wrapi(index + step, 0, _profiles.size())]) # reloads this scene


func _nudge(gap_step: float, offset_step: float) -> void:
	Screens.set_layout(maxf(Screens.profile.gap_mm + gap_step, 0.0), Screens.profile.offset_mm + offset_step)
	_refresh()


func _save() -> void:
	Screens.save_profile()
	%Status.text = "SETTINGS_SAVED"


func _refresh() -> void:
	%Device.text = tr("SETTINGS_DEVICE") % Screens.profile.display_name
	%Gap.text = tr("SETTINGS_GAP") % Screens.profile.gap_mm
	%Offset.text = tr("SETTINGS_OFFSET") % Screens.profile.offset_mm
	%Status.text = ""
