extends Control
## Uma peça exposta na loja (kit de papel): a carta pendurada no varal por um pregador (balcão de
## cartas) ou em pé na prateleira (balcão de itens), com a etiqueta de preço inclinada e o carimbo
## de VENDIDA quando já foi comprada. Quem monta e posiciona é a shop_screen.gd.
##   var it := ShopItem.new(); it.setup(id, "cards", 1.4, -2.5); it.home = Vector2(...)

signal picked
signal hovered

const TICKET := Color("9e5cff")
const TICKET_LIGHT := Color("c9a2ff")

var id := ""
## "cards" pendura (pregador em cima) · "gear" fica em pé (etiqueta pendurada na prateleira)
var style := "cards"
var k := 1.0
var tilt := 0.0
var home := Vector2.ZERO
var price_text := ""
var ticket := false
var afford := true: set = _set_afford
var sold := false: set = _set_sold
var sold_text := "VENDIDA"
var selected := false: set = _set_selected
var hot := false

var card: CardView
var _over: Control
var _rot := 0.0
var _t := 0.0
var _stamp := 1.0
var _tw: Tween


func setup(card_id: String, item_style: String, card_scale: float, tilt_deg: float) -> void:
	id = card_id
	style = item_style
	k = card_scale
	tilt = tilt_deg
	_rot = tilt_deg
	size = Vector2(CardView.W, CardView.H) * k
	pivot_offset = Vector2(size.x * 0.5, 0.0 if style == "cards" else size.y)
	# PASS: o clique é da peça, mas a roda do mouse segue pra tela virar a página
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card = CardView.make(id)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = (size - Vector2(CardView.W, CardView.H)) * 0.5
	card.scale = Vector2.ONE * k
	add_child(card)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.size = size
	_over.draw.connect(_draw_over)
	add_child(_over)
	_t = float(hash(id) % 628) / 100.0
	rotation_degrees = _rot
	mouse_entered.connect(func():
		hot = true
		settle()
		hovered.emit())
	mouse_exited.connect(func():
		hot = false
		settle())
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			picked.emit())


func _set_afford(v: bool) -> void:
	afford = v
	if _over != null:
		_over.queue_redraw()


func _set_sold(v: bool) -> void:
	sold = v
	if card != null:
		card.state = "dim" if v else "face"
	if _over != null:
		_over.queue_redraw()


func _set_selected(v: bool) -> void:
	if selected == v:
		return
	selected = v
	if card != null:
		card.selected = v
	settle()


## Volta pro lugar: a escolhida endireita, cresce um pouco e sobe; as outras ficam tortas.
func settle() -> void:
	if not is_inside_tree():
		return
	if _tw != null:
		_tw.kill()
	var sc := 1.07 if selected else (1.04 if hot else 1.0)
	var lift := Vector2(0, -6.0 if (selected and style == "gear") else 0.0)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "_rot", 0.0 if selected else tilt, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE * sc, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", home + lift, 0.16)
	z_index = 1 if (selected or hot) else 0


## O carimbo bate na carta (acabou de ser vendida).
func slam() -> void:
	_stamp = 2.4
	var tw := create_tween()
	tw.tween_property(self, "_stamp", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	# no varal a carta balança de leve; na prateleira fica parada
	var sway := sin(_t * 1.3) * 0.9 if (style == "cards" and not selected) else 0.0
	rotation_degrees = _rot + sway
	if _stamp != 1.0:
		_over.queue_redraw()


func _draw_over() -> void:
	var w := size.x
	var h := size.y
	var ink := Paper.INK
	if style == "cards":
		# dois pregadores de madeira mordendo os cantos de cima (o nome da carta fica livre)
		for fx in [0.17, 0.83]:
			var px0: float = w * fx
			var pin := Rect2(px0 - 6.5, -20.0, 13.0, 34.0)
			_over.draw_rect(pin.grow(3.0), ink)
			_over.draw_rect(pin, Paper.CREAM2)
			_over.draw_line(Vector2(px0, pin.position.y + 3.0), Vector2(px0, pin.end.y - 3.0), Paper.BROWN, 2.0)
			_over.draw_rect(Rect2(pin.position.x - 2.0, -9.0, 17.0, 5.0), ink)
	if sold:
		var f := Paper.display(0.0)
		var px := int(round(17.0 * clampf(k, 1.0, 1.5)))
		var tw := f.get_string_size(sold_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var plate := Vector2(tw + 22.0, px + 16.0)
		_over.draw_set_transform(Vector2(w, h) * 0.5, deg_to_rad(-14.0), Vector2.ONE * _stamp)
		var r := Rect2(-plate * 0.5, plate)
		_over.draw_rect(Rect2(r.position + Vector2(4, 5), r.size), ink)
		_over.draw_rect(r, Paper.CREAM)
		_over.draw_rect(r.grow(-2.0), Paper.RED, false, 4.0)
		_over.draw_string(f, Vector2(r.position.x, r.position.y + plate.y * 0.5 + px * 0.36), sold_text, HORIZONTAL_ALIGNMENT_CENTER, plate.x, px, Paper.RED)
		_over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# etiqueta de preço: papel inclinado, pendurado por um fio
	var fd := Paper.display(0.0)
	var tk := clampf(k, 1.0, 1.35)
	var px := int(round(15.0 * tk))
	var icon := 9.0 * tk
	var tw := fd.get_string_size(price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var iw := icon * (2.6 if ticket else 2.0)
	var tag := Vector2(tw + iw + 28.0, px + 13.0)
	var top := h + (10.0 if style == "cards" else 14.0)
	_over.draw_line(Vector2(w * 0.5, h - 2.0), Vector2(w * 0.5, top + 4.0), ink, 3.0)
	var fill := Paper.GOLD
	var fg := ink
	if not afford:
		fill = Paper.CREAM2
		fg = Paper.RED
	elif ticket:
		fill = TICKET
		fg = Paper.CREAM
	_over.draw_set_transform(Vector2(w * 0.5, top), deg_to_rad(-5.0), Vector2.ONE)
	var pts := Paper.moved(Paper.skew_rect(tag, 12.0), Vector2(-tag.x * 0.5, 0))
	_over.draw_colored_polygon(Paper.moved(pts, Vector2(-4, 5)), ink)
	_over.draw_colored_polygon(pts, ink)
	_over.draw_colored_polygon(Paper.inset(pts, 3.0), fill)
	var x := -tag.x * 0.5 + 11.0
	var c := Vector2(x + iw * 0.5, tag.y * 0.5)
	if ticket:
		draw_ticket(_over, c, icon)
	else:
		draw_coin(_over, c, icon)
	_over.draw_string(fd, Vector2(x + iw + 6.0, tag.y * 0.5 + px * 0.36), price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)
	_over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Moeda do kit de papel: disco dourado com contorno INK, centrado em `c`.
static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Paper.INK)
	ci.draw_circle(c, r - maxf(2.0, r * 0.2), Paper.GOLD)
	ci.draw_circle(c, r * 0.48, Color("c9871a"))
	ci.draw_rect(Rect2(c.x - r * 0.1, c.y - r * 0.3, r * 0.2, r * 0.6), Paper.GOLD_HOVER)


## Ticket roxo (o que o ranking SSS dá), centrado em `c`.
static func draw_ticket(ci: CanvasItem, c: Vector2, r: float) -> void:
	var b := maxf(2.0, r * 0.2)
	var box := Rect2(c.x - r, c.y - r * 0.62, r * 2.0, r * 1.24)
	ci.draw_rect(box.grow(b), Paper.INK)
	ci.draw_rect(box, TICKET_LIGHT)
	ci.draw_circle(Vector2(box.position.x, c.y), r * 0.26, Paper.INK)
	ci.draw_circle(Vector2(box.end.x, c.y), r * 0.26, Paper.INK)
	var d := r * 0.36
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Paper.INK)
