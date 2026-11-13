class_name OptionsScreen
extends Control
## Opções do jogo: SOM e ATALHOS. É a mesma tela no menu principal e no pause (quem abre é o
## hud.gd); roda com a árvore congelada porque fica em PROCESS_MODE_ALWAYS.
## Visual: kit de papel (Paper), seguindo o design "Tela de Cartas".
## Volume: scripts/settings.gd (buses de verdade). Atalhos: scripts/binds.gd (InputMap).
##   ← → trocam de aba · ESC volta · num atalho: clique troca, botão direito remove.

signal closed

const BOX := Vector2(1040, 630)
const PAGE := Vector2(960, 400)
const ROW_H := 46
const CHIP := Vector2(176, 36)
## Cores do design "Tela de Cartas" que o kit Paper ainda não nomeia.
const NIGHT := Color("160C33")
const NAVY2 := Color("2B3384")
const PURPLE := Color("5B2BB8")
const DIM := Color("A9AEDC")
const DANGER := Color("FF5559")

var _box: Control
var _tabs: Array[ShineButton] = []
var _pages: Array[Control] = []
var _tab := 0
var _hint: Label

# som
var _sliders := {}  # bus -> {"slider": InkSlider, "value": Label}
var _mute: ShineButton

# atalhos
var _rows := {}  # id -> {"chips": [ShineButton, ShineButton], "reset": ShineButton, "skill": Label}
var _hero_note: Label
var _cap := {}  # {"id", "slot"} enquanto espera a tecla nova
var _dialog: Control
var _dialog_text: Label
var _dialog_yes: ShineButton
var _on_yes := Callable()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	Settings.boot()
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(NIGHT.r, NIGHT.g, NIGHT.b, 0.95)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_box = _centered(BOX)
	add_child(_box)
	var panel := _panel(Paper.NAVY, [[.012, 0], [1, .02], [.988, 1], [0, .98]], 6.0, Vector2(10, 10))
	panel.position = Vector2(0, 34)
	panel.size = BOX - Vector2(0, 34)
	_box.add_child(panel)
	var tag := _panel(Paper.CREAM, [[0, 0], [1, .08], [.95, 1], [.03, .9]])
	tag.position = Vector2(-18, 0)
	tag.size = Vector2(290, 78)
	tag.rotation = -0.04
	_box.add_child(tag)
	var title := _title("OPÇÕES", 44, Paper.INK)
	title.size = Vector2(290, 78)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(title)

	var names := ["SOM", "ATALHOS"]
	for k in names.size():
		var b := _button(names[k], Paper.CREAM, Paper.INK, 26)
		b.position = Vector2(590 + k * 206, 54)
		b.size = Vector2(194, 54)
		b.pressed.connect(_show_tab.bind(k))
		_box.add_child(b)
		_tabs.append(b)

	for build in [_build_sound, _build_binds]:
		var page := Control.new()
		page.position = Vector2(40, 132)
		page.size = PAGE
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(page)
		_pages.append(page)
		build.call(page)

	var back := _button("VOLTAR", Paper.GOLD, Paper.INK, 24)
	back.position = Vector2(40, 554)
	back.size = Vector2(190, 50)
	back.pressed.connect(close)
	_box.add_child(back)
	_hint = _text("", 14, DIM)
	_hint.position = Vector2(250, 568)
	_hint.size = Vector2(750, 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(_hint)

	_build_dialog()
	if get_tree().current_scene == self:
		# aberta sozinha (F6): não mexe no arquivo de configuração
		Knowledge.persist = false
		open()


func _centered(s: Vector2) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -s.x * 0.5
	c.offset_right = s.x * 0.5
	c.offset_top = -s.y * 0.5
	c.offset_bottom = s.y * 0.5
	c.pivot_offset = s * 0.5
	return c


# ---------------------------------------------------------------- peças do kit de papel

## Botão inclinado com contorno, sombra dura e o brilho do ShineButton.
func _button(text: String, fill: Color, fg: Color, px: int) -> ShineButton:
	var b := ShineButton.new()
	b.text = text
	b.fill = fill
	b.fg = fg
	b.font_px = px
	b.skew = 10.0
	b.border = 3.0 if px < 20 else 4.0
	b.shadow = Vector2(3, 4) if px < 20 else Vector2(5, 6)
	b.auto_hover = true
	b.hover_scale = 1.04
	return b


func _panel(fill: Color, shape: Array = [[.02, 0], [1, .04], [.98, 1], [0, .96]], border := 5.0, shadow := Vector2(8, 8)) -> CutPanel:
	var p := CutPanel.new()
	p.shape = shape
	p.fill = fill
	p.border = border
	p.shadow = shadow
	return p


## Título (Bowlby One).
func _title(text: String, px: int, col := Paper.CREAM) -> Label:
	return Paper.label(text, px, col, Paper.display())


## Texto corrido (Baloo 2).
func _text(text: String, px: int, col := Paper.CREAM) -> Label:
	return Paper.label(text, px, col, Paper.body(700))


# ---------------------------------------------------------------- som

func _build_sound(page: Control) -> void:
	var y := 14.0
	for c in Settings.CHANNELS:
		var bus: StringName = c["bus"]
		var l := _title(String(c["name"]).to_upper(), 20)
		l.position = Vector2(8, y + 4)
		l.size = Vector2(330, 34)
		page.add_child(l)
		var s := InkSlider.new()
		s.position = Vector2(350, y)
		s.size = Vector2(470, 40)
		page.add_child(s)
		var v := _title("", 26, Paper.GOLD)
		v.position = Vector2(840, y + 2)
		v.size = Vector2(110, 36)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		page.add_child(v)
		s.changed.connect(func(val: float):
			Settings.set_volume(bus, val)
			_refresh_sound())
		s.released.connect(Settings.save)
		_sliders[bus] = {"slider": s, "value": v}
		y += 76.0

	y += 14.0
	_mute = _button("", Paper.CREAM, Paper.INK, 18)
	_mute.position = Vector2(8, y)
	_mute.size = Vector2(360, 54)
	_mute.pressed.connect(func():
		Settings.set_mute_all(not Settings.mute_all)
		Settings.save()
		_refresh_sound())
	page.add_child(_mute)
	var reset := _button("RESTAURAR PADRÃO", Paper.CREAM, Paper.INK, 18)
	reset.position = Vector2(388, y)
	reset.size = Vector2(320, 54)
	reset.pressed.connect(func():
		Settings.reset_audio()
		Settings.save()
		_refresh_sound())
	page.add_child(reset)

	var note := _text("O jogo hoje só toca efeitos sonoros. Música, vozes e sons de interface ganham um controle aqui quando existirem.", 14, DIM)
	note.position = Vector2(8, y + 76)
	note.size = Vector2(900, 44)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)


func _refresh_sound() -> void:
	for bus in _sliders:
		var v: float = Settings.volume.get(bus, 1.0)
		_sliders[bus]["slider"].value = v
		_sliders[bus]["value"].text = "%d%%" % roundi(v * 100.0)
		_sliders[bus]["slider"].modulate.a = 0.45 if Settings.mute_all else 1.0
	_mute.text = "SILENCIAR TUDO: " + ("SIM" if Settings.mute_all else "NÃO")
	_mute.fill = DANGER if Settings.mute_all else Paper.CREAM


# ---------------------------------------------------------------- atalhos

func _build_binds(page: Control) -> void:
	_hero_note = _text("", 15, DIM)
	_hero_note.position = Vector2(8, 10)
	_hero_note.size = Vector2(440, 24)
	page.add_child(_hero_note)
	for k in 2:
		var h := _text(["PRINCIPAL", "ALTERNATIVO"][k], 13, DIM)
		h.position = Vector2(462 + k * (CHIP.x + 10), 26)
		h.size = Vector2(CHIP.x, 18)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(h)
	var all := _button("RESTAURAR TODOS", Paper.CREAM, Paper.INK, 11)
	all.position = Vector2(PAGE.x - 166, 4)
	all.size = Vector2(160, 36)
	all.pressed.connect(func():
		_ask("Voltar TODOS os atalhos pro padrão?", "RESTAURAR", func():
			Binds.reset_all()
			_binds_changed()))
	page.add_child(all)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 50)
	scroll.size = Vector2(PAGE.x, PAGE.y - 50)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var group := ""
	for a in Binds.ACTIONS:
		if a["group"] != group:
			group = a["group"]
			var head := Control.new()
			head.custom_minimum_size = Vector2(PAGE.x - 20, 34)
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var t := _title(group, 17, Paper.GOLD)
			t.position = Vector2(8, 10)
			t.size = Vector2(500, 22)
			head.add_child(t)
			list.add_child(head)
		list.add_child(_build_row(a))


func _build_row(a: Dictionary) -> Control:
	var id: String = a["id"]
	var row := Control.new()
	row.custom_minimum_size = Vector2(PAGE.x - 20, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var plate := ColorRect.new()
	plate.color = Color(Paper.INK.r, Paper.INK.g, Paper.INK.b, 0.6)
	plate.position = Vector2(0, 0)
	plate.size = Vector2(PAGE.x - 20, ROW_H)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plate)

	var info := {"chips": [], "reset": null, "skill": null, "badge": null}
	var x := 14.0
	if id.begins_with("skill_"):
		# o "ícone" do slot: a posição na barra, na cor do herói
		var badge := Control.new()
		badge.position = Vector2(8, 6)
		badge.size = Vector2(34, 34)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_meta("col", PURPLE)
		badge.set_meta("on", true)
		badge.draw.connect(_draw_badge.bind(badge, id.get_slice("_", 1)))
		row.add_child(badge)
		info["badge"] = badge
		x = 54.0
	var name_l := _text(String(a["name"]).to_upper(), 16)
	name_l.position = Vector2(x, 12)
	name_l.size = Vector2(300, 24)
	row.add_child(name_l)
	if id.begins_with("skill_"):
		var sk := _text("", 15, DIM)
		sk.position = Vector2(132, 13)
		sk.size = Vector2(320, 24)
		sk.clip_text = true
		row.add_child(sk)
		info["skill"] = sk

	for s in Binds.SLOTS:
		var chip := _button("", Paper.CREAM, Paper.INK, 15)
		chip.position = Vector2(462 + s * (CHIP.x + 10), 5)
		chip.size = CHIP
		chip.pressed.connect(_start_capture.bind(id, s))
		chip.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and _cap.is_empty():
				_clear(id, s))
		row.add_child(chip)
		info["chips"].append(chip)
	var reset := _button("PADRÃO", NAVY2, Paper.CREAM, 11)
	reset.position = Vector2(462 + 2 * (CHIP.x + 10), 7)
	reset.size = Vector2(80, 32)
	reset.pressed.connect(_reset_one.bind(id))
	row.add_child(reset)
	info["reset"] = reset
	_rows[id] = info
	return row


func _draw_badge(badge: Control, number: String) -> void:
	var col: Color = badge.get_meta("col")
	if not badge.get_meta("on"):
		col = col.darkened(0.55)
	var pts := Paper.skew_rect(badge.size, 8.0)
	draw_badge_poly(badge, pts, col)
	var f := Paper.display()
	badge.draw_string(f, Vector2(0, 25), number, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 20, Paper.INK)


static func draw_badge_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Paper.INK, 3.0, true)


func _refresh_binds() -> void:
	for id in _rows:
		var info: Dictionary = _rows[id]
		for s in Binds.SLOTS:
			var chip: ShineButton = info["chips"][s]
			var code: int = Binds.keys[id][s]
			var capturing: bool = not _cap.is_empty() and _cap["id"] == id and _cap["slot"] == s
			if capturing:
				chip.text = "APERTE UMA TECLA"
				chip.font_px = 11
				chip.fill = Paper.GOLD
			else:
				chip.text = Binds.code_name(code)
				chip.font_px = 15
				chip.fill = Paper.CREAM if code != 0 else NAVY2
			chip.fg = Paper.INK if (code != 0 or capturing) else DIM
			chip.tooltip_text = "Clique: trocar · Botão direito: remover" if Binds.can_clear(id, s) else "Clique: trocar"
		for chip in info["chips"]:
			chip.queue_redraw()
		var reset: ShineButton = info["reset"]
		reset.disabled = Binds.is_default(id)
		reset.queue_redraw()


## Mostra, em cada slot, a habilidade que ele dispara no herói `hero` (índice em Knowledge.HEROES).
func _show_hero(hero: int) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	_hero_note.text = "Slots mostrando as habilidades de: %s" % String(h["name"]).to_upper()
	var skills: Dictionary = load("res://scripts/game.gd").SKILLS
	var list: Array = skills.get(h["key"], [])
	for n in Binds.SKILL_SLOTS:
		var info: Dictionary = _rows["skill_%d" % (n + 1)]
		var has: bool = n < list.size() and list[n] != null
		info["skill"].text = String(list[n]["name"]) if has else "sem habilidade neste herói"
		info["badge"].set_meta("col", h["color"])
		info["badge"].set_meta("on", has)
		info["badge"].queue_redraw()


func _binds_changed() -> void:
	Settings.save()
	_refresh_binds()


func _start_capture(id: String, slot: int) -> void:
	if not _cap.is_empty() or _dialog.visible:
		return
	_cap = {"id": id, "slot": slot}
	_refresh_binds()
	_set_hint()


func _stop_capture() -> void:
	_cap = {}
	_refresh_binds()
	_set_hint()


func _captured(code: int) -> void:
	var id: String = _cap["id"]
	var slot: int = _cap["slot"]
	_stop_capture()
	var other := Binds.find(code, id, slot)
	if other.is_empty() or other["id"] == id:
		Binds.assign(id, slot, code)
		_binds_changed()
		return
	# nada de conflito silencioso: o jogador decide
	var oid: String = other["id"]
	var text := "%s já é o atalho de\n%s.\n\nSubstituir?" % [Binds.code_name(code), String(Binds.def(oid)["name"]).to_upper()]
	if not Binds.can_assign(id, slot, code):
		# sem tecla pra dar em troca, a ação obrigatória ficaria sem atalho
		_ask("%s é o único atalho de\n%s,\nque não pode ficar sem tecla." % [Binds.code_name(code), String(Binds.def(oid)["name"]).to_upper()], "", Callable())
		return
	if Binds.needed(oid) and Binds.count(oid) == 1:
		text = "%s já é o atalho de\n%s.\n\nTrocar os dois de lugar?" % [Binds.code_name(code), String(Binds.def(oid)["name"]).to_upper()]
	_ask(text, "SUBSTITUIR", func():
		Binds.assign(id, slot, code)
		_binds_changed())


func _clear(id: String, slot: int) -> void:
	if Binds.clear(id, slot):
		_binds_changed()


func _reset_one(id: String) -> void:
	if not _cap.is_empty():
		return
	var hits := Binds.reset_conflicts(id)
	if hits.is_empty():
		Binds.reset(id)
		_binds_changed()
		return
	var names: Array = []
	for h in hits:
		names.append(String(Binds.def(h["id"])["name"]).to_upper())
	_ask("O padrão de %s está em uso por\n%s.\n\nRestaurar mesmo assim?" % [String(Binds.def(id)["name"]).to_upper(), ", ".join(names)], "RESTAURAR", func():
		Binds.reset(id)
		_binds_changed())


# ---------------------------------------------------------------- confirmação

func _build_dialog() -> void:
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
	var box := _centered(Vector2(560, 270))
	_dialog.add_child(box)
	var panel := _panel(PURPLE)
	panel.size = Vector2(560, 270)
	box.add_child(panel)
	_dialog_text = _text("", 19)
	_dialog_text.position = Vector2(30, 24)
	_dialog_text.size = Vector2(500, 150)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_dialog_text)
	_dialog_yes = _button("SUBSTITUIR", Paper.GOLD, Paper.INK, 20)
	_dialog_yes.position = Vector2(40, 196)
	_dialog_yes.size = Vector2(230, 52)
	_dialog_yes.pressed.connect(_answer.bind(true))
	box.add_child(_dialog_yes)
	var no := _button("CANCELAR", Paper.CREAM, Paper.INK, 20)
	no.name = "No"
	no.position = Vector2(290, 196)
	no.size = Vector2(230, 52)
	no.pressed.connect(_answer.bind(false))
	box.add_child(no)


## Pergunta de sim/não. Com `yes` vazio vira só um aviso (um botão).
func _ask(text: String, yes: String, on_yes: Callable) -> void:
	_dialog_text.text = text
	_dialog_yes.visible = yes != ""
	_dialog_yes.text = yes
	var no: ShineButton = _dialog_yes.get_parent().get_node("No")
	no.text = "CANCELAR" if yes != "" else "ENTENDI"
	no.position.x = 290.0 if yes != "" else 165.0
	_on_yes = on_yes
	_dialog.visible = true
	_set_hint()


func _answer(yes: bool) -> void:
	if not _dialog.visible:
		return
	_dialog.visible = false
	var cb := _on_yes
	_on_yes = Callable()
	if yes and cb.is_valid():
		cb.call()
	_set_hint()


# ---------------------------------------------------------------- abrir / fechar / teclado

## `hero`: índice em Knowledge.HEROES de quem aparece nos slots de habilidade.
func open(hero := -1, tab := 0) -> void:
	visible = true
	_cap = {}
	_dialog.visible = false
	_show_hero(hero if hero >= 0 else Knowledge.start_hero)
	_refresh_sound()
	_refresh_binds()
	_show_tab(tab)
	_box.scale = Vector2.ONE * 0.94
	_box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box, "modulate:a", 1.0, 0.1)


func close() -> void:
	if not visible:
		return
	_cap = {}
	_dialog.visible = false
	Settings.save()
	visible = false
	closed.emit()


func _show_tab(k: int) -> void:
	if not _cap.is_empty() or _dialog.visible:
		return
	_tab = k
	for i in _pages.size():
		_pages[i].visible = i == k
		_tabs[i].fill = Paper.GOLD if i == k else Paper.CREAM2
	_set_hint()


func _set_hint() -> void:
	if _dialog.visible:
		_hint.text = "ENTER confirma  ·  ESC cancela"
	elif not _cap.is_empty():
		_hint.text = "Aperte a tecla nova  ·  ESC cancela"
	elif _tab == 1:
		_hint.text = "Clique num atalho pra trocar  ·  botão direito remove  ·  ← → aba  ·  ESC volta"
	else:
		_hint.text = "← → troca de aba  ·  ESC volta"


## Tudo em _input (antes das outras telas): enquanto as opções estão abertas, nenhuma tecla
## vaza pro menu ou pra luta que está por baixo.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _cap.is_empty():
		_capture_input(event)
		return
	if not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if _dialog.visible:
		if k == KEY_ESCAPE:
			_answer(false)
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			_answer(_dialog_yes.visible)
		return
	match k:
		KEY_ESCAPE: close()
		KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D: _show_tab(1 - _tab)


func _capture_input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo:
			return
		if event.physical_keycode == KEY_ESCAPE and not (_cap["id"] == "pause"):
			_stop_capture()
			return
		_captured(Binds.code_of(event))
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		var code := Binds.code_of(event)
		if code == 0:
			_stop_capture()  # clique comum cancela
		else:
			_captured(code)
