extends Control
## Liga as telas de menu entre si e com a luta:
##   título -> PLAY -> saves -> cafeteria (cena lobby.tscn: monta a party) -> bosses -> cartas -> luta
##   título -> gear (cartas do save ativo, sem o botão de luta)
##   vitória -> loja -> título
##   título -> tutoriais -> (cena do tutorial) -> tutoriais
##   título -> opções (a tela de opções é do hud.gd: é a mesma que o pause abre)
## Cada tela é uma cena própria em ui/screens/, que também abre sozinha com F6.

var g
var title: TitleScreen
var bosses: BossScreen
var cards: CardsScreen
var shop: ShopScreen
var tutorials: TutorialsScreen
var saves: SavesScreen
var _gear := false


func setup(game) -> void:
	g = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = preload("res://ui/screens/title_screen.tscn").instantiate()
	bosses = preload("res://ui/screens/boss_screen.tscn").instantiate()
	cards = preload("res://ui/screens/cards_screen.tscn").instantiate()
	shop = preload("res://ui/screens/shop_screen.tscn").instantiate()
	tutorials = TutorialsScreen.new()
	saves = SavesScreen.new()
	for s in [title, bosses, cards, shop, tutorials, saves]:
		add_child(s)
		s.visible = false
	title.play_pressed.connect(show_screen.bind("saves"))
	saves.back_pressed.connect(show_screen.bind("title"))
	saves.slot_chosen.connect(func(n: int):
		# carrega (ou cria) o save e vai pra cafeteria montar a party; os bosses só abrem depois dela
		Knowledge.select_slot(n)
		get_tree().change_scene_to_file("res://lobby.tscn"))
	title.gear_pressed.connect(func():
		if Knowledge.slot <= 0 and Knowledge.persist:
			show_screen("saves")  # as cartas são de um save: sem save escolhido, primeiro escolhe um
			return
		_gear = true
		show_screen("cards"))
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
		if i != Knowledge.boss:
			g.select_boss(i)  # recarrega a cena já na tela de cartas
		else:
			show_screen("cards"))
	cards.back_pressed.connect(func(): show_screen("title" if _gear else "bosses"))
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
	for s in [title, bosses, cards, shop, tutorials, saves]:
		s.visible = false
	match id:
		"bosses":
			bosses.visible = true
			bosses.open()
		"cards":
			cards.visible = true
			cards.open(Knowledge.start_hero, not _gear)
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
