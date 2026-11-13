class_name TutorialsScreen
extends Control
## Menu de tutoriais: o botão TUTORIAL DO JOGO da tela inicial abre esta lista, e daqui o
## jogador escolhe qual aula fazer. Hoje só existe o TUTORIAL 1; os outros lugares aparecem
## como "EM BREVE". Pra criar um tutorial novo, faça a cena dele e ponha uma entrada em LIST.
## Visual: kit de papel (Paper), no molde da prancha "Party" do design "Tela de Cartas".
##   A D / ← → escolhem · ENTER começa · ESC volta.

signal back_pressed
## `scene`: caminho da cena do tutorial escolhido (quem troca de cena é o menus.gd).
signal tutorial_chosen(scene: String)

const STAGE := Vector2(1280, 720)
const TILE := Vector2(250, 400)
const NAVY2 := Color("2B3384")
const PURPLE := Color("5B2BB8")
const DIM := Color("B9BEEA")
const ART := "res://assets/portraits/shopkeeper_art.webp"

## Um por tutorial. Sem "scene" = ainda não existe (aparece trancado, como "EM BREVE").
const LIST := [
	{"name": "TUTORIAL 1", "title": "Mecânicas e cartas", "scene": "res://tutorial.tscn",
		"desc": "As quatro mecânicas básicas e como ensinar seus companheiros com cartas.",
		"tags": ["4 MECÂNICAS", "CARTAS"]},
	{"name": "TUTORIAL 2", "title": "Em breve"},
	{"name": "TUTORIAL 3", "title": "Em breve"},
]

var _stage: Control
var _tiles: Array[Control] = []
var _focus := 0
var _start: ShineButton
var _built := false


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		# aberta sozinha (F6): não mexe no save
		Knowledge.persist = false
		open()


func open() -> void:
	_focus = 0
	_mark()
	# os cartões caem um depois do outro
	for k in _tiles.size():
		var t := _tiles[k]
		t.modulate.a = 0.0
		var home: float = t.get_meta("y")
		t.position.y = home - 30.0
		var tw := t.create_tween().set_parallel(true)
		tw.tween_property(t, "modulate:a", 1.0, 0.14).set_delay(0.05 + k * 0.07)
		tw.tween_property(t, "position:y", home, 0.26).set_delay(0.05 + k * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# fundo: passa do palco pros lados, pra janelas mais largas que 16:9
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): bg.draw_rect(Rect2(Vector2.ZERO, bg.size), Paper.NAVY))
	add_child(bg)

	# palco fixo de 1280x720, centralizado
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
	back.size = STAGE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(_draw_back.bind(back))
	_stage.add_child(back)

	# quem dá as aulas, no canto direito
	var art := TextureRect.new()
	art.texture = load(ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(900, 60)
	art.size = Vector2(400, 745)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(art)

	# título
	var tag := CutPanel.make(Rect2(20, 14, 330, 70), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	_stage.add_child(tag)
	var title := Paper.label("TUTORIAIS", 40, Paper.INK, Paper.display())
	title.size = Vector2(330, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.rotation = deg_to_rad(-2.0)
	title.pivot_offset = title.size * 0.5
	tag.add_child(title)
	var who := Chip.new()
	who.px = 14
	who.fill = Paper.INK
	who.ink = Paper.CREAM
	who.shadow = Vector2.ZERO
	who.text = "AULAS DA SHOPKEEPER"
	who.position = Vector2(382, 36)
	who.rotation = deg_to_rad(2.0)
	_stage.add_child(who)

	var rots := [-2.0, 1.0, -1.0, 2.0]
	for k in LIST.size():
		var t := _tile(k, LIST[k])
		t.position = Vector2(64 + k * (TILE.x + 26), 150 if LIST[k].has("scene") else 172)
		t.set_meta("y", t.position.y)
		t.rotation = deg_to_rad(rots[k % rots.size()])
		_stage.add_child(t)
		_tiles.append(t)

	var vb := ShineButton.new()
	vb.text = "VOLTAR"
	vb.font_px = 18
	vb.chevron = -1
	vb.chevron_px = 16
	vb.skew = 12
	vb.border = 4
	vb.shadow = Vector2(5, 5)
	vb.fill = Paper.CREAM
	vb.fill_hover = Paper.GOLD
	vb.position = Vector2(44, 638)
	vb.size = Vector2(160, 50)
	vb.pressed.connect(func(): back_pressed.emit())
	_stage.add_child(vb)

	_start = ShineButton.new()
	_start.text = "COMEÇAR"
	_start.shape = [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	_start.border = 6
	_start.font_px = 34
	_start.text_rot = -3
	_start.shadow = Vector2(10, 10)
	_start.fill = Paper.GOLD
	_start.fill_hover = Paper.GOLD_HOVER
	_start.fg_hover = Paper.RED
	_start.idle = true
	_start.hover_scale = 1.05
	_start.position = Vector2(540, 608)
	_start.size = Vector2(340, 88)
	_start.pressed.connect(_go)
	_stage.add_child(_start)


func _draw_back(d: Control) -> void:
	# pontilhado e recortes, como o fundo das telas do design
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.0, NAVY2)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(900, 400), [[0, 0], [1, 0], [.72, .54], [.86, .74], [.22, 1], [0, .78]]), Vector2(-40, -40)), PURPLE)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(700, 220), [[0, .4], [.9, 0], [1, 1], [0, 1]]), Vector2(-40, 540)), Paper.INK)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(520, 720), [[.24, 0], [1, 0], [1, 1], [.04, 1], [.16, .58], [.06, .44]]), Vector2(820, 0)), Paper.INK)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(500, 720), [[.24, 0], [1, 0], [1, 1], [.04, 1], [.16, .58], [.06, .44]]), Vector2(834, 0)), PURPLE.darkened(0.25))
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(470, 170), [[0, .78], [1, 0], [1, .3], [.06, 1]]), Vector2(860, 300)), Paper.GOLD)


## Cartão de um tutorial: número, nome, descrição e selos. Trancado = "EM BREVE".
func _tile(k: int, info: Dictionary) -> Control:
	var open_one: bool = info.has("scene")
	var t := Control.new()
	t.size = TILE
	t.pivot_offset = TILE * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open_one else Control.CURSOR_ARROW
	var shape := [[0, .03], [1, 0], [.97, 1], [.03, .97]]
	var ring := CutPanel.make(Rect2(-7, -7, TILE.x + 14, TILE.y + 14), shape, Paper.GOLD, 4, Vector2.ZERO)
	ring.name = "Ring"
	ring.visible = false
	t.add_child(ring)
	t.add_child(CutPanel.make(Rect2(0, 0, TILE.x, TILE.y), shape, Paper.CREAM if open_one else Color("1A1E52"), 6, Vector2(9, 10)))

	var num := CutPanel.make(Rect2(14, 18, 64, 64), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.GOLD if open_one else NAVY2, 4, Vector2(4, 4))
	num.rotation = deg_to_rad(-8.0)
	t.add_child(num)
	var n := Paper.label(str(k + 1), 36, Paper.INK if open_one else DIM, Paper.display())
	n.size = Vector2(64, 64)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(n)

	var ink := Paper.INK if open_one else DIM
	var name_l := Paper.label(String(info["name"]), 26, ink, Paper.display())
	name_l.position = Vector2(14, 104)
	name_l.size = Vector2(TILE.x - 28, 34)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(name_l)
	if not open_one:
		var soon := Chip.new()
		soon.px = 15
		soon.fill = Paper.INK
		soon.ink = DIM
		soon.shadow = Vector2.ZERO
		soon.text = "EM BREVE"
		soon.position = Vector2((TILE.x - soon.size.x) * 0.5, 190)
		soon.rotation = deg_to_rad(-6.0)
		t.add_child(soon)
		return t

	var sub := Paper.label(String(info["title"]), 19, Paper.INK, Paper.body(800))
	sub.position = Vector2(14, 142)
	sub.size = Vector2(TILE.x - 28, 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(sub)
	var desc := Paper.label(String(info.get("desc", "")), 16, Paper.INK, Paper.body(700))
	# quebra de linha ligada ANTES do tamanho: sem ela o Label se alarga pro texto inteiro
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(24, 182)
	desc.size = Vector2(TILE.x - 48, 110)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_constant_override("line_spacing", -4)
	t.add_child(desc)
	var y := 306.0
	for tag_text in info.get("tags", []):
		var c := Chip.new()
		c.px = 13
		c.fill = Paper.INK
		c.ink = Paper.CREAM
		c.shadow = Vector2.ZERO
		c.text = tag_text
		c.position = Vector2((TILE.x - c.size.x) * 0.5, y)
		t.add_child(c)
		y += 34.0

	t.mouse_entered.connect(func():
		_focus = k
		_mark())
	t.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_focus = k
			_mark()
			if e.double_click:
				_go())
	return t


## Índices dos tutoriais que já existem.
func _open_ones() -> Array:
	var out: Array = []
	for k in LIST.size():
		if LIST[k].has("scene"):
			out.append(k)
	return out


func _mark() -> void:
	for k in _tiles.size():
		_tiles[k].get_node("Ring").visible = k == _focus and LIST[k].has("scene")
		_tiles[k].scale = Vector2.ONE * (1.04 if k == _focus else 1.0)
	_start.disabled = not LIST[_focus].has("scene")


func _step(dir: int) -> void:
	var ones := _open_ones()
	if ones.is_empty():
		return
	var at := ones.find(_focus)
	_focus = ones[posmod(at + dir, ones.size())]
	_mark()


func _go() -> void:
	if LIST[_focus].has("scene"):
		tutorial_chosen.emit(String(LIST[_focus]["scene"]))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _step(-1)
		KEY_D, KEY_RIGHT: _step(1)
		KEY_ENTER, KEY_KP_ENTER: _go()
		KEY_ESCAPE: back_pressed.emit()
