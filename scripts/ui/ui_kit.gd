class_name UIKit
extends RefCounted
## Small helpers so all menus look the same without a theme file.

const ACCENT := Color(1.0, 0.72, 0.15)
const PANEL_BG := Color(0.07, 0.08, 0.12, 0.88)


static func label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(size / 6, 2))
	return l


static func button(text: String, on_press: Callable, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, size * 2)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_press)
	var normal := _box(Color(0.16, 0.18, 0.26))
	var hover := _box(Color(0.26, 0.29, 0.42))
	var pressed := _box(ACCENT.darkened(0.3))
	var focus := _box(Color(0, 0, 0, 0))
	focus.border_color = ACCENT
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(PANEL_BG)
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func bar(color: Color, min_width: float = 220.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(min_width, 14)
	pb.max_value = 1.0
	pb.step = 0.001
	var bg := _box(Color(0, 0, 0, 0.55))
	var fill := _box(color)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	return pb


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]


static func format_time(t: float) -> String:
	var minutes := int(t / 60.0)
	var seconds := fmod(t, 60.0)
	return "%d:%06.3f" % [minutes, seconds]


static func _box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	return sb
