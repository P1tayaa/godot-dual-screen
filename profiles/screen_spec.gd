class_name ScreenSpec
extends Resource
## One physical screen of a device.

## Physical pixels of the panel.
@export var resolution: Vector2i = Vector2i(640, 480)
## Visible area in millimetres.
@export var size_mm: Vector2 = Vector2(81.3, 61.0)
## Game pixels. Scaled by the largest integer that fits `resolution`, centred.
@export var base_size: Vector2i = Vector2i(320, 240)


## Game pixels per millimetre (the smaller axis, so a world circle stays round).
func px_per_mm() -> float:
	return minf(base_size.x / size_mm.x, base_size.y / size_mm.y)
