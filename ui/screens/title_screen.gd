class_name TitleScreen
extends Control
## Tela inicial: JOGAR (saves -> cafeteria -> bosses), SKILLS (consulta das habilidades de todos os
## personagens), TUTORIAL e OPÇÕES.
## As cartas (gear) e a loja são de cada save: o acesso fica dentro dele, na tela de bosses (CARTAS e LOJA).
## Layout da prancha "B · Elenco inteiro" do design "Menu Principal" (kit Paper): logo numa linha em cima,
## os heróis em faixas inclinadas (cada uma na cor do tema dele) que andam pra direita em carrossel e os botões numa barra embaixo.
## A tela é montada em código; a cena (title_screen.tscn) só tem a raiz com o script.

signal play_pressed
signal skills_pressed
signal options_pressed
signal tutorial_pressed

const STAGE := Vector2(1280, 720)
const PURPLE := Color("5B2BB8")
const PURPLE2 := Color("7A3FE0")
const DEEP := Color("1E2460")
const DEEP2 := Color("2B3384")
const COOKIE := Color("D9984F")
## Faixa do elenco: topo, altura e inclinação (graus) dos recortes.
const BAND_Y := 150.0
const BAND_H := 398.0
const BAND_SKEW := 12.0
## Largura de cada faixa e velocidade do carrossel (px por segundo, pra direita).
const BAND_W := 213.0
const BAND_SPEED := 28.0
## Caixa em que a arte é encaixada (cobre a caixa, ancorada no topo).
const ART_BOX := Vector2(300, 560)
const ART_WIDE := 440.0
## Um herói por faixa, na ordem do carrossel: chave da arte, cor do fundo e cor do pontilhado.
const ROSTER := [
	["tank", "2B4FBF", "4D80FF"],
	["maga", "E08A14", "FFC233"],
	["healer", "1F8A4C", "3FB86B"],
	["ringstar", "D9408F", "FF73BE"],
	["sleepwalker", "5A5FC8", "8A8FF0"],
	["burner", "D9622A", "FF9A4D"],
	["apothecary", "2F7A5C", "46A082"],
	["assassina", "7A3FE0", "9E5CFF"],
	["nurse", "D9DCF5", "B9BFEE"],
]

var _stage: Control
var _btns: Array = []
var _focus := 0
var _panels: Array[Control] = []
var _scroll := 0.0
var _built := false


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		# aberta sozinha (F6): não mexe no save
		Knowledge.persist = false
		open()


func open() -> void:
	_focus = 0
	# o logo "carimba" e os botões entram um depois do outro
	var logo: Control = $Stage/LogoPanel
	logo.scale = Vector2.ONE * 0.7
	logo.create_tween().tween_property(logo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in _btns.size():
		var b: Control = _btns[k]
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.08 + k * 0.07)
		tw.tween_property(b, "modulate:a", 1.0, 0.16)
	_mark_focus()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): bg.draw_rect(Rect2(Vector2.ZERO, bg.size), Paper.INK))
	add_child(bg)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
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
	_build_band()

	_build_logo()

	var motto := Chip.new()
	motto.px = 13
	motto.pad = 18.0
	motto.fill = Paper.INK
	motto.ink = Paper.CREAM
	motto.border = 0.0
	motto.shadow = Vector2.ZERO
	motto.text = "UM JOGADOR · QUATRO HERÓIS · UMA BOSS"
	motto.position = Vector2(STAGE.x - 56.0 - motto.size.x, 62)
	motto.rotation = deg_to_rad(-2.0)
	_stage.add_child(motto)

	var play := _button("BtnPlay", "JOGAR", Rect2(64, 580, 340, 100), Paper.GOLD, 52)
	play.shape = [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	play.border = 7.0
	play.shadow = Vector2(12, 12)
	play.text_rot = -3.0
	play.fill_hover = Paper.GOLD_HOVER
	play.hover_scale = 1.05
	play.pressed.connect(func(): play_pressed.emit())
	var skills := _button("BtnSkills", "SKILLS", Rect2(472, 606, 220, 60), Paper.CYAN, 26)
	skills.auto_hover = true
	skills.pressed.connect(func(): skills_pressed.emit())
	var tut := _button("BtnTutorial", "TUTORIAL", Rect2(732, 606, 220, 60), Paper.CREAM, 24)
	tut.fill_hover = Paper.GOLD_HOVER
	tut.pressed.connect(func(): tutorial_pressed.emit())
	var opt := _button("BtnOptions", "OPÇÕES", Rect2(992, 606, 220, 60), Paper.CREAM, 24)
	opt.fill_hover = Paper.GOLD_HOVER
	opt.pressed.connect(func(): options_pressed.emit())


func _button(node_name: String, label: String, rect: Rect2, col: Color, px: int) -> ShineButton:
	var b := ShineButton.new()
	b.name = node_name
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.fill = col
	b.font_px = px
	b.skew = 12.0
	b.border = 4.0
	b.shadow = Vector2(6, 6)
	var k := _btns.size()
	b.mouse_entered.connect(func():
		_focus = k
		_mark_focus())
	_stage.add_child(b)
	_btns.append(b)
	return b


func _build_logo() -> void:
	var logo := Control.new()
	logo.name = "LogoPanel"
	logo.position = Vector2(44, 20)
	logo.size = Vector2(640, 112)
	logo.pivot_offset = logo.size * 0.5
	logo.rotation = deg_to_rad(-2.0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(logo)
	logo.add_child(CutPanel.make(Rect2(Vector2.ZERO, logo.size), [[0, .08], [1, 0], [.98, 1], [.01, .92]], DEEP, 6, Vector2(10, 10)))
	var f := Paper.display(0.14)
	var bora := Paper.label("BORA", 56, Paper.CREAM, f)
	bora.position = Vector2(34, 16)
	bora.size = Vector2(200, 80)
	bora.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_child(bora)
	var bis := Paper.label("BISCOITAR", 56, Paper.GOLD, f)
	bis.position = Vector2(34 + f.get_string_size("BORA", HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x + 18.0, 16)
	bis.size = Vector2(400, 80)
	bis.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_child(bis)
	# o biscoito mordendo o canto do logo
	var cookie := Control.new()
	cookie.position = Vector2(578, -22)
	cookie.size = Vector2(84, 84)
	cookie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cookie.draw.connect(func():
		cookie.draw_circle(Vector2(42, 42), 42, Paper.INK)
		cookie.draw_circle(Vector2(42, 42), 36, COOKIE)
		for c in [[26, 28, 6], [52.5, 22.5, 4.5], [58.5, 50.5, 6.5], [30.5, 56.5, 4.5]]:
			cookie.draw_circle(Vector2(c[0], c[1]), c[2], Paper.BROWN))
	logo.add_child(cookie)


## Faixa do elenco: um recorte inclinado por herói, com a arte dentro. As faixas andam pra direita
## sem parar e voltam pela esquerda, então todos os heróis passam pela tela.
func _build_band() -> void:
	var band := Control.new()
	band.name = "Band"
	band.position = Vector2(0, BAND_Y)
	band.size = Vector2(STAGE.x, BAND_H)
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(band)
	for r in ROSTER:
		var path := "res://assets/portraits/%s_art.webp" % r[0]
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		var panel := Control.new()
		panel.size = Vector2(BAND_W, BAND_H)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.draw.connect(_draw_panel.bind(panel, tex, Color(r[1]), Color(r[2])))
		band.add_child(panel)
		_panels.append(panel)
	_place_panels()


func _draw_panel(ci: Control, tex: Texture2D, bg: Color, dot: Color) -> void:
	var d := tan(deg_to_rad(BAND_SKEW)) * BAND_H * 0.5
	var pts := PackedVector2Array([Vector2(d, 0), Vector2(BAND_W + d, 0), Vector2(BAND_W - d, BAND_H), Vector2(-d, BAND_H)])
	ci.draw_colored_polygon(pts, bg)
	_dots(ci, pts, dot)
	if tex != null:
		# a arte cobre a caixa ART_BOX, centrada na faixa e recortada no formato dela
		var ts := tex.get_size()
		# arte larga (Sleepwalker, Maga) encolhe até ART_WIDE de largura, pra caber mais do boneco na faixa
		var sz := ts * maxf(ART_BOX.x / ts.x, minf(ART_BOX.y / ts.y, ART_WIDE / ts.x))
		var at := Vector2((BAND_W - sz.x) * 0.5, 14.0)
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append((p - at) / sz)
		ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)
	# contorno dos dois lados: quem dá a volta no carrossel muda de ordem de desenho
	ci.draw_line(pts[0], pts[3], Paper.INK, 7.0, true)
	ci.draw_line(pts[1], pts[2], Paper.INK, 7.0, true)


func _place_panels() -> void:
	var d := tan(deg_to_rad(BAND_SKEW)) * BAND_H * 0.5
	var total := BAND_W * _panels.size()
	for i in _panels.size():
		_panels[i].position.x = fposmod(i * BAND_W + _scroll + d + BAND_W, total) - d - BAND_W


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_scroll = fposmod(_scroll + BAND_SPEED * delta, BAND_W * _panels.size())
	_place_panels()


## Fundo: pontilhado, recortes e a base escura atrás da faixa do elenco.
func _draw_back(ci: Control) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, STAGE), PURPLE)
	_dots(ci, PackedVector2Array([Vector2.ZERO, Vector2(STAGE.x, 0), STAGE, Vector2(0, STAGE.y)]), PURPLE2)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(694, -20), Vector2(1320, -20), Vector2(1320, 160), Vector2(640, 120)]), PURPLE2)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-20, 584), Vector2(1300, 540), Vector2(1300, 740), Vector2(-20, 740)]), DEEP)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(420, 692), Vector2(1300, 668), Vector2(1300, 688), Vector2(429, 708)]), DEEP2)
	ci.draw_rect(Rect2(0, BAND_Y - 8.0, STAGE.x, BAND_H + 16.0), Paper.INK)


## Pontilhado de 20 em 20 px, só nos pontos que caem dentro do polígono.
func _dots(ci: Control, pts: PackedVector2Array, col: Color) -> void:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	var y := floorf(box.position.y / 20.0) * 20.0 + 10.0
	while y < box.end.y:
		var x := floorf(box.position.x / 20.0) * 20.0 + 10.0
		while x < box.end.x:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pts):
				ci.draw_circle(Vector2(x, y), 3.2, col)
			x += 20.0
		y += 20.0


func _mark_focus() -> void:
	for k in _btns.size():
		_btns[k].focused = k == _focus


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT, KEY_W, KEY_UP:
			_focus = posmod(_focus - 1, _btns.size())
			_mark_focus()
		KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN:
			_focus = posmod(_focus + 1, _btns.size())
			_mark_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if not _btns[_focus].disabled:
				_btns[_focus].pressed.emit()
