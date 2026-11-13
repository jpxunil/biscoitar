extends CanvasLayer
## HUD da luta. Segue as regras de ui/style.gd: todo texto em cima de placa,
## arena livre no centro, informação nas bordas.
##
## Topo: boss (nome, vida, cast) · Esquerda: party · Direita: legenda dos elementos
## Rodapé: avisos (toast) · Por cima de tudo: menu de cartas e tela de fim.

var g
var boss_bar: Control
var boss_pct: Label
var end_stats: VBoxContainer
var skill_row: HBoxContainer
var skill_ui: Array = []
var skill_for := -1
var swap_name: Label
var swap_bar: Control
var time_bar: Control
var time_label: Label
var lb_back: Panel
var lb_fill: Panel
var lb_text: Label
var lb_button: Button
var lb_color := Color.WHITE
var state_chip: PanelContainer
var state_label: Label
var cast_row: Control
var cast_label: Label
var cast_bar: Control
var toast_slab: PanelContainer
var toast_label: Label
var toast_t := 0.0
var cards: Array = []
var boss_center: Control
var legend: Control
var fight_ui: Control
var biscoito: TextureRect
var _biscoito_tw: Tween
var cast_plate: PanelContainer
var my_cast_label: Label
var my_cast_bar: Control
var my_cast_red: Control
var flash_rect: ColorRect
var menu_root: Control
var menus
var pause: PauseMenu
var end_layer: Control
var end_title_slab: PanelContainer
var end_title: Label
var end_body: Label


func setup(game) -> void:
	g = game
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	fight_ui = Control.new()
	fight_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fight_ui)

	_build_boss()
	_build_party()
	_build_legend()
	_build_toast()
	_build_skills()
	_build_lb()
	_build_castbar()

	# rosto do biscoito: aparece com fade quando alguém usa o Bora Biscoitar
	biscoito = TextureRect.new()
	biscoito.texture = preload("res://assets/biscoitar.png")
	biscoito.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biscoito.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	biscoito.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	biscoito.anchor_left = 0.5
	biscoito.anchor_right = 0.5
	biscoito.anchor_top = 0.5
	biscoito.anchor_bottom = 0.5
	biscoito.offset_left = -130
	biscoito.offset_right = 130
	biscoito.offset_top = -190
	biscoito.offset_bottom = 70
	biscoito.pivot_offset = Vector2(130, 130)
	biscoito.modulate.a = 0.0
	root.add_child(biscoito)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	root.add_child(flash_rect)

	menu_root = root
	menus = preload("res://ui/screens/menus.gd").new()
	root.add_child(menus)
	menus.setup(g)

	_build_end(root)

	# por último: fica por cima de tudo, inclusive da tela de fim
	pause = PauseMenu.new()
	root.add_child(pause)
	pause.resume_pressed.connect(g.resume)
	pause.cards_pressed.connect(g.leave_fight.bind("cards"))
	pause.title_pressed.connect(g.leave_fight.bind("title"))


# ---------------------------------------------------------------- boss

func _build_boss() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 14
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(center)
	boss_center = center

	var plate := UiStyle.slab(UiStyle.INK, 0.12, 26, 10)
	plate.custom_minimum_size.x = 620
	center.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	plate.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var name_l := UiStyle.text(g.boss_def["name"], 20, UiStyle.PAPER)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	boss_pct = UiStyle.text("100%", 15, UiStyle.DIM)
	head.add_child(boss_pct)
	head.add_theme_constant_override("separation", 12)
	state_chip = UiStyle.slab(UiStyle.CYAN, UiStyle.SKEW, 12, 1)
	state_label = UiStyle.text("", 13, UiStyle.INK)
	state_chip.add_child(state_label)
	head.add_child(state_chip)

	boss_bar = UiStyle.bar(UiStyle.BOSS, 16, 0.3)
	v.add_child(boss_bar)

	# DPS check: barra de tempo na mesma escala da vida. Tempo mais curto que a vida = você está atrás.
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	v.add_child(trow)
	time_bar = UiStyle.bar(UiStyle.PAPER, 6, 0.3)
	time_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(time_bar)
	time_label = UiStyle.text("0:00", 13, UiStyle.DIM)
	time_label.custom_minimum_size.x = 38
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(time_label)

	# a linha de cast reserva o espaço mesmo vazia, pra placa não ficar pulando de tamanho
	cast_row = HBoxContainer.new()
	cast_row.add_theme_constant_override("separation", 12)
	cast_row.custom_minimum_size.y = 20
	v.add_child(cast_row)
	cast_label = UiStyle.text("", 14, UiStyle.YELLOW)
	cast_label.custom_minimum_size.x = 250
	cast_row.add_child(cast_label)
	cast_bar = UiStyle.bar(UiStyle.YELLOW, 8, 0.5)
	cast_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cast_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cast_row.add_child(cast_bar)


# ---------------------------------------------------------------- party / legenda / toast

func _build_party() -> void:
	var party := VBoxContainer.new()
	party.add_theme_constant_override("separation", 10)
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(party)
	for i in 4:
		var u: Unit = g.units[i]
		var card: CharacterCard = preload("res://ui/character_card.tscn").instantiate()
		card.index = i + 1
		card.char_name = u.unit_name
		card.accent = u.color
		card.face = load("res://assets/portraits/%s_face.png" % g.units[i].key)
		party.add_child(card)
		cards.append(card)
		# clicar foca o herói; quem troca de personagem é o Tab
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
	party.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 22)


func _on_card_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	g.pick_hero(i)


func _build_legend() -> void:
	var plate := UiStyle.slab(UiStyle.INK, 0.0, 14, 12)
	fight_ui.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	plate.add_child(v)
	for e in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiStyle.chip(g.EL_COL[e], 14))
		row.add_child(UiStyle.text(g.EL_NAME[e], 15, UiStyle.PAPER))
		v.add_child(row)
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	legend = plate
	# a legenda só existe em luta que usa elementos
	legend.visible = g.boss_def.has("elements")


func _build_toast() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -138
	center.offset_bottom = -92
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(center)
	toast_slab = UiStyle.slab(UiStyle.PAPER, UiStyle.SKEW, 28, 8)
	toast_label = UiStyle.text("", 18, UiStyle.INK)
	toast_slab.add_child(toast_label)
	toast_slab.visible = false
	center.add_child(toast_slab)


## Habilidades do personagem que você controla, com a recarga enchendo.
func _build_skills() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -78
	center.offset_bottom = -22
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(center)
	skill_row = HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 10)
	center.add_child(skill_row)


## Barra de cast: pequena, logo abaixo do meio da tela, só enquanto você conjura.
func _build_castbar() -> void:
	cast_plate = UiStyle.slab(UiStyle.INK, 0.0, 10, 6)
	cast_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(cast_plate)
	cast_plate.anchor_left = 0.5
	cast_plate.anchor_right = 0.5
	cast_plate.anchor_top = 0.5
	cast_plate.anchor_bottom = 0.5
	cast_plate.offset_left = -95
	cast_plate.offset_right = 95
	cast_plate.offset_top = 84
	cast_plate.offset_bottom = 84
	cast_plate.grow_vertical = Control.GROW_DIRECTION_END
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	cast_plate.add_child(v)
	my_cast_label = UiStyle.text("", 12, UiStyle.PAPER)
	my_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(my_cast_label)
	my_cast_bar = UiStyle.bar(UiStyle.PAPER, 5, 0.0)
	v.add_child(my_cast_bar)
	my_cast_red = UiStyle.bar(UiStyle.DANGER, 5, 0.0)
	v.add_child(my_cast_red)
	cast_plate.visible = false


## Cápsula do Limit Break: enche de 0 a 100% com o dano da party; cheia, vira o botão.
func _build_lb() -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(250, 44)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(holder)
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = -274
	holder.offset_right = -24
	holder.offset_top = -160
	holder.offset_bottom = -116

	lb_back = Panel.new()
	lb_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_back.add_theme_stylebox_override("panel", _pill(UiStyle.INK, 3, UiStyle.PAPER.darkened(0.55)))
	holder.add_child(lb_back)
	lb_fill = Panel.new()
	lb_fill.position = Vector2(5, 5)
	lb_fill.size = Vector2(0, 34)
	lb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_fill.add_theme_stylebox_override("panel", _pill(Color.WHITE, 0, Color.WHITE))
	holder.add_child(lb_fill)
	lb_text = UiStyle.text("0%", 16, UiStyle.PAPER)
	lb_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb_text.add_theme_constant_override("outline_size", 6)
	lb_text.add_theme_color_override("font_outline_color", UiStyle.INK)
	holder.add_child(lb_text)

	lb_button = Button.new()
	lb_button.text = "LIMIT BREAK   I"
	lb_button.focus_mode = Control.FOCUS_NONE
	lb_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb_button.add_theme_font_size_override("font_size", 18)
	lb_button.pressed.connect(g.use_lb)
	lb_button.visible = false
	holder.add_child(lb_button)


func _pill(col: Color, border: int, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	return sb


func _show_skills(i: int) -> void:
	skill_for = i
	skill_ui.clear()
	for c in skill_row.get_children():
		skill_row.remove_child(c)
		c.queue_free()
	var u: Unit = g.units[i]
	var list: Array = g.SKILLS[u.key]
	for n in list.size():
		if list[n] == null:
			continue
		var slab := UiStyle.slab(UiStyle.INK, UiStyle.SKEW, 20, 7)
		slab.custom_minimum_size.x = 186 if list.size() <= 4 else 168
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 5)
		slab.add_child(v)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var key := UiStyle.slab(UiStyle.PAPER, 0.0, 7, 0)
		key.add_child(UiStyle.text(g.SKILL_KEYS[n], 14, UiStyle.INK))
		row.add_child(key)
		var name_l := UiStyle.text(String(list[n]["name"]).to_upper(), 15, UiStyle.PAPER)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var cd := UiStyle.text("", 15, UiStyle.DIM)
		row.add_child(cd)
		var bar := UiStyle.bar(u.color, 5, 0.5)
		v.add_child(bar)
		skill_row.add_child(slab)
		skill_ui.append({"slot": n, "name": name_l, "cd": cd, "bar": bar, "total": list[n]["cd"], "stacks": int(list[n].get("stacks", 0))})

	# a troca de personagem aparece junto, com a própria recarga
	var sw := UiStyle.slab(UiStyle.INK, UiStyle.SKEW, 18, 7)
	sw.custom_minimum_size.x = 170
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	sw.add_child(sv)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	sv.add_child(srow)
	var skey := UiStyle.slab(UiStyle.PAPER, 0.0, 7, 0)
	skey.add_child(UiStyle.text("TAB", 14, UiStyle.INK))
	srow.add_child(skey)
	swap_name = UiStyle.text("TROCAR", 15, UiStyle.PAPER)
	swap_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(swap_name)
	swap_bar = UiStyle.bar(UiStyle.PAPER, 5, 0.5)
	sv.add_child(swap_bar)
	skill_row.add_child(sw)


func _process(delta: float) -> void:
	if g == null:
		return
	if g.ctrl != skill_for:
		_show_skills(g.ctrl)
	var me: Unit = g.units[g.ctrl]
	# tempo x vida: as duas barras têm a mesma largura, então dá pra comparar de olho
	var time_left: float = maxf(0.0, g.enrage - g.fight_time)
	var time_ratio: float = time_left / g.enrage
	UiStyle.set_bar(time_bar, time_ratio)
	# pequena folga: nos primeiros segundos a vida ainda não desceu e isso não é "estar atrás"
	var behind: bool = time_ratio < g.boss_hp / g.boss_max - 0.05
	time_bar.get_node("Fill").self_modulate = UiStyle.DANGER if behind else Color.WHITE
	time_label.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	time_label.add_theme_color_override("font_color", UiStyle.DANGER if behind else UiStyle.DIM)

	# Limit Break
	var ready: bool = g.lb >= 1.0
	lb_fill.size.x = maxf(34.0, 240.0 * g.lb) if g.lb > 0.02 else 0.0
	lb_fill.self_modulate = me.color
	lb_text.text = "%d%%" % int(g.lb * 100.0)
	lb_text.visible = not ready
	lb_button.visible = ready
	if ready:
		if lb_color != me.color:
			lb_color = me.color
			for state in ["normal", "hover", "pressed"]:
				lb_button.add_theme_stylebox_override(state, _pill(me.color.lightened(0.15 if state == "hover" else 0.0), 3, UiStyle.PAPER))
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				lb_button.add_theme_color_override(c, UiStyle.INK)
		# pulso lento: chama o olho sem piscar feito alarme
		lb_button.modulate = Color(1, 1, 1).lerp(Color(1.35, 1.35, 1.35), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))

	# barra de cast do herói controlado; vermelha por um instante se o cast foi cancelado
	if me.alive and me.channel_t > 0.0:
		cast_plate.visible = true
		my_cast_bar.visible = true
		my_cast_red.visible = false
		var cname := "LIMIT BREAK" if me.channel_slot == -1 else String(g.SKILLS[me.key][me.channel_slot]["name"]).to_upper()
		my_cast_label.text = "%s  %.1f" % [cname, me.channel_t]
		my_cast_label.add_theme_color_override("font_color", UiStyle.PAPER)
		UiStyle.set_bar(my_cast_bar, 1.0 - me.channel_t / me.channel_total)
	elif me.alive and me.cancel_t > 0.0:
		cast_plate.visible = true
		my_cast_bar.visible = false
		my_cast_red.visible = true
		my_cast_label.text = "CANCELADO"
		my_cast_label.add_theme_color_override("font_color", UiStyle.DANGER)
		UiStyle.set_bar(my_cast_red, maxf(me.cancel_ratio, 0.04))
		cast_plate.modulate.a = clampf(me.cancel_t * 3.0, 0.0, 1.0)
	else:
		cast_plate.visible = false
	if me.channel_t > 0.0:
		cast_plate.modulate.a = 1.0

	UiStyle.set_bar(swap_bar, 1.0 - g.swap_cd / g.SWAP_CD)
	swap_name.modulate.a = 1.0 if g.swap_cd <= 0.0 else 0.45
	for s in skill_ui:
		var n: int = s["slot"]
		var left: float = me.skill_cd[n]
		# pronta = barra cheia e nome claro; recarregando = barra enchendo e segundos
		if me.channel_t > 0.0 and me.channel_slot == n:
			# carregando: a barra enche até o disparo
			UiStyle.set_bar(s["bar"], 1.0 - me.channel_t / me.channel_total)
			s["cd"].text = "%.1f" % me.channel_t
			s["cd"].add_theme_color_override("font_color", UiStyle.YELLOW)
			s["name"].modulate.a = 1.0
			continue
		if s["stacks"] > 0:
			# habilidade de acúmulos (Blood Party): a barra é o quanto já juntou
			var full: bool = me.stacks >= s["stacks"]
			UiStyle.set_bar(s["bar"], 1.0 if me.party_t > 0.0 else float(me.stacks) / s["stacks"])
			s["cd"].text = ("%.0f" % ceilf(me.party_t)) if me.party_t > 0.0 else ("" if full else str(me.stacks))
			s["cd"].add_theme_color_override("font_color", UiStyle.DANGER if me.party_t > 0.0 else UiStyle.DIM)
			s["name"].modulate.a = 1.0 if (full or me.party_t > 0.0) else 0.45
			continue
		UiStyle.set_bar(s["bar"], 1.0 - left / maxf(s["total"], 0.1))
		s["cd"].text = "" if left <= 0.0 else "%.0f" % ceilf(left)
		s["cd"].add_theme_color_override("font_color", UiStyle.DIM)
		s["name"].modulate.a = 1.0 if left <= 0.0 else 0.45
	UiStyle.set_bar(boss_bar, g.boss_hp / g.boss_max)
	boss_pct.text = "%d%%" % ceili(g.boss_hp / g.boss_max * 100.0)

	var state := ""
	var state_col := UiStyle.CYAN
	if g.shield:
		state = "ÉGIDE"
	elif g.vulnerable:
		state = "VULNERÁVEL"
		state_col = UiStyle.YELLOW
	state_chip.modulate.a = 1.0 if state != "" else 0.0
	if state != "":
		state_label.text = state
		(state_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = state_col

	var casting: bool = g.cast_name != ""
	cast_row.modulate.a = 1.0 if casting or g.enrage_k > 0.0 else 0.0
	if g.enrage_k > 0.0:
		# a Fúria toma a barra de cast: quando encher, acabou
		cast_label.text = "FÚRIA  %.1f" % maxf(0.0, g.enrage - g.fight_time)
		cast_label.add_theme_color_override("font_color", UiStyle.DANGER)
		UiStyle.set_bar(cast_bar, g.enrage_k)
	elif casting:
		cast_label.add_theme_color_override("font_color", UiStyle.YELLOW)
		cast_label.text = "%s  %.1f" % [g.cast_name.to_upper(), maxf(0.0, g.phase_dur - g.phase_t)]
		UiStyle.set_bar(cast_bar, g.phase_t / g.phase_dur)

	for i in 4:
		var u: Unit = g.units[i]
		var card: CharacterCard = cards[i]
		if card.hp != u.hp or card.max_hp != u.max_hp:
			card.max_hp = u.max_hp
			card.hp = u.hp
		if card.has_element != (u.element >= 0):
			card.has_element = u.element >= 0
		if u.element >= 0 and card.element_color != g.EL_COL[u.element]:
			card.element_color = g.EL_COL[u.element]
		if card.state_text != u.action_text or card.state_kind != u.action_kind:
			card.state_kind = u.action_kind
			card.state_text = u.action_text
		if card.weak != (u.weak_t > 0.0):
			card.weak = u.weak_t > 0.0
		if card.dps != roundi(u.dps):
			card.dps = roundi(u.dps)
		if card.chosen != u.chosen:
			card.chosen = u.chosen
		if card.targeted != u.targeted:
			card.targeted = u.targeted
		if card.selected != u.controlled:
			card.selected = u.controlled
		card.lock_ratio = g.swap_cd / g.SWAP_CD
		card.shield_ratio = u.shield_hp / u.max_hp
		if card.locked != (g.swap_cd > 0.0):
			card.locked = g.swap_cd > 0.0
		if card.dead != (not u.alive):
			card.dead = not u.alive

	if toast_t > 0.0:
		toast_t -= delta
		toast_slab.modulate.a = clampf(toast_t * 3.0, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_slab.visible = false
	flash_rect.color.a = maxf(0.0, flash_rect.color.a - delta * 1.6)


func toast(text: String, time := 2.5) -> void:
	toast_label.text = text
	toast_slab.visible = true
	toast_slab.modulate.a = 1.0
	toast_t = time


## Mostra o rosto do biscoito: entra com fade e um leve crescimento, segura e some.
func show_biscoito(hold := 0.7) -> void:
	if _biscoito_tw != null:
		_biscoito_tw.kill()
	biscoito.scale = Vector2.ONE * 0.85
	_biscoito_tw = create_tween()
	_biscoito_tw.set_parallel(true)
	_biscoito_tw.tween_property(biscoito, "modulate:a", 0.92, 0.18)
	_biscoito_tw.tween_property(biscoito, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_biscoito_tw.set_parallel(false)
	_biscoito_tw.tween_interval(hold)
	_biscoito_tw.tween_property(biscoito, "modulate:a", 0.0, 0.5)


func flash(c: Color) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, 0.85)


## Entrada da luta: party um por um da esquerda, boss descendo do topo.
## Devolve quanto tempo a entrada leva, pro jogo só começar depois.
func play_intro() -> float:
	for i in cards.size():
		cards[i].play_intro(0.15 + i * 0.11)
	boss_center.modulate.a = 0.0
	boss_center.offset_top = -30
	legend.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(boss_center, "offset_top", 14.0, 0.35).set_delay(0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(boss_center, "modulate:a", 1.0, 0.25).set_delay(0.55)
	tw.tween_property(legend, "modulate:a", 1.0, 0.25).set_delay(0.7)
	return 1.15


func set_prep(on: bool) -> void:
	# com o menu aberto o HUD da luta some: nada competindo com as cartas
	fight_ui.visible = not on
	if menus != null:
		menus.set_open(on)


## Carta nova liberada: a carta entra pela direita com a faixa "CARTA NOVA!".
func card_unlocked(id: String) -> void:
	var holder := _side_splash("CARTA NOVA!", Knowledge.KIND_COLOR[Knowledge.CARDS[id]["kind"]].darkened(0.35), 3.2)
	var cv := CardView.make(id)
	cv.position = Vector2(96, 96)
	cv.scale = Vector2.ONE * 1.5
	cv.rotation_degrees = 6
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cv)
	var nm := Ink.title(Knowledge.CARDS[id]["name"], 24)
	nm.position = Vector2(20, 330)
	nm.size = Vector2(300, 40)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(nm)


## Limit Break: o rosto de quem soltou entra pela direita.
func limit_cut(u: Unit) -> void:
	var holder := _side_splash("LIMIT BREAK!", u.color.darkened(0.25), 1.6)
	var face := TextureRect.new()
	face.texture = load("res://assets/portraits/%s_face.png" % u.key)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.position = Vector2(60, 96)
	face.size = Vector2(220, 220)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)


## Painel lateral que entra da direita, fica um pouco e sai: base dos avisos grandes da luta.
func _side_splash(title_text: String, fill: Color, hold: float) -> Control:
	var p := Ink.panel(fill, 27)
	p.size = Vector2(340, 390)
	p.position = Vector2(1300, 150)
	p.rotation_degrees = 3
	fight_ui.add_child(p)
	var head := Ink.panel(Ink.CREAM, 13)
	head.size = Vector2(330, 70)
	head.position = Vector2(-30, -20)
	head.rotation_degrees = -7
	p.add_child(head)
	var t := Ink.title(title_text, 38, Ink.OUT)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", 910.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(p, "position:x", 1300.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)
	return p


## Fala da boss em destaque: placa irregular com letra grande, por um instante.
func shout(text: String) -> void:
	var p := Ink.panel(Ink.CREAM, 17)
	p.size = Vector2(620, 120)
	p.position = Vector2(330, 150)
	p.pivot_offset = p.size * 0.5
	p.rotation_degrees = -4.0
	fight_ui.add_child(p)
	var l := Ink.title(text, 54, Ink.OUT)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.scale = Vector2.ONE * 0.4
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## Mais um acerto na mão: mostra o progresso da maestria daquela mecânica.
func mastery_tick(key: String) -> void:
	var n := Knowledge.mastery_of(key)
	var pips := ""
	for k in Knowledge.MASTERY_NEED:
		pips += "◆" if k < n else "◇"
	toast("%s  %s" % [Knowledge.MASTERY[key]["name"], pips], 2.6)


# ---------------------------------------------------------------- fim

func _build_end(root: Control) -> void:
	end_layer = ColorRect.new()
	end_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.color = Color(0.03, 0.03, 0.08, 0.82)
	root.add_child(end_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	center.add_child(v)

	end_title_slab = UiStyle.slab(UiStyle.DANGER, UiStyle.SKEW, 40, 6)
	end_title_slab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	end_title = UiStyle.text("", 40, UiStyle.INK)
	end_title_slab.add_child(end_title)
	v.add_child(end_title_slab)

	var body := UiStyle.slab(UiStyle.INK, 0.0, 30, 24)
	body.custom_minimum_size.x = 620
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 20)
	body.add_child(bv)
	end_body = UiStyle.text("", 17, UiStyle.PAPER)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_constant_override("line_spacing", 8)
	bv.add_child(end_body)
	end_stats = VBoxContainer.new()
	end_stats.add_theme_constant_override("separation", 6)
	bv.add_child(end_stats)
	var again := UiStyle.slab(UiStyle.PAPER, UiStyle.SKEW, 20, 3)
	again.size_flags_horizontal = Control.SIZE_SHRINK_END
	again.add_child(UiStyle.text("ENTER", 15, UiStyle.INK))
	bv.add_child(again)
	end_layer.visible = false


func show_end(victory: bool, lines: Array, rank := -1, prize := {}) -> void:
	end_layer.visible = true
	fight_ui.visible = false
	var sb := end_title_slab.get_theme_stylebox("panel") as StyleBoxFlat
	if victory:
		end_title.text = "VITÓRIA"
		sb.bg_color = UiStyle.YELLOW
	else:
		end_title.text = "WIPE"
		sb.bg_color = UiStyle.DANGER
	var t := int(g.fight_time)
	var head_line := "%s  ·  tentativa %d  ·  %d:%02d" % [g.boss_def["name"], Knowledge.attempts, t / 60, t % 60]
	if not victory:
		head_line += "  ·  boss em %d%%" % ceili(g.boss_hp / g.boss_max * 100.0)
	if rank >= 0:
		head_line += "\n\nRANKING  %s" % Knowledge.RANKS[rank]
		if prize.has("coins"):
			head_line += "   ·   +%d moedas" % prize["coins"]
			if int(prize.get("ticket", 0)) > 0:
				head_line += "   ·   +1 ticket roxo"
			if String(prize.get("card", "")) != "":
				head_line += "   ·   carta: " + Knowledge.CARDS[prize["card"]]["name"]
	end_body.text = head_line
	if lines.size() > 0:
		end_body.text += "\n\n" + "\n".join(lines)

	# quem fez o dano: barra proporcional + DPS médio da luta
	for c in end_stats.get_children():
		c.queue_free()
	var best := 1.0
	for u in g.units:
		best = maxf(best, u.dmg_total)
	for u in g.units:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var n := UiStyle.text(u.unit_name.to_upper(), 14, u.color.lightened(0.3))
		n.custom_minimum_size.x = 110
		row.add_child(n)
		var b := UiStyle.bar(u.color, 10, 0.5)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiStyle.set_bar(b, u.dmg_total / best)
		row.add_child(b)
		var v := UiStyle.text("%d DPS" % roundi(u.dmg_total / maxf(g.fight_time, 1.0)), 14, UiStyle.PAPER)
		v.custom_minimum_size.x = 80
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		end_stats.add_child(row)
