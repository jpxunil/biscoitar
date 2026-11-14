class_name BossScreen
extends Control
## Escolha do boss, no kit Paper. À esquerda, uma lista inclinada com uma linha por luta de
## Knowledge.BOSS_INFO e, por último, o TREINO LIVRE (dummy que não morre; não dá recompensa nem mexe
## no save). À direita, um quadro só com o boss escolhido: emblema grande, nome, descrição, melhor
## ranking e a entrada pro painel "o que a party sabe". A cor do boss (HAIR) pinta a tela inteira.
## No topo, LOJA abre a loja do save, CARTAS o gear dele e GEAR os equipamentos.
##   W S / ↑ ↓ (ou A D / ← →) andam na lista · ENTER confirma · ESC volta.
## A lista aguenta mais bosses: as linhas encolhem e, se ainda assim não couber, ela rola.

## index = boss em Knowledge.BOSS_INFO, ou -1 pro treino livre.
signal boss_chosen(index: int)
signal back_pressed
## Abrir as cartas (gear) do save ativo, sem luta.
signal gear_pressed
## Abrir a loja do save ativo (só depois da primeira vitória).
signal shop_pressed
signal equip_pressed

const HAIR := [Color(0.86, 0.6, 0.3), Color(0.25, 0.8, 0.9), Color(1.0, 0.38, 0.66), Color(0.75, 0.45, 1.0), Color(0.4, 0.8, 1.0), Color(1.0, 0.8, 0.25)]
const STAGE := Vector2(1280, 720)
const NAVY2 := Color("2B3384")
const DEEP := Color("1A1E52")
const PURPLE := Color("5B2BB8")
const DIM := Color("B9BEEA")
const STRAW := Color(0.9, 0.75, 0.4)
## Inclinação das linhas e das etiquetas, em graus.
const LEAN := 12.0
const ROW_W := 430.0
## Janela da lista (o que passar disso rola).
const LIST_RECT := Rect2(0, 92, 690, 520)
const PRACTICE_BLURB := "Um dummy que não morre. Teste dano, combos e cartas à vontade."
## Lugar de cada botão no palco de 1280x720 (eles moram na raiz: testes e menus.gd os buscam pelo nome).
const HOMES := {"BtnShop": Vector2(812, 22), "BtnGear": Vector2(960, 22), "BtnEquip": Vector2(1116, 22), "NewCards": Vector2(1062, 6), "BtnBack": Vector2(44, 638), "BtnConfirm": Vector2(900, 614)}

var sel := 1
## Lugar do treino livre na seleção: logo depois do último boss.
var _practice_at := 0
var _last_boss := 1
var _stage: Control
var _back: Control
var _list: Control
var _detail: Control
var _rows: Array[Control] = []
var _row_h := 56.0
var _step_y := 66.0
var _hot := -1


func _ready() -> void:
	_practice_at = Knowledge.BOSS_INFO.size()
	_build_ui()
	if get_tree().current_scene == self:
		Knowledge.persist = false
		Knowledge.best_rank = {1: 6}
		open()


func open() -> void:
	sel = Knowledge.boss if Knowledge.boss_open(Knowledge.boss) else 1
	_last_boss = sel
	if Knowledge.practice:
		sel = _practice_at
	var any_new := false
	for h in Knowledge.fight_party():
		if Knowledge.has_new(h):
			any_new = true
	$NewCards.visible = any_new
	$BtnShop.disabled = not Knowledge.shop_unlocked
	$BtnShop.queue_redraw()
	close_info()
	_place_buttons()
	_build()


func _confirm() -> void:
	if sel == _practice_at:
		boss_chosen.emit(-1)
	elif Knowledge.boss_open(sel):
		boss_chosen.emit(sel)


## Cor da tela: a do boss escolhido (palha no treino).
func _accent() -> Color:
	return STRAW if sel >= _practice_at else HAIR[sel % HAIR.size()]


# ---------------------------------------------------------------- montagem

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): bg.draw_rect(Rect2(Vector2.ZERO, bg.size), Paper.NAVY))
	add_child(bg)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.anchor_left = 0.5
	_stage.anchor_right = 0.5
	_stage.anchor_top = 0.5
	_stage.anchor_bottom = 0.5
	_stage.offset_left = -STAGE.x * 0.5
	_stage.offset_right = STAGE.x * 0.5
	_stage.offset_top = -STAGE.y * 0.5
	_stage.offset_bottom = STAGE.y * 0.5
	add_child(_stage)
	_back = Control.new()
	_back.size = STAGE
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_back)
	_stage.add_child(_back)

	_detail = Control.new()
	_detail.size = STAGE
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_detail)

	var clip := Control.new()
	clip.position = LIST_RECT.position
	clip.size = LIST_RECT.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(clip)
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_list)

	var tag := CutPanel.make(Rect2(20, 14, 250, 66), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	_stage.add_child(tag)
	var title := Paper.label("BOSSES", 40, Paper.INK, Paper.display())
	title.size = Vector2(250, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.rotation = deg_to_rad(-2.0)
	title.pivot_offset = title.size * 0.5
	tag.add_child(title)

	# três botões pequenos no topo: a loja e as duas telas do herói (cartas e gear)
	var shop := _small("LOJA", PURPLE, Paper.CREAM)
	shop.name = "BtnShop"
	shop.size = Vector2(132, 46)
	shop.pressed.connect(func(): shop_pressed.emit())
	add_child(shop)
	var gear := _small("CARTAS", Paper.CREAM, Paper.INK)
	gear.name = "BtnGear"
	gear.size = Vector2(140, 46)
	gear.pressed.connect(func(): gear_pressed.emit())
	add_child(gear)
	var equip := _small("GEAR", Paper.GOLD, Paper.INK)
	equip.name = "BtnEquip"
	equip.size = Vector2(124, 46)
	equip.pressed.connect(func(): equip_pressed.emit())
	add_child(equip)
	# selo no botão CARTAS quando alguém da party tem carta nova pra ver
	var chip := Chip.new()
	chip.name = "NewCards"
	chip.px = 12
	chip.pad = 8.0
	chip.border = 3.0
	chip.shadow = Vector2(-3, 4)
	chip.fill = Paper.PINK
	chip.ink = Paper.CREAM
	chip.text = "NOVO"
	chip.rotation = deg_to_rad(8.0)
	chip.visible = false
	add_child(chip)

	var vb := _small("VOLTAR", Paper.CREAM, Paper.INK)
	vb.name = "BtnBack"
	vb.chevron = -1
	vb.chevron_px = 16
	vb.size = Vector2(160, 50)
	vb.pressed.connect(func(): back_pressed.emit())
	add_child(vb)
	var ok := ShineButton.new()
	ok.name = "BtnConfirm"
	ok.text = "CONFIRMAR"
	ok.shape = [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	ok.border = 6
	ok.font_px = 32
	ok.text_rot = -3
	ok.shadow = Vector2(10, 10)
	ok.fill = Paper.GOLD
	ok.fill_hover = Paper.GOLD_HOVER
	ok.fg_hover = Paper.RED
	ok.idle = true
	ok.hover_scale = 1.05
	ok.size = Vector2(332, 82)
	ok.pressed.connect(_confirm)
	add_child(ok)
	_place_buttons()
	resized.connect(_place_buttons)


## Põe os botões da raiz no lugar deles do palco, que fica centralizado na tela.
func _place_buttons() -> void:
	var off := (size - STAGE) * 0.5 if size.x > 0.0 else Vector2.ZERO
	for key in HOMES:
		var n := get_node_or_null(String(key)) as Control
		if n == null:
			continue
		var at: Vector2 = HOMES[key]
		n.position = at + off
		if n is ShineButton:
			n.set_home(n.position)


func _small(text: String, fill: Color, fg: Color) -> ShineButton:
	var b := ShineButton.new()
	b.text = text
	b.font_px = 18
	b.skew = LEAN
	b.border = 4
	b.shadow = Vector2(5, 5)
	b.fill = fill
	b.fg = fg
	b.auto_hover = true
	b.hover_scale = 1.04
	return b


## Fundo: papel azul pontilhado e, atrás do quadro do boss, uma faixa grande na cor dele.
func _draw_back() -> void:
	var d := _back
	var acc := _accent()
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.0, NAVY2)
	d.draw_colored_polygon(PackedVector2Array([Vector2(-10, 520), Vector2(420, 730), Vector2(-10, 730)]), PURPLE)
	# a faixa cai inclinada como as linhas da lista (o topo mais à direita)
	d.draw_colored_polygon(PackedVector2Array([Vector2(742, -10), Vector2(1290, -10), Vector2(1290, 730), Vector2(588, 730)]), Paper.INK)
	d.draw_colored_polygon(PackedVector2Array([Vector2(756, -10), Vector2(1290, -10), Vector2(1290, 730), Vector2(602, 730)]), acc)
	d.draw_colored_polygon(PackedVector2Array([Vector2(1000, -10), Vector2(1090, -10), Vector2(936, 730), Vector2(846, 730)]), acc.lightened(0.16))
	d.draw_colored_polygon(PackedVector2Array([Vector2(1180, -10), Vector2(1290, -10), Vector2(1290, 250), Vector2(1100, 730), Vector2(1010, 730)]), acc.darkened(0.16))
	d.draw_colored_polygon(PackedVector2Array([Vector2(700, 730), Vector2(1290, 500), Vector2(1290, 730)]), Paper.INK)


## Tamanho de letra que faz o texto caber em `max_w`.
func _fit(text: String, px: int, max_w: float) -> int:
	var f := Paper.display()
	while px > 11 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
		px -= 1
	return px


# ---------------------------------------------------------------- a lista

func _build() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	_hot = -1
	var n := Knowledge.BOSS_INFO.size() + 1
	# as linhas encolhem pra caber; abaixo de 44 px de passo a lista passa a rolar
	_step_y = clampf((LIST_RECT.size.y - 40.0) / n, 44.0, 66.0)
	_row_h = _step_y - 10.0
	var lean_x := tan(deg_to_rad(LEAN)) * _step_y
	for k in n:
		var row := _make_row(k)
		# a coluna inteira cai inclinada: cada linha um pouco mais à esquerda que a de cima
		var home := Vector2(60.0 + (n - 1 - k) * lean_x, 14.0 + k * _step_y + (12.0 if k == n - 1 else 0.0))
		row.position = home
		row.set_meta("home", home)
		_list.add_child(row)
		_rows.append(row)
		row.modulate.a = 0.0
		var tw := row.create_tween()
		tw.tween_interval(0.03 + k * 0.04)
		tw.tween_property(row, "modulate:a", 1.0, 0.14)
	_mark(false)


## Uma linha da lista: emblema pequeno, nome, etiqueta MINI BOSS e o melhor ranking.
## `k` = boss em BOSS_INFO; o último (k == _practice_at) é o treino livre, com o nome "Practice".
func _make_row(k: int) -> Control:
	var train := k == _practice_at
	var open_now := train or Knowledge.boss_open(k)
	var h := _row_h
	var row := Control.new()
	if train:
		row.name = "Practice"
	row.size = Vector2(ROW_W, h)
	row.pivot_offset = Vector2(0, h * 0.5)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.draw.connect(_draw_row.bind(row, k))
	row.mouse_entered.connect(_hover.bind(k, true))
	row.mouse_exited.connect(_hover.bind(k, false))
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _info == null:
			if sel == k:
				_confirm()
			else:
				sel = k
				_mark())
	var emblem := Control.new()
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if train:
		emblem.size = Vector2(80, 80)
		emblem.scale = Vector2.ONE * ((h - 10.0) / 80.0)
		emblem.draw.connect(_draw_dummy.bind(emblem))
	else:
		emblem.size = Vector2(180, 170)
		emblem.scale = Vector2.ONE * ((h - 12.0) / 170.0)
		emblem.draw.connect(_draw_emblem.bind(emblem, k, open_now))
	emblem.position = Vector2(20.0 + (h - emblem.size.x * emblem.scale.x) * 0.5, (h - emblem.size.y * emblem.scale.y) * 0.5)
	row.add_child(emblem)
	var text: String = "TREINO LIVRE" if train else String(Knowledge.BOSS_INFO[k]["name"])
	var tag_text := "SEM PROGRESSO" if train else ("MINI BOSS" if Knowledge.BOSS_INFO[k]["mini"] else "")
	var ranked := not train and Knowledge.best_rank.has(k)
	var x0 := 30.0 + h
	var room := ROW_W - x0 - 16.0 - (74.0 if ranked else 0.0)
	var tag: Chip = null
	if tag_text != "":
		tag = Chip.new()
		tag.px = 10
		tag.pad = 7.0
		tag.border = 2.0
		tag.shadow = Vector2(-2, 3)
		tag.fill = Paper.GOLD if open_now else Color("6E6F8F")
		tag.text = tag_text
		room -= tag.size.x + 12.0
	var px := _fit(text, 21 if h >= 50.0 else 17, room)
	var nm := Paper.label(text, px, Paper.INK if open_now else DIM, Paper.display())
	nm.position = Vector2(x0, 0)
	nm.size = Vector2(ROW_W - x0 - 10.0, h)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nm)
	if not open_now:
		# trancado: o nome sobe e o motivo vai embaixo
		nm.size.y = h * 0.62
		var why := Paper.label("Vença o anterior pra abrir", 12 if h >= 50.0 else 10, DIM, Paper.body(700))
		why.position = Vector2(x0 + 2.0, h * 0.5)
		why.size = Vector2(ROW_W - x0 - 10.0, h * 0.44)
		why.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(why)
	if tag != null:
		var name_w := Paper.display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		tag.position = Vector2(x0 + name_w + 12.0, (h * (1.0 if open_now else 0.62) - tag.size.y) * 0.5)
		tag.rotation = deg_to_rad(-4.0)
		row.add_child(tag)
	if ranked:
		# melhor ranking: carimbo roxo na ponta da linha
		var rank: String = Knowledge.RANKS[int(Knowledge.best_rank[k])]
		var stamp := Control.new()
		stamp.name = "Rank"
		stamp.size = Vector2(62, h - 16.0)
		stamp.position = Vector2(ROW_W - 14.0 - 62.0, 8.0)
		stamp.pivot_offset = stamp.size * 0.5
		stamp.rotation = deg_to_rad(5.0)
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.draw.connect(func():
			var pts := Paper.skew_rect(stamp.size, 8.0)
			stamp.draw_colored_polygon(Paper.moved(pts, Vector2(3, 3)), Paper.INK)
			stamp.draw_colored_polygon(pts, Paper.INK)
			stamp.draw_colored_polygon(Paper.inset(pts, 3.0), PURPLE)
			var f := Paper.display(0.0)
			var spx := int(minf(22.0, stamp.size.y * 0.6))
			stamp.draw_string(f, Vector2(0, stamp.size.y * 0.5 + spx * 0.37), rank, HORIZONTAL_ALIGNMENT_CENTER, stamp.size.x, spx, Paper.CREAM))
		row.add_child(stamp)
	return row


func _draw_row(row: Control, k: int) -> void:
	var on := k == sel
	var train := k == _practice_at
	var open_now := train or Knowledge.boss_open(k)
	var sz := row.size
	var pts := Paper.skew_rect(sz, LEAN)
	var fill := Paper.CREAM if open_now else Color("343A78")
	if on:
		fill = _accent() if open_now else Color("4A5096")
	elif k == _hot:
		fill = Color.WHITE if open_now else Color("4A5096")
	if on:
		# moldura clara e ponteiro: só o escolhido tem
		var big := Paper.moved(Paper.skew_rect(sz + Vector2(18, 16), LEAN), Vector2(-9, -8))
		row.draw_colored_polygon(Paper.moved(big, Vector2(7, 8)), Paper.INK)
		row.draw_colored_polygon(big, Paper.INK)
		row.draw_colored_polygon(Paper.inset(big, 4.0), Paper.CREAM)
		var py := sz.y * 0.5
		row.draw_colored_polygon(PackedVector2Array([Vector2(-54, py - 22), Vector2(-16, py), Vector2(-54, py + 22)]), Paper.INK)
		row.draw_colored_polygon(PackedVector2Array([Vector2(-49, py - 13), Vector2(-26, py), Vector2(-49, py + 13)]), Paper.GOLD)
	else:
		row.draw_colored_polygon(Paper.moved(pts, Vector2(6, 7)), Paper.INK)
	row.draw_colored_polygon(pts, Paper.INK)
	row.draw_colored_polygon(Paper.inset(pts, 4.0), fill)


func _hover(k: int, on: bool) -> void:
	_hot = k if on else (-1 if _hot == k else _hot)
	if k < _rows.size():
		_rows[k].queue_redraw()


## Marca o escolhido: a linha dele avança, cresce e pega a cor do boss; o fundo e o quadro acompanham.
func _mark(animate := true) -> void:
	sel = clampi(sel, 0, _practice_at)
	if sel < _practice_at:
		_last_boss = sel
	for k in _rows.size():
		var row := _rows[k]
		var on := k == sel
		var home: Vector2 = row.get_meta("home")
		var to := home + Vector2(26.0 if on else 0.0, 0.0)
		var sc := Vector2.ONE * (1.05 if on else 1.0)
		if on:
			_list.move_child(row, -1)
		row.queue_redraw()
		if animate and is_inside_tree():
			var tw := row.create_tween().set_parallel(true)
			tw.tween_property(row, "position", to, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(row, "scale", sc, 0.12)
		else:
			row.position = to
			row.scale = sc
	# rolagem: só existe quando as linhas não cabem na janela
	var content := 14.0 + (_practice_at + 1) * _step_y + 26.0
	var top := 0.0
	if content > LIST_RECT.size.y:
		top = clampf(LIST_RECT.size.y * 0.5 - (14.0 + sel * _step_y + _row_h * 0.5), LIST_RECT.size.y - content, 0.0)
	if animate and is_inside_tree():
		_list.create_tween().tween_property(_list, "position:y", top, 0.14)
	else:
		_list.position.y = top
	_back.queue_redraw()
	_fill_detail(animate)
	var train := sel == _practice_at
	$BtnConfirm.disabled = not train and not Knowledge.boss_open(sel)
	$BtnConfirm.queue_redraw()


# ---------------------------------------------------------------- o quadro do escolhido

func _fill_detail(animate := true) -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var train := sel == _practice_at
	var open_now := train or Knowledge.boss_open(sel)
	var acc := _accent()
	var info: Dictionary = {} if train else Knowledge.BOSS_INFO[sel]
	var text: String = "TREINO LIVRE" if train else String(info["name"])

	# cartão do emblema, com raios na cor do boss atrás do desenho
	var shape := [[.02, 0], [1, .05], [.97, 1], [0, .95]]
	var card := CutPanel.make(Rect2(742, 92, 372, 280), shape, Paper.CREAM if open_now else Color("B5B2A6"), 6, Vector2(10, 10))
	card.pivot_offset = card.size * 0.5
	card.rotation = deg_to_rad(-3.0)
	_detail.add_child(card)
	var rays := Control.new()
	rays.size = card.size
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ray_col := Paper.CREAM.lerp(acc, 0.38) if open_now else Color("A3A094")
	rays.draw.connect(func():
		var inner := Paper.inset(Paper.poly(rays.size, shape), 6.0)
		var c := rays.size * 0.5 + Vector2(0, 10)
		for n in 9:
			var a := TAU * n / 9.0 - 0.3
			var wedge := PackedVector2Array([c, c + Vector2.from_angle(a) * 420.0, c + Vector2.from_angle(a + TAU / 18.0) * 420.0])
			for piece in Geometry2D.intersect_polygons(wedge, inner):
				rays.draw_colored_polygon(piece, ray_col))
	card.add_child(rays)
	var emblem := Control.new()
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if train:
		emblem.size = Vector2(80, 80)
		emblem.scale = Vector2.ONE * 2.8
		emblem.draw.connect(_draw_dummy.bind(emblem))
	else:
		emblem.size = Vector2(180, 170)
		emblem.scale = Vector2.ONE * 1.36
		emblem.draw.connect(_draw_emblem.bind(emblem, sel, open_now))
	emblem.position = (card.size - emblem.size * emblem.scale) * 0.5 + Vector2(0, 0.0 if train else 14.0)
	card.add_child(emblem)

	# melhor ranking: carimbo grande no canto do cartão
	if not train and Knowledge.best_rank.has(sel):
		var rank: String = Knowledge.RANKS[int(Knowledge.best_rank[sel])]
		var stamp := CutPanel.make(Rect2(1076, 100, 156, 112), [[.04, 0], [1, .06], [.96, 1], [0, .94]], PURPLE, 5, Vector2(7, 7))
		stamp.name = "BestRank"
		stamp.pivot_offset = stamp.size * 0.5
		stamp.rotation = deg_to_rad(8.0)
		_detail.add_child(stamp)
		var cap := Paper.label("MELHOR RANK", 12, Paper.GOLD, Paper.display())
		cap.position = Vector2(0, 10)
		cap.size = Vector2(156, 20)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_child(cap)
		var rl := Paper.label(rank, 54 if rank.length() < 3 else 44, Paper.CREAM, Paper.display(0.0))
		rl.position = Vector2(0, 24)
		rl.size = Vector2(156, 82)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.add_child(rl)
	elif not train:
		var none := Chip.new()
		none.px = 13
		none.pad = 12.0
		none.fill = Color("C0183A") if not open_now else DEEP
		none.ink = Paper.CREAM
		none.text = "TRANCADO" if not open_now else "SEM RANK AINDA"
		none.position = Vector2(1232.0 - none.size.x, 116)
		none.rotation = deg_to_rad(6.0)
		_detail.add_child(none)

	# faixa do nome, por cima do pé do cartão
	var banner := Control.new()
	banner.position = Vector2(648, 366)
	banner.size = Vector2(566, 76)
	banner.pivot_offset = banner.size * 0.5
	banner.rotation = deg_to_rad(-3.0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(func():
		var pts := Paper.skew_rect(banner.size, LEAN)
		banner.draw_colored_polygon(Paper.moved(pts, Vector2(9, 9)), Paper.INK)
		banner.draw_colored_polygon(pts, Paper.CREAM)
		banner.draw_colored_polygon(Paper.inset(pts, 5.0), Paper.INK))
	_detail.add_child(banner)
	var nm := Paper.label(text, _fit(text, 44, 500.0), acc.lightened(0.25) if open_now else DIM, Paper.display())
	nm.size = banner.size
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(nm)
	var tag_text := "SEM PROGRESSO" if train else ("MINI BOSS" if info["mini"] else "")
	if tag_text != "":
		var tag := Chip.new()
		tag.px = 15
		tag.pad = 12.0
		tag.fill = Paper.GOLD
		tag.text = tag_text
		tag.position = Vector2(670, 340)
		tag.rotation = deg_to_rad(-7.0)
		_detail.add_child(tag)

	# descrição, numa tira de papel
	var slip := CutPanel.make(Rect2(644, 456, 548, 78), [[.015, 0], [1, .06], [.985, 1], [0, .92]], Paper.CREAM, 4, Vector2(6, 6))
	_detail.add_child(slip)
	var blurb: String = PRACTICE_BLURB if train else (String(info["blurb"]) if open_now else "Vença o anterior pra abrir.")
	var bl := Paper.label(blurb, 18, Paper.INK, Paper.body(700))
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.position = Vector2(24, 6)
	bl.size = Vector2(500, 66)
	bl.add_theme_constant_override("line_spacing", -4)
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slip.add_child(bl)

	# entrada do painel "o que a party sabe" (o treino não tem mecânicas)
	if not train:
		var q := _small("O QUE A PARTY SABE", Paper.CREAM, Paper.INK)
		q.name = "BtnInfo"
		q.font_px = 15
		q.chevron = 1
		q.chevron_px = 15
		q.position = Vector2(634, 552)
		q.size = Vector2(250, 44)
		q.pressed.connect(open_info.bind(sel))
		_detail.add_child(q)
	if animate and is_inside_tree():
		_detail.pivot_offset = Vector2(930, 330)
		_detail.scale = Vector2.ONE * 0.97
		_detail.create_tween().tween_property(_detail, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Emblema do treino: boneco de palha com alvo no peito.
func _draw_dummy(e: Control) -> void:
	var ink := Ink.OUT
	var straw := Color(0.9, 0.75, 0.4)
	e.draw_rect(Rect2(36, 40, 8, 38), ink)
	e.draw_rect(Rect2(8, 30, 64, 12), ink)
	e.draw_rect(Rect2(11, 33, 58, 6), straw)
	e.draw_circle(Vector2(40, 46), 21, ink)
	e.draw_circle(Vector2(40, 46), 17, straw)
	e.draw_circle(Vector2(40, 46), 11, Color(0.95, 0.94, 0.88))
	e.draw_circle(Vector2(40, 46), 7, Color(0.86, 0.16, 0.22))
	e.draw_circle(Vector2(40, 46), 3, Color(0.95, 0.94, 0.88))
	e.draw_circle(Vector2(40, 16), 14, ink)
	e.draw_circle(Vector2(40, 16), 10, straw)


## Emblema simples de cada boss, só com formas: um biscoito, ou uma cabeça de maria-chiquinha.
func _draw_emblem(e: Control, i: int, open_now: bool) -> void:
	var c := e.size * 0.5
	var col: Color = HAIR[i % HAIR.size()] if open_now else HAIR[i % HAIR.size()].darkened(0.6)
	var ink := Ink.OUT
	if Knowledge.BOSS_INFO[i]["name"] == "MEL-CHAN":
		# abelha: asas, corpo listrado e antenas com ponta de coração
		var wing := Color(0.8, 0.95, 1.0) if open_now else Color(0.35, 0.4, 0.45)
		var pink := Color(1.0, 0.45, 0.72) if open_now else Color(0.45, 0.25, 0.35)
		for s in [-1.0, 1.0]:
			e.draw_circle(c + Vector2(s * 58, -26), 36, ink)
			e.draw_circle(c + Vector2(s * 58, -26), 31, wing)
			e.draw_line(c + Vector2(s * 16, -52), c + Vector2(s * 34, -80), ink, 5.0, true)
			e.draw_circle(c + Vector2(s * 36, -82), 11, ink)
			e.draw_circle(c + Vector2(s * 36, -82), 8, pink)
		e.draw_circle(c + Vector2(0, 6), 62, ink)
		e.draw_circle(c + Vector2(0, 6), 56, col)
		for y in [-6.0, 26.0]:
			var half := sqrt(maxf(0.0, 56.0 * 56.0 - (y + 7.0) * (y + 7.0)))
			e.draw_rect(Rect2(c.x - half, c.y + y, half * 2.0, 14), ink)
		e.draw_circle(c + Vector2(-18, -22), 7, ink)
		e.draw_circle(c + Vector2(18, -22), 7, ink)
		return
	if Knowledge.BOSS_INFO[i]["name"] == "TROVÃO-KUN":
		# nuvem de tempestade com um raio no meio
		for p in [Vector2(-34, 6), Vector2(34, 6), Vector2(0, -22), Vector2(-20, -8), Vector2(22, -10), Vector2(0, 14)]:
			e.draw_circle(c + p, 44, ink)
		for p in [Vector2(-34, 6), Vector2(34, 6), Vector2(0, -22), Vector2(-20, -8), Vector2(22, -10), Vector2(0, 14)]:
			e.draw_circle(c + p, 38, col)
		var bolt := PackedVector2Array([c + Vector2(10, -34), c + Vector2(-22, 10), c + Vector2(-2, 10), c + Vector2(-14, 48), c + Vector2(24, -4), c + Vector2(4, -4)])
		e.draw_colored_polygon(bolt, Color(1.0, 0.92, 0.3) if open_now else Color(0.4, 0.37, 0.15))
		e.draw_polyline(PackedVector2Array([bolt[0], bolt[1], bolt[2], bolt[3], bolt[4], bolt[5], bolt[0]]), ink, 4.0, true)
		return
	if Knowledge.BOSS_INFO[i]["mini"]:
		e.draw_circle(c, 74, ink)
		e.draw_circle(c, 68, col)
		for p in [Vector2(-34, -30), Vector2(30, -38), Vector2(-40, 24), Vector2(36, 30), Vector2(2, 44)]:
			e.draw_circle(c + p, 9, Color(0.25, 0.13, 0.07))
		e.draw_circle(c + Vector2(-20, -4), 17, Color.WHITE)
		e.draw_circle(c + Vector2(22, -8), 12, Color.WHITE)
		e.draw_circle(c + Vector2(-16, -2), 7, ink)
		e.draw_circle(c + Vector2(24, -6), 5, ink)
		e.draw_line(c + Vector2(-18, 26), c + Vector2(20, 20), ink, 5.0, true)
		return
	# marias-chiquinhas
	for s in [-1.0, 1.0]:
		var tail := PackedVector2Array([c + Vector2(s * 40, -40), c + Vector2(s * 84, -20), c + Vector2(s * 72, 70), c + Vector2(s * 44, 30)])
		var out := PackedVector2Array()
		for p in tail:
			out.append(c + (p - c) * 1.08)
		e.draw_colored_polygon(out, ink)
		e.draw_colored_polygon(tail, col)
	e.draw_circle(c + Vector2(0, -6), 50, ink)
	e.draw_circle(c + Vector2(0, -12), 45, col)
	e.draw_circle(c + Vector2(0, 2), 36, Color(0.95, 0.8, 0.74) if open_now else Color(0.4, 0.36, 0.4))
	e.draw_circle(c + Vector2(-14, 2), 6, ink)
	e.draw_circle(c + Vector2(14, 2), 6, ink)
	e.draw_arc(c + Vector2(0, -66), 30, 0, TAU, 28, Color(1.0, 0.85, 0.35) if open_now else Color(0.5, 0.45, 0.3), 5.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _info != null:
		# com o painel aberto as teclas só fecham ele
		if event.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			close_info()
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_W, KEY_UP, KEY_A, KEY_LEFT: _step(-1)
		KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT: _step(1)
		KEY_ENTER, KEY_KP_ENTER: _confirm()
		KEY_ESCAPE: back_pressed.emit()


## Anda na lista (bosses e, por último, o treino), dando a volta nas pontas. Boss trancado também
## pode ser olhado; só não dá pra confirmar.
func _step(dir: int) -> void:
	sel = posmod(sel + dir, _practice_at + 1)
	_mark()


# ---------------------------------------------------------------- o que a party sabe

var _info: Control

## Painel de informação de um boss: as mecânicas dele em tiras de papel e os quatro heróis da party
## em colunas, com o quanto cada um entende de cada uma (carta equipada ou passiva = 100%, carimbo
## DOMINA; sem carta, uma barra com o que ele aprendeu na prática). Mecânica que ninguém viu ainda
## aparece tarjada, como "??????".
func open_info(i: int) -> void:
	close_info()
	_info = Control.new()
	_info.name = "InfoPanel"
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Paper.INK, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(dim)
	# boss sem lista própria (ainda): mostra pelo menos o desvio de vermelho
	var mechs: Array = Knowledge.BOSS_MECHS[i] if i < Knowledge.BOSS_MECHS.size() else ["dodge"]
	var party: Array = Knowledge.fight_party()
	var acc: Color = HAIR[i % HAIR.size()]
	var w := 1080.0
	var top := 208.0
	var row_h := clampf((680.0 - top - 28.0) / mechs.size(), 34.0, 50.0)
	var hs := Vector2(w, top + mechs.size() * row_h + 24.0)
	var holder := Control.new()
	holder.name = "Box"
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 0.5
	holder.anchor_bottom = 0.5
	holder.offset_left = -hs.x * 0.5
	holder.offset_right = hs.x * 0.5
	holder.offset_top = -hs.y * 0.5
	holder.offset_bottom = hs.y * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(holder)
	var box_shape := [[.008, 0], [1, .02], [.992, 1], [0, .985]]
	var box := CutPanel.make(Rect2(Vector2.ZERO, hs), box_shape, Paper.CREAM, 6, Vector2(12, 12))
	holder.add_child(box)
	# canto na cor do boss, atrás do título
	var corner := Control.new()
	corner.size = hs
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.draw.connect(func():
		var inner := Paper.inset(Paper.poly(corner.size, box_shape), 6.0)
		var slab := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 64), Vector2(0, 150)])
		for piece in Geometry2D.intersect_polygons(slab, inner):
			corner.draw_colored_polygon(piece, acc))
	holder.add_child(corner)

	# título: o nome do boss numa faixa escura e a etiqueta do painel pendurada nela
	var name_text := String(Knowledge.BOSS_INFO[i]["name"])
	var name_px := 30
	var name_w := Paper.display().get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
	var banner := Control.new()
	banner.position = Vector2(-18, 18)
	banner.size = Vector2(name_w + 76.0, 58)
	banner.rotation = deg_to_rad(-2.0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(func():
		var pts := Paper.skew_rect(banner.size, LEAN)
		banner.draw_colored_polygon(Paper.moved(pts, Vector2(7, 7)), Paper.INK)
		banner.draw_colored_polygon(pts, Paper.CREAM)
		banner.draw_colored_polygon(Paper.inset(pts, 4.0), Paper.INK))
	holder.add_child(banner)
	var head := Paper.label(name_text, name_px, acc.lightened(0.25), Paper.display())
	head.size = banner.size
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(head)
	var what := Chip.new()
	what.px = 17
	what.pad = 14.0
	what.fill = Paper.GOLD
	what.text = "O QUE A PARTY SABE"
	what.position = Vector2(banner.size.x + 4.0, 30)
	what.rotation = deg_to_rad(-3.0)
	holder.add_child(what)
	var sub := Paper.label("DOMINA = resolve sozinho (carta equipada ou passiva). Barra = o que ele aprendeu jogando.", 14, Paper.INK, Paper.body(700))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_constant_override("line_spacing", -4)
	sub.position = Vector2(34, 112)
	sub.size = Vector2(300, 84)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	holder.add_child(sub)

	# os heróis: retrato numa moldura da cor de cada um, com o nome numa etiqueta
	var col_x := 352.0
	var col_w := 176.0
	var tilt := [-4.0, 3.0, -2.0, 4.0]
	for c in party.size():
		var hero: int = party[c]
		var hcol: Color = Knowledge.HEROES[hero]["color"]
		var cx := col_x + c * col_w + col_w * 0.5
		var tile := CutPanel.make(Rect2(cx - 37.0, 92, 74, 78), [[0, .03], [1, 0], [.97, 1], [.03, .97]], hcol, 5, Vector2(5, 6))
		tile.name = "Hero_%d" % c
		tile.pivot_offset = tile.size * 0.5
		tile.rotation = deg_to_rad(tilt[c % tilt.size()])
		holder.add_child(tile)
		var face := TextureRect.new()
		face.texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[hero]["key"])
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.position = Vector2(8, 8)
		face.size = Vector2(58, 62)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(face)
		var nm := Chip.new()
		nm.px = 12
		nm.pad = 9.0
		nm.shadow = Vector2(-3, 4)
		nm.fill = Paper.INK
		nm.ink = hcol.lightened(0.45)
		nm.text = String(Knowledge.HEROES[hero]["name"]).to_upper()
		nm.position = Vector2(cx - nm.size.x * 0.5, 164)
		nm.rotation = deg_to_rad(-3.0)
		holder.add_child(nm)

	for r in mechs.size():
		var key: String = mechs[r]
		var seen := Knowledge.mech_seen(key)
		var y := top + r * row_h
		var sh := row_h - 8.0
		# tira de papel da mecânica (os cortes alternam pra não parecer tabela)
		var cut := [[0, .08], [1, 0], [.997, 1], [.004, .92]] if r % 2 == 0 else [[.004, 0], [.997, .08], [1, .94], [0, 1]]
		var strip := CutPanel.make(Rect2(20, y, w - 40.0, sh), cut, Color("FFFBEC") if seen else Color("D6CFB4"), 3, Vector2(4, 5))
		holder.add_child(strip)
		var lab_text := Knowledge.mech_name(key).to_upper() if seen else "??????"
		if not seen:
			# não revelada: tarja preta presa com fita
			var bar := Control.new()
			bar.position = Vector2(40, y + 5.0)
			bar.size = Vector2(270, sh - 10.0)
			bar.rotation = deg_to_rad(-1.0 if r % 2 == 0 else 1.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.draw.connect(func():
				bar.draw_colored_polygon(Paper.skew_rect(bar.size, 6.0), Paper.INK)
				for sx in [-12.0, bar.size.x - 22.0]:
					var tape := Paper.moved(Paper.skew_rect(Vector2(34, bar.size.y + 8.0), -14.0), Vector2(sx, -4))
					bar.draw_colored_polygon(tape, Color(1.0, 0.86, 0.45))
					bar.draw_polyline(PackedVector2Array([tape[0], tape[1], tape[2], tape[3], tape[0]]), Paper.INK, 2.0, true))
			holder.add_child(bar)
		var lab := Paper.label(lab_text, _fit(lab_text, 16, 286.0) if seen else 16, Paper.INK if seen else Paper.CREAM, Paper.display())
		lab.position = Vector2(40, y)
		lab.size = Vector2(290 if seen else 270, sh)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if not seen:
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(lab)
		for c in party.size():
			var hero: int = party[c]
			var hcol: Color = Knowledge.HEROES[hero]["color"]
			var cell := Control.new()
			cell.name = "Cell_%d_%d" % [r, c]
			cell.position = Vector2(col_x + c * col_w + 8.0, y)
			cell.size = Vector2(col_w - 16.0, sh)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(cell)
			if not Knowledge.mech_applies(hero, key):
				var na := Paper.label("não é com ele", 13, Color("8A8466"), Paper.body(700))
				na.size = cell.size
				na.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				na.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cell.add_child(na)
				continue
			var val := Knowledge.understanding(hero, key) if seen else 0.0
			cell.set_meta("value", val)
			if seen and val >= 100.0:
				# carimbo: este herói resolve sozinho
				var ok_stamp := Chip.new()
				ok_stamp.px = 14
				ok_stamp.pad = 12.0
				ok_stamp.shadow = Vector2(-3, 4)
				ok_stamp.fill = hcol.lightened(0.15)
				ok_stamp.text = "DOMINA"
				ok_stamp.position = (cell.size - ok_stamp.size) * 0.5
				ok_stamp.pivot_offset = ok_stamp.size * 0.5
				ok_stamp.rotation = deg_to_rad(-5.0 if (r + c) % 2 == 0 else 4.0)
				cell.add_child(ok_stamp)
				continue
			# barra com contorno e sombra dura, na cor do herói
			cell.draw.connect(func():
				var bar := Rect2(4, cell.size.y * 0.5 - 8.0, cell.size.x - 62.0, 16)
				cell.draw_rect(Rect2(bar.position + Vector2(0, 4), bar.size).grow(3), Paper.INK)
				cell.draw_rect(bar.grow(3), Paper.INK)
				cell.draw_rect(bar, Color("C9C2A6") if seen else Color("8F8A78"))
				if seen and val > 0.0:
					cell.draw_rect(Rect2(bar.position, Vector2(maxf(4.0, bar.size.x * clampf(val / 100.0, 0.0, 1.0)), bar.size.y)), hcol))
			var pct := Paper.label(("%d%%" % roundi(val)) if seen else "?", 15, Paper.INK if seen else Color("6B664F"), Paper.display(0.0))
			pct.position = Vector2(cell.size.x - 54.0, 0)
			pct.size = Vector2(54, cell.size.y)
			pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_child(pct)
	var ok := _small("FECHAR", PURPLE, Paper.CREAM)
	ok.name = "InfoClose"
	ok.size = Vector2(150, 46)
	ok.position = Vector2(w - 184.0, 20)
	ok.pressed.connect(close_info)
	holder.add_child(ok)
	_info.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close_info())
	holder.pivot_offset = hs * 0.5
	holder.scale = Vector2.ONE * 0.94
	holder.create_tween().tween_property(holder, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_info() -> void:
	if _info != null and is_instance_valid(_info):
		_info.queue_free()
	_info = null
