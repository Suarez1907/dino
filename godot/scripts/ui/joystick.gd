extends Control

signal moved(dir: Vector2)

var knob := Vector2.ZERO
var _pressing := false
var _touch := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(168, 168)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_touch = true
		if touch.pressed:
			_pressing = true
			_set_knob(touch.position)
		else:
			_release()
	elif event is InputEventScreenDrag and _pressing:
		_set_knob((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton and not _touch:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		_pressing = mouse.pressed
		if _pressing:
			_set_knob(mouse.position)
		else:
			_release()
	elif event is InputEventMouseMotion and _pressing and not _touch:
		_set_knob((event as InputEventMouseMotion).position)

func _release() -> void:
	_pressing = false
	knob = Vector2.ZERO
	moved.emit(Vector2.ZERO)
	queue_redraw()

func _set_knob(pos: Vector2) -> void:
	var center := size * 0.5
	var delta := pos - center
	var max_r: float = minf(size.x, size.y) * 0.34
	if max_r < 8.0:
		return
	if delta.length() > max_r:
		delta = delta.normalized() * max_r
	knob = delta
	moved.emit(Vector2(delta.x / max_r, delta.y / max_r))
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	draw_circle(center, radius, Color(1, 1, 1, 0.28))
	draw_arc(center, radius, 0, TAU, 40, Color(1, 0.96, 0.88, 0.95), 5.0, true)
	draw_circle(center + knob, radius * 0.42, Color(1.0, 0.45, 0.33, 0.96))
