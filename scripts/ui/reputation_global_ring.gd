extends Control

var _progress := 0.0

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(4.0, minf(size.x, size.y) * 0.5 - 3.0)
	draw_arc(center, radius, -PI * 0.5, TAU - PI * 0.5, 32, Color(0.18, 0.16, 0.12, 1.0), 4.0, true)
	if _progress > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * _progress, 32, Color(0.82, 0.63, 0.29, 1.0), 4.0, true)
