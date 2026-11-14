extends Control

var kind := "pile"
var tint := Color(0.55, 0.36, 0.22)

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, min(size.x, size.y) * 0.48, Color(1, 0.97, 0.9))
	match kind:
		"rock":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-16, 10), c + Vector2(-8, -14), c + Vector2(6, -8), c + Vector2(16, 12), c + Vector2(0, 16)
			]), tint)
		"block":
			draw_rect(Rect2(c + Vector2(-14, -12), Vector2(28, 26)), tint)
		"feather":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -18), c + Vector2(12, 8), c + Vector2(0, 16), c + Vector2(-12, 8)
			]), Color(0.95, 0.45, 0.6))
		"drops":
			draw_circle(c + Vector2(-8, 4), 8, Color(0.25, 0.62, 0.85))
			draw_circle(c + Vector2(8, 2), 6, Color(0.4, 0.75, 0.95))
		"gem":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -16), c + Vector2(14, 0), c + Vector2(0, 16), c + Vector2(-14, 0)
			]), Color(0.55, 0.62, 0.7))
		"star":
			draw_circle(c, 8, Color(1.0, 0.85, 0.35))
		"bone":
			draw_line(c + Vector2(-12, 8), c + Vector2(12, -8), Color(0.93, 0.88, 0.75), 6.0)
		_:
			draw_circle(c + Vector2(0, 6), 14, tint)
			draw_circle(c + Vector2(-10, 0), 8, tint.lightened(0.1))
			draw_circle(c + Vector2(10, -2), 7, tint.darkened(0.08))
