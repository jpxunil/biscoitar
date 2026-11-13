@tool
class_name InkBackdrop
extends Control
## Fundo dos menus: base escura, faixas de tinta na diagonal e um pontilhado de retícula.

@export var base := Color(0.075, 0.07, 0.16): set = _set_base
@export var stripe_a := Color(0.42, 0.22, 0.86): set = _set_a
@export var stripe_b := Color(0.13, 0.13, 0.3): set = _set_b
@export var dots := Color(1, 1, 1, 0.045)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_base(c: Color) -> void:
	base = c
	queue_redraw()


func _set_a(c: Color) -> void:
	stripe_a = c
	queue_redraw()


func _set_b(c: Color) -> void:
	stripe_b = c
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), base)
	# faixas largas de tinta, com a borda serrilhada
	_stripe(Vector2(w * 0.55, -40), Vector2(w * 1.05, h * 0.55), 190.0, Color(stripe_a.r, stripe_a.g, stripe_a.b, 0.5), 11)
	_stripe(Vector2(-60, h * 0.62), Vector2(w * 0.5, h + 60), 150.0, Color(stripe_b.r, stripe_b.g, stripe_b.b, 0.9), 23)
	_stripe(Vector2(w * 0.3, -60), Vector2(w * 0.72, h + 40), 46.0, Color(stripe_a.r, stripe_a.g, stripe_a.b, 0.16), 37)
	# retícula
	var y := 10.0
	var row := 0
	while y < h:
		var x := 10.0 + (9.0 if row % 2 == 1 else 0.0)
		while x < w:
			draw_circle(Vector2(x, y), 1.6, dots)
			x += 18.0
		y += 16.0
		row += 1


func _stripe(a: Vector2, b: Vector2, thick: float, col: Color, s: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var steps := 9
	for k in steps + 1:
		var p := a.lerp(b, float(k) / steps)
		top.append(p + n * (thick * 0.5 + rng.randf_range(-12, 12)))
		bot.append(p - n * (thick * 0.5 + rng.randf_range(-12, 12)))
	bot.reverse()
	top.append_array(bot)
	draw_colored_polygon(top, col)
