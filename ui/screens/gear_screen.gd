class_name GearScreen
extends Control
## Tela GEAR do menu: o equipamento de cada personagem.
## Kit de papel, na linha das telas de cartas e de skills: as setas em cima trocam de personagem
## (todos os nove), a arte dele fica à esquerda com o quadro de ATRIBUTOS embaixo.
## No meio, a ficha do herói (por enquanto o retrato no lugar do modelo 3D) com os GEAR_SLOTS ao
## lado; à direita a mochila (ITENS) e o slot de consumível; embaixo as PASSIVAS (cartas já
## aprendidas e as que estão sendo aprendidas) e a ficha do que estiver escolhido.
##   Clique numa peça da mochila pra escolher; clique de novo (ou ENTER) pra equipar no primeiro
##   slot livre. Clique duas vezes num slot ocupado pra tirar.
##   A D / ← → personagem · ENTER equipa/tira · ESC volta.

signal back_pressed
signal cards_pressed(hero: int)

const STAGE := Vector2(1280, 720)
const ORDER := [0, 4, 1, 2, 3, 5, 6, 7, 8, 9]
const DIM := Color("B9BEEA")
const BONUS := Color("54DE85")
const BASE_SPEED := 6.5
const HINT := "CLIQUE escolhe  ·  CLIQUE DE NOVO ou ENTER equipa/tira  ·  A D personagem  ·  ESC volta"


## Um quadradinho da tela: slot de equipamento, peça da mochila ou passiva.
class Tile extends Control:
	signal clicked
	signal hovered(on: bool)

	var id := ""
	## "gear" peça/slot · "passive" carta aprendida · "learning" carta sendo aprendida
	var mode := "gear"
	var pct := 0.0
	var tag := ""              # número do slot, no canto
	var selected := false
	var badge: Texture2D       # rosto de quem está com a peça agora
	var empty_fill := Color(0.07, 0.08, 0.2, 0.75)
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

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2(4, 5), size), Paper.INK)
		draw_rect(r, Paper.INK)
		var inner := r.grow(-3.0)
		var card: Dictionary = Knowledge.CARDS.get(id, {})
		if card.is_empty():
			# lugar vazio: fundo escuro com um "+"
			draw_rect(inner, empty_fill)
			var c := size * 0.5
			var k := size.x * 0.14
			var plus := Color(Paper.CREAM.r, Paper.CREAM.g, Paper.CREAM.b, 0.3)
			draw_line(c - Vector2(k, 0), c + Vector2(k, 0), plus, 4.0)
			draw_line(c - Vector2(0, k), c + Vector2(0, k), plus, 4.0)
		elif mode == "gear":
			var pal: Dictionary = Paper.KIND.get(card["kind"], Paper.KIND["white"])
			draw_rect(inner, pal["bg"])
			# faixa diagonal, como a janela da carta
			draw_colored_polygon(PackedVector2Array([
				inner.position + Vector2(inner.size.x * 0.45, 0), inner.position + Vector2(inner.size.x, 0),
				inner.position + Vector2(inner.size.x, inner.size.y * 0.55), inner.position + Vector2(inner.size.x * 0.1, inner.size.y),
				inner.position + Vector2(0, inner.size.y), inner.position + Vector2(0, inner.size.y * 0.75)]), pal["art"])
			var band := 17.0
			var side := minf(size.x, size.y - band) * 0.56
			Paper.draw_suit(self, card["cat"], Vector2((size.x - side) * 0.5, (size.y - band - side) * 0.5 + 1.0), side, Paper.INK)
			# nome curto no rodapé
			draw_rect(Rect2(3, size.y - band - 3, size.x - 6, band), Paper.INK)
			var f := Paper.body(800)
			var nm := String(card["name"]).to_upper()
			if f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > size.x - 10.0:
				nm = nm.split(" ")[-1] if nm.split(" ").size() > 1 and nm.split(" ")[0].length() <= 4 else nm.split(" ")[0]
			var px := 10
			while px > 7 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > size.x - 8.0:
				px -= 1
			draw_string(f, Vector2(3, size.y - 7.5), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, px, Paper.CREAM)
		elif mode == "passive":
			draw_rect(inner, Paper.GOLD)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.3)), Paper.GOLD_HOVER)
			var side2 := minf(size.x, size.y) * 0.56
			Paper.draw_suit(self, card["cat"], (size - Vector2(side2, side2)) * 0.5, side2, Paper.INK)
		else:
			# aprendendo: naipe apagado, porcentagem e barra
			draw_rect(inner, empty_fill)
			var side3 := minf(size.x * 0.5, size.y * 0.36)
			Paper.draw_suit(self, card["cat"], Vector2((size.x - side3) * 0.5, 7.0), side3, Color(Paper.CREAM.r, Paper.CREAM.g, Paper.CREAM.b, 0.55))
			var f2 := Paper.display(0.0)
			var px2 := 12 if size.x >= 46.0 else 10
			draw_string(f2, Vector2(0, size.y - 15.0), "%d%%" % int(pct), HORIZONTAL_ALIGNMENT_CENTER, size.x, px2, Paper.CREAM)
			var bar := Rect2(6, size.y - 12.0, size.x - 12.0, 6.0)
			draw_rect(bar, Paper.INK)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(pct / 100.0, 0.0, 1.0), bar.size.y)), Paper.GOLD)
		if tag != "":
			draw_rect(Rect2(0, 0, 18, 18), Paper.INK)
			draw_string(Paper.display(0.0), Vector2(0, 14), tag, HORIZONTAL_ALIGNMENT_CENTER, 18, 11, Paper.GOLD)
		if badge != null:
			var b := Rect2(size.x - 24, -4, 26, 26)
			draw_rect(b, Paper.INK)
			draw_texture_rect_region(badge, b.grow(-2.0), Rect2(Vector2(badge.get_width() * 0.1, badge.get_height() * 0.16), Vector2.ONE * badge.get_width() * 0.8))
		if selected:
			draw_rect(r.grow(3.0), Paper.GOLD, false, 4.0)
			draw_rect(r.grow(6.0), Paper.INK, false, 2.0)
		elif _hot:
			draw_rect(r.grow(2.0), Paper.CREAM, false, 3.0)


var hero := 0

var _stage: Control
var _bg: Control
var _built := false
var _th := {}
var _art: TextureRect
var _art_home := Vector2.ZERO
var _t := 0.0
var _hero_name: Label
var _hero_role: Label
var _hero_face: TextureRect
var _near: Array = []        # rostos dos vizinhos no seletor (antes, depois)
var _p_center: CutPanel
var _p_items: CutPanel
var _p_pass: CutPanel
var _p_attr: CutPanel
var _c_name: Label
var _c_role_holder: Control
var _model: TextureRect
var _model_back: CutPanel
var _slots_box: Control
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

	# arte do personagem, à esquerda (fica atrás dos painéis)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_art)

	var tag := CutPanel.make(Rect2(20, 14, 190, 66), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	_stage.add_child(tag)
	var title := Paper.label("GEAR", 40, Paper.INK, Paper.display())
	title.size = Vector2(190, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.rotation = deg_to_rad(-2.0)
	title.pivot_offset = title.size * 0.5
	tag.add_child(title)

	_build_selector()
	_build_attributes()
	_build_center()
	_build_items()
	_build_passives()
	_build_detail()

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
	vb.position = Vector2(28, 664)
	vb.size = Vector2(132, 42)
	vb.pressed.connect(func(): back_pressed.emit())
	_stage.add_child(vb)
	var cb := ShineButton.new()
	cb.text = "CARTAS"
	cb.font_px = 15
	cb.fill = Paper.GOLD
	cb.fill_hover = Paper.GOLD_HOVER
	cb.shadow = Vector2(5, 5)
	cb.position = Vector2(182, 666)
	cb.size = Vector2(118, 38)
	cb.pressed.connect(func(): cards_pressed.emit(hero))
	_stage.add_child(cb)


## Seletor de personagem: seta, vizinho apagado, rosto + nome + função, vizinho apagado, seta.
func _build_selector() -> void:
	_stage.add_child(CutPanel.make(Rect2(300, 16, 580, 64), [[.02, 0], [1, .06], [.98, 1], [0, .94]], Paper.INK, 0, Vector2(6, 7)))
	var prev := _arrow(-1)
	prev.position = Vector2(308, 24)
	prev.pressed.connect(_switch.bind(-1))
	_stage.add_child(prev)
	var next := _arrow(1)
	next.position = Vector2(824, 24)
	next.pressed.connect(_switch.bind(1))
	_stage.add_child(next)
	for k in 2:
		var nf := TextureRect.new()
		nf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		nf.position = Vector2(366 if k == 0 else 780, 28)
		nf.size = Vector2(32, 42)
		nf.modulate = Color(1, 1, 1, 0.4)
		nf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(nf)
		_near.append(nf)
	var face_frame := CutPanel.make(Rect2(414, 20, 44, 56), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.CREAM, 0, Vector2.ZERO)
	face_frame.rotation = deg_to_rad(-3.0)
	_stage.add_child(face_frame)
	_hero_face = TextureRect.new()
	_hero_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_face.position = Vector2(3, 3)
	_hero_face.size = Vector2(38, 50)
	face_frame.add_child(_hero_face)
	_hero_name = Paper.label("", 26, Paper.CREAM, Paper.display())
	_hero_name.position = Vector2(472, 18)
	_hero_name.size = Vector2(300, 34)
	_hero_name.clip_text = true
	_stage.add_child(_hero_name)
	_hero_role = Paper.label("", 14, Paper.GOLD, Paper.body(800))
	_hero_role.position = Vector2(474, 50)
	_hero_role.size = Vector2(300, 22)
	_hero_role.clip_text = true
	_stage.add_child(_hero_role)


func _build_attributes() -> void:
	_p_attr = CutPanel.make(Rect2(24, 478, 300, 170), [[0, .03], [1, 0], [.985, 1], [.02, .97]], Paper.INK, 5, Vector2(8, 8))
	_stage.add_child(_p_attr)
	var chip := Chip.new()
	chip.px = 14
	chip.pad = 12.0
	chip.fill = Paper.GOLD
	chip.shadow = Vector2(-3, 4)
	chip.text = "ATRIBUTOS"
	chip.position = Vector2(40, 466)
	_stage.add_child(chip)
	_attr_box = Control.new()
	_attr_box.position = Vector2(42, 504)
	_attr_box.size = Vector2(264, 136)
	_attr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_attr_box)


## Ficha do herói: nome, função, retrato (no lugar do modelo 3D) e a coluna de slots.
func _build_center() -> void:
	_p_center = CutPanel.make(Rect2(346, 100, 420, 376), [[0, .01], [1, 0], [.985, 1], [.015, .99]], Paper.NAVY, 6, Vector2(10, 10))
	_stage.add_child(_p_center)
	_c_name = Paper.label("", 24, Paper.CREAM, Paper.display())
	_c_name.position = Vector2(366, 110)
	_c_name.size = Vector2(250, 32)
	_c_name.clip_text = true
	_stage.add_child(_c_name)
	_c_role_holder = Control.new()
	_c_role_holder.position = Vector2(368, 144)
	_c_role_holder.size = Vector2(250, 24)
	_c_role_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_c_role_holder)
	_model_back = CutPanel.make(Rect2(372, 182, 252, 276), [[0, 0], [1, .02], [.98, 1], [.02, .98]], Paper.CREAM, 5, Vector2(7, 8))
	_stage.add_child(_model_back)
	_model = TextureRect.new()
	_model.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_model.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_model.position = Vector2(384, 194)
	_model.size = Vector2(228, 252)
	_model.clip_contents = true
	_model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_model)
	var soon := Chip.new()
	soon.px = 10
	soon.pad = 8.0
	soon.skew = 8.0
	soon.border = 2.0
	soon.shadow = Vector2(-2, 3)
	soon.text = "MODELO 3D EM BREVE"
	soon.position = Vector2(498 - soon.size.x * 0.5, 446)
	_stage.add_child(soon)
	var lt := Paper.label("EQUIPADO", 14, Paper.GOLD, Paper.display())
	lt.position = Vector2(640, 116)
	lt.size = Vector2(112, 22)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(lt)
	_slots_box = Control.new()
	_slots_box.position = Vector2(662, 148)
	_slots_box.size = Vector2(70, 310)
	_slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slots_box)


## Mochila: equipamentos soltos e, embaixo, o consumível.
func _build_items() -> void:
	_p_items = CutPanel.make(Rect2(790, 100, 466, 376), [[.01, 0], [1, .01], [.99, 1], [0, .99]], Paper.NAVY, 6, Vector2(10, 10))
	_stage.add_child(_p_items)
	var lt := Paper.label("ITENS", 20, Paper.GOLD, Paper.display())
	lt.position = Vector2(812, 110)
	lt.size = Vector2(200, 30)
	_stage.add_child(lt)
	var sub := Paper.label("mochila: o que dá pra equipar", 13, DIM, Paper.body(700))
	sub.position = Vector2(960, 116)
	sub.size = Vector2(278, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(sub)
	_bag_box = Control.new()
	_bag_box.position = Vector2(814, 150)
	_bag_box.size = Vector2(420, 220)
	_bag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_bag_box)
	_bag_empty = Paper.label("Mochila vazia.\nOs equipamentos são vendidos na loja de itens.", 15, DIM, Paper.body(700))
	_bag_empty.position = Vector2(814, 190)
	_bag_empty.size = Vector2(420, 80)
	_bag_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage.add_child(_bag_empty)
	var line := ColorRect.new()
	line.color = Color(Paper.CREAM.r, Paper.CREAM.g, Paper.CREAM.b, 0.18)
	line.position = Vector2(812, 380)
	line.size = Vector2(424, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(line)
	var ct := Paper.label("CONSUMÍVEL", 13, Paper.CYAN, Paper.display())
	ct.position = Vector2(812, 388)
	ct.size = Vector2(140, 20)
	_stage.add_child(ct)
	var cs := Paper.label("um por luta", 12, DIM, Paper.body(700))
	cs.position = Vector2(812, 406)
	cs.size = Vector2(140, 18)
	_stage.add_child(cs)
	_item_box = Control.new()
	_item_box.position = Vector2(960, 392)
	_item_box.size = Vector2(280, 66)
	_item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_item_box)


func _build_passives() -> void:
	_p_pass = CutPanel.make(Rect2(346, 494, 910, 102), [[0, .04], [1, 0], [.995, 1], [.005, .96]], Paper.NAVY, 5, Vector2(8, 8))
	_stage.add_child(_p_pass)
	var lt := Paper.label("PASSIVAS", 16, Paper.GOLD, Paper.display())
	lt.position = Vector2(366, 502)
	lt.size = Vector2(160, 24)
	_stage.add_child(lt)
	_pass_count = Paper.label("", 13, DIM, Paper.body(700))
	_pass_count.position = Vector2(700, 504)
	_pass_count.size = Vector2(538, 20)
	_pass_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(_pass_count)
	_pass_box = Control.new()
	_pass_box.position = Vector2(366, 530)
	_pass_box.size = Vector2(872, 54)
	_pass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pass_box)
	_pass_empty = Paper.label("Nenhuma ainda. Lute com as cartas de aprendizado no baralho: em 100% elas viram passiva.", 15, DIM, Paper.body(700))
	_pass_empty.position = Vector2(366, 544)
	_pass_empty.size = Vector2(872, 24)
	_stage.add_child(_pass_empty)


## Ficha do que estiver escolhido (ou embaixo do mouse).
func _build_detail() -> void:
	_stage.add_child(CutPanel.make(Rect2(346, 612, 910, 78), [[.004, 0], [1, .04], [.996, 1], [0, .96]], Paper.CREAM, 5, Vector2(8, 8)))
	_d_name = Paper.label("", 20, Paper.INK, Paper.display())
	_d_name.position = Vector2(366, 618)
	_d_name.size = Vector2(330, 28)
	_d_name.clip_text = true
	_stage.add_child(_d_name)
	_d_chips = Control.new()
	_d_chips.position = Vector2(370, 652)
	_d_chips.size = Vector2(330, 26)
	_d_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_d_chips)
	_d_desc = Paper.label("", 16, Paper.INK, Paper.body(700))
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.add_theme_constant_override("line_spacing", -4)
	_d_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_desc.position = Vector2(712, 618)
	_d_desc.size = Vector2(526, 66)
	_d_desc.clip_text = true
	_stage.add_child(_d_desc)
	# faixa escura atrás da dica: o fundo de alguns temas é claro
	_stage.add_child(CutPanel.make(Rect2(676, 697, 588, 20), [[.01, 0], [1, 0], [.99, 1], [0, 1]], Color(Paper.INK, 0.82), 0, Vector2.ZERO))
	_hint = Paper.label(HINT, 13, DIM, Paper.body(700))
	_hint.position = Vector2(346, 696)
	_hint.size = Vector2(904, 20)
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


func _draw_back(d: Control) -> void:
	var dot: Color = _th.get("bg2", Color("2B3384"))
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.0, Color(dot.r, dot.g, dot.b, 0.5))
	# palco da arte, à esquerda, com as faixas do tema
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(400, 760), [[0, 0], [1, 0], [.72, 1], [0, 1]]), Vector2(-20, -20)), _th.get("stage", _th.get("deep", Paper.INK)))
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(380, 130), [[0, .5], [1, 0], [1, .5], [0, 1]]), Vector2(-10, 300)), _th.get("acc", Paper.GOLD))
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(380, 56), [[0, .6], [1, 0], [1, .4], [0, 1]]), Vector2(-10, 404)), _th.get("stripe3", Paper.CREAM))


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
	_bg.queue_redraw()
	_stage.get_node("Back").queue_redraw()
	_p_center.fill = _th["deep"]
	_p_items.fill = _th["deep"]
	_p_pass.fill = _th["deep2"]
	_p_attr.fill = _th["deep2"]
	_model_back.fill = _th["bg2"]
	var nm := String(h["name"]).to_upper()
	_hero_name.text = nm
	_hero_role.text = String(h["role"]).to_upper()
	_hero_face.texture = _face(hero)
	var at := ORDER.find(hero)
	_near[0].texture = _face(ORDER[posmod(at - 1, ORDER.size())])
	_near[1].texture = _face(ORDER[posmod(at + 1, ORDER.size())])
	_c_name.text = nm
	var px := 24
	while px > 14 and Paper.display().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 246.0:
		px -= 1
	_c_name.add_theme_font_size_override("font_size", px)
	_clear(_c_role_holder)
	var rc := Chip.new()
	rc.px = 11
	rc.pad = 9.0
	rc.skew = 8.0
	rc.border = 2.0
	rc.shadow = Vector2(-2, 3)
	rc.fill = _th["acc"]
	rc.ink = _th["acc_t"]
	rc.text = String(h["role"]).to_upper()
	_c_role_holder.add_child(rc)
	_model.texture = _face(hero)
	# arte de corpo inteiro: a maior que cabe na coluna da esquerda, sem distorcer
	var art := "res://assets/portraits/%s_art.webp" % h["key"]
	_art.visible = ResourceLoader.exists(art)
	if _art.visible:
		var tex: Texture2D = load(art)
		var ts := tex.get_size()
		var w := minf(318.0, 540.0 * ts.x / ts.y)
		_art.texture = tex
		_art.size = Vector2(w, w * ts.y / ts.x)
		ArtShadow.for_hero(_art, h["key"])
		# figura baixa encosta no quadro de atributos em vez de flutuar no topo
		_art_home = Vector2(172.0 - w * 0.5, 96.0 + maxf(0.0, 400.0 - _art.size.y))
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
	t.id = id
	t.empty_fill = Color(_th["deep2"], 1.0).darkened(0.25)
	t.selected = _sel["zone"] == zone and ((idx >= 0 and _sel["idx"] == idx) or (idx < 0 and _sel["id"] == id))
	t.clicked.connect(_click.bind(zone, id, idx))
	t.hovered.connect(func(on: bool):
		if on:
			_show(zone, id, idx)
		else:
			_show(_sel["zone"], _sel["id"], _sel["idx"]))
	box.add_child(t)
	return t


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
	# slots de equipamento
	_clear(_slots_box)
	var worn: Array = Knowledge.gear_of(hero)
	for n in Knowledge.GEAR_SLOTS:
		var id: String = String(worn[n]) if n < worn.size() else ""
		var t := _tile(_slots_box, Vector2(0, n * 78), Vector2(70, 70), id, "slot", n)
		t.tag = str(n + 1)
	# mochila
	_clear(_bag_box)
	var bag: Array = Knowledge.gear_bag(hero)
	_bag_empty.visible = bag.is_empty()
	for n in bag.size():
		var t := _tile(_bag_box, Vector2((n % 5) * 84 + 4, (n / 5) * 76), Vector2(68, 68), bag[n], "bag")
		var who := Knowledge.holder(bag[n])
		if who >= 0 and who != hero:
			t.badge = _face(who)
	# consumível: o slot e, ao lado, os que estão soltos
	_clear(_item_box)
	var slots: Array = Knowledge.deck(hero)["item"]
	var held: String = String(slots[0]) if slots.size() > 0 else ""
	var st := _tile(_item_box, Vector2(0, 0), Vector2(64, 64), held, "islot", 0)
	st.empty_fill = Paper.KIND["item"]["eb"]
	var x := 96.0
	for id in _consumables():
		if id == held:
			continue
		var t := _tile(_item_box, Vector2(x, 0), Vector2(64, 64), id, "ibag")
		var who := Knowledge.holder(id)
		if who >= 0 and who != hero:
			t.badge = _face(who)
		x += 78.0
	if x > 96.0:
		var arrow := Paper.label("‹", 30, DIM, Paper.body(800))
		arrow.position = Vector2(66, 8)
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
		var y := n * 34.0
		if n > 0:
			var line := ColorRect.new()
			line.color = Color(Paper.CREAM.r, Paper.CREAM.g, Paper.CREAM.b, 0.14)
			line.position = Vector2(0, y - 1)
			line.size = Vector2(264, 2)
			_attr_box.add_child(line)
		var l := Paper.label(rows[n][0], 13, DIM, Paper.display())
		l.position = Vector2(0, y)
		l.size = Vector2(120, 32)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attr_box.add_child(l)
		var has_bonus: bool = rows[n][2] != ""
		var v := Paper.label(rows[n][1], 20, BONUS if has_bonus else Paper.CREAM, Paper.body(800))
		v.position = Vector2(110, y)
		v.size = Vector2(70, 32)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_attr_box.add_child(v)
		if has_bonus:
			var b := Paper.label(rows[n][2], 14, BONUS, Paper.body(800))
			b.position = Vector2(188, y)
			b.size = Vector2(80, 32)
			b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_attr_box.add_child(b)


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
		KEY_ESCAPE: back_pressed.emit()
		_: return
	get_viewport().set_input_as_handled()
