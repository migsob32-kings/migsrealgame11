extends Camera2D

const ZOOM_SPEED = 0.1
const ZOOM_MIN = 0.5
const ZOOM_MAX = 3.0

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clamp_zoom(zoom.x + ZOOM_SPEED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clamp_zoom(zoom.x - ZOOM_SPEED)

func clamp_zoom(value):
	var z = clamp(value, ZOOM_MIN, ZOOM_MAX)
	return Vector2(z, z)
