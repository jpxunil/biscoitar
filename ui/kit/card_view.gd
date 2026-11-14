class_name CardView
extends Control
## Uma carta em pé, desenhada a partir do id em Knowledge.CARDS.
## Layout (design/tela-cartas-v2, prancha "Carta"): faixa do nome em cima, janela da ilustração
## (sem arte ainda: duas faixas diagonais e o naipe da categoria) e rodapé com naipes ou preço.
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
## Moldura dourada da carta em foco. `halo_grow` faz ela pulsar (0 = parada).
var halo := false: set = _set_halo
var halo_grow := 0.0: set = _set_halo_grow
## Contorno solto em volta da carta (slot válido no arrasto, carta selecionada). Alfa 0 = sem contorno.
var ring := Color(0, 0, 0, 0): set = _set_ring
var ring_gap := 4.0: set = _set_ring_gap
var ring_w := 4.0
## Rosto pequeno no canto: quem está com esta carta de cópia única agora (item ou carta da loja).
var badge: Texture2D: set = _set_badge
## Carta nova que o jogador ainda não viu: selo NOVO no canto e contorno dourado pulsando.
var fresh := false: set = _set_fresh
## Carta de APRENDIZADO: o quanto o herói já aprendeu dela (0..100). Desenha uma barrinha no pé da
## carta. -1 = não mostra. `tag` é uma etiqueta pequena no topo ("CRITÉRIO", "PASSIVA"...).
var learn := -1.0: set = _set_learn
var tag := "": set = _set_tag
var _fresh_t := 0.0


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
	set_process(false)
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W, H) * 0.5


func _set_fresh(v: bool) -> void:
	fresh = v
	set_process(v)
	queue_redraw()


func _process(delta: float) -> void:
	_fresh_t += delta
	queue_redraw()


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


func _set_learn(v: float) -> void:
	learn = v
	queue_redraw()


func _set_tag(v: String) -> void:
	tag = v
	queue_redraw()


func _set_progress(v: int) -> void:
	progress = v
	queue_redraw()


func _set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _set_halo(v: bool) -> void:
	halo = v
	queue_redraw()


func _set_halo_grow(v: float) -> void:
	halo_grow = v
	if halo:
		queue_redraw()


func _set_badge(v: Texture2D) -> void:
	badge = v
	queue_redraw()


func _set_ring(v: Color) -> void:
	ring = v
	queue_redraw()


func _set_ring_gap(v: float) -> void:
	ring_gap = v
	if ring.a > 0.0:
		queue_redraw()


func _rr(rect: Rect2, col: Color, radius: float, border := Color(0, 0, 0, 0), bw := 0, center := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.draw_center = center
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	draw_style_box(sb, rect)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


## Faixa diagonal do placeholder: um retângulo girado -24 graus, recortado na janela.
func _stripe(win: Rect2, top: float, thick: float, col: Color) -> void:
	var c := win.position + Vector2(50, top + thick * 0.5)
	var band := PackedVector2Array()
	for p in [Vector2(-70, -thick * 0.5), Vector2(70, -thick * 0.5), Vector2(70, thick * 0.5), Vector2(-70, thick * 0.5)]:
		band.append(c + p.rotated(deg_to_rad(-24.0)))
	var box := PackedVector2Array([win.position, Vector2(win.end.x, win.position.y), win.end, Vector2(win.position.x, win.end.y)])
	for piece in Geometry2D.intersect_polygons(band, box):
		draw_colored_polygon(piece, col)


func _draw() -> void:
	var k: Dictionary = Paper.KIND.get(kind, Paper.KIND["white"])
	var ink := Paper.INK
	var full := Rect2(Vector2.ZERO, Vector2(W, H))
	if ring.a > 0.0:
		_rr(full.grow(ring_gap + ring_w), Color(0, 0, 0, 0), 12, ring, int(ring_w), false)
	if state == "empty":
		_rr(full, k["eb"], 9, k["bg"], 3)
		Paper.draw_suit(self, "special", Vector2(34, 56), 40, k["eg"])
		return
	if halo or selected:
		_rr(full.grow(7.0 + halo_grow), Paper.GOLD, 14, ink, 3)
	# sombra dura, como carta apoiada
	_rr(Rect2(Vector2(4, 5), Vector2(W, H)), ink, 9)
	if state == "back":
		_rr(full, Paper.NAVY, 9, ink, 3)
		_rr(Rect2(9, 9, 90, 134), Color(0, 0, 0, 0), 5, k["bg"], 3, false)
		draw_string(Paper.display(0.0), Vector2(3, 78), "?", HORIZONTAL_ALIGNMENT_CENTER, 102, 58, Paper.CREAM)
		if progress >= 0:
			# maestria: um losango por acerto, cheio quando já foi feito
			for n in Knowledge.MASTERY_NEED:
				var pc := Vector2(W * 0.5 + (n - (Knowledge.MASTERY_NEED - 1) * 0.5) * 21.0, 114)
				_diamond(pc, 10.0, Paper.CREAM)
				_diamond(pc, 5.8, Paper.GOLD if n < progress else Paper.NAVY)
		return

	_rr(full, k["bg"], 9, ink, 3)
	# faixa do nome
	var band := StyleBoxFlat.new()
	band.bg_color = ink
	band.corner_radius_top_left = 6
	band.corner_radius_top_right = 6
	draw_style_box(band, Rect2(3, 3, W - 6, 28))
	var nm: String = Knowledge.CARDS[id]["name"] if Knowledge.CARDS.has(id) else ""
	var f := Paper.body(800)
	var px := 10 if nm.length() > 13 else 12
	var lines := _wrap(nm, f, px, W - 14)
	var ty := 17.0 - (lines.size() - 1) * 5.5 + px * 0.36
	for line in lines:
		draw_string(f, Vector2(3, ty), line, HORIZONTAL_ALIGNMENT_CENTER, W - 6, px, Paper.CREAM)
		ty += 11.0
	# janela da ilustração: faixas diagonais no tom da raridade + naipe da categoria
	var win := Rect2(9, 37, 90, 78)
	draw_rect(win, k["art"])
	var inner := win.grow(-2)
	_stripe(inner, 14, 14, k["st"])
	_stripe(inner, 46, 8, k["st"])
	var cat: String = Knowledge.CARDS[id]["cat"] if Knowledge.CARDS.has(id) else "special"
	Paper.draw_suit(self, cat, Vector2(32, 53), 46, ink)
	draw_rect(win.grow(-1), ink, false, 2.0)
	# rodapé: preço ou três naipes
	if price_tag != "":
		var fd := Paper.display(0.0)
		var tw := fd.get_string_size(price_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var coin := price_tag.is_valid_int()
		var x := (W - tw - (18.0 if coin else 0.0)) * 0.5
		if coin:
			draw_circle(Vector2(x + 6.5, 131), 6.5, ink)
			draw_circle(Vector2(x + 6.5, 131), 3.5, Paper.CREAM)
			x += 18.0
		draw_string(fd, Vector2(x, 136), price_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	else:
		Paper.draw_suit(self, cat, Vector2(30.5, 126), 10, ink)
		Paper.draw_suit(self, cat, Vector2(46.5, 123.5), 15, ink)
		Paper.draw_suit(self, cat, Vector2(67.5, 126), 10, ink)
	if state == "dim":
		_rr(full, Color(ink.r, ink.g, ink.b, 0.6), 9)
	if badge != null:
		draw_rect(Rect2(W - 24, -12, 32, 41), ink)
		draw_texture_rect(badge, Rect2(W - 21, -9, 26, 35), false)
	if learn >= 0.0 and state != "back" and state != "empty":
		# barra de aprendizado: enche até virar passiva
		var bar := Rect2(8, H - 17, W - 16, 9)
		draw_rect(bar.grow(2), Paper.INK)
		draw_rect(bar, Color(0.16, 0.17, 0.3))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(learn / 100.0, 0.0, 1.0), bar.size.y)), Paper.GOLD)
		draw_string(Paper.body(800), Vector2(bar.position.x, bar.position.y + 8), "%d%%" % roundi(learn), HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 9, Paper.CREAM if learn < 55.0 else Paper.INK)
	if tag != "" and state != "empty":
		var fd := Paper.display()
		var tw := fd.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
		var tr := Rect2(W - tw + 4, 30, tw, 14)
		draw_rect(tr.grow(2), Paper.INK)
		draw_rect(tr, Paper.PINK if tag == "CRITÉRIO" else Paper.GOLD)
		draw_string(fd, Vector2(tr.position.x + 5, tr.position.y + 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Paper.CREAM if tag == "CRITÉRIO" else Paper.INK)
	if fresh:
		_draw_fresh()


## Selo NOVO do kit de papel: contorno dourado respirando e uma etiqueta rosa inclinada, com sombra
## dura, pendurada no canto de cima.
func _draw_fresh() -> void:
	var p := 0.5 + 0.5 * sin(_fresh_t * 5.0)
	_rr(Rect2(Vector2.ZERO, Vector2(W, H)).grow(4.0 + 3.0 * p), Color(0, 0, 0, 0), 13, Color(Paper.GOLD.r, Paper.GOLD.g, Paper.GOLD.b, 0.55 + 0.45 * p), 4, false)
	var f := Paper.display()
	var tw := f.get_string_size("NOVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var tag := Vector2(tw + 18.0, 24.0)
	draw_set_transform(Vector2(-12.0, -10.0 - 2.0 * p), deg_to_rad(-8.0), Vector2.ONE * (1.0 + 0.06 * p))
	var pts := Paper.skew_rect(tag, 10.0)
	draw_colored_polygon(Paper.moved(pts, Vector2(-3, 4)), Paper.INK)
	draw_colored_polygon(pts, Paper.INK)
	draw_colored_polygon(Paper.inset(pts, 3.0), Paper.PINK)
	draw_string(f, Vector2(0, 17.5), "NOVO", HORIZONTAL_ALIGNMENT_CENTER, tag.x, 13, Paper.CREAM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
