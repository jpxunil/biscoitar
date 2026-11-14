class_name GearScreen
extends Control
## Tela GEAR do menu: o equipamento de cada personagem.
## Kit de papel, na linha das telas de cartas e de skills, e a tela inteira veste a cor do herói:
## a paleta sai de Knowledge.HEROES[h]["color"] (ver `_palette`); a Maga, que é arco-íris, ganha
## faixas de sete cores no lugar de uma cor só.
##   - à esquerda, um campo diagonal escuro com as faixas do herói e a arte dele bem grande; por
##     cima do pé da arte, os ATRIBUTOS em tiras inclinadas;
##   - em cima, o alternador CARTAS | GEAR (a mesma peça da tela de cartas) e o seletor de herói;
##   - no meio, a ficha: placa do nome, retrato pequeno (no lugar do modelo 3D) e os GEAR_SLOTS
##     em zigue-zague, ligados ao retrato;
##   - à direita a mochila (ITENS) e, numa faixa própria, o consumível;
##   - embaixo as PASSIVAS (cartas aprendidas e as que estão sendo aprendidas) e a ficha do que
##     estiver escolhido.
##   Clique numa peça da mochila pra escolher; clique de novo (ou ENTER) pra equipar no primeiro
##   slot livre. Clique duas vezes num slot ocupado pra tirar.
##   A D / ← → personagem · ENTER equipa/tira · TAB cartas · ESC volta.

signal back_pressed
signal cards_pressed(hero: int)

const STAGE := Vector2(1280, 720)
const ORDER := [0, 4, 1, 2, 3, 5, 6, 7, 8, 9]
const DIM := Color("B9BEEA")
const BONUS := Color("54DE85")
const BASE_SPEED := 6.5
const HINT := "CLIQUE escolhe  ·  DE NOVO ou ENTER equipa/tira  ·  A D personagem  ·  TAB cartas  ·  ESC volta"
## As sete cores da Maga (as mesmas da sombra arco-íris dela, em ui/kit/art_shadow.gd).
const RAINBOW := [Color("ff4059"), Color("ff9933"), Color("ffe040"), Color("59e673"), Color("40d9ff"), Color("6680ff"), Color("cc66ff")]
## Heróis com tratamento arco-íris.
const RAINBOW_HEROES := ["maga"]
const DuoToggleKit := preload("res://ui/kit/duo_toggle.gd")
## Borda inclinada do campo da arte: x no topo e no pé da tela.
const FIELD_TOP := 452.0
const FIELD_BOT := 290.0


## Control que desenha com uma função: `fn` recebe o próprio nó.
class Deco extends Control:
	var fn: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## Um quadradinho da tela: slot de equipamento, peça da mochila ou passiva.
## Papel recortado: dois cantos cortados, contorno INK e sombra dura.
class Tile extends Control:
	signal clicked
	signal hovered(on: bool)

	var id := ""
	## "gear" peça/slot · "passive" carta aprendida · "learning" carta sendo aprendida
	var mode := "gear"
	var pct := 0.0
	var tag := ""              # número do slot, numa etiqueta no canto
	var selected := false
	var badge: Texture2D       # rosto de quem está com a peça agora
	var empty_fill := Color(0.07, 0.08, 0.2, 0.75)
	## Cor do herói: o "+" e os riscos do lugar vazio.
	var glow := Paper.CREAM
	var _hot := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			_hot = true
			queue_redraw()
			hovered.emit(true))
		mouse_exited.connect(func():
			_hot = false
			queue_redraw()
			hovered.emit(false))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _shape() -> PackedVector2Array:
		var c := minf(size.x, size.y) * 0.16
		return PackedVector2Array([Vector2(0, 0), Vector2(size.x - c, 0), Vector2(size.x, c), Vector2(size.x, size.y), Vector2(c, size.y), Vector2(0, size.y - c)])

	## Pinta `poly` só onde ele cai dentro de `inner`.
	func _clip(poly: PackedVector2Array, inner: PackedVector2Array, col: Color) -> void:
		for piece in Geometry2D.intersect_polygons(poly, inner):
			draw_colored_polygon(piece, col)

	func _box(r: Rect2) -> PackedVector2Array:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

	func _draw() -> void:
		var pts := _shape()
		var inner := Paper.inset(pts, 3.0)
		draw_colored_polygon(Paper.moved(pts, Vector2(4, 5)), Paper.INK)
		if selected:
			for ring in Geometry2D.offset_polygon(pts, 7.0, Geometry2D.JOIN_MITER):
				draw_colored_polygon(ring, Paper.INK)
			for ring in Geometry2D.offset_polygon(pts, 5.0, Geometry2D.JOIN_MITER):
				draw_colored_polygon(ring, Paper.GOLD)
		elif _hot:
			for ring in Geometry2D.offset_polygon(pts, 3.0, Geometry2D.JOIN_MITER):
				draw_colored_polygon(ring, Paper.CREAM)
		draw_colored_polygon(pts, Paper.INK)
		var card: Dictionary = Knowledge.CARDS.get(id, {})
		if card.is_empty():
			# lugar vazio: fundo escuro riscado na cor do herói, com um "+"
			draw_colored_polygon(inner, empty_fill)
			for n in 3:
				var y := size.y * (0.1 + n * 0.42)
				_clip(PackedVector2Array([Vector2(0, y + size.y * 0.3), Vector2(size.x, y - size.y * 0.1), Vector2(size.x, y + size.y * 0.06), Vector2(0, y + size.y * 0.46)]), inner, Color(glow, 0.13))
			var c := size * 0.5
			var k := size.x * 0.15
			var plus := Color(glow, 0.75)
			draw_line(c - Vector2(k, 0), c + Vector2(k, 0), plus, 5.0)
			draw_line(c - Vector2(0, k), c + Vector2(0, k), plus, 5.0)
		elif mode == "gear":
			var pal: Dictionary = Paper.KIND.get(card["kind"], Paper.KIND["white"])
			draw_colored_polygon(inner, pal["bg"])
			# faixa diagonal, como a janela da carta
			_clip(PackedVector2Array([Vector2(size.x * 0.45, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.55), Vector2(size.x * 0.1, size.y), Vector2(0, size.y), Vector2(0, size.y * 0.75)]), inner, pal["art"])
			var band := 17.0
			var side := minf(size.x, size.y - band) * 0.56
			Paper.draw_suit(self, card["cat"], Vector2((size.x - side) * 0.5, (size.y - band - side) * 0.5 + 1.0), side, Paper.INK)
			# nome curto no rodapé
			_clip(_box(Rect2(0, size.y - band - 3, size.x, band + 3)), inner, Paper.INK)
			var f := Paper.body(800)
			var nm := String(card["name"]).to_upper()
			if f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > size.x - 10.0:
				nm = nm.split(" ")[-1] if nm.split(" ").size() > 1 and nm.split(" ")[0].length() <= 4 else nm.split(" ")[0]
			var px := 10
			while px > 7 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > size.x - 12.0:
				px -= 1
			draw_string(f, Vector2(5, size.y - 7.5), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, px, Paper.CREAM)
		elif mode == "passive":
			draw_colored_polygon(inner, Paper.GOLD)
			_clip(_box(Rect2(0, 0, size.x, size.y * 0.32)), inner, Paper.GOLD_HOVER)
			var side2 := minf(size.x, size.y) * 0.56
			Paper.draw_suit(self, card["cat"], (size - Vector2(side2, side2)) * 0.5, side2, Paper.INK)
		else:
			# aprendendo: naipe apagado, porcentagem e barra
			draw_colored_polygon(inner, empty_fill)
			var side3 := minf(size.x * 0.5, size.y * 0.36)
			Paper.draw_suit(self, card["cat"], Vector2((size.x - side3) * 0.5, 7.0), side3, Color(Paper.CREAM, 0.55))
			var f2 := Paper.display(0.0)
			var px2 := 12 if size.x >= 46.0 else 10
			draw_string(f2, Vector2(0, size.y - 15.0), "%d%%" % int(pct), HORIZONTAL_ALIGNMENT_CENTER, size.x, px2, Paper.CREAM)
			var bar := Rect2(8, size.y - 12.0, size.x - 14.0, 6.0)
			draw_rect(bar, Paper.INK)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(pct / 100.0, 0.0, 1.0), bar.size.y)), Paper.GOLD)
		if tag != "":
			# número do slot: etiqueta inclinada pendurada no canto
			var tg := Paper.moved(Paper.skew_rect(Vector2(24, 20), 12), Vector2(-8, -8))
			draw_colored_polygon(Paper.moved(tg, Vector2(2, 3)), Paper.INK)
			draw_colored_polygon(tg, Paper.INK)
			draw_colored_polygon(Paper.inset(tg, 2.5), Paper.GOLD)
			draw_string(Paper.display(0.0), Vector2(-8, 7), tag, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Paper.INK)
		if badge != null:
			var b := Rect2(size.x - 22, -6, 26, 26)
			draw_rect(b, Paper.INK)
			draw_texture_rect_region(badge, b.grow(-2.0), Rect2(Vector2(badge.get_width() * 0.1, badge.get_height() * 0.16), Vector2.ONE * badge.get_width() * 0.8))


var hero := 0

var _stage: Control
var _bg: Control
var _built := false
var _th := {}
## Paleta da tela, derivada da cor do herói (ver `_palette`).
var _pal := {}
var _art: TextureRect
var _art_home := Vector2.ZERO
var _t := 0.0
var _toggle: Control
var _hero_name: Label
var _hero_role: Label
var _hero_face: TextureRect
var _near: Array = []        # rostos dos vizinhos no seletor (antes, depois)
var _p_center: CutPanel
var _p_items: CutPanel
var _p_pass: CutPanel
## Tudo que se redesenha quando o herói muda (campos de cor, lombadas, faixas).
var _decos: Array = []
## Etiquetas de seção que vestem a cor do herói.
var _chips: Array = []
var _c_head: Control
var _model: TextureRect
var _model_back: CutPanel
var _slots_box: Control
var _slot_count: Label
var _bag_box: Control
var _bag_empty: Label
var _item_box: Control
var _pass_box: Control
var _pass_empty: Label
var _pass_count: Label
var _attr_box: Control
var _d_name: Label
var _d_chips: Control
var _d_desc: Label
var _hint: Label
var _hint_t := 0.0
## O que está escolhido: zone = "slot" | "bag" | "islot" | "ibag" | "pass" ("" = nada).
var _sel := {"zone": "", "id": "", "idx": -1}
static var _consts := {}


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		Knowledge.persist = false
		open(0)


func open(hero_idx: int) -> void:
	_build()
	hero = clampi(hero_idx, 0, Knowledge.HEROES.size() - 1)
	_sel = {"zone": "", "id": "", "idx": -1}
	_toggle.pop()
	_refresh(0)


func _key() -> String:
	return Knowledge.HEROES[hero]["key"]


## Constantes de game.gd (UNIT_DEFS, MOVE_MULT...) sem instanciar a luta.
static func _game_const(cname: String, fallback: Variant) -> Variant:
	if _consts.is_empty():
		var gs: Script = load("res://scripts/game.gd")
		if gs != null:
			_consts = gs.get_script_constant_map()
	return _consts.get(cname, fallback)


## A identidade de cor do herói `i`, tirada de Knowledge.HEROES[i]["color"]:
##   main  a cor dele, viva (placas, etiquetas, valores)   · light  a mesma cor, clara
##   bg    a cor que inunda o fundo · bg2 recortes e pontos do fundo
##   deep  painéis (escuro puxado pro tom dele) · deep2  painel mais claro
##   acc   destaque (o do tema de papel dele) com acc_t = texto em cima
##   rainbow  true pra Maga: as faixas viram as sete cores de RAINBOW
static func _palette(i: int) -> Dictionary:
	var h: Dictionary = Knowledge.HEROES[i]
	var c: Color = h["color"]
	var th: Dictionary = Paper.THEMES.get(h["key"], Paper.THEMES["tank"])
	var hue := c.h
	var sat := clampf(c.s, 0.5, 0.82)
	# amarelo e laranja escurecidos viram marrom: nos tons quentes o fundo fica mais claro
	var warm := clampf(1.0 - absf(hue - 0.11) / 0.09, 0.0, 1.0)
	var pal := {
		"main": Color.from_hsv(hue, sat, maxf(c.v, 0.92)),
		"light": Color.from_hsv(hue, 0.3, 1.0),
		"bg": Color.from_hsv(hue, clampf(sat + 0.08, 0.55, 0.88), lerpf(0.72, 0.96, warm)),
		"bg2": Color.from_hsv(hue, clampf(sat - 0.04, 0.45, 0.8), lerpf(0.84, 1.0, warm)),
		"deep": Color.from_hsv(hue, 0.62, 0.27).lerp(Paper.INK, 0.2),
		"deep2": Color.from_hsv(hue, 0.56, 0.42).lerp(Paper.INK, 0.15),
		"acc": th["acc"],
		"acc_t": th["acc_t"],
		"rainbow": RAINBOW_HEROES.has(h["key"]),
	}
	if pal["rainbow"]:
		# arco-íris sobre violeta: nada de marrom com laranja
		pal["deep"] = Color("1c1549")
		pal["deep2"] = Color("2f2573")
		pal["acc"] = Paper.PINK
		pal["acc_t"] = Paper.INK
	return pal


## Cor da faixa `n` do herói: a cor dele, ou uma das sete da Maga.
func _stripe_color(n: int) -> Color:
	if _pal.get("rainbow", false):
		return RAINBOW[posmod(n, RAINBOW.size())]
	return _pal.get("main", Paper.GOLD)


# ---------------------------------------------------------------- montagem

func _deco(fn: Callable, at := Vector2.ZERO, sz := Vector2.ZERO) -> Deco:
	var d := Deco.new()
	d.fn = fn
	d.position = at
	d.size = sz
	_stage.add_child(d)
	_decos.append(d)
	return d


## Etiqueta de seção pendurada na borda de um painel. `hero_color`: veste a cor do herói.
func _section(text: String, at: Vector2, hero_color := true, rot := -3.0) -> Chip:
	var chip := Chip.new()
	chip.px = 15
	chip.pad = 13.0
	chip.fill = Paper.GOLD
	chip.shadow = Vector2(-3, 4)
	chip.text = text
	chip.position = at
	chip.pivot_offset = chip.size * 0.5
	chip.rotation = deg_to_rad(rot)
	_stage.add_child(chip)
	if hero_color:
		_chips.append(chip)
	return chip


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(func(): _bg.draw_rect(Rect2(Vector2.ZERO, _bg.size), _pal.get("bg", Paper.NAVY)))
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
	var back := _deco(_draw_back, Vector2.ZERO, STAGE)
	back.name = "Back"

	# arte do personagem, à esquerda (fica atrás dos painéis e das tiras de atributos)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_art)

	_build_selector()
	_build_attributes()
	_build_center()
	_build_items()
	_build_passives()
	_build_detail()

	# título: o alternador CARTAS | GEAR (a mesma peça, no mesmo lugar, da tela de cartas)
	_toggle = DuoToggleKit.new()
	_toggle.active = 1
	_toggle.position = Vector2(20, 10)
	_toggle.flipped.connect(func(_to: int): cards_pressed.emit(hero))
	_stage.add_child(_toggle)

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
	vb.position = Vector2(28, 668)
	vb.size = Vector2(132, 40)
	vb.pressed.connect(func(): back_pressed.emit())
	_stage.add_child(vb)


## Seletor de personagem: seta, vizinho apagado, rosto + nome + função, vizinho apagado, seta.
func _build_selector() -> void:
	_stage.add_child(CutPanel.make(Rect2(330, 14, 560, 64), [[.02, 0], [1, .06], [.98, 1], [0, .94]], Paper.INK, 0, Vector2(6, 7)))
	# filete na cor do herói no pé do seletor
	_deco(func(d: Deco):
		var n := 7 if _pal.get("rainbow", false) else 1
		for k in n:
			var x0 := d.size.x * k / n
			var x1 := d.size.x * (k + 1) / n
			d.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 3, 0), Vector2(x1 + 3, 0), Vector2(x1, d.size.y), Vector2(x0, d.size.y)]), _stripe_color(k)), Vector2(340, 68), Vector2(534, 6))
	var prev := _arrow(-1)
	prev.position = Vector2(340, 22)
	prev.pressed.connect(_switch.bind(-1))
	_stage.add_child(prev)
	var next := _arrow(1)
	next.position = Vector2(832, 22)
	next.pressed.connect(_switch.bind(1))
	_stage.add_child(next)
	for k in 2:
		var nf := TextureRect.new()
		nf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		nf.position = Vector2(398 if k == 0 else 790, 22)
		nf.size = Vector2(32, 42)
		nf.modulate = Color(1, 1, 1, 0.4)
		nf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(nf)
		_near.append(nf)
	var face_frame := CutPanel.make(Rect2(444, 16, 44, 56), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.CREAM, 0, Vector2.ZERO)
	face_frame.rotation = deg_to_rad(-3.0)
	_stage.add_child(face_frame)
	_hero_face = TextureRect.new()
	_hero_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_face.position = Vector2(3, 3)
	_hero_face.size = Vector2(38, 50)
	face_frame.add_child(_hero_face)
	_hero_name = Paper.label("", 26, Paper.CREAM, Paper.display())
	_hero_name.position = Vector2(502, 14)
	_hero_name.size = Vector2(280, 34)
	_hero_name.clip_text = true
	_stage.add_child(_hero_name)
	_hero_role = Paper.label("", 14, Paper.GOLD, Paper.body(800))
	_hero_role.position = Vector2(504, 44)
	_hero_role.size = Vector2(280, 22)
	_hero_role.clip_text = true
	_stage.add_child(_hero_role)


## Atributos: uma tira inclinada por linha, por cima do pé da arte (as tiras são montadas em
## `_fill_attributes`, porque os números mudam com o equipamento).
func _build_attributes() -> void:
	_attr_box = Control.new()
	_attr_box.position = Vector2(20, 504)
	_attr_box.size = Vector2(320, 150)
	_attr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_attr_box)
	_section("ATRIBUTOS", Vector2(30, 472))


## Ficha do herói: placa do nome, retrato (no lugar do modelo 3D) e os slots em zigue-zague.
func _build_center() -> void:
	_p_center = CutPanel.make(Rect2(352, 100, 414, 376), [[0, .03], [.88, 0], [1, .09], [.985, 1], [.015, .985]], Paper.NAVY, 6, Vector2(10, 10))
	_stage.add_child(_p_center)
	# faixa diagonal na cor do herói por dentro do painel, e as linhas que ligam o retrato aos slots
	_deco(_draw_center, Vector2(352, 100), Vector2(414, 376))
	_c_head = Control.new()
	_c_head.position = Vector2(372, 116)
	_c_head.size = Vector2(250, 60)
	_c_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_c_head)
	_model_back = CutPanel.make(Rect2(384, 190, 172, 204), [[0, 0], [1, .02], [.98, 1], [.02, .98]], Paper.CREAM, 5, Vector2(7, 8))
	_model_back.pivot_offset = _model_back.size * 0.5
	_model_back.rotation = deg_to_rad(-4.0)
	_stage.add_child(_model_back)
	_model = TextureRect.new()
	_model.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_model.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_model.position = Vector2(11, 11)
	_model.size = Vector2(150, 182)
	_model.clip_contents = true
	_model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_model_back.add_child(_model)
	var soon := Chip.new()
	soon.px = 9
	soon.pad = 7.0
	soon.skew = 8.0
	soon.border = 2.0
	soon.shadow = Vector2(-2, 3)
	soon.text = "MODELO 3D EM BREVE"
	soon.position = Vector2(86 - soon.size.x * 0.5, 190)
	_model_back.add_child(soon)
	_slot_count = Paper.label("", 13, DIM, Paper.body(700))
	_slot_count.position = Vector2(382, 424)
	_slot_count.size = Vector2(230, 40)
	_slot_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_count.add_theme_constant_override("line_spacing", -4)
	_stage.add_child(_slot_count)
	_slots_box = Control.new()
	_slots_box.position = Vector2(628, 126)
	_slots_box.size = Vector2(120, 340)
	_slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slots_box)
	_section("EQUIPADO", Vector2(626, 86), true, 3.0)


## Mochila: equipamentos soltos e, numa faixa própria embaixo, o consumível.
func _build_items() -> void:
	_p_items = CutPanel.make(Rect2(790, 100, 466, 376), [[.01, .02], [.93, 0], [1, .08], [.99, 1], [0, .985]], Paper.NAVY, 6, Vector2(10, 10))
	_stage.add_child(_p_items)
	_deco(_draw_items, Vector2(790, 100), Vector2(466, 376))
	_section("ITENS", Vector2(806, 88))
	var sub := Paper.label("mochila: o que dá pra equipar", 13, DIM, Paper.body(700))
	sub.position = Vector2(930, 120)
	sub.size = Vector2(278, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(sub)
	_bag_box = Control.new()
	_bag_box.position = Vector2(818, 150)
	_bag_box.size = Vector2(420, 220)
	_bag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_bag_box)
	_bag_empty = Paper.label("Mochila vazia.\nOs equipamentos são vendidos na loja de itens.", 15, DIM, Paper.body(700))
	_bag_empty.position = Vector2(818, 200)
	_bag_empty.size = Vector2(420, 80)
	_bag_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage.add_child(_bag_empty)
	var ct := Chip.new()
	ct.px = 12
	ct.pad = 10.0
	ct.border = 3.0
	ct.fill = Paper.CYAN
	ct.shadow = Vector2(-3, 4)
	ct.text = "CONSUMÍVEL"
	ct.position = Vector2(808, 386)
	ct.pivot_offset = ct.size * 0.5
	ct.rotation = deg_to_rad(-4.0)
	_stage.add_child(ct)
	var cs := Paper.label("um por luta", 13, Color("9fe9f7"), Paper.body(700))
	cs.position = Vector2(814, 428)
	cs.size = Vector2(130, 18)
	_stage.add_child(cs)
	_item_box = Control.new()
	_item_box.position = Vector2(962, 398)
	_item_box.size = Vector2(280, 64)
	_item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_item_box)


func _build_passives() -> void:
	_p_pass = CutPanel.make(Rect2(352, 498, 904, 100), [[0, .05], [1, 0], [.994, 1], [.006, .95]], Paper.NAVY, 5, Vector2(8, 8))
	_stage.add_child(_p_pass)
	_deco(func(d: Deco): _draw_spine(d, 7.0), Vector2(352, 498), Vector2(904, 100))
	_section("PASSIVAS", Vector2(368, 486))
	_pass_count = Paper.label("", 13, DIM, Paper.body(700))
	_pass_count.position = Vector2(700, 506)
	_pass_count.size = Vector2(538, 20)
	_pass_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(_pass_count)
	_pass_box = Control.new()
	_pass_box.position = Vector2(378, 532)
	_pass_box.size = Vector2(860, 54)
	_pass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pass_box)
	_pass_empty = Paper.label("Nenhuma ainda. Lute com as cartas de aprendizado no baralho: em 100% elas viram passiva.", 15, DIM, Paper.body(700))
	_pass_empty.position = Vector2(378, 546)
	_pass_empty.size = Vector2(860, 24)
	_stage.add_child(_pass_empty)


## Ficha do que estiver escolhido (ou embaixo do mouse).
func _build_detail() -> void:
	_stage.add_child(CutPanel.make(Rect2(352, 614, 904, 78), [[.004, 0], [1, .04], [.996, 1], [0, .96]], Paper.CREAM, 5, Vector2(8, 8)))
	_d_name = Paper.label("", 20, Paper.INK, Paper.display())
	_d_name.position = Vector2(372, 620)
	_d_name.size = Vector2(330, 28)
	_d_name.clip_text = true
	_stage.add_child(_d_name)
	_d_chips = Control.new()
	_d_chips.position = Vector2(376, 654)
	_d_chips.size = Vector2(330, 26)
	_d_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_d_chips)
	_d_desc = Paper.label("", 16, Paper.INK, Paper.body(700))
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.add_theme_constant_override("line_spacing", -4)
	_d_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_desc.position = Vector2(716, 620)
	_d_desc.size = Vector2(522, 66)
	_d_desc.clip_text = true
	_stage.add_child(_d_desc)
	# faixa escura atrás da dica: o fundo de alguns heróis é claro
	_stage.add_child(CutPanel.make(Rect2(596, 698, 668, 20), [[.01, 0], [1, 0], [.99, 1], [0, 1]], Color(Paper.INK, 0.86), 0, Vector2.ZERO))
	_hint = Paper.label(HINT, 13, DIM, Paper.body(700))
	_hint.position = Vector2(352, 697)
	_hint.size = Vector2(898, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(_hint)


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


# ---------------------------------------------------------------- desenho

## x da borda inclinada do campo da arte na altura y.
func _field_x(y: float) -> float:
	return lerpf(FIELD_TOP, FIELD_BOT, y / STAGE.y)


## Fundo: a cor do herói inunda a tela; à esquerda, um campo escuro cortado na diagonal com o
## nome gigante e as faixas dele (as sete cores, na Maga).
func _draw_back(d: Deco) -> void:
	if _pal.is_empty():
		return
	var name_up := String(Knowledge.HEROES[hero]["name"]).to_upper()
	var field := PackedVector2Array([Vector2(-1400, -700), Vector2(_field_x(-700.0), -700), Vector2(_field_x(1420.0), 1420), Vector2(-1400, 1420)])
	d.draw_colored_polygon(field, _pal["deep"])
	# nome gigante, como textura do campo (o que passar da borda é coberto pelo fundo, logo abaixo)
	var f := Paper.display()
	var px := 150
	while px > 70 and f.get_string_size(name_up, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 560.0:
		px -= 4
	d.draw_set_transform(Vector2(-14, 236), deg_to_rad(-11.0), Vector2.ONE)
	d.draw_string(f, Vector2.ZERO, name_up, HORIZONTAL_ALIGNMENT_LEFT, -1, px, _pal["deep2"])
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# faixas subindo pra direita
	var bands: Array = []
	if _pal["rainbow"]:
		for n in 7:
			bands.append([352.0 + n * 30.0, 30.0, RAINBOW[n]])
	else:
		bands = [[388.0, 132.0, _pal["main"]], [540.0, 40.0, _pal["acc"]], [598.0, 16.0, Paper.CREAM]]
	for b in bands:
		var y: float = b[0]
		var th: float = b[1]
		var band := PackedVector2Array([Vector2(-1400, y + 560.0), Vector2(520, y - 208.0), Vector2(520, y - 208.0 + th), Vector2(-1400, y + 560.0 + th)])
		for piece in Geometry2D.intersect_polygons(band, field):
			d.draw_colored_polygon(piece, b[2])
	# o resto da tela: a cor do herói, com um recorte mais claro em cima e pontos de retícula
	var rest := PackedVector2Array([Vector2(_field_x(-700.0), -700), Vector2(2700, -700), Vector2(2700, 1420), Vector2(_field_x(1420.0), 1420)])
	d.draw_colored_polygon(rest, _pal["bg"])
	var dot: Color = _pal["bg2"]
	for iy in 36:
		for ix in 64:
			var c := Vector2(ix * 20 + 10, iy * 20 + 10)
			if c.x > _field_x(c.y) + 12.0:
				d.draw_circle(c, 5.0, Color(dot, 0.6))
	d.draw_colored_polygon(PackedVector2Array([Vector2(_field_x(-10.0), -10), Vector2(1300, -10), Vector2(1300, 150), Vector2(_field_x(92.0), 92)]), dot)
	d.draw_colored_polygon(PackedVector2Array([Vector2(900, 730), Vector2(1300, 640), Vector2(1300, 730)]), Paper.CREAM)
	# a borda do campo: um talho INK com um filete claro
	var top := Vector2(_field_x(-700.0), -700)
	var bot := Vector2(_field_x(1420.0), 1420)
	d.draw_line(top + Vector2(5, 0), bot + Vector2(5, 0), Paper.INK, 16.0, true)
	d.draw_line(top + Vector2(18, 0), bot + Vector2(18, 0), _pal["light"], 5.0, true)


## Lombada do painel: uma barra inclinada na cor do herói junto da borda esquerda (sete cores na Maga).
func _draw_spine(d: Deco, inset: float) -> void:
	if _pal.is_empty():
		return
	var n := 7 if _pal["rainbow"] else 1
	var y0 := inset + 5.0
	var y1 := d.size.y - inset - 2.0
	for k in n:
		var a := lerpf(y0, y1, float(k) / n)
		var b := lerpf(y0, y1, float(k + 1) / n)
		d.draw_colored_polygon(PackedVector2Array([Vector2(inset + 1, a), Vector2(inset + 11, a), Vector2(inset + 11, b), Vector2(inset + 1, b)]), _stripe_color(k))


## Miolo da ficha: faixa diagonal do herói, lombada e as linhas que ligam o retrato a cada slot.
func _draw_center(d: Deco) -> void:
	if _pal.is_empty():
		return
	var inner := Paper.inset(Paper.poly(d.size, _p_center.shape), 6.0)
	# faixa diagonal atravessando o painel por trás do retrato
	var n := 7 if _pal["rainbow"] else 1
	var thick := 96.0 / n
	for k in n:
		var y := 250.0 + k * thick
		var band := PackedVector2Array([Vector2(0, y + 60), Vector2(d.size.x, y - 110), Vector2(d.size.x, y - 110 + thick), Vector2(0, y + 60 + thick)])
		var col := _stripe_color(k)
		for piece in Geometry2D.intersect_polygons(band, inner):
			d.draw_colored_polygon(piece, Color(col, 0.9) if _pal["rainbow"] else _pal["deep2"])
	_draw_spine(d, 8.0)
	# papel escuro atrás do texto de baixo (a faixa colorida passa por ali)
	var note := Paper.moved(Paper.skew_rect(Vector2(232, 46), 10.0), Vector2(20, 320))
	d.draw_colored_polygon(note, Color(Paper.INK, 0.88))
	# do retrato pra cada slot
	var from := Vector2(196, 196)
	for k in Knowledge.GEAR_SLOTS:
		var to := _slot_at(k) + _slots_box.position - d.position + Vector2(6, 39)
		var elbow := Vector2(to.x - 30.0, to.y)
		d.draw_polyline(PackedVector2Array([from, elbow, to]), Paper.INK, 9.0, true)
		d.draw_polyline(PackedVector2Array([from, elbow, to]), _stripe_color(k * 2), 3.0, true)


## Miolo da mochila: lombada e a faixa do consumível, cortada na diagonal.
func _draw_items(d: Deco) -> void:
	if _pal.is_empty():
		return
	var inner := Paper.inset(Paper.poly(d.size, _p_items.shape), 6.0)
	var band := PackedVector2Array([Vector2(0, 292), Vector2(d.size.x, 268), Vector2(d.size.x, d.size.y), Vector2(0, d.size.y)])
	for piece in Geometry2D.intersect_polygons(band, inner):
		d.draw_colored_polygon(piece, Color("0f3442"))
	var edge := PackedVector2Array([Vector2(0, 288), Vector2(d.size.x, 264), Vector2(d.size.x, 270), Vector2(0, 294)])
	for piece in Geometry2D.intersect_polygons(edge, inner):
		d.draw_colored_polygon(piece, Paper.CYAN)
	_draw_spine(d, 8.0)
	# lugares da mochila ainda sem peça: recortes tracejados, pra grade não sumir quando ela está vazia
	var have := Knowledge.gear_bag(hero).size()
	var off := _bag_box.position - d.position
	for n in range(have, 15):
		var at := off + Vector2((n % 5) * 84 + 4, (n / 5) * 76)
		var c := 68.0 * 0.16
		var cell := PackedVector2Array([at, at + Vector2(68 - c, 0), at + Vector2(68, c), at + Vector2(68, 68), at + Vector2(c, 68), at + Vector2(0, 68 - c), at])
		if at.y + 68.0 > 262.0:
			continue
		for k in cell.size() - 1:
			d.draw_dashed_line(cell[k], cell[k + 1], Color(_pal["light"], 0.2), 2.0, 6.0)


# ---------------------------------------------------------------- conteúdo

func _switch(dir: int) -> void:
	var at := ORDER.find(hero)
	hero = ORDER[posmod(at + dir, ORDER.size())]
	_sel = {"zone": "", "id": "", "idx": -1}
	_refresh(dir)


func _face(i: int) -> Texture2D:
	var p := "res://assets/portraits/%s_face.png" % Knowledge.HEROES[i]["key"]
	return load(p) if ResourceLoader.exists(p) else null


func _refresh(dir: int) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	_th = Paper.THEMES.get(h["key"], Paper.THEMES["tank"])
	_pal = _palette(hero)
	_bg.queue_redraw()
	for d in _decos:
		d.queue_redraw()
	for chip in _chips:
		chip.fill = _pal["main"]
		chip.queue_redraw()
	_toggle.accent = _pal["acc"]
	_p_center.fill = _pal["deep"]
	_p_items.fill = _pal["deep"]
	_p_pass.fill = _pal["deep2"]
	_model_back.fill = _pal["light"]
	var nm := String(h["name"]).to_upper()
	_hero_name.text = nm
	_hero_role.text = String(h["role"]).to_upper()
	_hero_role.add_theme_color_override("font_color", _pal["light"])
	_hero_face.texture = _face(hero)
	var at := ORDER.find(hero)
	_near[0].texture = _face(ORDER[posmod(at - 1, ORDER.size())])
	_near[1].texture = _face(ORDER[posmod(at + 1, ORDER.size())])
	# placa do nome na cor do herói, com a função pendurada embaixo
	_clear(_c_head)
	var plate := Chip.new()
	plate.px = 22
	while plate.px > 13 and Paper.display().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, plate.px).x > 200.0:
		plate.px -= 1
	plate.pad = 14.0
	plate.border = 4.0
	plate.shadow = Vector2(-4, 5)
	plate.fill = _pal["main"]
	plate.text = nm
	plate.position = Vector2(4, 0)
	plate.pivot_offset = plate.size * 0.5
	plate.rotation = deg_to_rad(-3.0)
	_c_head.add_child(plate)
	var rc := Chip.new()
	rc.px = 11
	rc.pad = 9.0
	rc.skew = 8.0
	rc.border = 2.0
	rc.shadow = Vector2(-2, 3)
	rc.fill = _pal["acc"]
	rc.ink = _pal["acc_t"]
	rc.text = String(h["role"]).to_upper()
	rc.position = Vector2(22, plate.size.y + 2.0)
	_c_head.add_child(rc)
	_model.texture = _face(hero)
	# arte de corpo inteiro, grande: ocupa a coluna da esquerda e o pé fica atrás dos atributos
	var art := "res://assets/portraits/%s_art.webp" % h["key"]
	_art.visible = ResourceLoader.exists(art)
	if _art.visible:
		var tex: Texture2D = load(art)
		var ts := tex.get_size()
		var w := minf(372.0, 640.0 * ts.x / ts.y)
		_art.texture = tex
		_art.size = Vector2(w, w * ts.y / ts.x)
		ArtShadow.for_hero(_art, h["key"])
		# figura baixa desce até encostar nos atributos em vez de flutuar no topo
		_art_home = Vector2(176.0 - w * 0.5, 88.0 + maxf(0.0, 420.0 - _art.size.y))
		_art.position = _art_home - Vector2(60.0 * dir, 0)
		_art.modulate.a = 0.0 if dir != 0 else 1.0
		var tw := _art.create_tween().set_parallel(true)
		tw.tween_property(_art, "position:x", _art_home.x, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_art, "modulate:a", 1.0, 0.16)
	_fill()


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _tile(box: Control, at: Vector2, side: Vector2, id: String, zone: String, idx := -1) -> Tile:
	var t := Tile.new()
	t.position = at
	t.size = side
	t.pivot_offset = side * 0.5
	t.id = id
	t.empty_fill = Color(_pal["deep2"], 1.0).darkened(0.35)
	t.glow = _pal["light"]
	t.selected = _sel["zone"] == zone and ((idx >= 0 and _sel["idx"] == idx) or (idx < 0 and _sel["id"] == id))
	t.clicked.connect(_click.bind(zone, id, idx))
	t.hovered.connect(func(on: bool):
		if on:
			_show(zone, id, idx)
		else:
			_show(_sel["zone"], _sel["id"], _sel["idx"]))
	box.add_child(t)
	return t


## Canto de cima do slot de equipamento `n`, dentro de `_slots_box`: uma coluna em zigue-zague.
func _slot_at(n: int) -> Vector2:
	return Vector2(34.0 if n % 2 == 1 else 0.0, n * 86.0)


## Consumíveis que o jogador tem e este herói pode usar.
func _consumables() -> Array:
	var out: Array = []
	for id in Knowledge.CARDS:
		if Knowledge.CARDS[id]["kind"] == "item" and Knowledge.owned.has(id) and Knowledge.usable(hero, id):
			out.append(id)
	return out


## Cartas de aprendizado do herói: [aprendidas, aprendendo].
func _learning() -> Array:
	var done: Array = []
	var doing: Array = []
	for id in Knowledge.passives(hero):
		if Knowledge.CARDS.has(id) and not done.has(id):
			done.append(id)
	for id in Knowledge.CARDS:
		if done.has(id) or Knowledge.role(id) != "learn" or not Knowledge.usable(hero, id):
			continue
		if Knowledge.in_deck(hero, id) or Knowledge.learn_progress(hero, id) > 0.0:
			doing.append(id)
	doing.sort_custom(func(a: String, b: String): return Knowledge.learn_progress(hero, a) > Knowledge.learn_progress(hero, b))
	return [done, doing]


## Remonta tudo que depende do estado: slots, mochila, consumível, passivas, atributos e ficha.
func _fill() -> void:
	# slots de equipamento: zigue-zague, cada um inclinado pra um lado
	_clear(_slots_box)
	var worn: Array = Knowledge.gear_of(hero)
	var used := 0
	for n in Knowledge.GEAR_SLOTS:
		var id: String = String(worn[n]) if n < worn.size() else ""
		if id != "":
			used += 1
		var t := _tile(_slots_box, _slot_at(n), Vector2(78, 78), id, "slot", n)
		t.tag = str(n + 1)
		t.rotation = deg_to_rad(3.0 if n % 2 == 1 else -3.0)
		if _pal["rainbow"]:
			t.glow = RAINBOW[(n * 2) % RAINBOW.size()]
	_slot_count.text = "%d de %d slots em uso.\nDois cliques num slot tiram a peça." % [used, Knowledge.GEAR_SLOTS]
	# mochila
	_clear(_bag_box)
	var bag: Array = Knowledge.gear_bag(hero)
	_bag_empty.visible = bag.is_empty()
	for n in bag.size():
		var t := _tile(_bag_box, Vector2((n % 5) * 84 + 4, (n / 5) * 76), Vector2(68, 68), bag[n], "bag")
		t.rotation = deg_to_rad([-1.5, 1.0, -0.6, 1.6, -1.0][n % 5])
		var who := Knowledge.holder(bag[n])
		if who >= 0 and who != hero:
			t.badge = _face(who)
	# consumível: o slot e, ao lado, os que estão soltos
	_clear(_item_box)
	var slots: Array = Knowledge.deck(hero)["item"]
	var held: String = String(slots[0]) if slots.size() > 0 else ""
	var st := _tile(_item_box, Vector2(0, 0), Vector2(64, 64), held, "islot", 0)
	st.empty_fill = Paper.KIND["item"]["eb"]
	st.glow = Paper.CYAN
	st.rotation = deg_to_rad(-3.0)
	var x := 100.0
	for id in _consumables():
		if id == held:
			continue
		var t := _tile(_item_box, Vector2(x, 0), Vector2(64, 64), id, "ibag")
		var who := Knowledge.holder(id)
		if who >= 0 and who != hero:
			t.badge = _face(who)
		x += 78.0
	if x > 100.0:
		var arrow := Paper.label("‹", 30, Paper.CYAN, Paper.body(800))
		arrow.position = Vector2(68, 8)
		arrow.size = Vector2(28, 44)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_box.add_child(arrow)
	# passivas
	_clear(_pass_box)
	var lists := _learning()
	var done: Array = lists[0]
	var doing: Array = lists[1]
	var total := done.size() + doing.size()
	_pass_empty.visible = total == 0
	_pass_count.text = "%d aprendida%s  ·  %d aprendendo" % [done.size(), "" if done.size() == 1 else "s", doing.size()]
	var w := clampf(floorf((_pass_box.size.x + 8.0) / maxf(total, 1.0)) - 8.0, 26.0, 54.0)
	for n in total:
		var id: String = done[n] if n < done.size() else doing[n - done.size()]
		var t := _tile(_pass_box, Vector2(n * (w + 8.0), 0), Vector2(w, 54), id, "pass")
		t.mode = "passive" if n < done.size() else "learning"
		t.pct = Knowledge.learn_progress(hero, id)
	_fill_attributes()
	_show(_sel["zone"], _sel["id"], _sel["idx"])


func _fill_attributes() -> void:
	_clear(_attr_box)
	var defs: Array = _game_const("UNIT_DEFS", [])
	var def: Dictionary = defs[hero] if hero < defs.size() else {}
	var mult: Dictionary = _game_const("MOVE_MULT", {})
	var gs: Dictionary = Knowledge.gear_stats(hero)
	var hp := float(def.get("hp", Knowledge.HEROES[hero].get("hp", 100)))
	var reach := float(def.get("range", 0.0))
	var speed := BASE_SPEED * float(mult.get(_key(), _game_const("MOVE_DEFAULT", 1.0)))
	var hp_up := float(gs.get("hp", 0.0))
	var range_k := float(gs.get("range", 1.0))
	var speed_k := float(gs.get("speed", 1.0))
	var crit := float(gs.get("crit", 0.0))
	var rows := [
		["VIDA", "%d" % int(hp + hp_up), ("+%d" % int(hp_up)) if hp_up > 0.0 else ""],
		["ALCANCE", _num(reach * range_k), ("+%d%%" % roundi((range_k - 1.0) * 100.0)) if range_k > 1.0 else ""],
		["VELOCIDADE", _num(speed * speed_k), ("+%d%%" % roundi((speed_k - 1.0) * 100.0)) if speed_k > 1.0 else ""],
		["CRÍTICO", "%d%%" % roundi(crit * 100.0), "+50% dano" if crit > 0.0 else ""],
	]
	for n in rows.size():
		# uma tira por atributo, cada uma um pouco mais pra direita que a de cima
		var row: Array = rows[n]
		var strip := Deco.new()
		strip.position = Vector2(8.0 + n * 9.0, n * 37.0)
		strip.size = Vector2(286, 30)
		strip.fn = _draw_stat.bind(String(row[0]), String(row[1]), String(row[2]), _stripe_color(n * 2))
		_attr_box.add_child(strip)


## Tira de atributo: nome no papel escuro, valor numa placa na cor do herói e, se o equipamento
## mexeu nele, o bônus em verde na ponta.
func _draw_stat(d: Deco, label: String, value: String, bonus: String, col: Color) -> void:
	var pts := Paper.skew_rect(d.size, 12.0)
	d.draw_colored_polygon(Paper.moved(pts, Vector2(5, 5)), Paper.INK)
	d.draw_colored_polygon(pts, Paper.INK)
	d.draw_colored_polygon(Paper.inset(pts, 3.0), _pal["deep2"])
	var f := Paper.display()
	var fb := Paper.body(800)
	d.draw_string(f, Vector2(16, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Paper.CREAM)
	# placa do valor
	var plate := Paper.moved(Paper.skew_rect(Vector2(74, d.size.y), 12.0), Vector2(132, 0))
	for piece in Geometry2D.intersect_polygons(plate, Paper.inset(pts, 3.0)):
		d.draw_colored_polygon(piece, col)
	d.draw_string(fb, Vector2(132, 23), value, HORIZONTAL_ALIGNMENT_CENTER, 74, 20, Paper.INK)
	if bonus != "":
		d.draw_string(fb, Vector2(210, 21), bonus, HORIZONTAL_ALIGNMENT_LEFT, 72, 14 if bonus.length() <= 5 else 12, BONUS)


static func _num(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


func _chip(text: String, fill: Color, ink := Paper.INK) -> void:
	var c := Chip.new()
	c.px = 11
	c.pad = 9.0
	c.skew = 8.0
	c.border = 2.0
	c.shadow = Vector2(-2, 3)
	c.fill = fill
	c.ink = ink
	c.text = text
	var x := 0.0
	for o in _d_chips.get_children():
		x = maxf(x, o.position.x + o.size.x + 8.0)
	c.position = Vector2(x, 0)
	_d_chips.add_child(c)


## Preenche a ficha com um slot, uma peça da mochila ou uma passiva.
func _show(zone: String, id: String, idx: int) -> void:
	_clear(_d_chips)
	var card: Dictionary = Knowledge.CARDS.get(id, {})
	if card.is_empty():
		if zone == "slot":
			_d_name.text = "SLOT %d VAZIO" % (idx + 1)
			_d_desc.text = "Escolha um equipamento em ITENS e clique de novo nele (ou ENTER) pra equipar."
			_chip("EQUIPAMENTO", Paper.GOLD)
		elif zone == "islot":
			_d_name.text = "SEM CONSUMÍVEL"
			_d_desc.text = "Um consumível por herói. Escolha um ao lado e clique de novo nele pra levar pra luta."
			_chip("CONSUMÍVEL", Paper.CYAN)
		else:
			_d_name.text = String(Knowledge.HEROES[hero]["name"]).to_upper()
			_d_desc.text = "Passe o mouse ou clique num slot, numa peça da mochila ou numa passiva pra ver o que ela faz."
		_d_name.add_theme_font_size_override("font_size", 20)
		return
	_d_name.text = String(card["name"]).to_upper()
	var px := 20
	while px > 13 and Paper.display().get_string_size(_d_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 326.0:
		px -= 1
	_d_name.add_theme_font_size_override("font_size", px)
	var desc := String(card["desc"])
	var pal: Dictionary = Paper.KIND.get(card["kind"], Paper.KIND["white"])
	if zone == "pass":
		var pct := Knowledge.learn_progress(hero, id)
		if Knowledge.is_passive(hero, id):
			_chip("PASSIVA", Paper.GOLD)
		else:
			_chip("APRENDENDO %d%%" % int(pct), Paper.INK, Paper.CREAM)
			desc += "  Em 100% vira passiva e sai do baralho."
	else:
		var item: bool = card["kind"] == "item"
		_chip("CONSUMÍVEL" if item else "EQUIPAMENTO", Paper.CYAN if item else Paper.GOLD)
		if zone == "slot" or zone == "islot":
			_chip("EQUIPADO", Paper.GREEN)
		else:
			var who := Knowledge.holder(id)
			if who >= 0 and who != hero:
				desc += "  Está com %s: equipar aqui tira de lá." % Knowledge.HEROES[who]["name"]
	if not (zone != "pass" and card["kind"] == "item"):
		_chip(String(Knowledge.KIND_NAME.get(card["kind"], "")).to_upper(), pal["chip"], pal["chip_t"])
	_d_desc.text = desc


func _click(zone: String, id: String, idx: int) -> void:
	var same: bool = _sel["zone"] == zone and ((idx >= 0 and _sel["idx"] == idx) or (idx < 0 and _sel["id"] == id))
	if same:
		_act()
		return
	_sel = {"zone": zone, "id": id, "idx": idx}
	_fill()


## Equipa a peça escolhida (mochila) ou tira a que está no slot escolhido.
func _act() -> void:
	var zone: String = _sel["zone"]
	var id: String = _sel["id"]
	if id == "" or not Knowledge.CARDS.has(id):
		return
	match zone:
		"bag":
			if not Knowledge.equip(hero, id) or not Knowledge.gear_of(hero).has(id):
				_say("Sem slot livre: tire um equipamento antes (clique duas vezes no slot).")
				return
			_sel = {"zone": "slot", "id": id, "idx": Knowledge.gear_of(hero).find(id)}
		"ibag":
			# só há um slot de consumível: o novo entra no lugar do antigo
			if not Knowledge.equip(hero, id, 0):
				_say("Este herói não pode levar esse consumível.")
				return
			_sel = {"zone": "islot", "id": id, "idx": 0}
		"slot":
			Knowledge.unequip(hero, id)
			_sel = {"zone": "bag", "id": id, "idx": -1}
		"islot":
			Knowledge.unequip(hero, id)
			_sel = {"zone": "ibag", "id": id, "idx": -1}
		_:
			return
	Knowledge.save()
	_fill()


func _say(text: String) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", Paper.GOLD)
	_hint_t = 2.6


func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree():
		return
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			_hint.text = HINT
			_hint.add_theme_color_override("font_color", DIM)
	if not _art.visible:
		return
	_t += delta
	# a arte respira devagar, como na tela de cartas
	_art.position.y = _art_home.y + sin(_t * 1.7) * 7.0


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _switch(-1)
		KEY_D, KEY_RIGHT: _switch(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _act()
		KEY_TAB: cards_pressed.emit(hero)
		KEY_ESCAPE: back_pressed.emit()
		_: return
	get_viewport().set_input_as_handled()
