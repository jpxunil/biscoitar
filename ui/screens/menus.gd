extends Control
## Liga as telas de menu entre si e com a luta:
##   título -> PLAY -> saves -> cafeteria (cena lobby.tscn: monta a party) -> bosses -> cartas -> luta
##   bosses -> CARTAS (gear: as cartas do save ativo, sem o botão de luta) -> bosses
##   bosses -> TREINO LIVRE (dummy) -> cartas -> luta sem progresso
##   bosses -> LOJA (do save ativo; abre depois da primeira vitória) -> bosses
##   vitória -> loja -> bosses
##   título -> tutoriais -> (cena do tutorial) -> tutoriais
##   título -> SKILLS (consulta das habilidades de todos os personagens) -> título
##   cartas <-> GEAR (o alternador CARTAS | GEAR no título das duas telas, ou TAB; mantém o herói)
##   cartas -> SKILLS (botão pequeno embaixo do VOLTAR, abre no herói que está sendo visto) -> cartas
##   título -> opções (a tela de opções é do hud.gd: é a mesma que o pause abre)
## Cada tela é uma cena própria em ui/screens/, que também abre sozinha com F6.

var g
var title: TitleScreen
var bosses: BossScreen
var cards: CardsScreen
var shop: ShopScreen
var tutorials: TutorialsScreen
var saves: SavesScreen
var skills: SkillsScreen
var gear_screen: Control  # GearScreen (ui/screens/gear_screen.gd): equipamentos, atributos e passivas
var _gear_hero := -1
var _pop: Control       # comemoração de carta que virou passiva
var _gear := false
var _skills_from_cards := false
var _skills_hero := -1
var _cards_hero := -1
## As cartas estavam no caminho de uma luta quando o jogador virou pro GEAR: a volta mantém o botão de luta.
var _fight_cards := false


func setup(game) -> void:
	g = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = preload("res://ui/screens/title_screen.tscn").instantiate()
	bosses = preload("res://ui/screens/boss_screen.tscn").instantiate()
	cards = preload("res://ui/screens/cards_screen.tscn").instantiate()
	shop = preload("res://ui/screens/shop_screen.tscn").instantiate()
	tutorials = TutorialsScreen.new()
	saves = SavesScreen.new()
	skills = SkillsScreen.new()
	gear_screen = load("res://ui/screens/gear_screen.gd").new()
	for s in [title, bosses, cards, shop, tutorials, saves, skills, gear_screen]:
		add_child(s)
		s.visible = false
	gear_screen.back_pressed.connect(show_screen.bind("bosses"))
	gear_screen.cards_pressed.connect(func(hero: int):
		_gear = not _fight_cards
		_cards_hero = hero
		show_screen("cards"))
	cards.gear_pressed.connect(func(hero: int):
		# a outra face do alternador: a tela GEAR no mesmo herói
		_fight_cards = not _gear
		_gear_hero = hero
		show_screen("gear"))
	bosses.equip_pressed.connect(show_screen.bind("gear"))
	title.play_pressed.connect(show_screen.bind("saves"))
	title.skills_pressed.connect(show_screen.bind("skills"))
	skills.back_pressed.connect(func():
		# volta pra onde veio: a tela de cartas (botão SKILLS dela) ou o menu principal
		var to := "cards" if _skills_from_cards else "title"
		_skills_from_cards = false
		show_screen(to))
	cards.skills_pressed.connect(func(hero: int):
		_skills_from_cards = true
		_skills_hero = hero
		_cards_hero = hero  # na volta, as cartas reabrem no mesmo herói
		show_screen("skills"))
	saves.back_pressed.connect(show_screen.bind("title"))
	saves.slot_chosen.connect(func(n: int):
		# carrega (ou cria) o save e vai pra cafeteria montar a party; os bosses só abrem depois dela
		Knowledge.select_slot(n)
		get_tree().change_scene_to_file("res://lobby.tscn"))
	title.options_pressed.connect(func(): g.hud.open_options(false))
	title.tutorial_pressed.connect(show_screen.bind("tutorials"))
	tutorials.back_pressed.connect(show_screen.bind("title"))
	tutorials.tutorial_chosen.connect(func(scene: String):
		# cada tutorial é uma cena própria (o 1 é scripts/tutorial.gd); ele volta pra esta lista quando acaba
		Knowledge.save()
		get_tree().change_scene_to_file(scene))
	bosses.back_pressed.connect(func():
		# voltar dos bosses é voltar pra cafeteria (a party pode ser trocada lá)
		Knowledge.save()
		get_tree().change_scene_to_file("res://lobby.tscn"))
	bosses.boss_chosen.connect(func(i: int):
		_gear = false
		# trocar de luta (ou entrar/sair do treino) recarrega a cena já na tela de cartas
		if i < 0:
			if Knowledge.practice:
				show_screen("cards")
			else:
				g.select_practice()
		elif i != Knowledge.boss or Knowledge.practice:
			g.select_boss(i)
		else:
			show_screen("cards"))
	bosses.gear_pressed.connect(func():
		# gear: as cartas e os baralhos do save ativo, sem começar luta nenhuma
		_gear = true
		show_screen("cards"))
	cards.back_pressed.connect(func():
		_gear = false
		show_screen("bosses"))
	cards.ready_pressed.connect(func():
		if g.select_hero(cards.hero):
			g.start_fight())
	# uma entrada só: a loja abre no balcão de cartas e a troca pro de itens é lá dentro
	bosses.shop_pressed.connect(show_screen.bind("shop"))
	# a loja é do save: sair dela volta pros bosses (sem save ou party, isso cai na tela de saves)
	shop.back_pressed.connect(show_screen.bind("bosses"))
	visible = false


func set_open(on: bool) -> void:
	visible = on
	if on:
		show_screen(Knowledge.screen)


func show_screen(id: String) -> void:
	if id == "shop" and not Knowledge.shop_unlocked:
		id = "bosses"
	Knowledge.screen = id
	# os bosses e as cartas de luta só existem com um save e uma party de quatro
	if id == "bosses" and Knowledge.persist and (Knowledge.slot <= 0 or not Knowledge.party_ready()):
		id = "saves"
	for s in [title, bosses, cards, shop, tutorials, saves, skills, gear_screen]:
		s.visible = false
	match id:
		"gear":
			gear_screen.visible = true
			gear_screen.open(_gear_hero if _gear_hero >= 0 else Knowledge.start_hero)
			_gear_hero = -1
		"skills":
			skills.visible = true
			skills.open(_skills_hero if _skills_hero >= 0 else Knowledge.start_hero)
			_skills_hero = -1
		"bosses":
			_fight_cards = false
			bosses.visible = true
			bosses.open()
			_celebrate()
		"cards":
			cards.visible = true
			cards.open(_cards_hero if _cards_hero >= 0 else Knowledge.start_hero, not _gear)
			_cards_hero = -1
		"shop":
			shop.visible = true
			shop.open()
		"tutorials":
			tutorials.visible = true
			tutorials.open()
		"saves":
			saves.visible = true
			saves.open()
		_:
			_gear = false
			title.visible = true
			title.open()


## Uma carta de aprendizado chegou a 100% e virou PASSIVA: a tela pisca, a carta salta pro meio com
## brilho e a mensagem explica o que mudou. O botão leva pra tela de gear, onde as passivas ficam.
func _celebrate() -> void:
	if Knowledge.learned_now.is_empty() or (_pop != null and is_instance_valid(_pop)):
		return
	var entry: Array = Knowledge.learned_now.pop_front()
	var hero: int = entry[0]
	var id: String = entry[1]
	_pop = Control.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pop)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.1, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(dim)
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.95, 0.7, 0.9)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(flash)
	var center := size * 0.5
	var cv := CardView.make(id)
	cv.halo = true
	cv.learn = 100.0
	cv.pivot_offset = Vector2(CardView.W, CardView.H) * 0.5
	cv.position = center - cv.pivot_offset + Vector2(0, -70)
	cv.scale = Vector2.ONE * 0.4
	cv.rotation = deg_to_rad(-14.0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_child(cv)
	var head := Paper.label("VIROU APRENDIZADO!", 44, Paper.GOLD, Paper.display())
	head.position = Vector2(0, center.y + 110)
	head.size = Vector2(size.x, 54)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.modulate.a = 0.0
	_pop.add_child(head)
	var who: String = Knowledge.HEROES[hero]["name"]
	var body := Paper.label("%s aprendeu \"%s\" de vez. Agora é uma passiva: vale sempre e não ocupa mais slot do baralho." % [who, Knowledge.CARDS[id]["name"]], 18, Paper.CREAM, Paper.body(700))
	body.position = Vector2(size.x * 0.5 - 330, center.y + 168)
	body.size = Vector2(660, 56)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.modulate.a = 0.0
	_pop.add_child(body)
	var go := ShineButton.new()
	go.text = "VER PASSIVAS"
	go.font_px = 22
	go.size = Vector2(260, 58)
	go.position = Vector2(size.x * 0.5 - 130, center.y + 238)
	go.modulate.a = 0.0
	_pop.add_child(go)
	var tw := _pop.create_tween().set_parallel(true)
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_property(dim, "color:a", 0.82, 0.25)
	tw.tween_property(cv, "scale", Vector2.ONE * 2.2, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation", deg_to_rad(3.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(head, "modulate:a", 1.0, 0.25).set_delay(0.35)
	tw.tween_property(body, "modulate:a", 1.0, 0.25).set_delay(0.5)
	tw.tween_property(go, "modulate:a", 1.0, 0.25).set_delay(0.65)
	var close := func(open_gear: bool):
		if not is_instance_valid(_pop):
			return
		_pop.queue_free()
		_pop = null
		if open_gear:
			Knowledge.learned_now.clear()
			_gear_hero = hero
			show_screen("gear")
		else:
			_celebrate()  # próxima da fila, se tiver
	go.pressed.connect(func(): close.call(true))
	_pop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close.call(false))
