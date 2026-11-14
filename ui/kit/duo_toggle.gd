class_name DuoToggle
extends Control
## Alternador de duas faces do kit de papel: "CARTAS | GEAR". É UMA peça só, usada no mesmo lugar
## nas duas telas, então trocar de tela parece virar o mesmo controle.
##   - a metade ativa é a grande e clara (é o título da tela);
##   - a outra é menor, escura e clicável: acende no hover e pede a troca no clique;
##   - entre as duas, um talho inclinado na cor de destaque.
## Defina `labels`, `active` e `accent` e escute `flipped(to)` (0 = esquerda, 1 = direita).
## `flip()` faz o mesmo que o clique (atalho de teclado); `key_hint` é a tecla mostrada no canto.

signal flipped(to: int)

const SIZE := Vector2(262, 62)
## Largura da metade grande; o resto é da pequena.
const BIG_W := 166.0
const SLANT := 13.0

var labels := ["CARTAS", "GEAR"]: set = _set_labels
var active := 0: set = _set_active
var accent := Paper.PINK: set = _set_accent
var key_hint := "TAB": set = _set_hint
## Só a metade ativa, sem a outra nem o talho: vira um título comum (aula do tutorial).
var solo := false: set = _set_solo

var _hot := 0.0
var _over := false
var _tw: Tween
var _pop := 1.0


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(_hover.bind(false))


func _set_labels(v: Array) -> void:
	labels = v
	queue_redraw()


func _set_active(v: int) -> void:
	active = clampi(v, 0, 1)
	queue_redraw()


func _set_accent(v: Color) -> void:
	accent = v
	queue_redraw()


func _set_hint(v: String) -> void:
	key_hint = v
	queue_redraw()


func _set_solo(v: bool) -> void:
	solo = v
	queue_redraw()


## A metade ativa dá um pulinho: chame ao abrir a tela, pra troca parecer uma virada.
func pop() -> void:
	_pop = 0.86
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_pop = v
		queue_redraw(), 0.86, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pede a troca pra outra metade (clique nela ou atalho de teclado).
func flip() -> void:
	if not solo:
		flipped.emit(1 - active)


## Onde fica o talho (x no meio da altura).
func _cut_x() -> float:
	return BIG_W if active == 0 else size.x - BIG_W


## Polígono de uma metade: 0 = esquerda, 1 = direita. A ativa ocupa a altura toda; a outra é mais baixa.
func _half(side: int, grow := 0.0) -> PackedVector2Array:
	var cx := _cut_x()
	var big := side == active
	var top := (0.0 if big else 9.0) - grow
	var bot := (size.y if big else size.y - 9.0) + grow
	# o talho é uma reta só: x = cx + SLANT * (1 - 2 * y / altura)
	var xt := cx + SLANT * (1.0 - 2.0 * top / size.y)
	var xb := cx + SLANT * (1.0 - 2.0 * bot / size.y)
	var gap := 5.0
	if side == 0:
		var l := -grow
		return PackedVector2Array([Vector2(l, top + (0.0 if big else 2.0)), Vector2(xt - gap, top + (4.0 if big else 0.0)), Vector2(xb - gap, bot), Vector2(l + 6.0, bot - (5.0 if big else 2.0))])
	var r := size.x + grow
	return PackedVector2Array([Vector2(xt + gap, top), Vector2(r, top + (5.0 if big else 3.0)), Vector2(r - 9.0, bot - (0.0 if big else 2.0)), Vector2(xb + gap, bot - (4.0 if big else 0.0))])


func _has_point(p: Vector2) -> bool:
	return not solo and _in_other(p)


func _in_other(p: Vector2) -> bool:
	return not solo and Geometry2D.is_point_in_polygon(p, _half(1 - active, 4.0))


func _hover(on: bool) -> void:
	if on == _over:
		return
	_over = on
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(func(v: float):
		_hot = v
		queue_redraw(), _hot, 1.0 if on else 0.0, 0.12)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover(_in_other(e.position))
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed and _in_other(e.position):
		accept_event()
		flip()


func _text(f: Font, txt: String, poly: PackedVector2Array, px: int, col: Color, dy := 0.0) -> void:
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var mid := (lo + hi) * 0.5
	draw_string(f, Vector2(mid.x - w * 0.5, mid.y + (f.get_ascent(px) - f.get_descent(px)) * 0.5 + dy), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw() -> void:
	var f := Paper.display()
	var other := 1 - active
	if not solo:
		# metade apagada primeiro (fica atrás da grande)
		var small := _half(other)
		var lift := Vector2(0, -3.0 * _hot)
		draw_colored_polygon(Paper.moved(small, Vector2(5, 6)), Paper.INK)
		draw_colored_polygon(Paper.moved(small, lift), Paper.INK)
		var body := Color("2a3276").lerp(accent, _hot)
		draw_colored_polygon(Paper.moved(Paper.inset(small, 3.0), lift), body)
		var spx := 17
		while spx > 10 and f.get_string_size(labels[other], HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x > size.x - BIG_W - 26.0:
			spx -= 1
		_text(f, labels[other], Paper.moved(small, lift), spx, Color(Paper.CREAM, 0.9).lerp(Paper.INK, _hot), -4.0 if key_hint != "" else 0.0)
		if key_hint != "":
			# tecla do atalho, numa etiqueta pequena pendurada no pé da metade clicável
			var kf := Paper.display(0.0)
			var kw := kf.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0
			var c := (small[2] + small[3]) * 0.5 + lift + Vector2(0, -1)
			var tag := Paper.moved(Paper.skew_rect(Vector2(kw, 15), 12), c - Vector2(kw * 0.5, 9))
			draw_colored_polygon(tag, Paper.INK)
			draw_colored_polygon(Paper.inset(tag, 2.0), Paper.GOLD)
			draw_string(kf, Vector2(c.x - kw * 0.5, c.y + 2.0), key_hint, HORIZONTAL_ALIGNMENT_CENTER, kw, 9, Paper.INK)
	# metade ativa: o título da tela
	var big := _half(active)
	var mid := Vector2(BIG_W * 0.5 if active == 0 else size.x - BIG_W * 0.5, size.y * 0.5)
	draw_set_transform(mid * (1.0 - _pop), 0.0, Vector2.ONE * _pop)
	draw_colored_polygon(Paper.moved(big, Vector2(6, 7)), Paper.INK)
	draw_colored_polygon(big, Paper.INK)
	draw_colored_polygon(Paper.inset(big, 4.0), Paper.CREAM)
	var bpx := 34
	while bpx > 18 and f.get_string_size(labels[active], HORIZONTAL_ALIGNMENT_LEFT, -1, bpx).x > BIG_W - 30.0:
		bpx -= 1
	draw_set_transform(mid * (1.0 - _pop) + mid * _pop, deg_to_rad(-2.0), Vector2.ONE * _pop)
	var tw := f.get_string_size(labels[active], HORIZONTAL_ALIGNMENT_LEFT, -1, bpx).x
	draw_string(f, Vector2(-tw * 0.5 - 2.0, (f.get_ascent(bpx) - f.get_descent(bpx)) * 0.5), labels[active], HORIZONTAL_ALIGNMENT_LEFT, -1, bpx, Paper.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if solo:
		return
	# o talho: uma lasca na cor de destaque, mais comprida que as duas metades
	var cx := _cut_x()
	var slash := PackedVector2Array([
		Vector2(cx + SLANT * 1.3 - 3.5, -9.0), Vector2(cx + SLANT * 1.3 + 4.5, -9.0),
		Vector2(cx - SLANT * 1.3 + 3.5, size.y + 9.0), Vector2(cx - SLANT * 1.3 - 4.5, size.y + 9.0)])
	draw_colored_polygon(Paper.moved(slash, Vector2(3, 3)), Paper.INK)
	for ring in Geometry2D.offset_polygon(slash, 2.5, Geometry2D.JOIN_MITER):
		draw_colored_polygon(ring, Paper.INK)
	draw_colored_polygon(slash, accent.lerp(Paper.GOLD, _hot))
