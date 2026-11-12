extends Control
## Menu de cartas, antes da luta. Uma coluna por personagem:
## 1 roxa, 2 amarelas, 3 brancas (programáveis, na ordem de prioridade).
##
## Leitura visual: carta equipada = cor cheia · slot vazio = só contorno na cor do tipo.

signal fight_pressed

const COL_W := 276
const BG := Color(0.11, 0.1, 0.22)
const SLOT_BG := Color(0.09, 0.09, 0.19)

var g
var columns: HBoxContainer
var _animate_next := false
var _pulse := ""


func setup(game) -> void:
	g = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	add_child(bg)
	# faixas diagonais bem discretas: dão direção ao fundo sem competir com as cartas
	for band in [[820.0, 300.0, 0.035], [1020.0, 120.0, 0.05]]:
		var p := Panel.new()
		p.position = Vector2(band[0], -40)
		p.size = Vector2(band[1], 800)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", UiStyle.box(Color(1, 1, 1, band[2]), 0.45))
		add_child(p)

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
	var title := UiStyle.slab(UiStyle.PAPER, UiStyle.SKEW, 30, 4)
	title.add_child(UiStyle.text("CARTAS", 30, UiStyle.INK))
	head.add_child(title)
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
			_style_button(tab, UiStyle.BOSS, UiStyle.INK, UiStyle.SKEW)
		else:
			_style_button(tab, UiStyle.INK, UiStyle.BOSS, UiStyle.SKEW, UiStyle.INK_SOFT)
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
	_style_button(fight, UiStyle.PAPER, UiStyle.INK, UiStyle.SKEW, Color.WHITE)
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
			["K", "skill"], ["L", "especial"], ["U", "biscoitar"], ["I", "limit"], ["Q", "reunir"], ["E", "espalhar"], ["R", "manter"], ["F", "atacar livre"]]:
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
	_animate_next = false
	_pulse = ""


# ---------------------------------------------------------------- coluna

func _column(i: int) -> Control:
	var u: Unit = g.units[i]
	var d: Dictionary = Knowledge.deck(i)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = COL_W
	col.add_theme_constant_override("separation", 6)
	col.add_child(_hero_header(i, u))

	var gap := Control.new()
	gap.custom_minimum_size.y = 5
	col.add_child(gap)

	# --- roxa
	var pb: Button
	if d["purple"]:
		pb = _slot(Knowledge.PURPLE_NAME.to_upper(), UiStyle.PURPLE, true, true, 50, 17)
	elif not Knowledge.purple_known:
		pb = _slot("?", UiStyle.PURPLE, false, false, 50, 17)
	else:
		pb = _slot(Knowledge.PURPLE_NAME, UiStyle.PURPLE, false, Knowledge.purple_left() > 0, 50, 17)
	pb.pressed.connect(func():
		Knowledge.toggle_purple(i)
		_pulse = "p%d" % i
		refresh())
	_maybe_pulse(pb, "p%d" % i)
	col.add_child(pb)

	# --- amarelas: todas as cartas aparecem; só YELLOW_SLOTS podem ficar equipadas
	var equipped: int = d["yellow"].size()
	var mine_yellow: Array = Knowledge.yellow_for(g.UNIT_DEFS[i]["key"])
	for id in mine_yellow:
		var yb: Button
		var key := "y%d_%s" % [i, id]
		if not Knowledge.yellow_known.has(id):
			yb = _slot("?", UiStyle.YELLOW, false, false, 40, 15)
		else:
			var on := Knowledge.has_yellow(i, id)
			var label: String = Knowledge.YELLOW[id]
			# sem slot livre, as que sobram ficam apagadas: o limite aparece sem precisar de texto
			yb = _slot(label.to_upper() if on else label, UiStyle.YELLOW, on, on or equipped < Knowledge.YELLOW_SLOTS, 40, 15)
			yb.pressed.connect(func():
				Knowledge.toggle_yellow(i, id)
				_pulse = key
				refresh())
			_maybe_pulse(yb, key)
		col.add_child(yb)
	for n in maxi(0, Knowledge.YELLOW_SLOTS - mine_yellow.size()):
		col.add_child(_slot("", UiStyle.YELLOW, false, false, 40, 15))

	# --- brancas
	for slot in Knowledge.WHITE_SLOTS:
		var card := _white_card(i, slot, d["white"][slot])
		_maybe_pulse(card, "w%d_%d" % [i, slot])
		col.add_child(card)
	return col


## Faixa do herói: rosto recortado na inclinação + nome, na cor da classe.
func _hero_header(i: int, u: Unit) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(COL_W, 60)
	# clicar na faixa escolhe com quem você começa a luta
	var mine := Knowledge.start_hero == i
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not mine:
			g.select_hero(i)
			refresh())
	if mine:
		# moldura clara = "este é você"; os outros ficam um tom abaixo
		var frame := Panel.new()
		frame.position = Vector2(-5, -5)
		frame.size = Vector2(COL_W + 10, 70)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PAPER, UiStyle.SKEW))
		c.add_child(frame)
	else:
		c.modulate = Color(0.72, 0.72, 0.78)
	var slab := Panel.new()
	slab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_theme_stylebox_override("panel", UiStyle.box(u.color, UiStyle.SKEW))
	c.add_child(slab)

	var face := TextureRect.new()
	face.texture = load("res://assets/portraits/%s_face.png" % g.UNIT_DEFS[i]["key"])
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(-7, 0)
	face.size = Vector2(88, 60)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ui/skew_clip.gdshader")
	mat.set_shader_parameter("rect_size", face.size)
	mat.set_shader_parameter("slab_width", 74.0)
	mat.set_shader_parameter("skew", UiStyle.SKEW)
	face.material = mat
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(face)

	var name_l := UiStyle.text(u.unit_name.to_upper(), 23, UiStyle.INK)
	name_l.position = Vector2(92, 0)
	name_l.size = Vector2(COL_W - 100, 60)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(name_l)
	return c


## Slot de carta pronta (roxa/amarela). Cheio = equipada; contorno = vazio ou disponível.
func _slot(text: String, col: Color, filled: bool, enabled: bool, height: int, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.custom_minimum_size.y = height
	b.add_theme_font_size_override("font_size", font)
	if filled:
		_style_button(b, col, UiStyle.INK, 0.0, col.lightened(0.18))
	else:
		var edge := col if enabled else col.darkened(0.3)
		_style_button(b, SLOT_BG, edge, 0.0, SLOT_BG.lightened(0.08), edge)
	return b


func _white_card(i: int, slot: int, w: Dictionary) -> Control:
	var filled: bool = w["t"] != "" and w["a"] != ""
	var card := PanelContainer.new()
	var sb := UiStyle.box(UiStyle.PAPER if filled else SLOT_BG, 0.0, 8, 8)
	if not filled:
		sb.border_color = UiStyle.PAPER.darkened(0.62)
		sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	# a ordem das brancas é a prioridade, então o número faz parte da carta
	var num := UiStyle.text(str(slot + 1), 24, UiStyle.INK if filled else UiStyle.PAPER.darkened(0.5))
	num.custom_minimum_size.x = 16
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)

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
	l.custom_minimum_size.x = 50
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


func _style_button(b: Button, bg: Color, fg: Color, skew := 0.0, hover_bg := Color(-1, 0, 0), border := Color(-1, 0, 0)) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := bg
		if hover_bg.r >= 0.0 and (state == "hover" or state == "pressed"):
			col = hover_bg
		var sb := UiStyle.box(col, skew, 8, 4)
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
