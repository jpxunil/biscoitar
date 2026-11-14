class_name BossScreen
extends Control
## Escolha do boss. Um painel por luta de Knowledge.BOSS_INFO; os painéis são montados aqui,
## dentro do contêiner "List" da cena. Embaixo, entre VOLTAR e CONFIRMAR, fica o TREINO LIVRE
## (dummy que não morre; não dá recompensa nem mexe no save). No topo, CARTAS abre o gear do save e LOJA a loja dele.
##   A D / ← → trocam de boss · S / ↓ vai pro treino, W / ↑ volta · ENTER confirma · ESC volta.

## index = boss em Knowledge.BOSS_INFO, ou -1 pro treino livre.
signal boss_chosen(index: int)
signal back_pressed
## Abrir as cartas (gear) do save ativo, sem luta.
signal gear_pressed
## Abrir a loja do save ativo (só depois da primeira vitória).
signal shop_pressed
signal equip_pressed

const HAIR := [Color(0.86, 0.6, 0.3), Color(0.25, 0.8, 0.9), Color(1.0, 0.38, 0.66), Color(0.75, 0.45, 1.0), Color(0.4, 0.8, 1.0), Color(1.0, 0.8, 0.25)]

var sel := 1
var _panels: Array = []
## Lugar do treino livre na seleção: logo depois do último boss.
var _practice_at := 0
var _practice: InkPanel
var _last_boss := 1


func _ready() -> void:
	_practice_at = Knowledge.BOSS_INFO.size()
	$BtnBack.pressed.connect(func(): back_pressed.emit())
	$BtnConfirm.pressed.connect(_confirm)
	# três botões no topo: a loja (cartas e itens, lá dentro) e as duas telas do herói (cartas e gear)
	var gear := Ink.button("CARTAS", Ink.CREAM, Ink.OUT, 22, 11)
	gear.name = "BtnGear"
	gear.position = Vector2(884, 40)
	gear.size = Vector2(170, 60)
	gear.pressed.connect(func(): gear_pressed.emit())
	add_child(gear)
	var shop := Ink.button("LOJA", Ink.GRAPE, Ink.CREAM, 22, 13)
	shop.name = "BtnShop"
	shop.position = Vector2(700, 40)
	shop.size = Vector2(170, 60)
	shop.pressed.connect(func(): shop_pressed.emit())
	add_child(shop)
	var equip := Ink.button("GEAR", Ink.COIN, Ink.OUT, 22, 19)
	equip.name = "BtnEquip"
	equip.position = Vector2(1068, 40)
	equip.size = Vector2(170, 60)
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
	chip.position = Vector2(1006, 24)
	chip.rotation = deg_to_rad(8.0)
	chip.visible = false
	add_child(chip)
	_build_practice()
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
	_build()


func _confirm() -> void:
	if sel == _practice_at:
		boss_chosen.emit(-1)
	elif Knowledge.boss_open(sel):
		boss_chosen.emit(sel)


## Placa do treino livre, na faixa de baixo.
func _build_practice() -> void:
	var slot := Control.new()
	slot.name = "Practice"
	slot.position = Vector2(276, 596)
	slot.size = Vector2(596, 104)
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(slot)
	_practice = Ink.panel(Ink.NAVY, 61)
	_practice.position = Vector2(0, 8)
	_practice.size = Vector2(596, 90)
	slot.add_child(_practice)
	var emblem := Control.new()
	emblem.position = Vector2(20, 6)
	emblem.size = Vector2(80, 80)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(_draw_dummy.bind(emblem))
	_practice.add_child(emblem)
	var nm := Ink.title("TREINO LIVRE", 26, Ink.CREAM)
	nm.position = Vector2(112, 10)
	nm.size = Vector2(300, 36)
	_practice.add_child(nm)
	var tag := Ink.panel(Ink.COIN, 5)
	tag.position = Vector2(404, 12)
	tag.size = Vector2(170, 28)
	tag.rotation_degrees = 2
	_practice.add_child(tag)
	var tl := Ink.title("SEM PROGRESSO", 14, Ink.OUT)
	tl.position = Vector2(12, 4)
	tag.add_child(tl)
	var bl := Ink.text("Um dummy que não morre. Teste dano, combos e cartas à vontade.", 14, Color(0.8, 0.82, 0.95))
	bl.position = Vector2(112, 48)
	bl.size = Vector2(470, 36)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_practice.add_child(bl)
	slot.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if sel == _practice_at:
				_confirm()
			else:
				sel = _practice_at
				_mark())


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


func _build() -> void:
	for c in $List.get_children():
		$List.remove_child(c)
		c.queue_free()
	_panels.clear()
	# com mais de quatro lutas os painéis estreitam pra caber todos na tela
	var count := Knowledge.BOSS_INFO.size()
	var w := 283.0 if count <= 4 else floorf((1188.0 - 18.0 * (count - 1)) / count)
	var slim := w < 200.0
	for i in Knowledge.BOSS_INFO.size():
		var info: Dictionary = Knowledge.BOSS_INFO[i]
		var open_now := Knowledge.boss_open(i)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(w, 420)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open_now else Control.CURSOR_ARROW
		var p := Ink.panel(Ink.NAVY, 30 + i * 7)
		p.size = Vector2(w, 400)
		p.position = Vector2(0, 16)
		slot.add_child(p)
		var emblem := Control.new()
		emblem.position = Vector2((w - 180.0) * 0.5, 22)
		emblem.size = Vector2(180, 170)
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.draw.connect(_draw_emblem.bind(emblem, i, open_now))
		p.add_child(emblem)
		if info["mini"]:
			var tag := Ink.panel(Ink.COIN, 5)
			tag.position = Vector2(14, 10)
			tag.size = Vector2(118, 30)
			tag.rotation_degrees = -5
			p.add_child(tag)
			var tl := Ink.title("MINI BOSS", 15, Ink.OUT)
			tl.position = Vector2(10, 4)
			tag.add_child(tl)
		var nm := Ink.title(info["name"], 25 if w > 250.0 else (17 if slim else 20), Ink.CREAM if open_now else Ink.CREAM.darkened(0.45))
		nm.position = Vector2(10, 204)
		nm.size = Vector2(w - 20.0, 36)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(nm)
		var bl := Ink.text(info["blurb"] if open_now else "Vença o anterior pra abrir.", 13 if slim else 15, Color(0.8, 0.82, 0.95) if open_now else Color(0.55, 0.56, 0.7))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.position = Vector2(12 if slim else 22, 246)
		bl.size = Vector2(w - (24.0 if slim else 44.0), 90)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(bl)
		if Knowledge.best_rank.has(i):
			# melhor ranking: letra grande num carimbo
			var stamp := Ink.panel(Ink.CREAM, 11)
			stamp.position = Vector2((w - 112.0) * 0.5, 322)
			stamp.size = Vector2(112, 62)
			stamp.rotation_degrees = 4
			p.add_child(stamp)
			var rl := Ink.title(Knowledge.RANKS[int(Knowledge.best_rank[i])], 40, Ink.GRAPE)
			rl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stamp.add_child(rl)
		# botão "?": o que cada herói da party sabe das mecânicas desta luta
		var q := Ink.button("?", Ink.COIN, Ink.OUT, 22, 23 + i)
		q.name = "Info%d" % i
		q.position = Vector2(w - 54.0, 26)
		q.size = Vector2(42, 42)
		q.pressed.connect(open_info.bind(i))
		slot.add_child(q)
		if open_now:
			slot.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					if sel == i:
						_confirm()
					else:
						sel = i
						_last_boss = i
						_mark())
		$List.add_child(slot)
		_panels.append(p)
		slot.modulate.a = 0.0
		var tw := slot.create_tween()
		tw.tween_interval(0.05 + i * 0.06)
		tw.tween_property(slot, "modulate:a", 1.0, 0.18)
	_mark()


## O escolhido sobe, clareia e ganha contorno claro.
func _mark() -> void:
	for i in _panels.size():
		var p: InkPanel = _panels[i]
		var on := i == sel
		p.fill = HAIR[i].darkened(0.55) if on else Ink.NAVY
		p.outline = Ink.CREAM if on else Ink.OUT
		p.create_tween().tween_property(p, "position:y", 0.0 if on else 16.0, 0.12)
	var train := sel == _practice_at
	_practice.fill = Color(0.3, 0.24, 0.1) if train else Ink.NAVY
	_practice.outline = Ink.CREAM if train else Ink.OUT
	_practice.queue_redraw()
	_practice.create_tween().tween_property(_practice, "position:y", 0.0 if train else 8.0, 0.12)
	$BtnConfirm.disabled = not train and not Knowledge.boss_open(sel)


## Emblema simples de cada boss, só com formas: um biscoito, ou uma cabeça de maria-chiquinha.
func _draw_emblem(e: Control, i: int, open_now: bool) -> void:
	var c := e.size * 0.5
	var col: Color = HAIR[i] if open_now else HAIR[i].darkened(0.6)
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
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _step(-1)
		KEY_D, KEY_RIGHT: _step(1)
		KEY_S, KEY_DOWN:
			if sel != _practice_at:
				_last_boss = sel
				sel = _practice_at
				_mark()
		KEY_W, KEY_UP:
			if sel == _practice_at:
				sel = _last_boss
				_mark()
		KEY_ENTER, KEY_KP_ENTER: _confirm()
		KEY_ESCAPE: back_pressed.emit()


func _step(dir: int) -> void:
	var n := Knowledge.BOSS_INFO.size()
	if sel == _practice_at:
		sel = _last_boss
		_mark()
		return
	var k := sel
	for _t in n:
		k = posmod(k + dir, n)
		if Knowledge.boss_open(k):
			sel = k
			break
	_last_boss = sel
	_mark()


# ---------------------------------------------------------------- o que a party sabe

var _info: Control

## Painel de informação de um boss: as mecânicas dele em linhas e os quatro heróis da party em colunas,
## com o quanto cada um entende de cada uma (carta equipada ou passiva = 100%; sem carta, o que ele
## aprendeu na prática). Mecânica que ninguém viu ainda aparece como "??????".
func open_info(i: int) -> void:
	close_info()
	_info = Control.new()
	_info.name = "InfoPanel"
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.1, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(dim)
	# boss sem lista própria (ainda): mostra pelo menos o desvio de vermelho
	var mechs: Array = Knowledge.BOSS_MECHS[i] if i < Knowledge.BOSS_MECHS.size() else ["dodge"]
	var party: Array = Knowledge.fight_party()
	var row_h := 46.0
	var box := Ink.panel(Ink.NAVY, 41)
	box.size = Vector2(1000, 190 + mechs.size() * row_h)
	box.position = Vector2((1280.0 - box.size.x) * 0.5, (720.0 - box.size.y) * 0.5)
	_info.add_child(box)
	var head := Ink.title(String(Knowledge.BOSS_INFO[i]["name"]) + "  ·  O QUE A PARTY SABE", 28, Ink.CREAM)
	head.position = Vector2(34, 22)
	head.size = Vector2(800, 40)
	box.add_child(head)
	var sub := Ink.text("100% = resolve sozinho (carta equipada ou passiva). Abaixo disso, ele tenta com o que aprendeu jogando.", 14, Color(0.8, 0.82, 0.95))
	sub.position = Vector2(36, 62)
	sub.size = Vector2(920, 22)
	box.add_child(sub)
	var col_x := 330.0
	var col_w := 160.0
	for c in party.size():
		var hero: int = party[c]
		var face := TextureRect.new()
		face.texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[hero]["key"])
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.position = Vector2(col_x + c * col_w + 8, 94)
		face.size = Vector2(44, 44)
		box.add_child(face)
		var nm := Ink.title(String(Knowledge.HEROES[hero]["name"]).to_upper(), 13, Knowledge.HEROES[hero]["color"].lightened(0.35))
		nm.position = Vector2(col_x + c * col_w + 58, 106)
		nm.size = Vector2(col_w - 60, 22)
		nm.clip_text = true
		box.add_child(nm)
	for r in mechs.size():
		var key: String = mechs[r]
		var seen := Knowledge.mech_seen(key)
		var y := 150.0 + r * row_h
		var stripe := ColorRect.new()
		stripe.color = Color(1, 1, 1, 0.05 if r % 2 == 0 else 0.0)
		stripe.position = Vector2(24, y - 4)
		stripe.size = Vector2(952, row_h - 4)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(stripe)
		var lab := Ink.title(Knowledge.mech_name(key).to_upper() if seen else "??????", 16, Ink.CREAM if seen else Color(0.55, 0.56, 0.7))
		lab.position = Vector2(36, y + 4)
		lab.size = Vector2(290, 26)
		lab.clip_text = true
		box.add_child(lab)
		for c in party.size():
			var hero: int = party[c]
			var cell := Control.new()
			cell.name = "Cell_%d_%d" % [r, c]
			cell.position = Vector2(col_x + c * col_w + 8, y + 2)
			cell.size = Vector2(col_w - 20, 30)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(cell)
			if not Knowledge.mech_applies(hero, key):
				var na := Ink.text("não é com ele", 12, Color(0.5, 0.52, 0.66))
				na.position = Vector2(0, 6)
				cell.add_child(na)
				continue
			var val := Knowledge.understanding(hero, key) if seen else 0.0
			cell.set_meta("value", val)
			cell.draw.connect(func():
				var bar := Rect2(0, 8, cell.size.x - 46, 14)
				cell.draw_rect(bar.grow(2), Ink.OUT)
				cell.draw_rect(bar, Color(0.09, 0.09, 0.2))
				var full := val >= 100.0
				cell.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(val / 100.0, 0.0, 1.0), bar.size.y)), Ink.COIN if full else Ink.VIOLET))
			var pct := Ink.title(("%d%%" % roundi(val)) if seen else "?", 14, Ink.COIN if val >= 100.0 else Ink.CREAM)
			pct.position = Vector2(cell.size.x - 42, 4)
			pct.size = Vector2(44, 22)
			cell.add_child(pct)
	var ok := Ink.button("FECHAR", Ink.CREAM, Ink.OUT, 20, 29)
	ok.name = "InfoClose"
	ok.size = Vector2(170, 46)
	ok.position = Vector2(box.size.x - 200, 26)
	ok.pressed.connect(close_info)
	box.add_child(ok)
	_info.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close_info())
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2.ONE * 0.92
	box.create_tween().tween_property(box, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_info() -> void:
	if _info != null and is_instance_valid(_info):
		_info.queue_free()
	_info = null
