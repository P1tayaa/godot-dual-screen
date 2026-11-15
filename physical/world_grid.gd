class_name WorldGrid
extends Node2D
## Draws the physical world of a DualScene (use_physical_world_2d): a millimetre grid over both screens and the gap,
## each screen's outline, and two long diagonals. When gap and offset are right, the diagonals continue straight
## across the hinge. Redraws only when the layout changes.

@export var step_mm: float = 10.0
@export var grid_color: Color = Color(1, 1, 1, 0.12)
@export var outline_color: Color = Color(1, 0.706, 0.329, 0.8)
@export var diagonal_color: Color = Color(0.4, 0.8, 1.0, 0.9)


func _ready() -> void:
	Screens.layout_changed.connect(queue_redraw)


func _draw() -> void:
	var area: Rect2 = Screens.profile.union_rect_mm()
	var x: float = floorf(area.position.x / step_mm) * step_mm
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), grid_color, -1.0)
		x += step_mm
	var y: float = floorf(area.position.y / step_mm) * step_mm
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid_color, -1.0)
		y += step_mm
	for screen: DualScene.Screen in [DualScene.Screen.TOP, DualScene.Screen.BOTTOM]:
		draw_rect(Screens.profile.rect_mm(screen).grow(-0.5), outline_color, false, 0.6)
	draw_line(area.position, area.end, diagonal_color, 0.4)
	draw_line(Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), diagonal_color, 0.4)
	draw_arc(area.get_center(), minf(area.size.x, area.size.y) * 0.45, 0.0, TAU, 96, diagonal_color, 0.4)
