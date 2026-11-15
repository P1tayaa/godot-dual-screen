class_name DualScene
extends VBoxContainer
## Base of every screen scene: a top and a bottom SubViewport, stacked like a DS in the editor and with F6.
## Put top content under %TopViewport and bottom content under %BottomViewport. `Screens` decides where each one
## is shown (stacked in one window, two desktop windows, or the two displays of a handheld). Each screen's size comes
## from the device profile (`Screens.screen_size()`).
##
## Physical world: `use_physical_world_2d()` makes both viewports look into ONE 2D world measured in millimetres,
## each through a camera placed where its real panel is (gap and offset included). Something thrown off the bottom
## screen spends real time crossing the hinge before it shows up on the top screen.

## An ON_CHANGE screen will draw one more frame (the Android second display uses it to know when to draw).
signal redraw_requested(screen: Screen)

enum Screen { TOP, BOTTOM }
## ALWAYS redraws every frame. ON_CHANGE redraws only after input or `request_redraw()`: a static screen costs nothing.
enum Redraw { ALWAYS, ON_CHANGE }

@export var top_redraw: Redraw = Redraw.ALWAYS
@export var bottom_redraw: Redraw = Redraw.ALWAYS
## Renders both screens at this multiple of the base size (2 = 640x480 on the RG DS, the panel's own pixels) while
## the scene keeps working in base-size coordinates (size_2d_override). For sharp text and hanzi, or full-res 3D.
## Costs pixel_scale² the fill. Ignored in the stacked layout.
@export_range(1, 4) var pixel_scale: int = 1

var _physical_cameras: Array[Camera2D] = []

@onready var top_container: SubViewportContainer = %TopContainer
@onready var bottom_container: SubViewportContainer = %BottomContainer
@onready var top_viewport: SubViewport = %TopViewport
@onready var bottom_viewport: SubViewport = %BottomViewport


func _ready() -> void:
	for screen: Screen in [Screen.TOP, Screen.BOTTOM]:
		var size_px: Vector2i = Screens.screen_size(screen)
		var container: SubViewportContainer = top_container if screen == Screen.TOP else bottom_container
		container.custom_minimum_size = Vector2(size_px)
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		viewport(screen).size = size_px
		viewport(screen).size_2d_override = size_px
		viewport(screen).size_2d_override_stretch = true
		viewport(screen).render_target_update_mode = _update_mode(redraw_mode(screen))
	Screens.attach(self)


func viewport(screen: Screen) -> SubViewport:
	return top_viewport if screen == Screen.TOP else bottom_viewport


func redraw_mode(screen: Screen) -> Redraw:
	return top_redraw if screen == Screen.TOP else bottom_redraw


## Draws one more frame of an ON_CHANGE screen. Call it after changing that screen from code (tween, timer, data).
func request_redraw(screen: Screen) -> void:
	if redraw_mode(screen) == Redraw.ON_CHANGE:
		viewport(screen).render_target_update_mode = SubViewport.UPDATE_ONCE
		redraw_requested.emit(screen)


## Changes a screen's redraw mode at run time.
func set_redraw(screen: Screen, mode: Redraw) -> void:
	if screen == Screen.TOP:
		top_redraw = mode
	else:
		bottom_redraw = mode
	viewport(screen).render_target_update_mode = _update_mode(mode)
	redraw_requested.emit(screen)


## Both viewports share the top viewport's World2D (one canvas, one physics space), in millimetres. Put world nodes
## under either viewport; put per-screen UI in a CanvasLayer (a layer is drawn only by its own viewport).
func use_physical_world_2d() -> void:
	bottom_viewport.world_2d = top_viewport.world_2d
	for screen: Screen in [Screen.TOP, Screen.BOTTOM]:
		var camera: Camera2D = Camera2D.new()
		camera.name = "PhysicalCamera"
		viewport(screen).add_child(camera)
		camera.make_current()
		_physical_cameras.append(camera)
	_place_physical_cameras()
	Screens.layout_changed.connect(_place_physical_cameras)


## A screen position (game pixels) to physical world millimetres. Needs use_physical_world_2d().
func screen_to_world(screen: Screen, position_px: Vector2) -> Vector2:
	return viewport(screen).get_canvas_transform().affine_inverse() * position_px


## Stacked layout only: puts the bottom screen first when swapped.
func set_stacked_order(swapped: bool) -> void:
	move_child(bottom_container, 0 if swapped else 1)


## True when the screens are shown elsewhere (two windows, two displays): the containers hide, the viewports keep
## rendering by their own update mode.
func set_external(external: bool) -> void:
	top_container.visible = not external
	bottom_container.visible = not external
	# Outside the stacked layout each screen has its own surface, so it can render at pixel_scale.
	var scale: int = pixel_scale if external else 1
	for screen: Screen in [Screen.TOP, Screen.BOTTOM]:
		viewport(screen).size = Screens.screen_size(screen) * scale
	# The scene root covers the window: let touch through to the presenter drawn under it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if external else Control.MOUSE_FILTER_PASS
	# A container sets its viewport to UPDATE_DISABLED when hidden (ALWAYS when shown): put our modes back.
	top_viewport.render_target_update_mode = _update_mode(top_redraw)
	bottom_viewport.render_target_update_mode = _update_mode(bottom_redraw)


func _place_physical_cameras() -> void:
	for i: int in _physical_cameras.size():
		var screen: Screen = Screen.TOP if i == 0 else Screen.BOTTOM
		var camera: Camera2D = _physical_cameras[i]
		camera.position = Screens.profile.rect_mm(screen).get_center()
		camera.zoom = Vector2.ONE * Screens.profile.spec(screen).px_per_mm()
		request_redraw(screen)


func _input(event: InputEvent) -> void:
	# Stacked layout: the containers forward input themselves, ON_CHANGE screens just need one more frame.
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask == 0:
		return
	request_redraw(Screen.TOP)
	request_redraw(Screen.BOTTOM)


func _update_mode(mode: Redraw) -> SubViewport.UpdateMode:
	return SubViewport.UPDATE_ALWAYS if mode == Redraw.ALWAYS else SubViewport.UPDATE_ONCE
