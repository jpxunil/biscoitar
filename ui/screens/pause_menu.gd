class_name PauseMenu
extends Control
## Menu de pause da luta (ESC). Congela a árvore com get_tree().paused e roda mesmo assim,
## porque fica em PROCESS_MODE_ALWAYS. Quem decide o que cada opção faz é o game.gd.
## Opções: CONTINUAR, TENTAR NOVAMENTE, OPÇÕES, SELEÇÃO DE CARTAS, MENU PRINCIPAL.
##   ↑↓ / W S escolhem · ENTER confirma · ESC ou a tecla de pause (ou CONTINUAR) volta pra luta.
## OPÇÕES abre a tela de opções por cima (hud.gd), com a luta ainda congelada.
## Visual: kit de papel (Paper), seguindo o design "Tela de Cartas": painel recortado, etiqueta
## creme de título, botão principal dourado e os outros em creme inclinado, todos com sombra dura.

signal resume_pressed
## TENTAR NOVAMENTE: recomeça a luta atual do zero (game.gd: retry_fight).
signal retry_pressed
signal options_pressed
signal cards_pressed
signal title_pressed

const PANEL := Vector2(460, 578)
const DIM := Color("A9AEDC")

## No tutorial não existe seleção de cartas pra voltar: o menu fica com CONTINUAR, OPÇÕES e SAIR
## (que emite title_pressed). Defina antes de pôr o nó na árvore.
var in_tutorial := false

var _btns: Array[ShineButton] = []
var _focus := 0
var _box: Control
var _tw: Tween
var _hint: Label


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # a luta por trás não recebe clique
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var items := [["CONTINUAR", "resume"], ["TENTAR NOVAMENTE", "retry"], ["OPÇÕES", "options"], ["SELEÇÃO DE CARTAS", "cards"], ["MENU PRINCIPAL", "title"]]
	if in_tutorial:
		items = [["CONTINUAR", "resume"], ["OPÇÕES", "options"], ["SAIR DO TUTORIAL", "title"]]
	var box_size := Vector2(PANEL.x, PANEL.y - (5 - items.size()) * 78.0)

	# caixa de tamanho fixo, sempre no centro da tela
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -box_size.x * 0.5
	_box.offset_right = box_size.x * 0.5
	_box.offset_top = -box_size.y * 0.5
	_box.offset_bottom = box_size.y * 0.5
	_box.pivot_offset = box_size * 0.5
	add_child(_box)

	_box.add_child(CutPanel.make(Rect2(0, 30, box_size.x, box_size.y - 30), [[.03, 0], [1, .03], [.97, 1], [0, .97]], Paper.NAVY, 6, Vector2(10, 10)))
	# etiqueta "PAUSE": papel creme torto por cima da borda, como o título das telas do design
	var tag := CutPanel.make(Rect2(-14, 0, 232, 72), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	tag.rotation = deg_to_rad(-3.0)
	_box.add_child(tag)
	var title := Paper.label("PAUSE", 44, Paper.INK, Paper.display())
	title.size = Vector2(232, 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(title)

	var y := 104.0
	for k in items.size():
		var b := ShineButton.new()
		b.text = items[k][0]
		b.set_meta("id", items[k][1])
		b.shadow = Vector2(6, 7)
		b.hover_scale = 1.04
		if k == 0:
			# o principal: dourado, recortado e maior, como o JOGAR / CONFIRMAR do design
			b.shape = [[.03, .06], [1, 0], [.97, .92], [0, 1]]
			b.border = 6.0
			b.font_px = 32
			b.text_rot = -2.0
			b.fill = Paper.GOLD
			b.fill_hover = Paper.GOLD_HOVER
			b.position = Vector2(38, y)
			b.size = Vector2(384, 84)
			y += 104.0
		else:
			b.skew = 12.0
			b.border = 4.0
			b.font_px = 22
			b.fill = Paper.CREAM
			b.fill_hover = Paper.GOLD
			b.position = Vector2(54 + (10 if k % 2 == 0 else 0), y)
			b.size = Vector2(346, 58)
			y += 78.0
		b.mouse_entered.connect(func():
			_focus = k
			_mark_focus())
		b.pressed.connect(_choose.bind(k))
		_box.add_child(b)
		_btns.append(b)

	_hint = Paper.label("", 14, DIM, Paper.body(700))
	_hint.position = Vector2(0, box_size.y - 38)
	_hint.size = Vector2(box_size.x, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_hint)


func open() -> void:
	visible = true
	_focus = 0
	_hint.text = "%s continua  ·  ↑↓ escolhe  ·  ENTER confirma" % Binds.label("pause")
	_mark_focus()
	# entrada rápida: a caixa "carimba" e os botões aparecem em sequência
	if _tw:
		_tw.kill()
	_box.scale = Vector2.ONE * 0.9
	_box.modulate.a = 0.0
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_box, "modulate:a", 1.0, 0.1)
	for k in _btns.size():
		_btns[k].modulate.a = 0.0
		_tw.tween_property(_btns[k], "modulate:a", 1.0, 0.12).set_delay(0.05 + k * 0.05)


func close() -> void:
	if _tw:
		_tw.kill()
	visible = false


## Volta das opções: reaparece como estava, sem a animação de entrada (a tecla de pause pode ter mudado).
func back_from_options() -> void:
	visible = true
	_hint.text = "%s continua  ·  ↑↓ escolhe  ·  ENTER confirma" % Binds.label("pause")
	_mark_focus()


func _mark_focus() -> void:
	for k in _btns.size():
		_btns[k].focused = k == _focus


func _choose(k: int) -> void:
	if not visible:
		return
	match String(_btns[k].get_meta("id")):
		"resume": resume_pressed.emit()
		"retry": retry_pressed.emit()
		"options": options_pressed.emit()
		"cards": cards_pressed.emit()
		"title": title_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	# a tecla de pause do jogador (Binds) também fecha; ESC sempre fecha, como em todo menu
	if event.is_action_pressed("pause"):
		k = KEY_ESCAPE
	if k not in [KEY_ESCAPE, KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return
	# marca antes de agir: sair da luta recarrega a cena e este nó já sai da árvore
	get_viewport().set_input_as_handled()
	match k:
		KEY_ESCAPE:
			resume_pressed.emit()
		KEY_W, KEY_UP:
			_focus = posmod(_focus - 1, _btns.size())
			_mark_focus()
		KEY_S, KEY_DOWN:
			_focus = posmod(_focus + 1, _btns.size())
			_mark_focus()
		_:
			_choose(_focus)
