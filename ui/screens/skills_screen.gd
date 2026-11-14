class_name SkillsScreen
extends Control
## Tela SKILLS do menu principal: as habilidades de cada personagem, só pra consulta.
## Kit de papel, na linha da tela de cartas: setas em cima trocam de personagem (todos os nove),
## a arte dele fica à direita. À esquerda, uma linha por slot (ícone, nome, tipo, recarga e a TECLA
## atual); no meio, a ficha completa da habilidade escolhida.
## O número do slot é a posição na barra; a tecla vem do Binds e muda junto com os atalhos.
## Os ícones e os textos são os mesmos da barra da luta (SkillInfo).
##   A D / ← → personagem · W S / ↑ ↓ habilidade · TAB modo (Sleepwalker) · ESC volta.
## ARRUMAR A BARRA: segure uma linha e arraste até outra pra trocar as duas de posição (R restaura a
## ordem original). Cada linha é uma POSIÇÃO da barra, com a tecla dela; a ordem fica em
## Knowledge.layouts, por herói e por save, e vale na luta (barra, teclas e clique).

signal back_pressed

const STAGE := Vector2(1280, 720)
const ORDER := [0, 4, 1, 2, 3, 5, 6, 7, 8, 9]
const DIM := Color("B9BEEA")
const ROW_H := 82.0

var hero := 0
var asleep := false
var sel := 0

var _stage: Control
var _bg: Control
var _built := false
var _th := {}
var _rows: Array = []      # por slot: {"root", "slot": SkillSlot, "name", "meta", "key": Chip holder}
var _list: Control
var _hero_name: Label
var _hero_role: Label
var _hero_face: TextureRect
var _art: TextureRect
var _art_home := Vector2.ZERO
var _mode_btn: ShineButton
var _d_icon: TextureRect
var _d_name: Label
var _d_type_holder: Control
var _d_stats: Control
var _d_desc: Label
var _d_slot: Label
var _pointer: Control
var _t := 0.0
var _drop_at := -1   # linha embaixo do que está sendo arrastado


## A habilidade do kit que está na posição `pos` da barra deste herói.
func _slot_at(pos: int) -> int:
	return Knowledge.skill_at(hero, pos, SkillInfo.kit(_key(), asleep).size())


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_at >= 0:
		_drop_at = -1
		for r in _rows:
			r["root"].queue_redraw()


func _drag_row(n: int) -> Variant:
	sel = n
	_show_detail(false)
	var ghost := Control.new()
	var pic := TextureRect.new()
	pic.texture = SkillInfo.icon(_key(), _slot_at(n), asleep)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(72, 72)
	pic.position = Vector2(-36, -36)
	pic.rotation = deg_to_rad(-6.0)
	pic.modulate.a = 0.92
	ghost.add_child(pic)
	set_drag_preview(ghost)
	return {"skill_pos": n, "hero": hero, "asleep": asleep}


func _can_drop_row(n: int, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.get("hero", -1) == hero and data.has("skill_pos") and int(data["skill_pos"]) != n
	var at := n if ok else -1
	if at != _drop_at:
		_drop_at = at
		for r in _rows:
			r["root"].queue_redraw()
	return ok


func _drop_row(n: int, data: Variant) -> void:
	_drop_at = -1
	Knowledge.swap_skills(hero, int(data["skill_pos"]), n, SkillInfo.kit(_key(), asleep).size())
	sel = n
	_fill_list()
	_show_detail(true)
	# as duas linhas trocadas dão um pulinho
	for at in [n, int(data["skill_pos"])]:
		if at < _rows.size():
			var slot: Control = _rows[at]["slot"]
			slot.pivot_offset = slot.size * 0.5
			slot.scale = Vector2.ONE * 1.35
			slot.create_tween().tween_property(slot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		Knowledge.persist = false
		Binds.boot()
		open(0)


func open(hero_idx: int) -> void:
	hero = clampi(hero_idx, 0, Knowledge.HEROES.size() - 1)
	asleep = false
	sel = 0
	_refresh(0)


func _key() -> String:
	return Knowledge.HEROES[hero]["key"]


# ---------------------------------------------------------------- montagem

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(func(): _bg.draw_rect(Rect2(Vector2.ZERO, _bg.size), _th.get("bg", Paper.NAVY)))
	add_child(_bg)
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
	var back := Control.new()
	back.name = "Back"
	back.size = STAGE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(_draw_back.bind(back))
	_stage.add_child(back)

	# arte do personagem, à direita (fica atrás dos painéis)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_art)

	var tag := CutPanel.make(Rect2(20, 14, 220, 66), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	_stage.add_child(tag)
	var title := Paper.label("SKILLS", 40, Paper.INK, Paper.display())
	title.size = Vector2(220, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.rotation = deg_to_rad(-2.0)
	title.pivot_offset = title.size * 0.5
	tag.add_child(title)

	# seletor de personagem: seta, rosto + nome + função, seta
	var bar := CutPanel.make(Rect2(300, 16, 520, 64), [[.02, 0], [1, .06], [.98, 1], [0, .94]], Paper.INK, 0, Vector2(6, 7))
	_stage.add_child(bar)
	var prev := _arrow(-1)
	prev.position = Vector2(308, 24)
	prev.pressed.connect(_switch.bind(-1))
	_stage.add_child(prev)
	var next := _arrow(1)
	next.position = Vector2(764, 24)
	next.pressed.connect(_switch.bind(1))
	_stage.add_child(next)
	var face_frame := CutPanel.make(Rect2(372, 20, 44, 56), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.CREAM, 0, Vector2.ZERO)
	face_frame.rotation = deg_to_rad(-3.0)
	_stage.add_child(face_frame)
	_hero_face = TextureRect.new()
	_hero_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_face.position = Vector2(3, 3)
	_hero_face.size = Vector2(38, 50)
	face_frame.add_child(_hero_face)
	_hero_name = Paper.label("", 26, Paper.CREAM, Paper.display())
	_hero_name.position = Vector2(430, 18)
	_hero_name.size = Vector2(326, 34)
	_stage.add_child(_hero_name)
	_hero_role = Paper.label("", 14, Paper.GOLD, Paper.body(800))
	_hero_role.position = Vector2(432, 50)
	_hero_role.size = Vector2(326, 22)
	_stage.add_child(_hero_role)

	var vb := ShineButton.new()
	vb.text = "VOLTAR"
	vb.font_px = 16
	vb.chevron = -1
	vb.chevron_px = 14
	vb.fill = Paper.CREAM
	vb.fill_hover = Paper.INK
	vb.fg = Paper.INK
	vb.fg_hover = Paper.CREAM
	vb.shadow = Vector2(5, 5)
	vb.position = Vector2(1128, 20)
	vb.size = Vector2(128, 42)
	vb.pressed.connect(func(): back_pressed.emit())
	_stage.add_child(vb)

	# lista de habilidades
	_stage.add_child(CutPanel.make(Rect2(28, 104, 470, 590), [[0, .01], [1, 0], [.985, 1], [.015, .99]], Paper.NAVY, 6, Vector2(10, 10)))
	_list = Control.new()
	_list.position = Vector2(40, 162)
	_list.size = Vector2(446, 520)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_list)
	_mode_btn = ShineButton.new()
	_mode_btn.font_px = 15
	_mode_btn.skew = 10
	_mode_btn.border = 3
	_mode_btn.shadow = Vector2(4, 5)
	_mode_btn.auto_hover = true
	_mode_btn.position = Vector2(196, 114)
	_mode_btn.size = Vector2(288, 38)
	_mode_btn.pressed.connect(_toggle_mode)
	_stage.add_child(_mode_btn)
	var lt := Paper.label("HABILIDADES", 18, Paper.GOLD, Paper.display())
	lt.position = Vector2(46, 118)
	lt.size = Vector2(160, 30)
	_stage.add_child(lt)
	_pointer = Control.new()
	_pointer.size = Vector2(26, 32)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(func():
		_pointer.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(26, 16), Vector2(0, 32)]), Paper.INK)
		_pointer.draw_colored_polygon(PackedVector2Array([Vector2(4, 7), Vector2(18, 16), Vector2(4, 25)]), Paper.GOLD))
	_stage.add_child(_pointer)

	# ficha da habilidade escolhida
	_stage.add_child(CutPanel.make(Rect2(522, 104, 400, 590), [[.02, 0], [1, .015], [.98, 1], [0, .985]], Paper.CREAM, 6, Vector2(10, 10)))
	var icon_back := CutPanel.make(Rect2(546, 126, 136, 136), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.INK, 0, Vector2(6, 7))
	icon_back.rotation = deg_to_rad(-3.0)
	_stage.add_child(icon_back)
	_d_icon = TextureRect.new()
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.position = Vector2(4, 4)
	_d_icon.size = Vector2(128, 128)
	icon_back.add_child(_d_icon)
	_d_slot = Paper.label("", 15, Color("5B2BB8"), Paper.display())
	_d_slot.position = Vector2(700, 126)
	_d_slot.size = Vector2(210, 22)
	_stage.add_child(_d_slot)
	_d_name = Paper.label("", 26, Paper.INK, Paper.display())
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_name.add_theme_constant_override("line_spacing", -6)
	_d_name.position = Vector2(700, 148)
	_d_name.size = Vector2(212, 84)
	_stage.add_child(_d_name)
	_d_type_holder = Control.new()
	_d_type_holder.position = Vector2(702, 236)
	_d_type_holder.size = Vector2(200, 28)
	_stage.add_child(_d_type_holder)
	_d_stats = Control.new()
	_d_stats.position = Vector2(546, 284)
	_d_stats.size = Vector2(356, 130)
	_d_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_d_stats)
	_d_desc = Paper.label("", 17, Paper.INK, Paper.body(700))
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.add_theme_constant_override("line_spacing", -3)
	_d_desc.position = Vector2(548, 424)
	_d_desc.size = Vector2(350, 256)
	_stage.add_child(_d_desc)

	var hint := Paper.label("SEGURE E ARRASTE pra trocar de slot  ·  R restaura  ·  A D personagem  ·  W S habilidade  ·  ESC volta", 14, DIM, Paper.body(700))
	hint.position = Vector2(500, 694)
	hint.size = Vector2(760, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(hint)


func _arrow(dir: int) -> ShineButton:
	var b := ShineButton.new()
	b.chevron = dir
	b.chevron_px = 20
	b.fill = Paper.GOLD
	b.fill_hover = Paper.GOLD_HOVER
	b.border = 3
	b.skew = 6
	b.auto_hover = true
	b.size = Vector2(48, 48)
	return b


func _draw_back(d: Control) -> void:
	var dot: Color = _th.get("bg2", Color("2B3384"))
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.0, Color(dot.r, dot.g, dot.b, 0.5))
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(640, 760), [[.34, 0], [1, 0], [1, 1], [0, 1]]), Vector2(700, -20)), _th.get("deep", Paper.INK))
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(560, 150), [[0, .5], [1, 0], [1, .5], [0, 1]]), Vector2(760, 250)), _th.get("acc", Paper.GOLD))
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(560, 60), [[0, .6], [1, 0], [1, .4], [0, 1]]), Vector2(760, 372)), Paper.CREAM)


# ---------------------------------------------------------------- conteúdo

func _switch(dir: int) -> void:
	var at := ORDER.find(hero)
	hero = ORDER[posmod(at + dir, ORDER.size())]
	asleep = false
	sel = 0
	_refresh(dir)


func _toggle_mode() -> void:
	if not SkillInfo.has_alt(_key()):
		return
	asleep = not asleep
	_fill_list()
	_show_detail(true)


func _refresh(dir: int) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	_th = Paper.THEMES.get(h["key"], Paper.THEMES["tank"])
	_bg.queue_redraw()
	_stage.get_node("Back").queue_redraw()
	_hero_name.text = String(h["name"]).to_upper()
	_hero_role.text = "%s  ·  %d DE VIDA" % [String(h["role"]).to_upper(), int(h["hp"])]
	_hero_face.texture = load("res://assets/portraits/%s_face.png" % h["key"])
	# arte de corpo inteiro: a maior que cabe na coluna da direita, sem distorcer
	var art := "res://assets/portraits/%s_art.webp" % h["key"]
	_art.visible = ResourceLoader.exists(art)
	if _art.visible:
		var tex: Texture2D = load(art)
		var ts := tex.get_size()
		var w := minf(360.0, 600.0 * ts.x / ts.y)
		_art.texture = tex
		_art.size = Vector2(w, w * ts.y / ts.x)
		ArtShadow.for_hero(_art, h["key"])
		_art_home = Vector2(1100.0 - w * 0.5, 96.0 + maxf(0.0, (600.0 - _art.size.y) * 0.5))
		_art.position = _art_home + Vector2(60.0 * dir, 0)
		_art.modulate.a = 0.0 if dir != 0 else 1.0
		var tw := _art.create_tween().set_parallel(true)
		tw.tween_property(_art, "position:x", _art_home.x, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_art, "modulate:a", 1.0, 0.16)
	_fill_list()
	_show_detail(dir != 0)


func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var key := _key()
	var list: Array = SkillInfo.kit(key, asleep)
	sel = clampi(sel, 0, list.size() - 1)
	_mode_btn.visible = SkillInfo.has_alt(key)
	_mode_btn.text = "MODO DORMINDO  (TAB)" if asleep else "MODO ACORDADO  (TAB)"
	_mode_btn.fill = Color("C04BFF") if asleep else Paper.CREAM
	_mode_btn.fg = Paper.CREAM if asleep else Paper.INK
	for n in list.size():
		# n é a POSIÇÃO na barra; k é a habilidade do kit que o jogador pôs nela
		var k := _slot_at(n)
		var info := SkillInfo.info(key, k, asleep)
		var row := Control.new()
		row.position = Vector2(0, n * ROW_H)
		row.size = Vector2(446, ROW_H - 8)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				sel = n
				_show_detail(true))
		row.draw.connect(_draw_row.bind(row, n))
		row.set_drag_forwarding(func(_at: Vector2): return _drag_row(n),
			func(_at: Vector2, data: Variant): return _can_drop_row(n, data),
			func(_at: Vector2, data: Variant): _drop_row(n, data))
		_list.add_child(row)
		var slot := SkillSlot.new()
		slot.custom_minimum_size = Vector2(62, 62)
		slot.size = Vector2(62, 62)
		slot.position = Vector2(34, 6)
		slot.icon = SkillInfo.icon(key, k, asleep)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_process(false)
		row.add_child(slot)
		var num := Paper.label(str(n + 1), 20, DIM, Paper.display())
		num.position = Vector2(4, 0)
		num.size = Vector2(26, ROW_H - 8)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(num)
		var nm := Paper.label(String(info["name"]).to_upper(), 16, Paper.CREAM, Paper.display())
		nm.position = Vector2(108, 6)
		nm.size = Vector2(250, 24)
		nm.clip_text = true
		var px := 16
		while px > 11 and Paper.display().get_string_size(nm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 248.0:
			px -= 1
		nm.add_theme_font_size_override("font_size", px)
		row.add_child(nm)
		var chip := Chip.new()
		chip.px = 10
		chip.pad = 8.0
		chip.skew = 8.0
		chip.border = 2.0
		chip.shadow = Vector2.ZERO
		chip.fill = SkillInfo.TYPE_COL.get(info["type"], Paper.CREAM)
		chip.text = String(info["type"]).to_upper()
		chip.position = Vector2(108, 36)
		row.add_child(chip)
		var meta := Paper.label(_short_meta(info), 13, DIM, Paper.body(800))
		meta.position = Vector2(116 + chip.size.x, 38)
		meta.size = Vector2(250, 20)
		row.add_child(meta)
		# tecla atual do slot (Binds): informação separada do número do slot
		var keychip := Chip.new()
		keychip.px = 13
		keychip.pad = 9.0
		keychip.skew = 0.0
		keychip.border = 3.0
		keychip.shadow = Vector2(-3, 4)
		keychip.text = Binds.label("skill_%d" % (n + 1))
		keychip.position = Vector2(436 - keychip.size.x, 22)
		row.add_child(keychip)
		_rows.append({"root": row, "slot": slot})
		row.modulate.a = 0.0
		row.create_tween().tween_property(row, "modulate:a", 1.0, 0.14).set_delay(n * 0.03)


func _short_meta(info: Dictionary) -> String:
	var parts: Array = []
	if float(info["cd"]) > 0.0:
		parts.append("%s s" % SkillInfo._n(info["cd"]))
	if float(info["cast"]) > 0.0:
		parts.append("cast %s s" % SkillInfo._n(info["cast"]))
	if String(info["cost"]) != "":
		parts.append(String(info["cost"]))
	return "  ·  ".join(parts)


func _draw_row(row: Control, n: int) -> void:
	var on := n == sel
	var pts := Paper.skew_rect(row.size, 4.0)
	if on:
		row.draw_colored_polygon(Paper.moved(pts, Vector2(5, 6)), Paper.INK)
		row.draw_colored_polygon(pts, Paper.INK)
		row.draw_colored_polygon(Paper.inset(pts, 4.0), _th.get("deep2", Color("2B3384")))
		row.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Paper.GOLD, 3.0, true)
	else:
		row.draw_colored_polygon(pts, Color(0.07, 0.08, 0.2, 0.55))
	if n == _drop_at:
		# é aqui que a habilidade arrastada vai cair
		row.draw_colored_polygon(pts, Color(Paper.GOLD.r, Paper.GOLD.g, Paper.GOLD.b, 0.22))
		row.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Paper.GOLD, 4.0, true)


func _show_detail(animate: bool) -> void:
	var key := _key()
	var list: Array = SkillInfo.kit(key, asleep)
	sel = clampi(sel, 0, list.size() - 1)
	for n in _rows.size():
		_rows[n]["root"].queue_redraw()
		_rows[n]["slot"].selected = n == sel
		_rows[n]["slot"].queue_redraw()
	_pointer.position = Vector2(14, _list.position.y + sel * ROW_H + 21)
	var info := SkillInfo.info(key, _slot_at(sel), asleep)
	_d_icon.texture = SkillInfo.icon(key, _slot_at(sel), asleep)
	_d_slot.text = "SLOT %d%s" % [sel + 1, "  ·  DORMINDO" if asleep else ""]
	_d_name.text = String(info["name"]).to_upper()
	var px := 26
	while px > 15 and _too_big(_d_name.text, px):
		px -= 1
	_d_name.add_theme_font_size_override("font_size", px)
	for c in _d_type_holder.get_children():
		c.queue_free()
	var chip := Chip.new()
	chip.px = 13
	chip.pad = 12.0
	chip.border = 3.0
	chip.shadow = Vector2(-3, 4)
	chip.fill = SkillInfo.TYPE_COL.get(info["type"], Paper.CREAM)
	chip.text = String(info["type"]).to_upper()
	_d_type_holder.add_child(chip)
	if info["big"]:
		var star := Chip.new()
		star.px = 13
		star.pad = 10.0
		star.border = 3.0
		star.shadow = Vector2(-3, 4)
		star.fill = Paper.GOLD
		star.text = "DESTAQUE"
		star.position = Vector2(chip.size.x + 10, 0)
		_d_type_holder.add_child(star)
	# quadro de números: recarga, conjuração, custo, tecla
	for c in _d_stats.get_children():
		c.queue_free()
	var cells := [
		["RECARGA", ("%s s" % SkillInfo._n(info["cd"])) if float(info["cd"]) > 0.0 else "sem recarga"],
		["CONJURAÇÃO", ("%s s" % SkillInfo._n(info["cast"])) if float(info["cast"]) > 0.0 else "instantânea"],
		["CUSTO", String(info["cost"]) if String(info["cost"]) != "" else "nenhum"],
		["ATALHO", Binds.label("skill_%d" % (sel + 1))],
	]
	for k in cells.size():
		var cell := CutPanel.make(Rect2((k % 2) * 182, (k / 2) * 64, 172, 56), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.INK, 0, Vector2.ZERO)
		_d_stats.add_child(cell)
		var cl := Paper.label(cells[k][0], 11, Paper.GOLD, Paper.display())
		cl.position = Vector2(10, 5)
		cl.size = Vector2(152, 16)
		cell.add_child(cl)
		var cv := Paper.label(cells[k][1], 18, Paper.CREAM, Paper.body(800))
		cv.position = Vector2(10, 22)
		cv.size = Vector2(156, 28)
		cv.clip_text = true
		cell.add_child(cv)
	_d_desc.text = info["desc"]
	if animate:
		_d_icon.pivot_offset = _d_icon.size * 0.5
		_d_icon.scale = Vector2.ONE * 0.82
		_d_icon.create_tween().tween_property(_d_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _too_big(text: String, px: int) -> bool:
	# o nome cabe em até três linhas de 212 px?
	var f := Paper.display()
	var lines := 1
	var cur := 0.0
	for w in text.split(" "):
		var ww := f.get_string_size(w + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if ww > 212.0:
			return true
		if cur + ww > 212.0:
			lines += 1
			cur = ww
		else:
			cur += ww
	return lines * (px + 2) > 84


func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree() or not _art.visible:
		return
	_t += delta
	# a arte respira devagar, como na tela de cartas
	_art.position.y = _art_home.y + sin(_t * 1.7) * 7.0


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var count: int = SkillInfo.kit(_key(), asleep).size()
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _switch(-1)
		KEY_D, KEY_RIGHT: _switch(1)
		KEY_W, KEY_UP:
			sel = posmod(sel - 1, count)
			_show_detail(true)
		KEY_S, KEY_DOWN:
			sel = posmod(sel + 1, count)
			_show_detail(true)
		KEY_TAB: _toggle_mode()
		KEY_R:
			Knowledge.reset_layout(hero)
			_fill_list()
			_show_detail(true)
		KEY_ESCAPE: back_pressed.emit()
		_: return
	get_viewport().set_input_as_handled()
