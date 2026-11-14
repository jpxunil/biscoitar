class_name SkillSlot
extends Control
## Um slot de habilidade com ícone, no estilo de barra de MMORPG, com a cara do kit de papel:
## moldura INK, sombra dura, ícone ilustrado (SkillInfo.icon), recarga em leque escuro com os
## segundos por cima, etiqueta da TECLA atual (vem do Binds, não é o número do slot) e brilho forte
## quando a habilidade está fortalecida. É o mesmo componente na luta e na tela SKILLS.

var icon: Texture2D: set = _set_icon
## Tecla configurada pro slot ("" = não mostra a etiqueta).
var key_text := "": set = _set_key
## Número do slot (1..6), mostrado no canto de cima quando show_number está ligado. Posição, não tecla.
var number := 0
var show_number := false
var cd_left := 0.0: set = _set_cd
## 0..1 enquanto a habilidade está sendo conjurada; -1 fora disso.
var cast_k := -1.0
## Habilidade fortalecida / a próxima da sequência: o slot brilha.
var glow := false
## Dá pra usar agora? (falta recurso, fora de ordem...) Desligado = ícone apagado.
var usable := true
## Travado (punição, no ar): tudo cinza com um X.
var locked := false
var selected := false
var accent := Paper.GOLD

var _peak := 0.01
var _t := 0.0
var _hot := false


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(func():
		_hot = true
		queue_redraw())
	mouse_exited.connect(func():
		_hot = false
		queue_redraw())


func _set_icon(v: Texture2D) -> void:
	icon = v
	queue_redraw()


func _set_key(v: String) -> void:
	key_text = v
	queue_redraw()


func _set_cd(v: float) -> void:
	# a recarga (re)começou: guarda o total pra saber o tamanho do leque
	if v > cd_left + 0.05 or cd_left <= 0.0:
		_peak = maxf(v, 0.01)
	cd_left = v


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _rr(r: Rect2, col: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0, filled := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.draw_center = filled
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	draw_style_box(sb, r)


func _draw() -> void:
	var s := size.x
	var full := Rect2(Vector2.ZERO, Vector2(s, s))
	var rad := int(s * 0.16)
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	if glow:
		# raios girando atrás do slot e três halos pulsando: brilho de verdade, não um tom amarelado
		var c := full.get_center()
		for n in 8:
			var a := _t * 1.6 + n * TAU / 8.0
			var d := Vector2(cos(a), sin(a))
			var side := Vector2(-d.y, d.x)
			var far := s * (0.92 + 0.14 * pulse)
			draw_colored_polygon(PackedVector2Array([c + side * s * 0.1, c + d * far, c - side * s * 0.1]),
				Color(accent.r, accent.g, accent.b, 0.55))
		for k in 3:
			var grow := 4.0 + k * 5.0 + pulse * 4.0
			_rr(full.grow(grow), Color(1.0, 0.95, 0.6, (0.5 - k * 0.14) * (0.6 + 0.4 * pulse)), rad + int(grow))
	# sombra dura e moldura
	_rr(Rect2(Vector2(4, 5), full.size), Paper.INK, rad)
	_rr(full, Paper.INK, rad)
	var inner := full.grow(-3)
	if icon != null:
		draw_texture_rect(icon, inner, false)
	else:
		_rr(inner, Paper.NAVY, rad - 2)
	if glow:
		_rr(full.grow(1.0), Color(0, 0, 0, 0), rad, Color(1.0, 0.97, 0.7, 0.75 + 0.25 * pulse), 4, false)
		_rr(inner, Color(1.0, 0.95, 0.55, 0.12 + 0.16 * pulse), rad - 2)
	elif selected:
		_rr(full.grow(3.0), Color(0, 0, 0, 0), rad + 2, accent, 4, false)
	elif _hot:
		_rr(full, Color(0, 0, 0, 0), rad, Paper.CREAM, 3, false)
	var f := Paper.display(0.0)
	# recarga: leque escuro que vai abrindo no sentido do relógio, com os segundos no meio
	if cd_left > 0.0:
		var frac := clampf(cd_left / _peak, 0.0, 1.0)
		var c := inner.get_center()
		var r := inner.size.x * 0.75
		var pts := PackedVector2Array([c])
		var steps := maxi(3, int(28 * frac))
		for n in steps + 1:
			var a := -PI * 0.5 + TAU * (1.0 - frac) + TAU * frac * n / steps
			var p := c + Vector2(cos(a), sin(a)) * r
			pts.append(Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y)))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.03, 0.03, 0.09, 0.78))
		var txt := ("%.0f" % ceilf(cd_left)) if cd_left >= 1.0 else ("%.1f" % cd_left)
		var px := int(s * 0.36)
		draw_string_outline(f, Vector2(0, s * 0.5 + px * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, s, px, 6, Paper.INK)
		draw_string(f, Vector2(0, s * 0.5 + px * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, s, px, Paper.CREAM)
	elif not usable:
		_rr(inner, Color(0.03, 0.03, 0.09, 0.66), rad - 2)
	if locked:
		_rr(inner, Color(0.25, 0.05, 0.1, 0.6), rad - 2)
		draw_line(inner.position + Vector2(10, 10), inner.end - Vector2(10, 10), Paper.CREAM, 5.0, true)
		draw_line(Vector2(inner.end.x - 10, inner.position.y + 10), Vector2(inner.position.x + 10, inner.end.y - 10), Paper.CREAM, 5.0, true)
	# conjurando: barra amarela enchendo embaixo do ícone
	if cast_k >= 0.0:
		draw_rect(Rect2(3, s - 12, s - 6, 9), Paper.INK)
		draw_rect(Rect2(5, s - 10, (s - 10) * clampf(cast_k, 0.0, 1.0), 5), Paper.GOLD)
		_rr(full, Color(0, 0, 0, 0), rad, Paper.GOLD, 3, false)
	# número do slot: posição na barra (canto de cima, discreto)
	if show_number and number > 0:
		draw_circle(Vector2(11, 11), 10.0, Paper.INK)
		draw_string(f, Vector2(1, 16), str(number), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Paper.CREAM)
	# tecla atual: etiqueta creme pendurada embaixo
	if key_text != "":
		var kpx := 12 if key_text.length() <= 3 else 9
		var w := maxf(24.0, f.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, kpx).x + 12.0)
		var kr := Rect2((s - w) * 0.5, s - 9, w, 19)
		_rr(Rect2(kr.position + Vector2(2, 3), kr.size), Paper.INK, 5)
		_rr(kr, Paper.CREAM, 5, Paper.INK, 2)
		draw_string(f, Vector2(kr.position.x, kr.position.y + 9.5 + kpx * 0.36), key_text, HORIZONTAL_ALIGNMENT_CENTER, w, kpx, Paper.INK)
