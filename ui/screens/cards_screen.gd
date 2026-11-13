class_name CardsScreen
extends Control
## Cartas de UM herói por vez (design em design/tela-cartas-v2, prancha "Motion").
## À esquerda os slots equipados; embaixo a mão, numa roleta; à direita a arte do herói,
## os detalhes da carta e o botão de luta. As cores do cenário seguem o tema do herói.
##   clicar numa carta da roleta: traz pro foco · clicar numa equipada: mostra os detalhes
##   segurar e arrastar: roleta -> slot equipa (ou troca) · slot -> slot troca · slot -> roleta tira
## A tela é montada em código sobre um palco fixo de 1280x720; as medidas estão nas constantes.

signal ready_pressed
signal back_pressed

const STAGE := Vector2(1280, 720)
## Roleta: centro fora da tela, cartas a RADIUS do centro, uma a cada STEP graus.
const HUB := Vector2(450, 1100)
const RADIUS := 560.0
const STEP := 13.0
const RIM := 672.0
const SLOT_AT := {
	"purple": [Vector2(60, 96), Vector2(176, 96)],
	"gold": [Vector2(308, 96), Vector2(424, 96), Vector2(540, 96)],
	"white": [Vector2(118, 240), Vector2(234, 240), Vector2(350, 240), Vector2(466, 240)],
	"item": [Vector2(741, 184)],
}
## Frase do balão. Quem não tem frase própria usa o `blurb` do herói.
const QUOTES := {"maga": "Relaxa, eu resolvo. Como sempre."}
const CARD_HALF := Vector2(CardView.W, CardView.H) * 0.5


## Control que desenha com uma função: `fn` recebe o próprio nó.
class Draw extends Control:
	var fn: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## Etiqueta inclinada com texto; `fit()` ajusta a largura ao texto.
class Tag extends Control:
	var text := ""
	var px := 12
	var bg := Paper.INK
	var fg := Paper.CREAM
	var border := 0.0
	var skew := 12.0
	var pad := 8.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func fit(height: float) -> void:
		size = Vector2(Paper.display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + (pad + border) * 2.0, height)
		queue_redraw()

	func _draw() -> void:
		var pts := Paper.skew_rect(size, skew)
		if border > 0.0:
			draw_colored_polygon(pts, Paper.INK)
		draw_colored_polygon(Paper.inset(pts, border), bg)
		var f := Paper.display()
		draw_string(f, Vector2(0, size.y * 0.5 + (f.get_ascent(px) - f.get_descent(px)) * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, px, fg)


var hero := 0
var _show_ready := true
var _th: Dictionary = Paper.THEMES["tank"]
var _built := false
var _t := 0.0

var _stage: Control
var _cards: Control
var _top: Control
var _bg: Draw
var _wheel: Draw
var _ticks: Control
var _stripes: Array = []
var _stage_block: CutPanel
var _pointer: Draw
var _tray: CutPanel
var _tray_band: Draw
var _item_tray: CutPanel
var _art: Control
var _art_tex: TextureRect
var _face_frame: CutPanel
var _face_tex: TextureRect
var _bubble: Control
var _bubble_text: Label
var _boss: Draw
var _strip_bar: CutPanel
var _chip: Draw
var _chip_face: TextureRect
var _faces: Array = []
var _name_tag: Control
var _name_panel: CutPanel
var _name_label: Label
var _role_tag: Tag
var _hp: Draw
var _d_tile: Draw
var _d_name: Label
var _d_kind: Tag
var _d_cat: Tag
var _d_desc: Label
var _ready_btn: ShineButton
var _ready_shadow: Draw

## Mão: ids na ordem da roleta. `_focus` é a carta do topo.
var _hand: Array = []
var _focus := 0
## Carta equipada selecionada por clique (índice em _slots), ou -1: os detalhes mostram ela.
var _sel := -1
## Um dicionário por carta: {cv, src ("slot"/"hand"), idx, id, kind, home, rot0, hover, press, drag_ok, alt, tw, spoke}
var _slots: Array = []
var _spokes: Array = []
var _pend = null
var _drag = null
var _ghost: CardView
var _over := -1
var _detail_id := ""
var _mouse_at := Vector2.ZERO


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		# aberta sozinha (F6): dados de exemplo, sem tocar no save
		Knowledge.persist = false
		for id in ["stack", "pair", "spread", "mitigate", "provoke", "instinct", "sharpen", "plate", "potion", "revive", "eshield", "spark", "secondskin", "phoenix"]:
			Knowledge.owned[id] = true
		Knowledge.dps_known["maga"] = true
		Knowledge.mastery["link"] = 2
		for id in ["stack", "sharpen", "potion", "dps"]:
			Knowledge.equip(3, id)
		open(3)


func open(hero_idx: int, show_ready := true) -> void:
	hero = clampi(hero_idx, 0, 3)
	_show_ready = show_ready
	refresh(true)


func _switch(dir: int) -> void:
	_go(posmod(hero + dir, 4), dir)


func _go(to: int, dir: int) -> void:
	if to == hero:
		return
	hero = to
	Knowledge.start_hero = hero
	Knowledge.save()
	refresh(true, dir)


func refresh(animate := false, dir := 0) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	_th = Paper.THEMES.get(h["key"], Paper.THEMES["tank"])
	_cancel_drag()
	_sel = -1
	# cenário e painéis no tema do herói
	_bg.queue_redraw()
	_wheel.queue_redraw()
	_stage_block.fill = _th["deep"]
	_stripes[0].fill = _th["bg2"]
	_stripes[1].fill = _th["acc"]
	_tray.fill = _th["deep"]
	_tray_band.queue_redraw()
	_item_tray.fill = _th["deep2"]
	_strip_bar.fill = _th["deep2"]
	_boss.queue_redraw()
	_chip.queue_redraw()
	_chip_face.texture = load("res://assets/portraits/%s_face.png" % h["key"])
	_build_faces()
	# arte: ilustração inteira se existir, senão o rosto numa moldura
	var art := ""
	for ext in ["webp", "png"]:
		var p := "res://assets/portraits/%s_art.%s" % [h["key"], ext]
		if ResourceLoader.exists(p):
			art = p
			break
	_art_tex.visible = art != ""
	_face_frame.visible = art == ""
	if art != "":
		_art_tex.texture = load(art)
	else:
		_face_tex.texture = load("res://assets/portraits/%s_face.png" % h["key"])
	_bubble_text.text = QUOTES.get(h["key"], h["blurb"])
	# nome, classe e vida
	var nm := String(h["name"]).to_upper()
	_name_label.text = nm
	var nw := maxf(150.0, Paper.display().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 56.0)
	_name_panel.size = Vector2(nw, 58)
	_name_label.size = Vector2(nw, 58)
	_name_label.pivot_offset = _name_label.size * 0.5
	_name_tag.pivot_offset = Vector2(nw, 58) * 0.5
	_role_tag.text = String(h["role"]).to_upper()
	_role_tag.bg = _th["acc"]
	_role_tag.fg = _th["acc_t"]
	_role_tag.fit(28)
	_hp.position = Vector2(_role_tag.position.x + _role_tag.size.x + 14.0, 446)
	_hp.queue_redraw()
	_ready_btn.visible = _show_ready
	_ready_shadow.visible = _show_ready
	# mão: o que ele tem e não está equipado, depois o que ainda não conquistou
	_hand = _hand_list()
	# começa no meio das cartas que ele já tem
	var mine := 0
	for id in _hand:
		if Knowledge.is_owned_by(hero, id):
			mine += 1
	_focus = clampi(mine / 2, 0, maxi(0, _hand.size() - 1))
	_ticks.rotation = deg_to_rad(-_focus * STEP)
	_build_cards(animate)
	if animate:
		_art.modulate.a = 0.0
		var from := 60.0 if dir >= 0 else -60.0
		_art.position.x = 860.0 + from
		var tw := _art.create_tween().set_parallel(true)
		tw.tween_property(_art, "position:x", 860.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_art, "modulate:a", 1.0, 0.18)


# ---------------------------------------------------------------- montagem (uma vez)

## Põe `node` em `parent`. Sem `at`, o nó fica onde já estava (painéis criados com um Rect2).
func _add(parent: Control, node: Control, at := Vector2.INF, sz := Vector2.ZERO):
	if at != Vector2.INF:
		node.position = at
	if sz != Vector2.ZERO:
		node.size = sz
	parent.add_child(node)
	return node


func _drawer(parent: Control, fn: Callable, at := Vector2.INF, sz := Vector2.ZERO) -> Draw:
	var d := Draw.new()
	d.fn = fn
	_add(parent, d, at, sz)
	return d


func _build() -> void:
	if _built:
		return
	_built = true
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	resized.connect(_center)
	_center()

	_bg = _drawer(_stage, _draw_bg)
	# palco da arte: bloco escuro + três faixas que deslizam devagar
	_add(_stage, CutPanel.make(Rect2(790, 0, 500, 720), [[.22, 0], [1, 0], [1, 1], [.06, 1], [.18, .56], [.08, .44]], Paper.INK, 0, Vector2.ZERO))
	_stage_block = _add(_stage, CutPanel.make(Rect2(800, 0, 480, 720), [[.22, 0], [1, 0], [1, 1], [.06, 1], [.18, .56], [.08, .44]], Paper.NAVY, 0, Vector2.ZERO))
	_stripes = [
		_add(_stage, CutPanel.make(Rect2(850, 96, 470, 190), [[0, .74], [1, 0], [1, .42], [.05, 1]], Paper.GOLD, 0, Vector2.ZERO)),
		_add(_stage, CutPanel.make(Rect2(866, 214, 450, 150), [[0, .78], [1, 0], [1, .3], [.06, 1]], Paper.RED, 0, Vector2.ZERO)),
		_add(_stage, CutPanel.make(Rect2(900, 300, 420, 120), [[0, .86], [1, 0], [1, .14], [.04, 1]], Paper.CREAM, 0, Vector2.ZERO)),
	]
	for s in _stripes:
		s.set_meta("home", s.position)

	# roleta: discos fixos, marcas do aro que giram com as cartas, ponteiro
	_wheel = _drawer(_stage, _draw_wheel)
	_ticks = Control.new()
	_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _ticks, HUB)
	_drawer(_ticks, _draw_ticks)
	var prev := _arrow(-1)
	_add(_stage, prev, Vector2(296, 668), Vector2(44, 44))
	prev.pressed.connect(func(): _spin(-1))
	var nxt := _arrow(1)
	_add(_stage, nxt, Vector2(560, 668), Vector2(44, 44))
	nxt.pressed.connect(func(): _spin(1))
	var hub_label := Paper.label("SUAS CARTAS", 21, Paper.CREAM, Paper.display())
	hub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_stage, hub_label, Vector2(348, 672), Vector2(204, 36))

	# bandejas dos slots
	_tray = _add(_stage, CutPanel.make(Rect2(36, 84, 632, 314), [[0, .04], [1, 0], [.98, 1], [.02, .96]], Paper.NAVY))
	_tray_band = _drawer(_stage, func(d: Draw): d.draw_rect(Rect2(Vector2.ZERO, d.size), _th["deep2"]), Vector2(46, 236), Vector2(612, 14))
	_tray_band.rotation = deg_to_rad(-1.0)
	_item_tray = _add(_stage, CutPanel.make(Rect2(700, 110, 190, 262), [[.08, 0], [1, .06], [.94, 1], [0, .92]], Paper.BROWN))
	var item_tag := Tag.new()
	item_tag.text = "ITEM ON HOLD"
	item_tag.px = 14
	item_tag.bg = Paper.CYAN
	item_tag.fg = Paper.INK
	item_tag.border = 3
	item_tag.skew = 10
	_add(_stage, item_tag, Vector2(716, 134), Vector2(158, 34))
	item_tag.pivot_offset = item_tag.size * 0.5
	item_tag.rotation = deg_to_rad(-4.0)

	# arte do herói (flutua) e o balão da frase
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _art, Vector2(860, 50), Vector2(430, 500))
	_art.pivot_offset = Vector2(215, 400)
	_art_tex = TextureRect.new()
	_art_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_art, _art_tex, Vector2.ZERO, Vector2(430, 500))
	_face_frame = _add(_art, CutPanel.make(Rect2(120, 70, 210, 290), [[.02, 0], [1, .03], [.97, 1], [0, .97]], Paper.CREAM, 6, Vector2(9, 9)))
	_face_frame.pivot_offset = _face_frame.size * 0.5
	_face_frame.rotation = deg_to_rad(-4.0)
	_face_tex = TextureRect.new()
	_face_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_face_frame, _face_tex, Vector2(14, 14), Vector2(182, 262))
	_bubble = Control.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _bubble, Vector2(876, 62), Vector2(156, 84))
	_bubble.pivot_offset = Vector2(78, 42)
	_add(_bubble, CutPanel.make(Rect2(0, 0, 150, 78), [[0, .1], [1, 0], [.96, .86], [.8, .88], [.84, 1], [.62, .9], [.04, .96]], Paper.CREAM, 0, Vector2(6, 6)))
	_bubble_text = Paper.label("", 14, Paper.INK, Paper.body(700))
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.add_theme_constant_override("line_spacing", -4)
	_bubble_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_bubble, _bubble_text, Vector2(22, 13), Vector2(118, 54))

	# cartas (slots + mão) e o ponteiro por cima delas
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _cards)
	_pointer = _drawer(_stage, _draw_pointer, Vector2(428, 398), Vector2(44, 36))
	_pointer.z_index = 8

	# tudo que fica por cima das cartas
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.z_index = 10
	_add(_stage, _top)
	_add(_top, CutPanel.make(Rect2(20, 10, 216, 62), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 4))
	var title := Paper.label("CARTAS", 38, Paper.INK, Paper.display())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_top, title, Vector2(20, 10), Vector2(216, 62))
	title.pivot_offset = title.size * 0.5
	title.rotation = deg_to_rad(-2.0)
	_boss = _drawer(_top, _draw_boss, Vector2(245, 22), Vector2(186, 42))

	# seletor de herói
	_strip_bar = _add(_top, CutPanel.make(Rect2(448, 10, 450, 62), [[.02, 0], [1, .06], [.98, 1], [0, .92]], Paper.NAVY, 4))
	var hp := _arrow(-1)
	_add(_top, hp, Vector2(464, 19), Vector2(40, 44))
	hp.pressed.connect(func(): _switch(-1))
	var hn := _arrow(1)
	_add(_top, hn, Vector2(850, 19), Vector2(40, 44))
	hn.pressed.connect(func(): _switch(1))
	_chip = _drawer(_top, _draw_chip, Vector2(514, 12), Vector2(186, 58))
	_chip.pivot_offset = _chip.size * 0.5
	_chip_face = TextureRect.new()
	_chip_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chip_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_chip_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_chip, _chip_face, Vector2(3, 3), Vector2(44, 52))
	_chip.rotation = deg_to_rad(-2.0)

	# voltar
	_drawer(_top, func(d: Draw): d.draw_colored_polygon(Paper.skew_rect(d.size, 12), Paper.INK), Vector2(1141, 21), Vector2(120, 40))
	var back := ShineButton.new()
	back.text = "VOLTAR"
	back.font_px = 15
	back.chevron = -1
	back.chevron_px = 14
	back.skew = 12
	back.fill = Paper.CREAM
	back.fill_hover = Paper.INK
	back.fg = Paper.INK
	back.fg_hover = Paper.CREAM
	_add(_top, back, Vector2(1136, 16), Vector2(120, 40))
	back.pressed.connect(func(): back_pressed.emit())

	# nome, classe e vida, colados sobre a arte
	_name_tag = Control.new()
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_top, _name_tag, Vector2(890, 382), Vector2(196, 58))
	_name_panel = _add(_name_tag, CutPanel.make(Rect2(0, 0, 196, 58), [[0, .08], [1, 0], [.96, 1], [.03, .92]], Paper.CREAM, 4, Vector2(8, 8)))
	_name_label = Paper.label("", 40, Paper.INK, Paper.display())
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_name_tag, _name_label, Vector2.ZERO, Vector2(196, 58))
	_name_label.rotation = deg_to_rad(-2.0)
	_role_tag = Tag.new()
	_role_tag.border = 3
	_role_tag.pad = 12
	_add(_top, _role_tag, Vector2(902, 446))
	_hp = _drawer(_top, _draw_hp, Vector2(1060, 446), Vector2(140, 28))

	# detalhes da carta
	_add(_top, CutPanel.make(Rect2(916, 480, 348, 124), [[.02, 0], [1, .05], [.97, 1], [0, .94]], Paper.CREAM, 5, Vector2(8, 8)))
	_d_tile = _drawer(_top, _draw_tile, Vector2(936, 496), Vector2(44, 44))
	_d_tile.pivot_offset = Vector2(22, 22)
	_d_tile.rotation = deg_to_rad(-6.0)
	_d_name = Paper.label("", 22, Paper.INK, Paper.display())
	_add(_top, _d_name, Vector2(992, 488), Vector2(260, 30))
	_d_kind = Tag.new()
	_d_kind.px = 11
	_add(_top, _d_kind, Vector2(994, 521))
	_d_cat = Tag.new()
	_d_cat.px = 11
	_add(_top, _d_cat, Vector2(1060, 521))
	_d_desc = Paper.label("", 16, Paper.INK, Paper.body(700))
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.add_theme_constant_override("line_spacing", -5)
	_add(_top, _d_desc, Vector2(938, 546), Vector2(306, 48))

	# READY FOR BATTLE
	var ready_shape := [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	_ready_shadow = _drawer(_top, func(d: Draw): d.draw_colored_polygon(Paper.poly(d.size, ready_shape), Paper.INK), Vector2(942, 628), Vector2(330, 84))
	_ready_btn = ShineButton.new()
	_ready_btn.text = "READY FOR BATTLE"
	_ready_btn.font_px = 25
	_ready_btn.shape = ready_shape
	_ready_btn.border = 6
	_ready_btn.fill = Paper.GOLD
	_ready_btn.fill_hover = Paper.GOLD_HOVER
	_ready_btn.fg = Paper.INK
	_ready_btn.fg_hover = Paper.RED
	_ready_btn.text_rot = -3
	_ready_btn.idle = true
	_ready_btn.hover_scale = 1.05
	_add(_top, _ready_btn, Vector2(932, 618), Vector2(330, 84))
	_ready_btn.pressed.connect(func(): ready_pressed.emit())


func _arrow(dir: int) -> ShineButton:
	var b := ShineButton.new()
	b.chevron = dir
	return b


func _center() -> void:
	_stage.position = ((size - STAGE) * 0.5).floor()


# ---------------------------------------------------------------- desenho

func _draw_bg(d: Draw) -> void:
	# o fundo passa do palco pros lados, pra janelas mais largas que 16:9
	d.draw_rect(Rect2(-1200, -600, 3680, 1920), _th["bg"])
	var dot: Color = _th["bg2"]
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.5, dot)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(760, 420), [[0, 0], [1, 0], [.62, .46], [.78, .62], [.3, 1], [0, .84]]), Vector2(-40, -40)), dot)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(420, 220), [[0, .3], [.7, 0], [1, .22], [.4, .62], [0, 1]]), Vector2(-30, 300)), Paper.CREAM)
	d.draw_rect(Rect2(1280, -600, 1200, 1920), _th["deep"])


func _disc(d: Draw, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for n in 240:
		pts.append(HUB + Vector2.from_angle(TAU * n / 240.0) * r)
	d.draw_colored_polygon(pts, col)


func _draw_wheel(d: Draw) -> void:
	_disc(d, RIM, Paper.INK)
	_disc(d, 666, Paper.CREAM)
	_disc(d, 652, Paper.INK)
	_disc(d, 648, Paper.BROWN)
	_disc(d, 470, Paper.INK)
	_disc(d, 464, _th["deep"])


func _draw_ticks(d: Draw) -> void:
	for n in range(-14, 70):
		d.draw_set_transform(Vector2.ZERO, deg_to_rad((n + 0.5) * STEP), Vector2.ONE)
		d.draw_rect(Rect2(-3, -666, 6, 14), Paper.INK)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pointer(d: Draw) -> void:
	d.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(44, 0), Vector2(22, 36)]), Paper.INK)
	d.draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(36, 4), Vector2(22, 27)]), Paper.GOLD)


func _draw_boss(d: Draw) -> void:
	var pts := Paper.skew_rect(d.size, 14)
	d.draw_colored_polygon(Paper.moved(pts, Vector2(5, 6)), Paper.INK)
	d.draw_colored_polygon(pts, Paper.INK)
	d.draw_colored_polygon(Paper.inset(pts, 3), Paper.PINK)
	var f := Paper.display()
	var nm: String = Knowledge.BOSS_INFO[Knowledge.boss]["name"] if _show_ready else "GEAR"
	var vs := "VS" if _show_ready else ""
	var w1 := f.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var px := 17
	while px > 11 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + w1 + 30 > d.size.x:
		px -= 1
	var w2 := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var gap := 8.0 if vs != "" else 0.0
	var x := (d.size.x - w1 - gap - w2) * 0.5
	if vs != "":
		d.draw_string(f, Vector2(x, 26), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Paper.INK)
	d.draw_string(f, Vector2(x + w1 + gap, 27), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Paper.INK)


func _draw_chip(d: Draw) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	d.draw_rect(Rect2(Vector2.ZERO, d.size), Paper.INK)
	d.draw_rect(Rect2(3, 3, d.size.x - 6, d.size.y - 6), Paper.CREAM)
	d.draw_rect(Rect2(47, 3, 3, 52), Paper.INK)
	var f := Paper.display(0.0)
	d.draw_string(f, Vector2(60, 28), String(h["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 120, 20, Paper.INK)
	var role_px := 14
	while role_px > 10 and Paper.body(700).get_string_size(h["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, role_px).x > 120.0:
		role_px -= 1
	d.draw_string(Paper.body(700), Vector2(60, 46), h["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, role_px, Color("3e2413"))


func _draw_hp(d: Draw) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	var f := Paper.display()
	var num := str(h["hp"])
	var w := 24.0 + f.get_string_size("HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8 + 56 + 8 + f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	d.draw_colored_polygon(Paper.skew_rect(Vector2(w, 28), 12), Paper.INK)
	d.draw_string(f, Vector2(12, 19), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Paper.CREAM)
	var x := 12.0 + f.get_string_size("HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
	d.draw_rect(Rect2(x, 9, 56, 10), Paper.GREEN)
	d.draw_string(f, Vector2(x + 64, 20), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Paper.CREAM)


func _draw_tile(d: Draw) -> void:
	if _detail_id == "":
		return
	var c: Dictionary = Knowledge.CARDS[_detail_id]
	d.draw_rect(Rect2(Vector2.ZERO, d.size), Paper.INK)
	d.draw_rect(Rect2(3, 3, 38, 38), Paper.KIND[c["kind"]]["bg"])
	Paper.draw_suit(d, c["cat"], Vector2(9, 9), 26, Paper.INK)


# ---------------------------------------------------------------- seletor de herói

func _build_faces() -> void:
	for b in _faces:
		_top.remove_child(b)
		b.queue_free()
	_faces.clear()
	var xs := [708.0, 755.0, 802.0]
	var rots := [3.0, -3.0, 2.0]
	var k := 0
	for i in 4:
		if i == hero:
			continue
		var b := ShineButton.new()
		b.texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[i]["key"])
		b.skew = 0
		b.hover_scale = 1.15
		_add(_top, b, Vector2(xs[k], 17), Vector2(40, 48))
		b.rotation = deg_to_rad(rots[k])
		b.pressed.connect(_go.bind(i, 1 if i > hero else -1))
		_faces.append(b)
		k += 1


# ---------------------------------------------------------------- cartas

## Cartas do herói que não estão equipadas, e depois as que ele ainda não tem (de verso, com a maestria).
func _hand_list() -> Array:
	var out: Array = []
	for id in Knowledge.inventory(hero):
		out.append(id)
	for kind in Knowledge.KINDS:
		for id in Knowledge.CARDS:
			if Knowledge.CARDS[id]["kind"] == kind and Knowledge.usable(hero, id) and not Knowledge.is_owned_by(hero, id):
				out.append(id)
	return out


## Depois de mexer nos slots: mantém a ordem da roleta, tira o que foi equipado e põe no fim o que faltar.
func _sync_hand() -> void:
	var want := _hand_list()
	var out: Array = []
	for id in _hand:
		if want.has(id) and not out.has(id):
			out.append(id)
	for id in want:
		if not out.has(id):
			out.append(id)
	_hand = out
	_focus = clampi(_focus, 0, maxi(0, _hand.size() - 1))


func _build_cards(deal := false, drop := "") -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_slots.clear()
	_spokes.clear()
	var deck := Knowledge.deck(hero)
	for kind in Knowledge.KINDS:
		for n in Knowledge.SLOTS[kind]:
			var id: String = deck[kind][n]
			var cv := CardView.make(id) if id != "" else CardView.empty(kind)
			cv.position = SLOT_AT[kind][n]
			_cards.add_child(cv)
			var idx := _slots.size()
			var info := {"cv": cv, "src": "slot", "idx": idx, "n": n, "id": id, "kind": kind, "home": cv.position,
				"rot0": 3.0 if kind == "item" else 0.0, "hover": false, "press": false, "drag_ok": id != "", "alt": idx % 2 == 1, "tw": null, "spoke": null}
			_slots.append(info)
			if id != "":
				_wire(info)
			else:
				cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in _hand.size():
		var id: String = _hand[k]
		var mine := Knowledge.is_owned_by(hero, id)
		var spoke := Control.new()
		spoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spoke.position = HUB
		spoke.rotation = deg_to_rad((k - _focus) * STEP)
		_cards.add_child(spoke)
		var cv := CardView.make(id, "face" if mine else "back")
		if not mine:
			var key := Knowledge.mastery_key(id)
			if key != "":
				cv.progress = Knowledge.mastery_of(key)
		cv.position = Vector2(-CARD_HALF.x, -RADIUS - CARD_HALF.y)
		spoke.add_child(cv)
		var info := {"cv": cv, "src": "hand", "idx": k, "n": k, "id": id, "kind": Knowledge.kind_of(id), "home": cv.position,
			"rot0": 0.0, "hover": false, "press": false, "drag_ok": mine, "alt": k % 2 == 1, "tw": null, "spoke": spoke}
		_spokes.append(info)
		_wire(info)
	for info in _slots + _spokes:
		_settle(info, true)
	if deal:
		for info in _slots:
			if info["id"] != "":
				_deal(info, info["idx"] * 0.045)
		for info in _spokes:
			_deal(info, 0.35 + info["idx"] * 0.04)
	if drop != "":
		# a carta que acabou de encaixar chega maior e inclinada e assenta
		var list: Array = _slots if drop.begins_with("s") else _spokes
		var at := int(drop.substr(1))
		if at < list.size():
			var cv: CardView = list[at]["cv"]
			cv.scale *= 1.35
			cv.rotation += deg_to_rad(8.0)
			_settle(list[at], false, 0.35)
	_update_details()


func _wire(info: Dictionary) -> void:
	var cv: CardView = info["cv"]
	cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if info["drag_ok"] else Control.CURSOR_ARROW
	cv.mouse_entered.connect(func():
		info["hover"] = true
		_settle(info))
	cv.mouse_exited.connect(func():
		info["hover"] = false
		_settle(info))
	cv.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_pend = {"info": info, "start": _mouse_at}
			info["press"] = true
			_settle(info))


## Escala, giro (graus) e deslocamento vertical que a carta deve ter agora.
func _pose(info: Dictionary) -> Array:
	var sc := 1.0
	var rot := 0.0
	var dy := 0.0
	var focus: bool = info["src"] == "hand" and info["idx"] == _focus and _sel < 0
	if focus:
		sc = 1.15
		dy = -14.0
	if info["src"] == "slot" and info["idx"] == _sel:
		sc = 1.06
	if info["hover"] and _drag == null and info["id"] != "":
		if focus:
			sc = 1.2
			rot = 2.0
			dy = -18.0
		else:
			sc = 1.09
			rot = 3.0 if info["alt"] else -3.0
			dy = -12.0
	if info["press"] and _drag == null:
		sc = 1.02
	if info["src"] == "slot" and info["idx"] == _over:
		sc = 1.1
	return [sc, rot, dy]


## Leva a carta pra pose dela e atualiza moldura, contorno e ordem de desenho.
func _settle(info: Dictionary, snap := false, time := 0.22) -> void:
	var cv: CardView = info["cv"]
	if not is_instance_valid(cv):
		return
	var p := _pose(info)
	var sc := Vector2.ONE * float(p[0])
	var rot := deg_to_rad(float(info["rot0"]) + float(p[1]))
	var pos: Vector2 = info["home"] + Vector2(0, p[2])
	var lifted: bool = _drag != null and is_same(_drag, info)
	var hand: bool = info["src"] == "hand"
	cv.halo = hand and info["idx"] == _focus and _sel < 0
	if info["src"] == "slot":
		if _drag != null and not lifted and info["kind"] == _drag["kind"]:
			var on: bool = info["idx"] == _over
			cv.ring = Paper.GOLD if on else Paper.CREAM
			cv.ring_w = 6.0 if on else 4.0
			if on:
				cv.ring_gap = 4.0
		elif info["idx"] == _sel and _drag == null:
			cv.ring = Paper.GOLD
			cv.ring_w = 5.0
			cv.ring_gap = 3.0
		else:
			cv.ring = Color(0, 0, 0, 0)
	var z := 9 if (info["hover"] and _drag == null) else (5 if cv.halo or (hand and info["idx"] == _focus) else (2 if hand else 0))
	if hand:
		info["spoke"].z_index = z
	else:
		cv.z_index = z
	if info["tw"] != null:
		info["tw"].kill()
		info["tw"] = null
	if snap:
		cv.scale = sc
		cv.rotation = rot
		cv.position = pos
		cv.modulate.a = 0.25 if lifted else 1.0
		return
	var tw := cv.create_tween().set_parallel(true)
	tw.tween_property(cv, "scale", sc, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation", rot, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "position", pos, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "modulate:a", 0.25 if lifted else 1.0, 0.15)
	info["tw"] = tw


## Entrada: a carta sobe de baixo, pequena e transparente, e assenta. Cada uma com seu atraso.
func _deal(info: Dictionary, delay: float) -> void:
	var cv: CardView = info["cv"]
	var sc := cv.scale
	var pos := cv.position
	cv.scale = sc * 0.7
	cv.position = pos + Vector2(0, 40)
	cv.modulate.a = 0.0
	var tw := cv.create_tween().set_parallel(true)
	tw.tween_property(cv, "scale", sc, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(cv, "position", pos, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(cv, "modulate:a", 1.0, 0.2).set_delay(delay)
	info["tw"] = tw


func _settle_all() -> void:
	for info in _slots + _spokes:
		_settle(info)


# ---------------------------------------------------------------- roleta

func _spin(dir: int) -> void:
	_set_focus(_focus + dir)


func _set_focus(k: int) -> void:
	_focus = clampi(k, 0, maxi(0, _hand.size() - 1))
	_sel = -1
	for info in _spokes:
		var sp: Control = info["spoke"]
		var tw := sp.create_tween()
		# passa um pouco do ponto e volta, como roleta parando
		tw.tween_property(sp, "rotation", deg_to_rad((info["idx"] - _focus) * STEP), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ticks.create_tween().tween_property(_ticks, "rotation", deg_to_rad(-_focus * STEP), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_settle_all()
	_update_details()


# ---------------------------------------------------------------- arrastar e soltar

func _slot_at(p: Vector2) -> int:
	for info in _slots:
		if Rect2(info["home"] - Vector2(8, 8), Vector2(CardView.W + 16, CardView.H + 16)).has_point(p):
			return info["idx"]
	return -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouse:
		# posição do ponteiro em coordenadas do palco 1280x720
		_mouse_at = _stage.get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseButton and event.pressed and _pend == null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_spin(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_spin(1)
	if _pend == null:
		return
	var info: Dictionary = _pend["info"]
	if event is InputEventMouseMotion:
		var p := _mouse_at
		if _drag == null and info["drag_ok"] and p.distance_to(_pend["start"]) > 6.0:
			_start_drag(info)
		if _drag != null:
			_ghost.position = p - CARD_HALF
			var si := _slot_at(p)
			var ok: bool = si >= 0 and _slots[si]["kind"] == info["kind"] and not is_same(_slots[si], info)
			var over := si if ok else -1
			if over != _over:
				_over = over
				for s in _slots:
					_settle(s)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish()


func _start_drag(info: Dictionary) -> void:
	_drag = info
	info["hover"] = false
	_ghost = CardView.make(info["id"])
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.scale = Vector2.ONE * 1.15
	_ghost.rotation = deg_to_rad(7.0)
	_ghost.z_index = 50
	_top.add_child(_ghost)
	_ghost.position = _mouse_at - CARD_HALF
	_settle_all()


func _cancel_drag() -> void:
	if _pend != null:
		_pend["info"]["press"] = false
	_pend = null
	_drag = null
	_over = -1
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _finish() -> void:
	var info: Dictionary = _pend["info"]
	var dragged: bool = _drag != null
	var p := _mouse_at
	_cancel_drag()
	if not dragged:
		# clique simples: carta da roleta vem pro foco; carta equipada mostra os detalhes
		if info["src"] == "hand":
			_set_focus(info["idx"])
		else:
			_sel = info["idx"]
			_settle_all()
			_update_details()
		return
	var id: String = info["id"]
	var si := _slot_at(p)
	var drop := ""
	if si >= 0 and _slots[si]["kind"] == info["kind"]:
		if info["src"] == "hand":
			drop = _equip_from_hand(info["idx"], si)
		elif si != info["idx"]:
			var arr: Array = Knowledge.deck(hero)[info["kind"]]
			var a: int = info["n"]
			var b: int = _slots[si]["n"]
			arr[a] = arr[b]
			arr[b] = id
			drop = "s%d" % si
	elif info["src"] == "slot" and p.distance_to(HUB) < RIM:
		# de volta pra roleta: a carta entra na mão já em foco
		Knowledge.unequip(hero, id)
		_hand.insert(mini(_focus, _hand.size()), id)
		drop = "h%d" % _focus
	_sel = -1
	if drop != "":
		Knowledge.save()
		_sync_hand()
	_build_cards(false, drop)


## Roleta -> slot. Se o slot estava ocupado, a carta antiga volta pro mesmo lugar da mão.
func _equip_from_hand(k: int, si: int) -> String:
	var id: String = _hand[k]
	var old: String = _slots[si]["id"]
	if not Knowledge.equip(hero, id, _slots[si]["n"]):
		return ""
	if old != "":
		_hand[k] = old
		_focus = k
	else:
		_hand.remove_at(k)
		if _focus > k:
			_focus -= 1
	return "s%d" % si


## Atalhos usados pelos testes (ui/tests/shot.gd): o mesmo efeito de soltar a carta.
func _drop_slot(kind: String, n: int, data) -> void:
	var id: String = data["card"]
	var arr: Array = Knowledge.deck(hero)[kind]
	if data["from"] == "slot":
		var src := arr.find(id)
		if src >= 0 and src != n:
			arr[src] = arr[n]
			arr[n] = id
	else:
		Knowledge.equip(hero, id, n)
	Knowledge.save()
	_sync_hand()
	_build_cards()


func _drop_hand(_at: Vector2, data) -> void:
	Knowledge.unequip(hero, data["card"])
	Knowledge.save()
	_sync_hand()
	_build_cards()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and _drag != null:
		_cancel_drag()
		_build_cards()


# ---------------------------------------------------------------- detalhes

func _update_details() -> void:
	var id := ""
	var mine := true
	if _sel >= 0 and _sel < _slots.size() and _slots[_sel]["id"] != "":
		id = _slots[_sel]["id"]
	elif _focus < _hand.size():
		id = _hand[_focus]
		mine = Knowledge.is_owned_by(hero, id)
	_detail_id = id
	_d_tile.queue_redraw()
	_d_kind.visible = id != ""
	_d_cat.visible = id != ""
	if id == "":
		_d_name.text = ""
		_d_desc.text = ""
		return
	var c: Dictionary = Knowledge.CARDS[id]
	var k: Dictionary = Paper.KIND[c["kind"]]
	var nm := String(c["name"]).to_upper() if mine else "???"
	var px := 22
	while px > 13 and Paper.display().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 258.0:
		px -= 1
	_d_name.text = nm
	_d_name.add_theme_font_size_override("font_size", px)
	_d_kind.text = String(Knowledge.KIND_NAME[c["kind"]]).to_upper()
	_d_kind.bg = k["chip"]
	_d_kind.fg = k["chip_t"]
	_d_kind.fit(20)
	var key := Knowledge.mastery_key(id)
	if mine or key == "":
		_d_cat.text = String(Knowledge.CAT_NAME[c["cat"]]).to_upper()
	else:
		_d_cat.text = "MAESTRIA %d/%d" % [Knowledge.mastery_of(key), Knowledge.MASTERY_NEED]
	_d_cat.fit(20)
	_d_cat.position.x = _d_kind.position.x + _d_kind.size.x + 8.0
	if mine:
		_d_desc.text = c["desc"]
	elif key != "":
		_d_desc.text = ""
	else:
		_d_desc.text = c.get("earn", "À venda na loja.")


# ---------------------------------------------------------------- movimento parado

func _wave(period: float) -> float:
	return 0.5 - 0.5 * cos(TAU * _t / period)


func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree():
		return
	_t += delta
	# arte: sobe e desce 20 px com um balanço leve, girando a partir da base
	var k := _wave(3.6)
	_art.position.y = 50.0 + lerpf(6.0, -14.0, k)
	_art.rotation = deg_to_rad(lerpf(-1.0, 1.4, k))
	k = _wave(3.4)
	_bubble.position.y = 62.0 - 5.0 * k
	_bubble.rotation = deg_to_rad(-1.5 * k)
	k = _wave(5.2)
	_name_tag.position.y = 382.0 - 5.0 * k
	_name_tag.rotation = deg_to_rad(-1.5 * k)
	# faixas do palco deslizando, cada uma no seu ritmo
	var periods := [14.0, 18.0, 11.0]
	for i in _stripes.size():
		var s: CutPanel = _stripes[i]
		s.position = s.get_meta("home") + Vector2(-10, 4).lerp(Vector2(12, -5), _wave(periods[i]))
	_pointer.position.y = 398.0 + 5.0 * _wave(1.0)
	if _focus < _spokes.size():
		_spokes[_focus]["cv"].halo_grow = 3.0 * _wave(1.1)
	if _drag != null:
		# slots válidos: o contorno respira
		for s in _slots:
			if not is_same(s, _drag) and s["kind"] == _drag["kind"] and s["idx"] != _over:
				s["cv"].ring_gap = 4.0 + 5.0 * _wave(0.7)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _switch(-1)
		KEY_D, KEY_RIGHT: _switch(1)
		KEY_Q: _spin(-1)
		KEY_E: _spin(1)
		KEY_ENTER, KEY_KP_ENTER:
			if _show_ready:
				ready_pressed.emit()
		KEY_ESCAPE: back_pressed.emit()
