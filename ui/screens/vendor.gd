@tool
class_name Vendor
extends Control
## O vendedor de cartas: Farelo, um bicho-biscoito de capuz, sonolento, atrás de um balcão
## cheio de pacotes de carta. Desenhado só com formas. `mood` muda a cara dele.

## "idle" sonolento · "happy" vendeu · "sad" faltou dinheiro · "wow" carta rara
@export var mood := "idle": set = _set_mood

var _t := 0.0
var _blink := 0.0
var _hop := 0.0


func _set_mood(v: String) -> void:
	mood = v
	if v == "happy":
		_hop = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -0.14:
		_blink = randf_range(2.0, 4.5)
	_hop = maxf(0.0, _hop - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Ink.OUT
	var bob := sin(_t * 1.6) * 4.0 - sin(_hop * PI) * 26.0
	var c := Vector2(w * 0.5, h * 0.42 + bob)
	# capuz
	var hood := PackedVector2Array([c + Vector2(-112, 70), c + Vector2(-124, -30), c + Vector2(-70, -118), c + Vector2(0, -140),
		c + Vector2(74, -116), c + Vector2(122, -28), c + Vector2(112, 70)])
	_poly(hood, Ink.GRAPE.darkened(0.25), ink)
	# orelhas de biscoito saindo do capuz
	for s in [-1.0, 1.0]:
		_poly(PackedVector2Array([c + Vector2(s * 60, -112), c + Vector2(s * 104, -160), c + Vector2(s * 106, -92)]), Ink.TAN, ink)
	# rosto
	draw_circle(c + Vector2(0, -12), 86, ink)
	draw_circle(c + Vector2(0, -12), 80, Ink.TAN.lightened(0.12))
	for p in [Vector2(-52, -52), Vector2(44, -60), Vector2(60, 10), Vector2(-58, 22)]:
		draw_circle(c + p, 8, Ink.BROWN)
	# olhos: meio fechados de sono, arregalados quando a carta é rara
	var closed := _blink < 0.0
	for s in [-1.0, 1.0]:
		var e := c + Vector2(s * 30, -20)
		if closed or mood == "happy":
			draw_arc(e + Vector2(0, 4), 13, PI, TAU, 12, ink, 5.0, true)
		else:
			var r := 17.0 if mood == "wow" else 14.0
			draw_circle(e, r, Color.WHITE)
			draw_circle(e + Vector2(0, 3), r * 0.5, ink)
			if mood == "idle" or mood == "sad":
				# pálpebra caída
				draw_rect(Rect2(e.x - r - 1, e.y - r - 1, r * 2 + 2, r * (0.95 if mood == "idle" else 0.7)), Ink.TAN.lightened(0.12))
				draw_line(e + Vector2(-r, -r * 0.05), e + Vector2(r, -r * 0.05), ink, 4.0, true)
	# boca
	var m := c + Vector2(0, 26)
	if mood == "happy":
		draw_arc(m + Vector2(0, -8), 22, 0.15, PI - 0.15, 14, ink, 6.0, true)
	elif mood == "sad":
		draw_arc(m + Vector2(0, 14), 18, PI + 0.3, TAU - 0.3, 12, ink, 5.0, true)
	elif mood == "wow":
		draw_circle(m, 11, ink)
	else:
		draw_line(m + Vector2(-14, 0), m + Vector2(14, -3), ink, 5.0, true)
	# cachecol
	_poly(PackedVector2Array([c + Vector2(-86, 52), c + Vector2(86, 52), c + Vector2(96, 86), c + Vector2(-96, 86)]), Ink.CREAM, ink)
	# balcão e pacotes de carta
	var top := h * 0.74
	_poly(PackedVector2Array([Vector2(0, top), Vector2(w, top - 8), Vector2(w, h), Vector2(0, h)]), Ink.BROWN, ink)
	draw_line(Vector2(0, top + 22), Vector2(w, top + 14), Ink.BROWN.lightened(0.18), 5.0)
	var packs := [[Vector2(26, top - 54), Ink.GRAPE, -8.0], [Vector2(88, top - 62), Ink.COIN, 5.0], [Vector2(w - 96, top - 58), Ink.CREAM, -4.0]]
	for pk in packs:
		draw_set_transform(pk[0] + Vector2(27, 37), deg_to_rad(pk[2]), Vector2.ONE)
		draw_rect(Rect2(-30, -40, 60, 80), ink)
		draw_rect(Rect2(-26, -36, 52, 72), pk[1])
		draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(11, 0), Vector2(0, 12), Vector2(-11, 0)]), ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(pts: PackedVector2Array, fill: Color, line: Color) -> void:
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, line, 5.0, true)
