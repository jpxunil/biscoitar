class_name CardView
extends Control
## Uma carta em pé, desenhada a partir do id em Knowledge.CARDS.
## Layout: faixa do nome em cima, janela da ilustração (por enquanto a inicial) e naipes embaixo.
## Use CardView.make(id) e depois mude `state`, `price_tag` ou `progress` se precisar.
##
## state: "face"  carta normal, virada pra cima
##        "dim"   virada pra cima mas apagada (não pode usar/comprar agora)
##        "back"  de verso, com "?" (ainda não é do jogador)
##        "empty" lugar vazio de um slot (use kind pra dar a cor)

const W := 108.0
const H := 152.0

var id := "": set = _set_id
var kind := "white": set = _set_kind
var state := "face": set = _set_state
## Texto de preço no rodapé ("100", "1 ticket", "VENDIDA"). Vazio = mostra os naipes.
var price_tag := "": set = _set_price
## Maestria: quantas de quantas (só aparece em carta de verso). -1 = não mostra.
var progress := -1: set = _set_progress
var selected := false: set = _set_selected


static func make(card_id: String, card_state := "face") -> CardView:
	var c := CardView.new()
	c.id = card_id
	c.state = card_state
	return c


static func empty(slot_kind: String) -> CardView:
	var c := CardView.new()
	c.kind = slot_kind
	c.state = "empty"
	return c


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W, H) * 0.5


func _set_id(v: String) -> void:
	id = v
	if Knowledge.CARDS.has(v):
		kind = Knowledge.CARDS[v]["kind"]
	queue_redraw()


func _set_kind(v: String) -> void:
	kind = v
	queue_redraw()


func _set_state(v: String) -> void:
	state = v
	queue_redraw()


func _set_price(v: String) -> void:
	price_tag = v
	queue_redraw()


func _set_progress(v: int) -> void:
	progress = v
	queue_redraw()


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _rr(rect: Rect2, col: Color, radius: float, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	draw_style_box(sb, rect)


func _draw() -> void:
	var col: Color = Knowledge.KIND_COLOR.get(kind, Color.WHITE)
	var full := Rect2(Vector2.ZERO, Vector2(W, H))
	if state == "empty":
		_rr(full, Color(0, 0, 0, 0.28), 9, Color(col.r, col.g, col.b, 0.55), 2)
		var c := full.get_center()
		var d := 9.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Color(col.r, col.g, col.b, 0.3))
		return
	# sombra dura, como carta apoiada
	_rr(Rect2(Vector2(3, 5), Vector2(W, H)), Color(0, 0, 0, 0.45), 9)
	if selected:
		_rr(full.grow(4), Color(1, 1, 1, 0.95), 12)
	var f := ThemeDB.fallback_font
	if state == "back":
		_rr(full, Ink.NAVY, 9, col.darkened(0.25), 3)
		var x := -H
		while x < W:
			draw_line(Vector2(maxf(x, 6), 6 + maxf(0.0, 6 - x)), Vector2(minf(x + H, W - 6), minf(H - 6, H - 6 - maxf(0.0, x + H - W + 6))), Color(col.r, col.g, col.b, 0.16), 1.0)
			x += 14.0
		draw_string(Ink.font(0.0, 1.0), Vector2(0, H * 0.5 + 14), "?", HORIZONTAL_ALIGNMENT_CENTER, W, 44, col.lightened(0.25))
		if progress >= 0:
			# maestria: um losango por acerto que falta
			for k in Knowledge.MASTERY_NEED:
				var pc := Vector2(W * 0.5 + (k - (Knowledge.MASTERY_NEED - 1) * 0.5) * 20.0, H - 22)
				var on := k < progress
				var r := 6.0
				var dia := PackedVector2Array([pc + Vector2(0, -r), pc + Vector2(r, 0), pc + Vector2(0, r), pc + Vector2(-r, 0)])
				if on:
					draw_colored_polygon(dia, col.lightened(0.2))
				else:
					dia.append(dia[0])
					draw_polyline(dia, Color(col.r, col.g, col.b, 0.7), 2.0, true)
		return

	var dim := state == "dim"
	var paper := Ink.CREAM if not dim else Ink.CREAM.darkened(0.45)
	var ink := Ink.OUT
	_rr(full, paper, 9, col if not dim else col.darkened(0.4), 4)
	_rr(full.grow(-6), Color(0, 0, 0, 0), 5, Color(ink.r, ink.g, ink.b, 0.25), 1)
	# faixa do nome
	_rr(Rect2(8, 8, W - 16, 38), ink if not dim else ink.lightened(0.12), 5)
	var nm: String = Knowledge.CARDS[id]["name"] if Knowledge.CARDS.has(id) else ""
	var name_col := Ink.CREAM if not dim else Ink.CREAM.darkened(0.3)
	var lines := _wrap(nm, f, 12, W - 22)
	var ty := 8 + 19 - (lines.size() - 1) * 6.5 + 4.5
	for line in lines:
		draw_string(f, Vector2(8, ty), line, HORIZONTAL_ALIGNMENT_CENTER, W - 16, 12, name_col)
		ty += 13.0
	# janela da ilustração: sem arte ainda, vai a inicial
	var art := Rect2(11, 52, W - 22, 64)
	_rr(art, col if not dim else col.darkened(0.5), 6, ink, 2)
	draw_string(Ink.font(0.0, 1.0), Vector2(art.position.x, art.position.y + 46), nm.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, art.size.x, 40, ink if not dim else ink.lightened(0.2))
	# rodapé: preço ou naipes
	if price_tag != "":
		_rr(Rect2(10, H - 31, W - 20, 22), ink, 5)
		draw_string(f, Vector2(10, H - 15), price_tag, HORIZONTAL_ALIGNMENT_CENTER, W - 20, 12, Ink.CREAM)
	else:
		for k in 3:
			var pc := Vector2(W * 0.5 + (k - 1) * 19.0, H - 20)
			var r := 5.5
			draw_colored_polygon(PackedVector2Array([pc + Vector2(0, -r), pc + Vector2(r, 0), pc + Vector2(0, r), pc + Vector2(-r, 0)]), col.darkened(0.15) if not dim else col.darkened(0.5))


func _wrap(t: String, f: Font, px: int, max_w: float) -> Array:
	var words := t.split(" ")
	var lines: Array = []
	var cur := ""
	for w in words:
		var cand := w if cur == "" else cur + " " + w
		if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = cand
	if cur != "":
		lines.append(cur)
	return lines
