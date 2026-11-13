class_name CardsScreen
extends Control
## Cartas de UM herói por vez. Em cima, o seletor dos quatro; no meio, os slots equipados;
## embaixo, a mão ("suas cartas"). Arrastar e soltar de verdade, e clique como atalho:
##   mão -> slot do mesmo tipo: equipa · slot -> mão: tira · slot -> slot: troca de lugar
## O layout fica na cena (cards_screen.tscn); aqui é só comportamento.

signal ready_pressed
signal back_pressed

const HAND_W := 644.0
const PER_PAGE := 7

var hero := 0
var _page := 0
var _pop := ""  # "tipo:slot" da carta que acabou de entrar: ela dá um pulinho


func _ready() -> void:
	$BtnPrev.pressed.connect(func(): _switch(-1))
	$BtnNext.pressed.connect(func(): _switch(1))
	$BtnReady.pressed.connect(func(): ready_pressed.emit())
	$BtnBack.pressed.connect(func(): back_pressed.emit())
	$HandPanel/HandPrev.pressed.connect(func(): _turn_page(-1))
	$HandPanel/HandNext.pressed.connect(func(): _turn_page(1))
	# soltar uma carta equipada em cima da mão devolve ela pro inventário
	$HandPanel/HandRow.set_drag_forwarding(Callable(), _can_drop_hand, _drop_hand)
	if get_tree().current_scene == self:
		# aberta sozinha (F6): dados de exemplo, sem tocar no save
		Knowledge.persist = false
		for id in ["stack", "pair", "spread", "mitigate", "provoke", "instinct", "sharpen", "plate", "potion", "revive", "eshield"]:
			Knowledge.owned[id] = true
		Knowledge.dps_known["tank"] = true
		Knowledge.mastery["link"] = 2
		for id in ["stack", "mitigate", "potion"]:
			Knowledge.equip(0, id)
		open(0)


func open(hero_idx: int, show_ready := true) -> void:
	hero = clampi(hero_idx, 0, 3)
	_page = 0
	$BtnReady.visible = show_ready
	$TitlePanel/BossName.text = Knowledge.BOSS_INFO[Knowledge.boss]["name"] if show_ready else "GEAR"
	refresh(true)


func _switch(dir: int) -> void:
	hero = posmod(hero + dir, 4)
	Knowledge.start_hero = hero
	Knowledge.save()
	_page = 0
	refresh(true, dir)


func refresh(animate := false, dir := 0) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	var col: Color = h["color"]
	$HeroPanel.fill = col
	$HeroPanel/FaceFrame/Face.texture = load("res://assets/portraits/%s_face.png" % h["key"])
	$HeroPanel/HeroName.text = String(h["name"]).to_upper()
	$HeroPanel/HeroRole.text = h["role"]
	$HeroPanel/HpTag/HeroHp.text = "HP %d" % h["hp"]
	$HeroPanel/BlurbPanel/HeroBlurb.text = h["blurb"]
	_build_strip()
	_build_slots()
	_build_hand()
	_show("")
	if animate:
		# o painel do herói e os slots escorregam do lado pra onde você andou
		for node in [$HeroPanel, $EquipPanel]:
			var home: float = node.position.x
			node.position.x = home + (40.0 if dir >= 0 else -40.0)
			node.modulate.a = 0.0
			var tw: Tween = node.create_tween().set_parallel(true)
			tw.tween_property(node, "position:x", home, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "modulate:a", 1.0, 0.16)


# ---------------------------------------------------------------- seletor de herói

func _build_strip() -> void:
	var strip: Control = $HeroStrip
	for c in strip.get_children():
		strip.remove_child(c)
		c.queue_free()
	for i in 4:
		var h: Dictionary = Knowledge.HEROES[i]
		var on := i == hero
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(290 if on else 84, 88)
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var p := Ink.panel(h["color"] if on else Ink.NAVY, 40 + i)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.offset_bottom = -8
		chip.add_child(p)
		var face := TextureRect.new()
		face.texture = load("res://assets/portraits/%s_face.png" % h["key"])
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.position = Vector2(10, 10)
		face.size = Vector2(60, 60)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(face)
		if on:
			var nm := Ink.title(String(h["name"]).to_upper(), 28, Ink.OUT)
			nm.position = Vector2(82, 8)
			chip.add_child(nm)
			var rl := Ink.text(h["role"], 14, Ink.OUT)
			rl.position = Vector2(84, 46)
			chip.add_child(rl)
		else:
			# os outros ficam apagados, só o rosto
			face.modulate = Color(0.55, 0.55, 0.62)
			chip.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					var dir := 1 if i > hero else -1
					hero = i
					Knowledge.start_hero = hero
					Knowledge.save()
					_page = 0
					refresh(true, dir))
		strip.add_child(chip)


# ---------------------------------------------------------------- slots equipados

func _build_slots() -> void:
	var rows := {"purple": $EquipPanel/PurpleRow, "gold": $EquipPanel/GoldRow, "white": $EquipPanel/WhiteRow, "item": $EquipPanel/ItemRow}
	for kind in rows:
		var row: Control = rows[kind]
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
		var arr: Array = Knowledge.deck(hero)[kind]
		for n in Knowledge.SLOTS[kind]:
			var id: String = arr[n]
			var cv: CardView = CardView.make(id) if id != "" else CardView.empty(kind)
			cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" else Control.CURSOR_ARROW
			cv.set_drag_forwarding(
				func(_at: Vector2): return _drag(cv, id, "slot") if id != "" else null,
				func(_at: Vector2, data): return _is_card(data) and Knowledge.kind_of(data["card"]) == kind,
				func(_at: Vector2, data): _drop_slot(kind, n, data))
			if id != "":
				cv.mouse_entered.connect(_show.bind(id))
				cv.gui_input.connect(func(e: InputEvent):
					# clique simples: tira a carta
					if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not get_viewport().gui_is_dragging():
						Knowledge.unequip(hero, id)
						_changed())
			row.add_child(cv)
			if _pop == "%s:%d" % [kind, n]:
				cv.scale = Vector2.ONE * 1.25
				cv.create_tween().tween_property(cv, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop = ""


func _is_card(data) -> bool:
	return data is Dictionary and data.has("card")


func _drag(src: Control, id: String, from: String):
	var holder := Control.new()
	var ghost := CardView.make(id)
	ghost.position = -ghost.size * 0.5
	ghost.rotation_degrees = -5
	ghost.modulate.a = 0.9
	holder.add_child(ghost)
	src.set_drag_preview(holder)
	return {"card": id, "from": from}


func _drop_slot(kind: String, n: int, data) -> void:
	var id: String = data["card"]
	var arr: Array = Knowledge.deck(hero)[kind]
	if data["from"] == "slot":
		# de um slot pra outro: as duas cartas trocam de lugar
		var src := arr.find(id)
		if src >= 0 and src != n:
			arr[src] = arr[n]
			arr[n] = id
	else:
		Knowledge.equip(hero, id, n)
	_pop = "%s:%d" % [kind, n]
	_changed()


func _can_drop_hand(_at: Vector2, data) -> bool:
	return _is_card(data) and data["from"] == "slot"


func _drop_hand(_at: Vector2, data) -> void:
	Knowledge.unequip(hero, data["card"])
	_changed()


func _changed() -> void:
	Knowledge.save()
	_build_slots()
	_build_hand()


# ---------------------------------------------------------------- mão

## Cartas do herói que não estão equipadas, e depois as que ele ainda não tem (de verso, com a maestria).
func _hand_list() -> Array:
	var out: Array = []
	for id in Knowledge.inventory(hero):
		out.append([id, true])
	for kind in Knowledge.KINDS:
		for id in Knowledge.CARDS:
			if Knowledge.CARDS[id]["kind"] == kind and Knowledge.usable(hero, id) and not Knowledge.is_owned_by(hero, id):
				out.append([id, false])
	return out


func _turn_page(dir: int) -> void:
	var pages := maxi(1, ceili(_hand_list().size() / float(PER_PAGE)))
	_page = posmod(_page + dir, pages)
	_build_hand()


func _build_hand() -> void:
	var row: Control = $HandPanel/HandRow
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var list := _hand_list()
	var pages := maxi(1, ceili(list.size() / float(PER_PAGE)))
	_page = clampi(_page, 0, pages - 1)
	$HandPanel/HandPrev.visible = pages > 1
	$HandPanel/HandNext.visible = pages > 1
	var shown := list.slice(_page * PER_PAGE, _page * PER_PAGE + PER_PAGE)
	# as cartas se sobrepõem um pouco, como uma mão aberta
	var step := minf(CardView.W + 8.0, (HAND_W - CardView.W) / maxf(1.0, shown.size() - 1.0))
	for k in shown.size():
		var id: String = shown[k][0]
		var mine: bool = shown[k][1]
		var cv := CardView.make(id, "face" if mine else "back")
		cv.position = Vector2(k * step, 0)
		if not mine:
			var key := Knowledge.mastery_key(id)
			if key != "":
				cv.progress = Knowledge.mastery_of(key)
		cv.mouse_entered.connect(func():
			_show(id)
			cv.z_index = 5
			cv.create_tween().tween_property(cv, "position:y", -12.0, 0.08))
		cv.mouse_exited.connect(func():
			cv.z_index = 0
			cv.create_tween().tween_property(cv, "position:y", 0.0, 0.1))
		if mine:
			cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			cv.set_drag_forwarding(func(_at: Vector2): return _drag(cv, id, "hand"), _can_drop_hand, _drop_hand)
			cv.gui_input.connect(func(e: InputEvent):
				# clique simples: equipa no primeiro slot livre daquele tipo
				if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not get_viewport().gui_is_dragging():
					var kind := Knowledge.kind_of(id)
					var free: int = Knowledge.deck(hero)[kind].find("")
					if free >= 0 and Knowledge.equip(hero, id, free):
						_pop = "%s:%d" % [kind, free]
						_changed()
					else:
						_shake(cv))
		row.add_child(cv)


## Sem slot livre: a carta balança e fica onde está.
func _shake(cv: Control) -> void:
	var home := cv.position.x
	var tw := cv.create_tween()
	for d in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tw.tween_property(cv, "position:x", home + d, 0.04)


# ---------------------------------------------------------------- detalhes

func _show(id: String) -> void:
	if id == "":
		$Details/CardName.text = ""
		$Details/CardMeta.text = ""
		$Details/CardDesc.text = ""
		return
	var c: Dictionary = Knowledge.CARDS[id]
	$Details/CardName.text = c["name"]
	$Details/CardMeta.text = "%s  ·  %s" % [Knowledge.KIND_NAME[c["kind"]], Knowledge.CAT_NAME[c["cat"]]]
	var desc: String = c["desc"]
	if not Knowledge.is_owned_by(hero, id):
		# ainda não é sua: diz como conseguir
		var key := Knowledge.mastery_key(id)
		if key != "":
			desc = "Resolva na mão: %s  %d/%d" % [Knowledge.MASTERY[key]["name"], Knowledge.mastery_of(key), Knowledge.MASTERY_NEED]
		elif c.has("earn"):
			desc = c["earn"]
		else:
			desc = "À venda na loja."
	$Details/CardDesc.text = desc


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _switch(-1)
		KEY_D, KEY_RIGHT: _switch(1)
		KEY_ENTER, KEY_KP_ENTER:
			if $BtnReady.visible:
				ready_pressed.emit()
		KEY_ESCAPE: back_pressed.emit()
