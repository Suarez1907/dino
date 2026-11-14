extends RefCounted

const CREAM := Color(1.0, 0.965, 0.91)
const INK := Color(0.145, 0.18, 0.24)
const CORAL := Color(1.0, 0.45, 0.33)
const TEAL := Color(0.12, 0.45, 0.52)
const SUN := Color(0.98, 0.76, 0.32)
const GOOD := Color(0.33, 0.66, 0.42)
const SOFT := Color(0.96, 0.9, 0.8)

static func apply(root: Window, large: bool) -> void:
	var theme := Theme.new()
	var font = load("res://assets/fonts/Nunito-Bold.ttf")
	if font:
		theme.default_font = font
	theme.default_font_size = 34 if large else 26
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_stylebox("panel", "Panel", _box(CREAM, 28, Color(0, 0, 0, 0.12)))
	theme.set_stylebox("panel", "PanelContainer", _box(CREAM, 28, Color(0, 0, 0, 0.12)))
	var normal := _box(Color(1, 1, 1, 0.92), 22, Color(0, 0, 0, 0.08))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", _box(Color(1, 0.97, 0.9), 22, Color(0, 0, 0, 0.1)))
	theme.set_stylebox("pressed", "Button", _box(Color(0.96, 0.86, 0.74), 22, Color(0, 0, 0, 0.12)))
	theme.set_stylebox("focus", "Button", _box(Color(1, 1, 1, 0.92), 22, TEAL))
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	root.theme = theme

static func _box(color: Color, radius: int, shadow: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.shadow_color = shadow
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	return box

static func paint(btn: Button, kind: String) -> void:
	var bg := CREAM
	var fg := INK
	if kind == "primary":
		bg = CORAL
		fg = Color.WHITE
	elif kind == "teal":
		bg = TEAL
		fg = Color.WHITE
	elif kind == "sun":
		bg = SUN
		fg = INK
	elif kind == "good":
		bg = GOOD
		fg = Color.WHITE
	btn.add_theme_stylebox_override("normal", _box(bg, 22, Color(0, 0, 0, 0.16)))
	btn.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), 22, Color(0, 0, 0, 0.16)))
	btn.add_theme_stylebox_override("pressed", _box(bg.darkened(0.08), 22, Color(0, 0, 0, 0.12)))
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.focus_mode = Control.FOCUS_NONE

static func button(text: String, kind := "cream") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 76)
	btn.focus_mode = Control.FOCUS_NONE
	paint(btn, kind)
	return btn

static func label(text: String, size := 0) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if size > 0:
		lbl.add_theme_font_size_override("font_size", size)
	return lbl

static func fill(node: Control) -> Control:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	return node
