extends Control
## Liga as telas de menu entre si e com a luta:
##   título -> PLAY -> saves -> cafeteria (cena lobby.tscn: monta a party) -> bosses -> cartas -> luta
##   bosses -> CARTAS (gear: as cartas do save ativo, sem o botão de luta) -> bosses
##   bosses -> TREINO LIVRE (dummy) -> cartas -> luta sem progresso
##   vitória -> loja -> título
##   título -> tutoriais -> (cena do tutorial) -> tutoriais
##   título -> SKILLS (consulta das habilidades de todos os personagens) -> título
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
var _gear := false
var _skills_from_cards := false
var _skills_hero := -1
var _cards_hero := -1


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
	for s in [title, bosses, cards, shop, tutorials, saves, skills]:
		add_child(s)
		s.visible = false
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
	title.shop_pressed.connect(func(): show_screen("saves" if (Knowledge.slot <= 0 and Knowledge.persist) else "shop"))
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
	shop.back_pressed.connect(show_screen.bind("title"))
	visible = false


func set_open(on: bool) -> void:
	visible = on
	if on:
		show_screen(Knowledge.screen)


func show_screen(id: String) -> void:
	if id == "shop" and not Knowledge.shop_unlocked:
		id = "title"
	Knowledge.screen = id
	# os bosses e as cartas de luta só existem com um save e uma party de quatro
	if id == "bosses" and Knowledge.persist and (Knowledge.slot <= 0 or not Knowledge.party_ready()):
		id = "saves"
	for s in [title, bosses, cards, shop, tutorials, saves, skills]:
		s.visible = false
	match id:
		"skills":
			skills.visible = true
			skills.open(_skills_hero if _skills_hero >= 0 else Knowledge.start_hero)
			_skills_hero = -1
		"bosses":
			bosses.visible = true
			bosses.open()
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
