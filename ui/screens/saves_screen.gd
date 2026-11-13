class_name SavesScreen
extends Control
## Seleção de saves: quatro arquivos independentes (Knowledge.SLOT_COUNT). PLAY na tela inicial
## abre esta tela; escolher um save (novo ou existente) leva pra cafeteria montar a party.
## Layout da prancha "Saves" do design "Tela de Cartas" (kit Paper).
##   W S / ↑ ↓ escolhem · ENTER joga · DELETE apaga (pede confirmação) · ESC volta.

signal back_pressed
## O jogador escolheu jogar no save `n` (1..SLOT_COUNT). Quem carrega e troca de cena é o menus.gd.
signal slot_chosen(n: int)

const STAGE := Vector2(1280, 720)
const ROW := Vector2(980, 104)
const NAVY2 := Color("2B3384")
const PURPLE := Color("5B2BB8")
const DIM := Color("B9BEEA")
const DANGER := Color("C0183A")
const BOSS_COL := [Color("D9984F"), Color("40CCE6"), Color("FF61A8"), Color("9E5CFF")]

var _stage: Control
var _rows: Array[Control] = []
var _info: Array = []  # resumo de cada slot ({} = vazio)
var _focus := 0
var _pointer: Control
var _play: ShineButton
var _erase: ShineButton
var _dialog: Control
var _dialog_text: Label
var _built := false


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		Knowledge.persist = false
		open()


func open() -> void:
	_dialog.visible = false
	_info.clear()
	for n in Knowledge.SLOT_COUNT:
		_info.append(Knowledge.slot_info(n + 1))
	# começa no save ativo; sem save ativo, no primeiro
	_focus = clampi(Knowledge.slot - 1, 0, Knowledge.SLOT_COUNT - 1)
	for n in _rows.size():
		_fill(n)
		var row := _rows[n]
		row.modulate.a = 0.0
		var home: float = row.get_meta("x")
		row.position.x = home + 60.0
		var tw := row.create_tween().set_parallel(true)
		tw.tween_property(row, "modulate:a", 1.0, 0.14).set_delay(n * 0.05)
		tw.tween_property(row, "position:x", home, 0.24).set_delay(n * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mark()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): bg.draw_rect(Rect2(Vector2.ZERO, bg.size), Paper.NAVY))
	add_child(bg)
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

	var tag := CutPanel.make(Rect2(20, 14, 220, 66), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	_stage.add_child(tag)
	var title := Paper.label("SAVES", 40, Paper.INK, Paper.display())
	title.size = Vector2(220, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.rotation = deg_to_rad(-2.0)
	title.pivot_offset = title.size * 0.5
	tag.add_child(title)

	var rots := [-1.0, 0.6, -0.5, 0.8]
	for n in Knowledge.SLOT_COUNT:
		var row := Control.new()
		row.position = Vector2(150, 112 + n * 124)
		row.size = ROW
		row.pivot_offset = ROW * 0.5
		row.rotation = deg_to_rad(rots[n % rots.size()])
		row.set_meta("x", row.position.x)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_entered.connect(func():
			if not _dialog.visible:
				_focus = n
				_mark())
		row.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not _dialog.visible:
				_focus = n
				_mark()
				if e.double_click:
					_go())
		_stage.add_child(row)
		_rows.append(row)

	# ponteiro do save escolhido
	_pointer = Control.new()
	_pointer.size = Vector2(40, 46)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(func():
		_pointer.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(40, 23), Vector2(0, 46)]), Paper.INK)
		_pointer.draw_colored_polygon(PackedVector2Array([Vector2(5, 9), Vector2(30, 23), Vector2(5, 37)]), Paper.GOLD))
	_stage.add_child(_pointer)

	var vb := _small("VOLTAR", Paper.CREAM, Paper.INK)
	vb.chevron = -1
	vb.chevron_px = 16
	vb.position = Vector2(44, 638)
	vb.size = Vector2(160, 50)
	vb.pressed.connect(func(): back_pressed.emit())
	_stage.add_child(vb)
	_erase = _small("APAGAR", DANGER, Paper.CREAM)
	_erase.position = Vector2(670, 638)
	_erase.size = Vector2(170, 50)
	_erase.pressed.connect(_ask_erase)
	_stage.add_child(_erase)
	_play = ShineButton.new()
	_play.text = "JOGAR"
	_play.shape = [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	_play.border = 6
	_play.font_px = 38
	_play.text_rot = -3
	_play.shadow = Vector2(10, 10)
	_play.fill = Paper.GOLD
	_play.fill_hover = Paper.GOLD_HOVER
	_play.fg_hover = Paper.RED
	_play.idle = true
	_play.hover_scale = 1.05
	_play.position = Vector2(892, 608)
	_play.size = Vector2(340, 88)
	_play.pressed.connect(_go)
	_stage.add_child(_play)

	# confirmação de apagar
	_dialog = Control.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.visible = false
	add_child(_dialog)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(dim)
	var box := Control.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -280
	box.offset_right = 280
	box.offset_top = -120
	box.offset_bottom = 120
	_dialog.add_child(box)
	box.add_child(CutPanel.make(Rect2(0, 0, 560, 240), [[.02, 0], [1, .04], [.98, 1], [0, .96]], PURPLE, 5, Vector2(8, 8)))
	_dialog_text = Paper.label("", 19, Paper.CREAM, Paper.body(700))
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.position = Vector2(30, 22)
	_dialog_text.size = Vector2(500, 130)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_dialog_text)
	var yes := _small("APAGAR", DANGER, Paper.CREAM)
	yes.position = Vector2(50, 168)
	yes.size = Vector2(210, 50)
	yes.pressed.connect(_erase_now)
	box.add_child(yes)
	var no := _small("CANCELAR", Paper.CREAM, Paper.INK)
	no.position = Vector2(300, 168)
	no.size = Vector2(210, 50)
	no.pressed.connect(func(): _dialog.visible = false)
	box.add_child(no)


func _small(text: String, fill: Color, fg: Color) -> ShineButton:
	var b := ShineButton.new()
	b.text = text
	b.font_px = 18
	b.skew = 12
	b.border = 4
	b.shadow = Vector2(5, 5)
	b.fill = fill
	b.fg = fg
	b.auto_hover = true
	b.hover_scale = 1.04
	return b


func _draw_back(d: Control) -> void:
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.0, NAVY2)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(800, 460), [[.3, 0], [1, 0], [1, .78], [.7, 1], [.46, .48], [0, .26]]), Vector2(520, -40)), PURPLE)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(620, 260), [[0, .46], [.78, 0], [1, .22], [.28, 1], [0, 1]]), Vector2(-40, 500)), Paper.GOLD)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(560, 220), [[0, .6], [1, 0], [1, 1], [.1, 1]]), Vector2(760, 540)), Paper.INK)


## Monta o conteúdo da linha `n` a partir do resumo do slot.
func _fill(n: int) -> void:
	var row := _rows[n]
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var info: Dictionary = _info[n]
	var used := not info.is_empty()
	# moldura dourada de "escolhido" (liga e desliga em _mark)
	var ring := Control.new()
	ring.name = "Ring"
	ring.size = ROW
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func():
		var big := Paper.moved(Paper.skew_rect(ROW + Vector2(20, 18), 8.0), Vector2(-10, -9))
		ring.draw_colored_polygon(big, Paper.INK)
		ring.draw_colored_polygon(Paper.inset(big, 4.0), Paper.GOLD))
	row.add_child(ring)
	var plate := Control.new()
	plate.size = ROW
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(func():
		var pts := Paper.skew_rect(ROW, 8.0)
		plate.draw_colored_polygon(Paper.moved(pts, Vector2(8, 9)), Paper.INK)
		plate.draw_colored_polygon(pts, Paper.INK)
		plate.draw_colored_polygon(Paper.inset(pts, 5.0), Paper.CREAM if used else Color("1A1E52")))
	row.add_child(plate)

	var num := CutPanel.make(Rect2(26, 18, 68, 68), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.INK, 0, Vector2.ZERO)
	num.rotation = deg_to_rad(-5.0)
	row.add_child(num)
	var nl := Paper.label(str(n + 1), 40, Paper.CREAM, Paper.display())
	nl.size = Vector2(68, 68)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(nl)

	if not used:
		var plus := Paper.label("+  NOVO SAVE", 26, DIM, Paper.display())
		plus.position = Vector2(124, 0)
		plus.size = Vector2(600, ROW.y)
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(plus)
		return

	# party: os quatro do save (vazio = ainda não montou)
	var team: Array = info["party"]
	var rots := [-3.0, 2.0, -2.0, 3.0]
	for k in (4 if not team.is_empty() else 0):
		var frame := CutPanel.make(Rect2(124 + k * 66, 17, 56, 70), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.INK, 0, Vector2.ZERO)
		frame.rotation = deg_to_rad(rots[k])
		row.add_child(frame)
		if k < team.size():
			var face := TextureRect.new()
			face.texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[team[k]]["key"])
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			face.position = Vector2(4, 4)
			face.size = Vector2(48, 62)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(face)
	if team.is_empty():
		var none := Paper.label("SEM PARTY AINDA", 17, Color("8A8466"), Paper.display())
		none.position = Vector2(124, 0)
		none.size = Vector2(280, ROW.y)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(none)

	# até onde foi: um selo por boss, com o melhor ranking
	var ranks: Dictionary = info["rank"]
	var stamps := Control.new()
	stamps.position = Vector2(430, 22)
	stamps.size = Vector2(360, 64)
	stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamps.draw.connect(func():
		for b in Knowledge.BOSS_INFO.size():
			var c := Vector2(25 + b * 88, 29)
			stamps.draw_circle(c, 25, Paper.INK)
			stamps.draw_circle(c, 20, BOSS_COL[b % BOSS_COL.size()] if ranks.has(b) else Color("C9C2A6")))
	row.add_child(stamps)
	for b in Knowledge.BOSS_INFO.size():
		if ranks.has(b):
			var chip := Chip.new()
			chip.px = 14
			chip.skew = 0.0
			chip.pad = 7.0
			chip.ink = PURPLE
			chip.shadow = Vector2.ZERO
			chip.text = Knowledge.RANKS[int(ranks[b])]
			chip.position = Vector2(430 + 34 + b * 88, 48)
			chip.rotation = deg_to_rad(-7.0)
			row.add_child(chip)

	# carteira do save
	var wallet := Control.new()
	wallet.position = Vector2(800, 30)
	wallet.size = Vector2(170, 44)
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.draw.connect(func():
		wallet.draw_circle(Vector2(11, 22), 11, Color("C9871A"))
		wallet.draw_circle(Vector2(11, 22), 6, Paper.GOLD)
		var tk := Paper.moved(Paper.poly(Vector2(28, 18), [[0, 0], [1, 0], [1, .3], [.88, .5], [1, .7], [1, 1], [0, 1], [0, .7], [.12, .5], [0, .3]]), Vector2(92, 13))
		wallet.draw_colored_polygon(tk, Color("9E5CFF")))
	row.add_child(wallet)
	var coins := Paper.label(str(info["money"]), 22, Paper.INK, Paper.display())
	coins.position = Vector2(830, 30)
	coins.size = Vector2(60, 44)
	coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(coins)
	var tickets := Paper.label(str(info["tickets"]), 22, Paper.INK, Paper.display())
	tickets.position = Vector2(928, 30)
	tickets.size = Vector2(40, 44)
	tickets.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tickets)


func _mark() -> void:
	for n in _rows.size():
		_rows[n].get_node("Ring").visible = n == _focus
	_pointer.position = Vector2(92, _rows[_focus].position.y + 29)
	_erase.disabled = _info[_focus].is_empty()
	_erase.queue_redraw()
	_play.text = "JOGAR" if not _info[_focus].is_empty() else "CRIAR"


func _go() -> void:
	if not _dialog.visible:
		slot_chosen.emit(_focus + 1)


func _ask_erase() -> void:
	if _info[_focus].is_empty():
		return
	_dialog_text.text = "Apagar o SAVE %d?\nO progresso, as cartas e a party dele somem de vez. Não dá pra desfazer." % (_focus + 1)
	_dialog.visible = true


func _erase_now() -> void:
	Knowledge.delete_slot(_focus + 1)
	_dialog.visible = false
	_info[_focus] = {}
	_fill(_focus)
	_mark()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if _dialog.visible:
		if k == KEY_ESCAPE:
			_dialog.visible = false
		get_viewport().set_input_as_handled()
		return
	match k:
		KEY_W, KEY_UP:
			_focus = posmod(_focus - 1, _rows.size())
			_mark()
		KEY_S, KEY_DOWN:
			_focus = posmod(_focus + 1, _rows.size())
			_mark()
		KEY_ENTER, KEY_KP_ENTER: _go()
		KEY_DELETE: _ask_erase()
		KEY_ESCAPE: back_pressed.emit()
