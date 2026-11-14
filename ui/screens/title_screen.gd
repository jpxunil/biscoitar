class_name TitleScreen
extends Control
## Tela inicial: JOGAR (saves -> cafeteria -> bosses), LOJA (abre depois da primeira vitória),
## SKILLS (consulta das habilidades de todos os personagens), TUTORIAL e OPÇÕES. A LOJA vale pro save ativo; sem save escolhido, leva pros saves.
## As cartas (gear) são de cada save: o acesso fica dentro dele, na tela de bosses (botão CARTAS).
## Layout da prancha "B · Elenco inteiro" do design "Menu Principal" (kit Paper): logo numa linha em cima,
## os heróis em faixas inclinadas (cada uma na cor do tema dele) e os botões numa barra embaixo.
## A tela é montada em código; a cena (title_screen.tscn) só tem a raiz com o script.

signal play_pressed
signal shop_pressed
signal skills_pressed
signal options_pressed
signal tutorial_pressed

const STAGE := Vector2(1280, 720)
const PURPLE := Color("5B2BB8")
const PURPLE2 := Color("7A3FE0")
const DEEP := Color("1E2460")
const DEEP2 := Color("2B3384")
const TICKET := Color("C9A6FF")
const COOKIE := Color("D9984F")
## Faixa do elenco: topo, altura e inclinação (graus) dos recortes.
const BAND_Y := 150.0
const BAND_H := 398.0
const BAND_SKEW := 12.0
## Bordas das faixas, medidas no meio da altura (a primeira e a última passam da tela).
const BAND_X := [-50.0, 213.0, 426.0, 639.0, 852.0, 1065.0, 1335.0]
## Caixa em que a arte é encaixada (cobre a caixa, ancorada no topo).
const ART_BOX := Vector2(300, 560)
## Um herói por faixa: chave da arte, cor do fundo e cor do pontilhado.
const ROSTER := [
	["tank", "2B4FBF", "4D80FF"],
	["maga", "E08A14", "FFC233"],
	["healer", "1F8A4C", "3FB86B"],
	["ringstar", "D9408F", "FF73BE"],
	["assassina", "7A3FE0", "9E5CFF"],
	["nurse", "D9DCF5", "B9BFEE"],
]

var _stage: Control
var _btns: Array = []
var _focus := 0
var _enter: Chip
var _arts: Array = []
var _coins: Label
var _tickets: Label
var _built := false


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		# aberta sozinha (F6): não mexe no save
		Knowledge.persist = false
		open()


func open() -> void:
	_coins.text = str(Knowledge.money)
	_tickets.text = str(Knowledge.tickets)
	$Stage/BtnShop.disabled = not Knowledge.shop_unlocked
	$Stage/ShopLock.visible = not Knowledge.shop_unlocked
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

	for r in ROSTER:
		var path := "res://assets/portraits/%s_art.webp" % r[0]
		_arts.append(load(path) if ResourceLoader.exists(path) else null)
	var back := Control.new()
	back.size = STAGE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(_draw_back.bind(back))
	_stage.add_child(back)

	_build_logo()
	_build_wallet()

	var motto := Chip.new()
	motto.px = 13
	motto.pad = 18.0
	motto.fill = Paper.INK
	motto.ink = Paper.CREAM
	motto.border = 0.0
	motto.shadow = Vector2.ZERO
	motto.text = "UM JOGADOR · QUATRO HERÓIS · UMA BOSS"
	motto.position = Vector2(STAGE.x - 56.0 - motto.size.x, 92)
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
	var shop := _button("BtnShop", "LOJA", Rect2(452, 606, 180, 60), Paper.KIND["purple"]["bg"], 24)
	shop.auto_hover = true
	shop.pressed.connect(func(): shop_pressed.emit())
	var skills := _button("BtnSkills", "SKILLS", Rect2(652, 606, 180, 60), Paper.CYAN, 24)
	skills.auto_hover = true
	skills.pressed.connect(func(): skills_pressed.emit())
	var tut := _button("BtnTutorial", "TUTORIAL", Rect2(852, 606, 180, 60), Paper.CREAM, 20)
	tut.fill_hover = Paper.GOLD_HOVER
	tut.pressed.connect(func(): tutorial_pressed.emit())
	var opt := _button("BtnOptions", "OPÇÕES", Rect2(1052, 606, 180, 60), Paper.CREAM, 20)
	opt.fill_hover = Paper.GOLD_HOVER
	opt.pressed.connect(func(): options_pressed.emit())

	var lock := Chip.new()
	lock.name = "ShopLock"
	lock.px = 11
	lock.pad = 10.0
	lock.fill = Paper.INK
	lock.ink = Paper.GOLD
	lock.border = 0.0
	lock.shadow = Vector2.ZERO
	lock.text = "VENÇA UM BOSS PRA ABRIR"
	lock.position = Vector2(446, 584)
	lock.rotation = deg_to_rad(-4.0)
	_stage.add_child(lock)

	# a etiqueta ENTER acompanha o botão em foco
	_enter = Chip.new()
	_enter.px = 14
	_enter.pad = 12.0
	_enter.skew = 0.0
	_enter.shadow = Vector2(4, 4)
	_enter.text = "ENTER"
	_enter.rotation = deg_to_rad(4.0)
	_stage.add_child(_enter)


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


func _build_wallet() -> void:
	var wallet := Control.new()
	wallet.name = "Wallet"
	wallet.size = Vector2(236, 46)
	wallet.position = Vector2(STAGE.x - 52.0 - wallet.size.x, 26)
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.draw.connect(func(): wallet.draw_colored_polygon(Paper.skew_rect(wallet.size, 12.0), Paper.INK))
	_stage.add_child(wallet)
	var coin := Control.new()
	coin.position = Vector2(22, 10)
	coin.size = Vector2(26, 26)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(func(): Ink.draw_coin(coin, 26))
	wallet.add_child(coin)
	_coins = Paper.label("0", 22, Paper.GOLD, Paper.display(0.0))
	_coins.name = "Coins"
	_coins.position = Vector2(56, 0)
	_coins.size = Vector2(72, 46)
	_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(_coins)
	var ticket := Control.new()
	ticket.position = Vector2(132, 10)
	ticket.size = Vector2(26, 26)
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket.draw.connect(func(): Ink.draw_ticket(ticket, 26))
	wallet.add_child(ticket)
	_tickets = Paper.label("0", 22, TICKET, Paper.display(0.0))
	_tickets.name = "Tickets"
	_tickets.position = Vector2(166, 0)
	_tickets.size = Vector2(60, 46)
	_tickets.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(_tickets)


## Fundo: pontilhado, recortes e a faixa do elenco (um recorte inclinado por herói, com a arte dentro).
func _draw_back(ci: Control) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, STAGE), PURPLE)
	_dots(ci, PackedVector2Array([Vector2.ZERO, Vector2(STAGE.x, 0), STAGE, Vector2(0, STAGE.y)]), PURPLE2)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(694, -20), Vector2(1320, -20), Vector2(1320, 160), Vector2(640, 120)]), PURPLE2)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-20, 584), Vector2(1300, 540), Vector2(1300, 740), Vector2(-20, 740)]), DEEP)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(420, 692), Vector2(1300, 668), Vector2(1300, 688), Vector2(429, 708)]), DEEP2)
	ci.draw_rect(Rect2(0, BAND_Y - 8.0, STAGE.x, BAND_H + 16.0), Paper.INK)
	var d := tan(deg_to_rad(BAND_SKEW)) * BAND_H * 0.5
	var bottom := BAND_Y + BAND_H
	for i in ROSTER.size():
		var l: float = BAND_X[i]
		var r: float = BAND_X[i + 1]
		var pts := PackedVector2Array([Vector2(l + d, BAND_Y), Vector2(r + d, BAND_Y), Vector2(r - d, bottom), Vector2(l - d, bottom)])
		ci.draw_colored_polygon(pts, Color(ROSTER[i][1]))
		_dots(ci, pts, Color(ROSTER[i][2]))
		var tex: Texture2D = _arts[i]
		if tex != null:
			# a arte cobre a caixa ART_BOX, centrada na parte da faixa que aparece na tela
			var ts := tex.get_size()
			var sz := ts * maxf(ART_BOX.x / ts.x, ART_BOX.y / ts.y)
			var cx := (maxf(l, 0.0) + minf(r, STAGE.x)) * 0.5
			var at := Vector2(cx - sz.x * 0.5, BAND_Y + 14.0)
			var uvs := PackedVector2Array()
			for p in pts:
				uvs.append((p - at) / sz)
			ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)
	for i in range(1, ROSTER.size()):
		var x: float = BAND_X[i]
		ci.draw_line(Vector2(x + d, BAND_Y), Vector2(x - d, bottom), Paper.INK, 7.0, true)


## Pontilhado de 20 em 20 px, só nos pontos que caem dentro do polígono.
func _dots(ci: Control, pts: PackedVector2Array, col: Color) -> void:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	box = box.intersection(Rect2(Vector2.ZERO, STAGE))
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
	var b: Control = _btns[_focus]
	_enter.position = b.position + Vector2(b.size.x - 54.0, -16.0)


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
