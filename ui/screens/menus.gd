extends Control
## Liga as telas de menu entre si e com a luta:
##   título -> bosses -> cartas -> luta      título -> gear (cartas, sem o botão de luta)
##   vitória -> loja -> título
##   título -> opções (a tela de opções é do hud.gd: é a mesma que o pause abre)
## Cada tela é uma cena própria em ui/screens/, que também abre sozinha com F6.

var g
var title: TitleScreen
var bosses: BossScreen
var cards: CardsScreen
var shop: ShopScreen
var _gear := false


func setup(game) -> void:
	g = game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = preload("res://ui/screens/title_screen.tscn").instantiate()
	bosses = preload("res://ui/screens/boss_screen.tscn").instantiate()
	cards = preload("res://ui/screens/cards_screen.tscn").instantiate()
	shop = preload("res://ui/screens/shop_screen.tscn").instantiate()
	for s in [title, bosses, cards, shop]:
		add_child(s)
		s.visible = false
	title.bosses_pressed.connect(show_screen.bind("bosses"))
	title.gear_pressed.connect(func():
		_gear = true
		show_screen("cards"))
	title.shop_pressed.connect(show_screen.bind("shop"))
	title.options_pressed.connect(func(): g.hud.open_options(false))
	title.tutorial_pressed.connect(func():
		# o tutorial é uma cena própria (scripts/tutorial.gd); ele volta pra cá sozinho quando acaba
		Knowledge.save()
		get_tree().change_scene_to_file("res://tutorial.tscn"))
	bosses.back_pressed.connect(show_screen.bind("title"))
	bosses.boss_chosen.connect(func(i: int):
		_gear = false
		if i != Knowledge.boss:
			g.select_boss(i)  # recarrega a cena já na tela de cartas
		else:
			show_screen("cards"))
	cards.back_pressed.connect(func(): show_screen("title" if _gear else "bosses"))
	cards.ready_pressed.connect(func():
		# trocar de tank recarrega a cena; aí a luta começa sozinha
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
	for s in [title, bosses, cards, shop]:
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
		_:
			_gear = false
			title.visible = true
			title.open()
