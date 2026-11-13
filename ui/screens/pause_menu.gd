class_name PauseMenu
extends Control
## Menu de pause da luta (ESC). Congela a árvore com get_tree().paused e roda mesmo assim,
## porque fica em PROCESS_MODE_ALWAYS. Quem decide o que cada opção faz é o game.gd.
##   ↑↓ / W S escolhem · ENTER confirma · ESC ou a tecla de pause (ou CONTINUAR) volta pra luta.
## OPÇÕES abre a tela de opções por cima (hud.gd), com a luta ainda congelada.

signal resume_pressed
signal options_pressed
signal cards_pressed
signal title_pressed

const PANEL := Vector2(460, 512)

## No tutorial não existe seleção de cartas pra voltar: o menu fica com CONTINUAR, OPÇÕES e SAIR
## (que emite title_pressed). Defina antes de pôr o nó na árvore.
var in_tutorial := false

var _btns: Array[InkButton] = []
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

	# caixa de tamanho fixo, sempre no centro da tela
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -PANEL.x * 0.5
	_box.offset_right = PANEL.x * 0.5
	_box.offset_top = -PANEL.y * 0.5
	_box.offset_bottom = PANEL.y * 0.5
	_box.pivot_offset = PANEL * 0.5
	add_child(_box)

	var panel := Ink.panel(Ink.NAVY, 9)
	panel.position = Vector2(0, 30)
	panel.size = PANEL - Vector2(0, 30)
	_box.add_child(panel)

	# etiqueta "PAUSE" torta por cima da borda, como o logo da tela inicial
	var tag := Ink.panel(Ink.GRAPE, 21)
	tag.position = Vector2(-18, 0)
	tag.size = Vector2(250, 76)
	tag.rotation = -0.05
	_box.add_child(tag)
	var title := Ink.title("PAUSE", 52)
	title.position = Vector2(22, 4)
	title.size = Vector2(220, 68)
	tag.add_child(title)

	var items := [
		["CONTINUAR", Ink.COIN, 5],
		["OPÇÕES", Ink.CREAM, 9],
		["SELEÇÃO DE CARTAS", Ink.CREAM, 7],
		["MENU PRINCIPAL", Ink.CREAM, 11],
	]
	if in_tutorial:
		items = [["CONTINUAR", Ink.COIN, 5], ["OPÇÕES", Ink.CREAM, 9], ["SAIR DO TUTORIAL", Ink.CREAM, 11]]
	for k in items.size():
		var b := Ink.button(items[k][0], items[k][1], Ink.OUT, 30, items[k][2])
		b.position = Vector2(40 + (12 if k % 2 == 1 else 0), 112 + k * 92)
		b.size = Vector2(380, 74)
		b.mouse_entered.connect(func():
			_focus = k
			_mark_focus())
		b.pressed.connect(_choose.bind(k))
		_box.add_child(b)
		_btns.append(b)

	var hint := Ink.text("", 14, UiStyle.DIM)
	_hint = hint
	hint.position = Vector2(0, PANEL.y - 34)
	hint.size = Vector2(PANEL.x, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)


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
		_btns[k].outline = Ink.CREAM if k == _focus else Ink.OUT
		_btns[k].queue_redraw()


func _choose(k: int) -> void:
	if not visible:
		return
	if in_tutorial and k == 2:
		k = 3
	match k:
		0: resume_pressed.emit()
		1: options_pressed.emit()
		2: cards_pressed.emit()
		3: title_pressed.emit()


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
