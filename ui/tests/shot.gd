extends Control
## Abre uma tela sozinha e salva uma captura: godot res://ui/tests/shot.tscn -- --scene=title --wait=1.2
## Extras: --rich (moedas e ticket), --known (todas as cartas), --hero=N, --dialog (loja: abre a confirmação).

func _ready() -> void:
	Knowledge.persist = false
	var which := "title"
	var wait := 1.2
	var hero := 0
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--scene="):
			which = a.trim_prefix("--scene=")
		if a.begins_with("--wait="):
			wait = float(a.trim_prefix("--wait="))
		if a.begins_with("--hero="):
			hero = int(a.trim_prefix("--hero="))
	if args.has("--rich"):
		Knowledge.money = 500
		Knowledge.tickets = 1
		Knowledge.shop_unlocked = true
		Knowledge.best_rank = {0: 8, 1: 6}
	if args.has("--known"):
		for id in Knowledge.CARDS:
			Knowledge.owned[id] = true
	if args.has("--some"):
		for id in ["stack", "pair", "mitigate", "provoke", "instinct", "sharpen", "potion", "revive", "eshield"]:
			Knowledge.owned[id] = true
		Knowledge.dps_known["tank"] = true
		Knowledge.mastery["link"] = 2
		Knowledge.mastery["spread"] = 1
		for id in ["stack", "mitigate", "potion"]:
			Knowledge.equip(hero, id)
	var scene: Control = load("res://ui/screens/%s_screen.tscn" % which).instantiate()
	add_child(scene)
	if which == "cards":
		scene.open(hero)
	else:
		scene.open()
	if args.has("--dialog"):
		scene._select("eshield")
		scene._open_dialog()
	if args.has("--buy"):
		print("antes: moedas=", Knowledge.money, " tem=", Knowledge.owned.has("eshield"))
		scene._select("eshield")
		print("comprou=", scene.confirm_buy(), " moedas=", Knowledge.money, " tem=", Knowledge.owned.has("eshield"))
	if args.has("--drag"):
		# o mesmo caminho que soltar uma carta num slot usa
		scene._drop_slot("white", 2, {"card": "pair", "from": "hand"})
		scene._drop_slot("white", 0, {"card": "pair", "from": "slot"})
		print("brancas=", Knowledge.deck(hero)["white"])
		scene._drop_hand(Vector2.ZERO, {"card": "pair", "from": "slot"})
		print("depois de tirar=", Knowledge.deck(hero)["white"], " mão=", Knowledge.inventory(hero))
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png("user://screen.png")
	get_tree().quit()
