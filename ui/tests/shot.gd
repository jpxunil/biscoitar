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
	if which == "cards":
		for a in args:
			# --act=spin:2,sel:9,drag:hand:1:white:2,drag:slot:white:0:wheel,hover:hand:1 (em ordem, depois da entrada)
			if a.begins_with("--act="):
				await get_tree().create_timer(1.0).timeout
				for step in a.trim_prefix("--act=").split(","):
					var p := step.split(":")
					match p[0]:
						"go":
							# troca de herói e espera p[2] segundos (pra capturar a animação no meio)
							scene._go(int(p[1]), 1)
							await get_tree().create_timer(float(p[2])).timeout
							get_viewport().get_texture().get_image().save_png("user://screen.png")
							get_tree().quit()
							return
						"spin":
							scene._set_focus(scene._focus + int(p[1]))
						"sel":
							scene._sel = int(p[1])
							scene._settle_all()
							scene._update_details()
						"hover":
							var list: Array = scene._spokes if p[1] == "hand" else scene._slots
							list[int(p[2])]["hover"] = true
							scene._settle(list[int(p[2])])
						"hold":
							# começa a arrastar a carta k da mão e para em cima do slot si, sem soltar
							var info: Dictionary = scene._spokes[int(p[1])]
							scene._pend = {"info": info, "start": Vector2.ZERO}
							scene._start_drag(info)
							scene._over = int(p[2])
							scene._ghost.position = scene._slots[int(p[2])]["home"] + Vector2(30, 20)
							scene._settle_all()
						"mdrag", "mclick":
							# mouse de verdade: aperta em (x1,y1), arrasta até (x2,y2) em passos e solta
							var m0 := Vector2(float(p[1]), float(p[2]))
							var m1 := Vector2(float(p[3]), float(p[4])) if p[0] == "mdrag" else m0
							_mouse_move(m0)
							await get_tree().process_frame
							await get_tree().process_frame
							_mouse_button(m0, true)
							await get_tree().process_frame
							for n in 8:
								_mouse_move(m0.lerp(m1, (n + 1) / 8.0))
								await get_tree().process_frame
							if p.size() > 5 and p[5] == "hold":
								continue
							_mouse_button(m1, false)
							await get_tree().process_frame
							print("deck=", Knowledge.deck(scene.hero), " foco=", scene._focus, " sel=", scene._sel, " mão=", scene._hand.slice(0, 6))
						"equip":
							scene._pend = {"info": scene._spokes[int(p[1])], "start": Vector2.ZERO}
							scene._equip_from_hand(int(p[1]), int(p[2]))
							scene._cancel_drag()
							scene._sync_hand()
							scene._build_cards(false, "s" + p[2])
					await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png("user://screen.png")
	get_tree().quit()


func _mouse_move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)


func _mouse_button(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
