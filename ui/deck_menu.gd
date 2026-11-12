extends Control
## Menu de cartas, antes da luta. Uma coluna por personagem:
## 1 roxa, 4 amarelas, 3 brancas (programáveis, na ordem de prioridade).
##
## O menu é uma mesa de cartas: cada herói tem a sua raia, com as cartas em cascata
## (como numa paciência, só a faixa do título de cada uma aparece).
## Leitura visual: carta equipada = virada pra cima (clara) e puxada pra fora da pilha ·
## carta disponível = escura com contorno na cor do tipo · carta desconhecida = verso com "?".

signal fight_pressed

const COL_W := 276
const BG := Color(0.085, 0.08, 0.17)
const SLOT_BG := Color(0.1, 0.1, 0.21)
## Cascata: quanto de cada carta aparece, altura real dela e quanto a equipada sai da pilha.
const STRIP := 34
const CARD_H := 44
const PULL := 12
const RADIUS := 7

var g
var columns: HBoxContainer
var _animate_next := false
var _pulse := ""


func setup(game) -> void:
	g = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# descrição das cartas ao passar o mouse: mesma placa escura do resto da UI
	var th := Theme.new()
	var tip := UiStyle.box(UiStyle.INK, 0.0, 12, 8)
	tip.border_color = UiStyle.PAPER
	tip.set_border_width_all(2)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", UiStyle.PAPER)
	th.set_font_size("font_size", "TooltipLabel", 15)
	theme = th

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	add_child(bg)
	# o pano da mesa: uma área mais clara no meio, com uma linha fina de costura
	var felt := Panel.new()
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	felt.offset_left = 30
	felt.offset_right = -30
	felt.offset_top = 80
	felt.offset_bottom = -48
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := UiStyle.box(Color(0.115, 0.11, 0.235))
	fsb.set_corner_radius_all(18)
	fsb.border_color = Color(1, 1, 1, 0.07)
	fsb.set_border_width_all(2)
	felt.add_theme_stylebox_override("panel", fsb)
	add_child(felt)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 58)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	# --- cabeçalho
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	head.add_child(_title_deck())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	# abas dos bosses: a cheia é a luta atual
	for bi in g.BOSSES.size():
		var tab := Button.new()
		tab.text = g.BOSSES[bi]["name"]
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(0, 50)
		tab.add_theme_font_size_override("font_size", 17)
		if bi == Knowledge.boss:
			_style_button(tab, UiStyle.BOSS, UiStyle.INK, 0.0, Color(-1, 0, 0), UiStyle.BOSS.lightened(0.3), RADIUS)
		else:
			_style_button(tab, UiStyle.INK, UiStyle.BOSS, 0.0, UiStyle.INK_SOFT, UiStyle.BOSS.darkened(0.45), RADIUS)
			tab.pressed.connect(g.select_boss.bind(bi))
		for st in ["normal", "hover", "pressed"]:
			var tsb := tab.get_theme_stylebox(st) as StyleBoxFlat
			tsb.content_margin_left = 22
			tsb.content_margin_right = 22
		head.add_child(tab)
	var gap2 := Control.new()
	gap2.custom_minimum_size.x = 10
	head.add_child(gap2)
	var fight := Button.new()
	fight.text = "LUTAR"
	fight.focus_mode = Control.FOCUS_NONE
	fight.custom_minimum_size = Vector2(200, 50)
	fight.add_theme_font_size_override("font_size", 24)
	_style_button(fight, UiStyle.PAPER, UiStyle.INK, 0.0, Color.WHITE, UiStyle.INK, RADIUS)
	fight.pressed.connect(func(): fight_pressed.emit())
	head.add_child(fight)

	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(columns)

	# --- controles, como teclas
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 7)
	keys.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(keys)
	for pair in [["WASD", "mover"], ["J", "atacar"], ["ESPAÇO", "esquiva"], ["1-4", "trocar"], ["F1-F4", "alvo"],
			["K", "skill"], ["L", "especial"], ["U / O", "extra"], ["I", "limit"], ["Q", "reunir"], ["E", "espalhar"], ["R", "manter"], ["F", "atacar livre"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var key := UiStyle.slab(UiStyle.INK_SOFT, 0.0, 8, 2)
		key.add_child(UiStyle.text(pair[0], 12, UiStyle.PAPER))
		row.add_child(key)
		row.add_child(UiStyle.text(pair[1], 13, UiStyle.DIM))
		keys.add_child(row)


## Chamado ao abrir o menu: as colunas entram em sequência.
func open() -> void:
	_animate_next = true
	refresh()


func refresh() -> void:
	for c in columns.get_children():
		columns.remove_child(c)
		c.queue_free()
	for i in 4:
		var col := _column(i)
		columns.add_child(col)
		if _animate_next:
			col.modulate.a = 0.0
			var tw := col.create_tween()
			tw.tween_property(col, "modulate:a", 1.0, 0.22).set_delay(0.05 + i * 0.07)
			# as cartas são "dadas" na mesa: cada uma cai no lugar, uma depois da outra
			var n := 0
			for card in col.find_children("Card*", "Control", true, false):
				var home: float = card.position.y
				card.position.y = home - 26.0
				var ct := card.create_tween()
				ct.tween_property(card, "position:y", home, 0.2).set_delay(0.08 + i * 0.07 + n * 0.035) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				n += 1
	_animate_next = false
	_pulse = ""


# ---------------------------------------------------------------- coluna

func _column(i: int) -> Control:
	var u: Unit = g.units[i]
	var d: Dictionary = Knowledge.deck(i)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = COL_W
	# sem espaço automático: as cartas da cascata encostam, e os vãos são explícitos
	col.add_theme_constant_override("separation", 0)
	col.add_child(_hero_header(i, u))
	col.add_child(_spacer(12))

	# --- roxas: uma pilha em cascata
	var seat_n := 0
	for pid in Knowledge.PURPLE_ORDER:
		var pb: Button
		var known: bool = Knowledge.purple_known if pid == "mark" else Knowledge.dps_known.has(u["key"])
		var pname: String = Knowledge.PURPLE[pid]
		var p_on: bool = d["purple"] == pid
		if p_on:
			pb = _slot(pname.to_upper(), UiStyle.PURPLE, "on", true)
		elif not known:
			pb = _slot("?", UiStyle.PURPLE, "back", false)
		else:
			pb = _slot(pname, UiStyle.PURPLE, "off", Knowledge.purple_can(i, pid, u["key"]))
		if known:
			pb.tooltip_text = Knowledge.PURPLE_DESC[pid]
		var tag := "p%d%s" % [i, pid]
		pb.pressed.connect(func():
			Knowledge.toggle_purple(i, pid, u["key"])
			_pulse = tag
			refresh())
		_maybe_pulse(pb, tag)
		_seat(col, pb, seat_n, p_on)
		seat_n += 1
	col.add_child(_spacer(CARD_H - STRIP + 8))

	# --- amarelas: todas as cartas aparecem; só YELLOW_SLOTS podem ficar equipadas
	var equipped: int = d["yellow"].size()
	var mine_yellow: Array = Knowledge.yellow_for(g.UNIT_DEFS[i]["key"])
	for id in mine_yellow:
		var yb: Button
		var key := "y%d_%s" % [i, id]
		var y_on := false
		if not Knowledge.yellow_known.has(id):
			yb = _slot("?", UiStyle.YELLOW, "back", false)
		else:
			y_on = Knowledge.has_yellow(i, id)
			var label: String = Knowledge.YELLOW[id]
			# sem slot livre, as que sobram ficam apagadas: o limite aparece sem precisar de texto
			yb = _slot(label.to_upper() if y_on else label, UiStyle.YELLOW, "on" if y_on else "off", y_on or equipped < Knowledge.YELLOW_SLOTS)
			yb.tooltip_text = Knowledge.YELLOW_DESC.get(id, "")
			yb.pressed.connect(func():
				Knowledge.toggle_yellow(i, id)
				_pulse = key
				refresh())
			_maybe_pulse(yb, key)
		_seat(col, yb, seat_n, y_on)
		seat_n += 1
	for n in maxi(0, Knowledge.YELLOW_SLOTS - mine_yellow.size()):
		_seat(col, _slot("", UiStyle.YELLOW, "empty", false), seat_n, false)
		seat_n += 1
	col.add_child(_spacer(CARD_H - STRIP + 12))

	# --- brancas
	for slot in Knowledge.WHITE_SLOTS:
		var card := _white_card(i, slot, d["white"][slot])
		_maybe_pulse(card, "w%d_%d" % [i, slot])
		col.add_child(card)
		col.add_child(_spacer(6))
	return col


## Carta do herói: retrato numa janela + nome, na cor da classe.
func _hero_header(i: int, u: Unit) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(COL_W, 60)
	# clicar na carta escolhe com quem você começa a luta
	var mine := Knowledge.start_hero == i
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not mine:
			g.select_hero(i)
			refresh())
	var card := Panel.new()
	card.name = "CardHero"
	card.position = Vector2(0, -4 if mine else 0)
	card.size = Vector2(COL_W, 60)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# borda clara e carta levantada = "este é você"; os outros ficam um tom abaixo
	var sb := _card_box(u.color, UiStyle.PAPER if mine else u.color.darkened(0.45), 9, 3)
	card.add_theme_stylebox_override("panel", sb)
	c.add_child(card)
	if not mine:
		c.modulate = Color(0.7, 0.7, 0.76)
	card.add_child(_inner_frame(Vector2(COL_W, 60), UiStyle.INK, 0.22, 6))

	# janela do retrato, como a ilustração de uma carta
	var win := Panel.new()
	win.position = Vector2(8, 7)
	win.size = Vector2(46, 46)
	win.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wsb := UiStyle.box(UiStyle.INK)
	wsb.set_corner_radius_all(6)
	win.add_theme_stylebox_override("panel", wsb)
	card.add_child(win)
	var face := TextureRect.new()
	face.texture = load("res://assets/portraits/%s_face.png" % g.UNIT_DEFS[i]["key"])
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(2, 2)
	face.size = Vector2(42, 42)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(face)

	var name_l := UiStyle.text(u.unit_name.to_upper(), 22, UiStyle.INK)
	name_l.position = Vector2(66, 0)
	name_l.size = Vector2(COL_W - 76, 60)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(name_l)
	return c


## Carta pronta (roxa/amarela). kind: "on" = equipada, virada pra cima · "off" = na pilha ·
## "back" = ainda não descoberta, de verso · "empty" = lugar vazio na mesa.
func _slot(text: String, col: Color, kind: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var edge := col if enabled or kind == "on" else col.darkened(0.35)
	match kind:
		"on":
			_style_card(b, UiStyle.PAPER, UiStyle.INK, col, Color.WHITE)
			b.add_child(_pip(col, true))
		"off":
			_style_card(b, SLOT_BG, edge, edge, SLOT_BG.lightened(0.09))
			b.add_child(_pip(edge, false))
		"back":
			_style_card(b, UiStyle.INK_SOFT, col.lightened(0.2), edge, UiStyle.INK_SOFT)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_child(_card_back(col))
		_:
			# lugar vazio: só a marca de onde uma carta caberia
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var sb := UiStyle.box(Color(0, 0, 0, 0.16))
				sb.set_corner_radius_all(RADIUS)
				sb.border_color = Color(col.r, col.g, col.b, 0.22)
				sb.set_border_width_all(1)
				b.add_theme_stylebox_override(state, sb)
	return b


## Coloca a carta na cascata da coluna: só STRIP pixels dela ficam à mostra, a próxima cobre o resto.
## A equipada sai da pilha pro lado e fica levemente torta, como carta puxada à mão.
func _seat(col: Control, card: Button, n: int, pulled: bool) -> void:
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(COL_W, STRIP)
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.name = "Card%d" % n
	card.position = Vector2(PULL if pulled else 0, 0)
	# lugar vazio não é carta: fica raso, sem entrar na cascata
	card.size = Vector2(COL_W - PULL, STRIP - 5 if card.text == "" else CARD_H)
	card.pivot_offset = card.size * 0.5
	if pulled:
		card.rotation_degrees = 0.7 if n % 2 == 0 else -0.7
	seat.add_child(card)
	col.add_child(seat)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Naipe no canto da carta: losango, cheio quando a carta está em jogo.
func _pip(col: Color, filled: bool) -> Control:
	var p := Panel.new()
	p.position = Vector2(14, 11)
	p.size = Vector2(12, 12)
	p.pivot_offset = Vector2(6, 6)
	p.rotation_degrees = 45
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyle.box(col if filled else Color(0, 0, 0, 0))
	sb.border_color = col
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Verso de carta: treliça de losangos na cor do tipo, bem apagada.
func _card_back(col: Color) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 5
	c.offset_right = -5
	c.offset_top = 5
	c.offset_bottom = -5
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := Color(col.r, col.g, col.b, 0.2)
	c.draw.connect(func():
		var w := c.size.x
		var h := c.size.y
		var x := -h
		while x < w:
			c.draw_line(Vector2(x, 0), Vector2(x + h, h), line, 1.0)
			c.draw_line(Vector2(x + h, 0), Vector2(x, h), line, 1.0)
			x += 12.0)
	return c


## Moldura interna fina: o detalhe que faz um retângulo parecer carta.
func _inner_frame(size_px: Vector2, col: Color, alpha: float, inset := 4) -> Control:
	var f := Panel.new()
	f.position = Vector2(inset, inset)
	f.size = size_px - Vector2(inset, inset) * 2.0
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyle.box(Color(0, 0, 0, 0))
	sb.set_corner_radius_all(maxi(2, RADIUS - inset + 1))
	sb.border_color = Color(col.r, col.g, col.b, alpha)
	sb.set_border_width_all(1)
	f.add_theme_stylebox_override("panel", sb)
	return f


## Título como um baralho: versos empilhados e a carta de cima virada com o nome.
func _title_deck() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(200, 50)
	for k in 3:
		var back := Panel.new()
		back.position = Vector2(6 + k * 5, 3 - k * 2)
		back.size = Vector2(170, 46)
		back.pivot_offset = back.size * 0.5
		back.rotation_degrees = [-5.0, 3.5, -1.5][k]
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_theme_stylebox_override("panel", _card_box(UiStyle.INK_SOFT, UiStyle.PURPLE.darkened(0.35), RADIUS, 2))
		c.add_child(back)
	var top := Panel.new()
	top.position = Vector2(12, 0)
	top.size = Vector2(172, 48)
	top.pivot_offset = top.size * 0.5
	top.rotation_degrees = -2.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _card_box(UiStyle.PAPER, UiStyle.INK, RADIUS, 2))
	c.add_child(top)
	top.add_child(_inner_frame(top.size, UiStyle.INK, 0.3))
	var t := UiStyle.text("CARTAS", 28, UiStyle.INK)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(t)
	return c


func _white_card(i: int, slot: int, w: Dictionary) -> Control:
	var filled: bool = w["t"] != "" and w["a"] != ""
	var card := PanelContainer.new()
	card.name = "White%d" % slot
	# preenchida = carta clara virada pra cima; em branco = carta escura esperando as peças
	var sb := _card_box(UiStyle.PAPER if filled else SLOT_BG, UiStyle.INK if filled else UiStyle.PAPER.darkened(0.6), 8, 2)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	# a ordem das brancas é a prioridade, então o número faz parte da carta
	# o número vai num selo redondo no canto, como o valor de uma carta
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(26, 26)
	seal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := UiStyle.box(UiStyle.INK if filled else Color(0, 0, 0, 0))
	ssb.set_corner_radius_all(13)
	ssb.border_color = UiStyle.INK if filled else UiStyle.PAPER.darkened(0.5)
	ssb.set_border_width_all(2)
	seal.add_theme_stylebox_override("panel", ssb)
	var num := UiStyle.text(str(slot + 1), 15, UiStyle.PAPER if filled else UiStyle.PAPER.darkened(0.4))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(num)
	row.add_child(seal)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(inner)
	var tag_col := UiStyle.INK if filled else UiStyle.DIM
	# o FAZ só lista o que combina com o QUANDO escolhido (e com a classe)
	var ukey: String = g.UNIT_DEFS[i]["key"]
	inner.add_child(_piece_row("QUANDO", tag_col, w["t"], Knowledge.triggers_for(ukey), Knowledge.TRIGGERS,
		Knowledge.triggers_known, func(id): _set_white(i, slot, id, w["a"])))
	inner.add_child(_piece_row("FAZ", tag_col, w["a"], Knowledge.actions_for(w["t"], ukey), Knowledge.ACTIONS,
		Knowledge.actions_known, func(id): _set_white(i, slot, w["t"], id)))
	return card


func _set_white(i: int, slot: int, t: String, a: String) -> void:
	# trocou o QUANDO e o FAZ antigo não combina mais: limpa
	if not Knowledge.actions_for(t, g.UNIT_DEFS[i]["key"]).has(a):
		a = ""
	Knowledge.set_white(i, slot, t, a)
	_pulse = "w%d_%d" % [i, slot]
	refresh.call_deferred()


func _piece_row(tag: String, tag_col: Color, current: String, order: Array, names: Dictionary,
		known: Dictionary, on_pick: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := UiStyle.text(tag, 10, tag_col)
	l.custom_minimum_size.x = 46
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)

	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.custom_minimum_size.y = 30
	ob.add_theme_font_size_override("font_size", 13)
	ob.fit_to_longest_item = false
	ob.clip_text = true
	var picked := current != ""
	_style_button(ob, UiStyle.INK, UiStyle.PAPER if picked else UiStyle.DIM, 0.0, UiStyle.INK_SOFT)
	var ids: Array = [""]
	ob.add_item("—")
	for id in order:
		if known.has(id):
			ob.add_item(names[id])
			ids.append(id)
	# peças ainda não descobertas aparecem trancadas, pra dar pra ver que existem
	var locked := order.size() - (ids.size() - 1)
	for n in locked:
		ob.add_item("???")
		ob.set_item_disabled(ob.item_count - 1, true)
	ob.select(maxi(0, ids.find(current)))
	ob.disabled = order.is_empty()
	ob.item_selected.connect(func(idx): on_pick.call(ids[idx]))
	_style_popup(ob.get_popup())
	row.add_child(ob)
	return row


# ---------------------------------------------------------------- estilo

func _maybe_pulse(node: Control, key: String) -> void:
	if _pulse != key:
		return
	# confirma o clique: a carta que mudou "acende" por um instante
	node.modulate.a = 0.35
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.18)


## Fundo de carta: cantos arredondados, borda e uma sombra curta de carta apoiada na mesa.
func _card_box(bg: Color, border: Color, radius := RADIUS, width := 2) -> StyleBoxFlat:
	var sb := UiStyle.box(bg)
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.anti_aliasing = true
	return sb


## Carta clicável da cascata: o título fica na faixa de cima, que é a parte que aparece.
func _style_card(b: Button, bg: Color, fg: Color, border: Color, hover_bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _card_box(hover_bg if state == "hover" or state == "pressed" else bg, border)
		sb.content_margin_left = 36
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		# o texto fica na faixa visível, não no meio da carta inteira
		sb.content_margin_bottom = CARD_H - STRIP + 3
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fg)


func _style_button(b: Button, bg: Color, fg: Color, skew := 0.0, hover_bg := Color(-1, 0, 0), border := Color(-1, 0, 0), radius := 0) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := bg
		if hover_bg.r >= 0.0 and (state == "hover" or state == "pressed"):
			col = hover_bg
		var sb := UiStyle.box(col, skew, 8, 4)
		if radius > 0:
			sb.set_corner_radius_all(radius)
			sb.anti_aliasing = true
		if border.r >= 0.0:
			sb.border_color = border
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fg)


func _style_popup(pm: PopupMenu) -> void:
	var panel := UiStyle.box(UiStyle.INK, 0.0, 4, 4)
	panel.border_color = UiStyle.PAPER
	panel.set_border_width_all(2)
	pm.add_theme_stylebox_override("panel", panel)
	pm.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.CYAN, 0.0, 6, 2))
	pm.add_theme_color_override("font_color", UiStyle.PAPER)
	pm.add_theme_color_override("font_hover_color", UiStyle.INK)
	pm.add_theme_color_override("font_disabled_color", UiStyle.DIM.darkened(0.45))
	pm.add_theme_font_size_override("font_size", 15)
	pm.add_theme_constant_override("v_separation", 10)
	for i in pm.item_count:
		pm.set_item_as_radio_checkable(i, false)
