class_name FpsLabel
extends Label
## Shows frames per second, refreshed once a second by a Timer (no string building every frame).


func _ready() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	_refresh()


func _refresh() -> void:
	text = tr("FPS_LABEL") % Engine.get_frames_per_second()
