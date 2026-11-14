extends CanvasLayer
## HUD da luta. Segue as regras de ui/style.gd: todo texto em cima de placa,
## arena livre no centro, informação nas bordas.
##
## Topo: boss (nome, vida, cast) · Esquerda: party · Direita: legenda dos elementos
## Rodapé: avisos (toast) · Por cima de tudo: menu de cartas e tela de fim.

var g
var boss_bar: Control
var boss_pct: Label
var dot_row: HBoxContainer
var bullet_row: Control
var dot_ui := {}  # id do DoT -> {"box": Control, "time": Label}
var end_stats: VBoxContainer
var skill_row: HBoxContainer
var skill_ui: Array = []
var skill_for := -1
var skill_asleep := false  # o Sleepwalker troca de barra quando dorme
var skill_tip: SkillTip
var _cut: Control  # destaque de habilidade importante em cena (só um por vez)
var buff_layer: Control  # ícones dos buffs ativos, à direita do card de cada herói
var party_fx: ColorRect  # Blood Party: a tela pulsando vermelho e roxo, cada vez mais forte
var _party_mat: ShaderMaterial
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
var options: OptionsScreen
var _options_from_pause := false
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
	# visão psicodélica do Blood Party: ondas vermelhas e roxas nas bordas, somadas à imagem. O meio
	# da tela fica limpo pra luta continuar legível.
	party_fx = ColorRect.new()
	party_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_fx.visible = false
	var psh := Shader.new()
	psh.code = PARTY_SHADER
	_party_mat = ShaderMaterial.new()
	_party_mat.shader = psh
	party_fx.material = _party_mat
	root.add_child(party_fx)
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
	pause.retry_pressed.connect(g.retry_fight)
	pause.cards_pressed.connect(g.leave_fight.bind("cards"))
	pause.title_pressed.connect(g.leave_fight.bind("title"))
	pause.options_pressed.connect(open_options.bind(true))
	# uma tela de opções só, pro menu principal e pro pause
	options = OptionsScreen.new()
	root.add_child(options)
	options.closed.connect(_on_options_closed)


# ---------------------------------------------------------------- boss

## Abre as opções por cima de tudo. Vindo do pause, a luta continua congelada e fechar volta pro pause.
func open_options(from_pause: bool) -> void:
	_options_from_pause = from_pause
	if from_pause:
		pause.visible = false
	options.open(g.units[g.ctrl].hero if from_pause else Knowledge.start_hero)


func _on_options_closed() -> void:
	if _options_from_pause:
		pause.back_from_options()
	# os atalhos podem ter mudado: a barra de habilidades mostra as teclas novas
	if skill_for >= 0:
		_show_skills(skill_for)


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
	# efeitos na boss (DoTs): um ícone por efeito, com o tempo que falta embaixo
	dot_row = HBoxContainer.new()
	dot_row.add_theme_constant_override("separation", 14)
	dot_row.custom_minimum_size.y = 34
	v.add_child(dot_row)


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
		# um clique foca o herói; dois cliques (ou o Tab) trocam de personagem
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
	party.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 22)
	buff_layer = Control.new()
	buff_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buff_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_layer.draw.connect(_draw_buffs)
	fight_ui.add_child(buff_layer)


## Buffs ativos de cada herói, numa fila à direita do card dele: o ícone da habilidade que deu o buff
## (menor) e os segundos que faltam embaixo.
func _draw_buffs() -> void:
	var f := Paper.display(0.0)
	for i in cards.size():
		var card: Control = cards[i]
		var list: Array = g.buffs_of(g.units[i])
		var at: Vector2 = card.global_position - buff_layer.global_position + Vector2(card.size.x * card.scale.x + 12.0, 6.0)
		for k in list.size():
			var r := Rect2(at + Vector2(k * 40.0, 0), Vector2(32, 32))
			buff_layer.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Paper.INK)
			buff_layer.draw_rect(r.grow(2.0), Paper.INK)
			if list[k]["icon"] != null:
				buff_layer.draw_texture_rect(list[k]["icon"], r, false)
			var t: float = list[k]["t"]
			var txt := ("%d" % ceili(t)) if t >= 1.0 else ("%.1f" % t)
			buff_layer.draw_string_outline(f, Vector2(r.position.x - 4, r.end.y + 15), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, 5, Paper.INK)
			buff_layer.draw_string(f, Vector2(r.position.x - 4, r.end.y + 15), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, Paper.CREAM)


func _on_card_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# um clique foca o herói (alvo de cura, escudo, reviver); dois cliques trocam o controle pra ele
	g.click_unit(i, event.double_click)


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
	center.offset_top = -104
	center.offset_bottom = -30
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(center)
	skill_row = HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 16)
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(skill_row)
	# ficha da habilidade ao passar o mouse num slot
	skill_tip = SkillTip.new()
	skill_tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(skill_tip)


## Clique num slot da barra: usa a habilidade, igual à tecla dele.
func _on_slot_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not g.prep and not g.ended and not g.fury:
			g.use_skill(g.units[g.ctrl], slot)
		get_viewport().set_input_as_handled()


func _tip_on(ui: SkillSlot, key: String, slot: int, asleep: bool) -> void:
	skill_tip.show_for(key, slot, asleep, ui.key_text, ui.get_global_rect())


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
	lb_button.text = "LIMIT BREAK   %s" % Binds.label("limit")
	lb_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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


var skill_rev := -1

func _show_skills(i: int) -> void:
	skill_for = i
	skill_ui.clear()
	for c in skill_row.get_children():
		skill_row.remove_child(c)
		c.queue_free()
	var u: Unit = g.units[i]
	var list: Array = g.kit(u)
	skill_asleep = u.asleep
	skill_tip.hide_tip()
	skill_rev = Knowledge.layout_rev
	for pos in list.size():
		# a barra segue a ordem que o jogador arrumou na tela SKILLS: n é a habilidade nesta posição
		var n: int = Knowledge.skill_at(u.hero, pos, list.size())
		if list[n] == null:
			continue
		# ícone da habilidade + a TECLA atual da posição (Binds). O mesmo arquivo de ícone da tela SKILLS.
		var ui := SkillSlot.new()
		ui.icon = SkillInfo.icon(u.key, n, u.asleep)
		ui.key_text = Binds.label("skill_%d" % (pos + 1))
		ui.accent = u.color.lightened(0.25)
		ui.mouse_entered.connect(_tip_on.bind(ui, u.key, n, u.asleep))
		ui.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ui.gui_input.connect(_on_slot_input.bind(n))
		ui.mouse_exited.connect(skill_tip.hide_tip)
		skill_row.add_child(ui)
		skill_ui.append({"slot": n, "ui": ui, "total": list[n]["cd"], "stacks": int(list[n].get("stacks", 0))})

	# a troca de personagem aparece junto, com a própria recarga
	var sw := UiStyle.slab(UiStyle.INK, UiStyle.SKEW, 18, 7)
	sw.custom_minimum_size.x = 170
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	sw.add_child(sv)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	sv.add_child(srow)
	var skey := UiStyle.slab(UiStyle.PAPER, 0.0, 7, 0)
	skey.add_child(UiStyle.text(Binds.label("swap"), 14, UiStyle.INK))
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
	if g.ctrl != skill_for or g.units[g.ctrl].asleep != skill_asleep:
		_show_skills(g.ctrl)
	var me: Unit = g.units[g.ctrl]
	# tempo x vida: as duas barras têm a mesma largura, então dá pra comparar de olho
	var time_left: float = maxf(0.0, g.enrage - g.fight_time)
	var time_ratio: float = time_left / g.enrage
	UiStyle.set_bar(time_bar, time_ratio)
	# pequena folga: nos primeiros segundos a vida ainda não desceu e isso não é "estar atrás"
	var behind: bool = time_ratio < g.boss_hp / g.boss_max - 0.05
	if Knowledge.practice:
		# treino livre: não existe prazo, o relógio só conta o tempo de treino
		behind = false
		time_left = g.fight_time
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
	var glow: int = g.glow_slot(me)
	buff_layer.queue_redraw()
	_tick_bullets(me)
	if skill_rev != Knowledge.layout_rev and skill_for >= 0:
		_show_skills(skill_for)  # a ordem da barra mudou na tela SKILLS
		return
	for s in skill_ui:
		var n: int = s["slot"]
		var ui: SkillSlot = s["ui"]
		# habilidade fortalecida (sequência da Ringstar, Disparo da Maga, próxima do sonho): o slot brilha
		ui.glow = n == glow
		ui.rainbow = false
		ui.glow_color = Color(1.0, 0.95, 0.6)
		if me.key == "nurse" and me.bath_window > 0.0 and me.bath_charges > 0 and g.BATH_SLOTS.has(n):
			# Bloodbath: as habilidades que podem sair fortalecidas brilham vermelho enquanto dá tempo de escolher
			ui.glow = true
			ui.glow_color = Color(1.0, 0.25, 0.35)
		if me.key == "nurse" and n == 5:
			var free: bool = me.party_t > 0.0 and me.bath_free
			if free:
				# Blood Party começou: o Bloodbath brilha porque agora sai de graça (uma vez)
				ui.glow = true
				ui.glow_color = Color(1.0, 0.25, 0.35)
		if me.key == "assassina" and (n == 3 or n == 4) and me.frenzy_t > 0.0:
			# Frenesi: Dança Carmesim (furacão) e Golpe de Misericórdia (serra) brilham roxo, estão mais fortes
			ui.glow = true
			ui.glow_color = Color(0.8, 0.3, 1.0)
		if me.key == "assassina" and n == 5:
			# janela da Última Dança: o botão do Frenesi troca de ícone, brilha e fica livre da recarga
			var bonus: bool = me.finisher_t > 0.0
			if bonus != s.get("bonus", false):
				s["bonus"] = bonus
				ui.icon = SkillInfo.bonus_icon("assassina") if bonus else SkillInfo.icon("assassina", 5)
			if bonus:
				ui.glow = true
				ui.rainbow = true
				ui.usable = true
				ui.cd_left = 0.0
				continue
		if me.key == "burner" and n == 5 and me.skill_cd[5] <= 0.0 and not g.get_dot("zenite").is_empty():
			# Juízo Solar pronto com a boss marcada: brilha em fogo verde, porque agora ele sai fortalecido
			ui.glow = true
			ui.glow_color = Color(0.3, 1.0, 0.45)
		if me.key == "maga":
			# Salva Astral com exatamente 6 balas (vai soltar a fada) e Canhão Estelar com o pente cheio
			if n == 4 and me.bullets.size() == g.SALVO_FAIRY:
				ui.glow = true
			if n == 5 and me.bullets.size() == g.BULLET_MAX:
				ui.glow = true
				ui.rainbow = true
		ui.locked = me.silence_t > 0.0 or me.air_t > 0.0
		ui.cast_k = (1.0 - me.channel_t / me.channel_total) if (me.channel_t > 0.0 and me.channel_slot == n) else -1.0
		if s["stacks"] > 0:
			# habilidade de gauge (Blood Party): acende quando o gauge enche; os segundos são a duração dela
			ui.usable = me.stacks >= s["stacks"] or me.party_t > 0.0
			ui.cd_left = me.party_t
			continue
		ui.usable = true
		if me.key == "nurse" and n == 5:
			# Bloodbath: precisa do Sangue, a não ser o grátis do Blood Party
			ui.usable = (me.party_t > 0.0 and me.bath_free) or me.stacks >= g.BATH_COST
		if me.key == "maga" and n == 1:
			# Rainbow Shots: precisa de pelo menos uma bala guardada
			ui.usable = not me.bullets.is_empty()
		if me.key == "maga" and n == 4:
			# Salva Astral: sem recarga, só acende com as balas pra pagar
			ui.usable = me.bullets.size() >= g.SALVO_COST
		if me.key == "sleepwalker" and me.asleep and n < 5:
			# dormindo: só a próxima da ordem, e só com Torpor pra pagar
			ui.usable = n == me.dream_step and (n == 0 or me.torpor >= float(g.SKILLS_ASLEEP[n]["cost"]))
		ui.cd_left = me.skill_cd[n]
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

	_tick_dots()
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
	# Blood Party de quem o jogador controla: a tela pulsa, e aperta conforme o tempo acaba
	var in_party: bool = me.alive and me.party_t > 0.0 and not g.ended
	var in_frenzy: bool = me.alive and me.key == "assassina" and me.frenzy_t > 0.0 and not g.ended
	party_fx.visible = in_party or in_frenzy
	if in_party:
		_party_mat.set_shader_parameter("urgency", 1.0 - clampf(me.party_t / g.PARTY_TIME, 0.0, 1.0))
		_party_mat.set_shader_parameter("col_a", Vector3(1.0, 0.08, 0.2))
		_party_mat.set_shader_parameter("col_b", Vector3(0.62, 0.12, 1.0))
		_party_mat.set_shader_parameter("gain", 1.0)
	elif in_frenzy:
		# Frenesi da Fera: a mesma pulsação, em roxo, apertando conforme o Frenesi acaba
		_party_mat.set_shader_parameter("urgency", 1.0 - clampf(me.frenzy_t / g.FRENZY_TIME, 0.0, 1.0))
		_party_mat.set_shader_parameter("col_a", Vector3(0.55, 0.1, 1.0))
		_party_mat.set_shader_parameter("col_b", Vector3(0.95, 0.2, 0.9))
		_party_mat.set_shader_parameter("gain", 1.35)


## Faixa de recurso da classe, em cima da barra de habilidades. Só aparece pra quem tem recurso:
## Maga (balas Rainbow), Apotecário (Vestígios e Paciente) e Sleepwalker (Torpor, Vulnerabilidade,
## Perto do Sonho e a janela de 1 s).
func _tick_bullets(me: Unit) -> void:
	if bullet_row == null:
		bullet_row = Control.new()
		bullet_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		bullet_row.offset_left = -210
		bullet_row.offset_right = 210
		# acima do aviso central (toast), pra um não cobrir o outro
		bullet_row.offset_top = -214
		bullet_row.offset_bottom = -144
		bullet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bullet_row.draw.connect(_draw_bullets)
		fight_ui.add_child(bullet_row)
	bullet_row.visible = me.alive and me.key in ["maga", "apothecary", "sleepwalker", "nurse"]
	if bullet_row.visible:
		bullet_row.queue_redraw()


func _draw_bullets() -> void:
	var me: Unit = g.units[g.ctrl]
	var f := ThemeDB.fallback_font
	match me.key:
		"nurse":
			# gauge de Sangue: enche com parry e Blood Consumed, paga o Blood Party. Cheio: cada golpe cura.
			var need: int = g.PARTY_NEED
			var full: bool = me.stacks >= need
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
			bullet_row.draw_rect(Rect2(-4, 36, 428, 34), UiStyle.INK)
			if full:
				bullet_row.draw_rect(Rect2(-8, 32, 436, 42), Color(1.0, 0.3, 0.4, 0.25 + 0.3 * pulse), false, 4.0)
			bullet_row.draw_rect(Rect2(0, 40, 420, 26), Color(0.2, 0.03, 0.08))
			bullet_row.draw_rect(Rect2(0, 40, 420.0 * minf(1.0, float(me.stacks) / need), 26), g.BLOOD.lightened(0.25 * pulse) if full else g.BLOOD)
			for n in range(1, 4):
				bullet_row.draw_rect(Rect2(420.0 * n / 4.0 - 1, 40, 2, 26), UiStyle.INK)
			bullet_row.draw_string(f, Vector2(8, 58), "SANGUE  %d / %d" % [me.stacks, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.PAPER)
			if me.party_t > 0.0:
				# Blood Party: o tempo que falta e a vida que ainda precisa recuperar, bem à vista
				var left: float = me.party_t / g.PARTY_TIME
				var ok: bool = me.hp >= me.max_hp - 0.5
				var warn := Color(0.4, 1.0, 0.6) if ok else Color(1.0, 0.3 + 0.5 * pulse, 0.35)
				bullet_row.draw_rect(Rect2(-8, -6, 436, 40), UiStyle.INK)
				bullet_row.draw_rect(Rect2(-4, -2, 428.0 * left, 10), warn)
				bullet_row.draw_rect(Rect2(-4, 12, 428, 18), Color(0.2, 0.03, 0.08))
				bullet_row.draw_rect(Rect2(-4, 12, 428.0 * clampf(me.hp / me.max_hp, 0.0, 1.0), 18), warn)
				bullet_row.draw_string(f, Vector2(0, 26), ("VIDA CHEIA: AGUENTE %d s" % ceili(me.party_t)) if ok else ("RECUPERE A VIDA: %d / %d   ·   %d s" % [int(me.hp), int(me.max_hp), ceili(me.party_t)]), HORIZONTAL_ALIGNMENT_CENTER, 420, 13, UiStyle.INK if ok else UiStyle.PAPER)
				bullet_row.draw_string(f, Vector2(0, 58), "BLOOD PARTY  %d s" % ceili(me.party_t), HORIZONTAL_ALIGNMENT_RIGHT, 412, 14, UiStyle.PAPER)
			elif full:
				bullet_row.draw_string(f, Vector2(0, 58), "CHEIO: CADA GOLPE CURA %d%%" % roundi(g.GAUGE_STEAL * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 412, 14, UiStyle.PAPER)
			if me.bath_window > 0.0 and me.bath_charges > 0:
				# tempo de escolher a habilidade fortalecida pelo Bloodbath
				var by := 78.0
				bullet_row.draw_rect(Rect2(60, by, 300, 18), UiStyle.INK)
				bullet_row.draw_rect(Rect2(62, by + 2, 296.0 * me.bath_window / g.BATH_WINDOW, 14), Color(1.0, 0.25, 0.35))
				bullet_row.draw_string(f, Vector2(60, by + 14), "ESCOLHA: %d FORTALECIDA%s" % [me.bath_charges, "S" if me.bath_charges > 1 else ""], HORIZONTAL_ALIGNMENT_CENTER, 300, 12, UiStyle.PAPER)
			if me.party_t <= 0.0 and me.hp / me.base_hp <= g.LOW_HP_FLOOR + 0.25:
				bullet_row.draw_rect(Rect2(110, 12, 200, 20), UiStyle.INK)
				bullet_row.draw_string(f, Vector2(110, 27), "VIDA BAIXA: +%d%% DE DANO" % roundi((g.low_hp_mult(me) - 1.0) * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 200, 12, UiStyle.YELLOW)
		"maga":
			var all: bool = me.bullets.size() >= g.BULLET_MAX
			bullet_row.draw_rect(Rect2(50, 40, 320, 28), UiStyle.INK)
			if all:
				# pente cheio: o Canhão Estelar vira o supercanhão
				var hue := fmod(Time.get_ticks_msec() * 0.0006, 1.0)
				bullet_row.draw_rect(Rect2(46, 36, 328, 36), Color.from_hsv(hue, 0.7, 1.0), false, 4.0)
				bullet_row.draw_rect(Rect2(110, 14, 200, 20), UiStyle.INK)
				bullet_row.draw_string(f, Vector2(110, 29), "SUPERCANHÃO PRONTO", HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color.from_hsv(hue, 0.5, 1.0))
			for n in g.BULLET_MAX:
				var c := Vector2(76 + n * 38, 54)
				if n < me.bullets.size():
					var col: Color = g.BULLETS[me.bullets[n]]["col"]
					bullet_row.draw_circle(c, 12.0 if n == 0 else 9.0, UiStyle.PAPER)
					bullet_row.draw_circle(c, 9.5 if n == 0 else 7.0, col)
				else:
					bullet_row.draw_circle(c, 7.0, UiStyle.INK_SOFT)
			# quanto falta pra próxima bala
			if me.bullets.size() < g.BULLET_MAX:
				bullet_row.draw_rect(Rect2(60, 66, 300.0 * me.bullet_t / g.BULLET_EVERY, 3), UiStyle.PAPER)
		"apothecary":
			bullet_row.draw_rect(Rect2(80, 40, 260, 28), UiStyle.INK)
			bullet_row.draw_string(f, Vector2(92, 60), "VESTÍGIOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.PAPER)
			for n in g.VESTIGE_MAX:
				var c := Vector2(196 + n * 30, 54)
				bullet_row.draw_circle(c, 10.0, UiStyle.PAPER)
				bullet_row.draw_circle(c, 7.5, g.CHEM if n < me.vestiges else UiStyle.INK_SOFT)
			if me.patient != null and me.patient_t > 0.0 and me.patient.alive:
				bullet_row.draw_rect(Rect2(80, 14, 260, 22), UiStyle.INK)
				bullet_row.draw_string(f, Vector2(80, 30), "PACIENTE: %s  %d s" % [me.patient.unit_name.to_upper(), ceili(me.patient_t)], HORIZONTAL_ALIGNMENT_CENTER, 260, 13, g.CHEM)
		"sleepwalker":
			# Torpor: barra de 0 a 100, com as marcas de quanto custa chegar em cada passo do sonho
			bullet_row.draw_rect(Rect2(0, 44, 420, 22), UiStyle.INK)
			bullet_row.draw_rect(Rect2(3, 47, 414.0 * me.torpor / 100.0, 16), g.DREAM if not me.asleep else UiStyle.PURPLE)
			var spent := 0.0
			for n in 5:
				spent += float(g.SKILLS_ASLEEP[n]["cost"])
				bullet_row.draw_rect(Rect2(3 + 414.0 * spent / 100.0 - 1, 44, 2, 22), UiStyle.PAPER)
			bullet_row.draw_string(f, Vector2(8, 60), "TORPOR  %d" % int(me.torpor), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.PAPER)
			# Vulnerabilidade Onírica: oito marcas e o tempo
			bullet_row.draw_rect(Rect2(0, 20, 420, 20), UiStyle.INK)
			for n in g.DREAM_MAX:
				bullet_row.draw_rect(Rect2(4 + n * 16, 25, 12, 10), UiStyle.YELLOW if n < g.dream_stacks else UiStyle.INK_SOFT)
			if g.dream_stacks > 0:
				bullet_row.draw_string(f, Vector2(138, 35), "+%d%%  %d s" % [g.dream_stacks * 2, ceili(g.dream_t)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.YELLOW)
			if me.near_t > 0.0:
				bullet_row.draw_string(f, Vector2(220, 35), "PERTO DO SONHO  %d s" % ceili(me.near_t), HORIZONTAL_ALIGNMENT_RIGHT, 194, 12, UiStyle.CYAN)
			# janela de 1 s pra próxima da sequência
			if me.window_t > 0.0 and not me.asleep:
				bullet_row.draw_rect(Rect2(60, 0, 300, 18), UiStyle.INK)
				bullet_row.draw_rect(Rect2(62, 2, 296.0 * me.window_t / g.SW_WINDOW, 14), UiStyle.YELLOW)
				bullet_row.draw_string(f, Vector2(60, 14), "AGORA: %s" % String(g.SKILLS["sleepwalker"][me.window_slot]["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 300, 12, UiStyle.INK)
			elif me.wake_t > 0.0:
				bullet_row.draw_string(f, Vector2(0, 14), "SEM TORPOR NECESSÁRIO, ACORDANDO", HORIZONTAL_ALIGNMENT_CENTER, 420, 13, UiStyle.DANGER)
			if me.silence_t > 0.0:
				# punição de quem acordou mal: anda, mas não age
				bullet_row.draw_rect(Rect2(60, 0, 300, 18), UiStyle.INK)
				bullet_row.draw_rect(Rect2(62, 2, 296.0 * minf(1.0, me.silence_t / g.SW_LOCK_BROKEN), 14), UiStyle.DANGER)
				bullet_row.draw_string(f, Vector2(60, 14), "SONOLENTO: SEM AGIR  %.1f s" % me.silence_t, HORIZONTAL_ALIGNMENT_CENTER, 300, 12, UiStyle.PAPER)


## Ícones dos DoTs embaixo da vida da boss: cor do efeito, nome curto e os segundos que faltam.
func _tick_dots() -> void:
	var alive := {}
	for d in g.boss_dots:
		var id: String = d["id"]
		alive[id] = true
		if not dot_ui.has(id):
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 0)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var top := HBoxContainer.new()
			top.add_theme_constant_override("separation", 5)
			top.add_child(UiStyle.chip(d["col"], 12))
			top.add_child(UiStyle.text(String(d["name"]).to_upper(), 11, UiStyle.PAPER))
			box.add_child(top)
			var time := UiStyle.text("", 12, UiStyle.YELLOW)
			box.add_child(time)
			dot_row.add_child(box)
			dot_ui[id] = {"box": box, "time": time}
		dot_ui[id]["time"].text = "%d s" % ceili(d["t"])
		# quase acabando: o tempo fica vermelho
		dot_ui[id]["time"].add_theme_color_override("font_color", UiStyle.DANGER if d["t"] <= 2.0 else UiStyle.YELLOW)
	for id in dot_ui.keys():
		if not alive.has(id):
			dot_ui[id]["box"].queue_free()
			dot_ui.erase(id)


func toast(text: String, time := 2.5) -> void:
	toast_label.text = text
	toast_slab.visible = true
	toast_slab.modulate.a = 1.0
	toast_t = time


## "PROVOKE!": etiqueta pequena do kit de papel que carimba ao lado da boss quando alguém pega a atenção dela.
func provoke_tag(at: Vector2) -> void:
	var tag := Chip.new()
	tag.px = 20
	tag.pad = 14.0
	tag.border = 4.0
	tag.fill = Paper.GOLD
	tag.ink = Color("B0181A")
	tag.shadow = Vector2(-4, 5)
	tag.text = "PROVOKE!"
	fight_ui.add_child(tag)
	tag.position = at - tag.size * 0.5
	tag.pivot_offset = tag.size * 0.5
	tag.rotation = deg_to_rad(-7.0)
	tag.scale = Vector2.ONE * 2.0
	tag.modulate.a = 0.0
	var tw := tag.create_tween()
	tw.tween_property(tag, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tag, "modulate:a", 1.0, 0.08)
	tw.tween_property(tag, "rotation", deg_to_rad(-3.0), 0.5)
	tw.tween_property(tag, "position:y", tag.position.y - 18.0, 0.35)
	tw.parallel().tween_property(tag, "modulate:a", 0.0, 0.35)
	tw.tween_callback(tag.queue_free)


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


## Clarão de tela inteira, que apaga sozinho. `strength` = opacidade inicial (0.85 é o clarão cheio
## dos golpes da boss; destaques de habilidade usam bem menos, pra não esconder a luta).
func flash(c: Color, strength := 0.85) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, strength)


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
	# a carta só é do save quando a run termina; sair ou reiniciar pelo pause joga ela fora
	toast("Carta garantida quando a luta terminar", 3.2)


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


const PARTY_SHADER := "shader_type canvas_item;
render_mode blend_add;
uniform float urgency = 0.0;
uniform vec3 col_a = vec3(1.0, 0.08, 0.2);
uniform vec3 col_b = vec3(0.62, 0.12, 1.0);
uniform float gain = 1.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.0, 0.72)) * 2.0;
	float ang = atan(d.y, d.x);
	// o pulso acelera com a urgência: de um batimento calmo a um piscar nervoso
	float beat = 0.5 + 0.5 * sin(TIME * (5.0 + urgency * 16.0));
	// ondas que giram e respiram: alternam vermelho e roxo em volta da tela
	float wave = 0.5 + 0.5 * sin(ang * 3.0 + TIME * (1.5 + urgency * 4.0) + sin(r * 6.0 - TIME * 3.0));
	vec3 col = mix(col_a, col_b, wave);
	float edge = smoothstep(0.55 - urgency * 0.3, 1.25, r);
	float a = edge * (0.22 + urgency * 0.5) * (0.55 + 0.45 * beat) * gain;
	COLOR = vec4(col * a, a);
}
"

## Destaque de habilidade importante (game.gd marca com "big": true), só pra quem o JOGADOR controla:
## brilho pulsando nas bordas da tela na cor do herói, a arte dele entrando pela direita com halo e
## faíscas, e o nome da habilidade. Um por vez: usar outra troca o destaque em cena.
const CUT_SHADER := "shader_type canvas_item;\nrender_mode blend_add;\nuniform vec4 tint : source_color = vec4(1.0);\nuniform float power = 0.0;\nvoid fragment() {\n\tvec2 d = abs(UV - vec2(0.5)) * 2.0;\n\tfloat edge = max(pow(d.x, 3.0), pow(d.y, 2.2));\n\tfloat corner = pow(d.x * d.y, 1.5);\n\tfloat a = clamp(smoothstep(0.35, 1.0, edge) * 0.8 + corner * 0.9, 0.0, 1.0) * power;\n\tCOLOR = vec4(tint.rgb * (1.0 + a), a);\n}\n"
const CUT_HOLD := 0.95

## Brilho rápido nas bordas e nos cantos da tela, na cor dada (golpes pesados de quem o jogador controla).
func edge_glow(col: Color, power := 1.0, time := 0.5) -> void:
	var edge := ColorRect.new()
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CUT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tint", col)
	edge.material = mat
	fight_ui.add_child(edge)
	var tw := edge.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("power", v), 0.0, power, 0.06)
	tw.tween_method(func(v: float): mat.set_shader_parameter("power", v), power, 0.0, time)
	tw.tween_callback(edge.queue_free)


func skill_cut(u: Unit, skill_name: String) -> void:
	if _cut != null and is_instance_valid(_cut):
		_cut.queue_free()
	var col: Color = u.color.lightened(0.15)
	_cut = Control.new()
	_cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(_cut)
	var root := _cut
	# brilho nas bordas e nos cantos
	var edge := ColorRect.new()
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CUT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tint", col)
	edge.material = mat
	root.add_child(edge)
	# a arte do personagem, à direita, acima da barra de Limit Break
	var art_path := "res://assets/portraits/%s_art.webp" % u.key
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var band := CutPanel.make(Rect2(40, 60, 300, 380), [[.16, 0], [1, .06], [.84, 1], [0, .92]], col.darkened(0.25), 6, Vector2(10, 10))
	holder.add_child(band)
	var w := 330.0
	if ResourceLoader.exists(art_path):
		var tex: Texture2D = load(art_path)
		var ts := tex.get_size()
		var h := minf(500.0, 360.0 * ts.y / ts.x)
		w = h * ts.x / ts.y
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		# halo: a mesma arte, maior e somada, na cor do herói
		for k in 2:
			var halo := TextureRect.new()
			halo.texture = tex
			halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			halo.size = Vector2(w, h)
			halo.position = Vector2(190 - w * 0.5, 10)
			halo.pivot_offset = Vector2(w, h) * 0.5
			halo.scale = Vector2.ONE * (1.07 + k * 0.08)
			halo.modulate = Color(col.r, col.g, col.b, 0.55 - k * 0.25)
			halo.material = add
			halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(halo)
			halo.create_tween().set_loops(4).tween_property(halo, "scale", Vector2.ONE * (1.12 + k * 0.1), 0.16).set_trans(Tween.TRANS_SINE)
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.size = Vector2(w, h)
		art.position = Vector2(190 - w * 0.5, 10)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(art)
		# clarão branco por cima da arte, que apaga rápido
		var white := TextureRect.new()
		white.texture = tex
		white.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		white.size = Vector2(w, h)
		white.position = art.position
		white.material = add
		white.modulate = Color(1, 1, 1, 0.9)
		white.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(white)
		white.create_tween().tween_property(white, "modulate:a", 0.0, 0.3)
	# faíscas
	var sparks := CPUParticles2D.new()
	sparks.position = Vector2(190, 250)
	sparks.amount = 46
	sparks.lifetime = 0.9
	sparks.explosiveness = 0.75
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(150, 200)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, -60)
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 190.0
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 8.0
	sparks.color = col.lightened(0.5)
	var smat := CanvasItemMaterial.new()
	smat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = smat
	holder.add_child(sparks)
	# nome da habilidade
	var tag := Chip.new()
	tag.px = 22
	tag.pad = 18.0
	tag.fill = Paper.CREAM
	tag.text = skill_name.to_upper()
	tag.position = Vector2(190 - tag.size.x * 0.5, 418)
	tag.rotation = deg_to_rad(-4.0)
	holder.add_child(tag)
	# entra da direita com um tranco, segura, sai
	holder.position = Vector2(1300, 84)
	flash(col, 0.22)
	var tw := root.create_tween()
	tw.tween_property(holder, "position:x", 900.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float): mat.set_shader_parameter("power", v), 0.0, 1.0, 0.1)
	tw.tween_method(func(v: float): mat.set_shader_parameter("power", v), 1.0, 0.55, 0.22)
	tw.tween_method(func(v: float): mat.set_shader_parameter("power", v), 0.55, 0.9, 0.2)
	tw.tween_interval(CUT_HOLD - 0.42)
	tw.tween_property(holder, "position:x", 1320.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.24)
	tw.parallel().tween_method(func(v: float): mat.set_shader_parameter("power", v), 0.9, 0.0, 0.24)
	tw.tween_callback(root.queue_free)


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
		end_title.text = "FIM DO TREINO" if Knowledge.practice else "WIPE"
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
	var got: Array = prize.get("cards", [])
	if not got.is_empty():
		var names: Array = []
		for id in got:
			names.append(Knowledge.CARDS[id]["name"])
		head_line += "\n\nCARTAS GARANTIDAS:  " + ",  ".join(names)
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
