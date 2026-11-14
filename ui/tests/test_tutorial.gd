extends SceneTree
## Joga o tutorial inteiro sozinho e confere cada parte: exercícios (com erros de propósito),
## cartas ganhas, tela de cartas guiada, a prova do companheiro, o final e o save intocado.
## godot --headless --path . --script res://ui/tests/test_tutorial.gd -- --test
## Com janela (sem --headless) e "--shots", salva capturas em user://tuto_*.png.

var failed := 0
var passed := 0
var tut: Node
var results: Array = []
var shots := false
var shot_done := {}


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("ok   ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func shot(name: String) -> void:
	if not shots or shot_done.has(name):
		return
	shot_done[name] = true
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("user://tuto_%s.png" % name)


func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
		await process_frame


## Avança as falas até aparecer uma tentativa de jogador (ou até `until` ser verdade).
func advance(until: Callable, limit := 4000) -> bool:
	for i in limit:
		if until.call():
			return true
		if tut._waiting:
			tut._confirm()
			tut._confirm()
		await process_frame
	return false


func attempt_running() -> bool:
	return not tut.ex.is_empty() and not tut.ex["demo"]


func solve() -> void:
	var m: Unit = tut.ex["marked"]
	var o: Unit = tut.units[1 - m.idx]
	match tut.ex["kind"]:
		"stack": o.position = m.position + Vector3(0.8, 0, 0)
		"pair":
			for i in 2:
				tut.units[i].position = tut.DUMMY_POS[i] + Vector3(0.5, 0, 0.3)
		"spread", "link":
			tut.units[0].position = Vector3(-4.6, 0, -1.5)
			tut.units[1].position = Vector3(4.6, 0, -1.5)


func wait_result() -> Array:
	var n := results.size()
	for i in 6000:
		if results.size() > n:
			return results[n]
		await process_frame
	return [false, "timeout"]


func _initialize() -> void:
	shots = OS.get_cmdline_user_args().has("--shots")
	Engine.time_scale = 3.0 if shots else 10.0
	await process_frame
	# progresso "de verdade" que o tutorial não pode tocar
	Knowledge.owned = {"dodge": true, "mitigate": true}
	Knowledge.money = 123
	Knowledge.mastery = {"stack": 2}
	Knowledge.start_hero = 1
	Knowledge.equip(0, "mitigate")

	tut = load("res://tutorial.tscn").instantiate()
	root.add_child(tut)
	current_scene = tut
	tut.attempt_done.connect(func(ok: bool, why: String): results.append([ok, why]))
	await process_frame
	check(Knowledge.sandbox and not Knowledge.owned.has("mitigate"), "o tutorial começa com as cartas zeradas (sandbox)")
	check(tut.units.size() == 2 and tut.units[0].key == "assassina" and tut.units[1].key == "maga", "dois heróis: Assassina e Maga")
	check(tut.shop.texture != null, "a Shopkeeper está na arena com a arte dela")
	check(tut.talk_box.visible and tut._waiting, "ela começa falando e espera o jogador")
	await shot("intro")

	# trocar de herói: tecla e clique
	await key(KEY_TAB)
	check(tut.ctrl == 1, "TAB troca de herói")
	tut._set_ctrl(0)
	check(tut.ctrl == 0, "clicar no retrato troca de herói")

	# pause com o menu próprio do tutorial
	await key(KEY_ESCAPE)
	check(paused and tut.pause_menu.visible and tut.pause_menu._btns.size() == 3, "ESC pausa, com CONTINUAR / OPÇÕES / SAIR DO TUTORIAL")
	await key(KEY_ESCAPE)
	check(not paused, "ESC de novo continua")

	for kind in tut.ORDER:
		# demonstração antes do exercício
		var saw_demo := await advance(func(): return not tut.ex.is_empty() and tut.ex["demo"])
		check(saw_demo and tut.ex["kind"] == kind and tut.demo_tag.visible, "%s: tem demonstração antes" % kind)
		if kind == "stack":
			await create_timer(2.5, false).timeout
			await shot("demo_stack")
		var demo := await wait_result()
		check(demo[0], "%s: a demonstração resolve certo" % kind)

		# primeira tentativa: erra de propósito
		check(await advance(attempt_running), "%s: chega a vez do jogador" % kind)
		check(tut.ex["kind"] == kind, "%s: é o exercício certo" % kind)
		var comp_at: Vector3 = tut.units[1 - tut.ctrl].position
		if kind == "pair":
			for u in tut.units:
				u.position = tut.DUMMY_POS[0] + Vector3(0.4, 0, 0)
		var bad := await wait_result()
		check(not bad[0], "%s: sem fazer o certo, falha (%s)" % [kind, bad[1]])
		if kind == "stack":
			check(tut.units[1 - tut.ctrl].position.is_equal_approx(comp_at), "sem carta, o companheiro não anda sozinho")
		if kind == "pair":
			check(bad[1] == "same", "pair: dois no mesmo boneco é reconhecido")
		if kind == "link":
			check(bad[1] == "burn" and not tut.units[0].alive, "link: parado, queima até cair")
		check(tut.fails[kind] == 1 and tut.wins[kind] == 0, "%s: erro não conta como acerto" % kind)

		# segunda: a dica aparece e os heróis voltam de pé
		check(await advance(attempt_running), "%s: nova tentativa depois do erro" % kind)
		check(tut.units[0].alive and tut.units[1].alive, "%s: os dois estão de pé na nova tentativa" % kind)
		var hint: String = tut._fmt(tut.HINTS[kind][0])
		check(tut.talk_text.text == hint, "%s: mostra a primeira dica" % kind)
		# erra mais duas vezes: a dica fica mais direta e o anel azul aparece
		if kind == "pair":
			await wait_result()
			await advance(attempt_running)
			check(tut.talk_text.text == tut._fmt(tut.HINTS[kind][1]), "pair: segunda dica, mais direta")
			await wait_result()
			await advance(attempt_running)
			await process_frame
			check(tut.talk_text.text == tut._fmt(tut.HINTS[kind][2]) and tut.guides[0].visible and tut.guides[1].visible, "pair: terceira dica marca os lugares no chão")
			await shot("pair_guides")
		for n in tut.NEED:
			if n > 0:
				check(await advance(attempt_running), "%s: tentativa %d" % [kind, n + 1])
			solve()
			if kind == "spread" and n == 0:
				await shot("spread")
			var good := await wait_result()
			check(good[0], "%s: acerto %d" % [kind, n + 1])
		check(tut.wins[kind] == 3, "%s: três acertos" % kind)
		await advance(func(): return Knowledge.owned.has(tut.CARD[kind]))
		check(Knowledge.owned.has(tut.CARD[kind]), "%s: ganha a carta" % kind)
		if kind == "stack":
			await advance(func(): return tut.card_pop.visible)
			await shot("carta_nova")

	# ---- conversa e tela de cartas
	check(await advance(func(): return tut.cards != null), "depois das quatro mecânicas abre a tela de cartas")
	var cards: CardsScreen = tut.cards
	var hero: int = tut.units[tut.comp].hero
	check(cards.hero == hero and tut.comp != tut.ctrl, "o baralho aberto é o do companheiro")
	var hand: Array = cards._hand.duplicate()
	hand.sort()
	check(hand == ["link", "pair", "spread", "stack"], "só aparecem as cartas ganhas no tutorial: %s" % [hand])
	cards._go(0, 1)
	check(cards.hero == hero, "não dá pra trocar de herói na aula")
	await advance(func(): return not tut._waiting)
	await create_timer(1.0, false).timeout
	await shot("cartas")
	check(not Knowledge.has(hero, "stack"), "a carta não é colocada sozinha")
	var spoke: Dictionary = cards._spokes[cards._hand.find("stack")]
	check(spoke["cv"].halo, "a carta Laranja Junto está em destaque")
	cards._quick(spoke)
	check(not Knowledge.has(hero, "stack"), "duplo clique não equipa: tem que arrastar")
	# segurando a carta, os slots livres acendem
	cards._pend = {"info": spoke, "start": Vector2.ZERO, "shook": false}
	cards._start_drag(spoke)
	await process_frame
	await process_frame
	var lit := false
	for s in cards._slots:
		if s["kind"] == "white" and s["cv"].modulate != Color(1, 1, 1):
			lit = true
	check(lit, "arrastando a carta, os espaços válidos brilham")
	await shot("cartas_arrastando")
	cards._cancel_drag()
	# carta errada primeiro
	cards._drop_slot("white", 1, {"card": "pair", "from": "hand"})
	await create_timer(0.5, false).timeout
	check(tut.cards != null and tut.stage == "cards", "equipar outra carta não avança")
	cards._drop_slot("white", 0, {"card": "stack", "from": "hand"})
	for id in ["spread", "link"]:
		cards._drop_slot("white", 2 if id == "spread" else 3, {"card": id, "from": "hand"})
	await create_timer(0.6, false).timeout
	check(cards._hand.is_empty() and not cards._d_panel.visible, "sem carta na mão, o painel de detalhes some")
	check(cards._tutor_next.visible and tut._waiting, "a fala que espera mostra a etiqueta ENTER")
	await shot("cartas_perfeito")
	check(await advance(func(): return tut.cards == null), "com a Laranja Junto no companheiro, a aula segue")

	# ---- a prova
	check(await advance(attempt_running), "começa a prova")
	check(tut.stage == "test" and tut.lock_move and tut.lock_swap, "na prova o jogador não anda nem troca")
	check(tut.ex["marked"] == tut.units[tut.ctrl] and tut.ctrl != tut.comp, "a bola laranja está no herói do jogador")
	var me: Unit = tut.units[tut.ctrl]
	var at := me.position
	var before: int = tut.ctrl
	await key(KEY_TAB)
	Input.action_press("move_left")
	await create_timer(1.5, false).timeout
	await shot("prova")
	Input.action_release("move_left")
	check(tut.ctrl == before and me.position.is_equal_approx(at), "apertar andar e TAB não faz nada")
	var proof := await wait_result()
	check(proof[0], "o companheiro com a carta vem sozinho e resolve o stack")
	check(tut.units[tut.comp].position.distance_to(me.position) <= tut.STACK_R, "ele terminou dentro do círculo")

	# ---- final
	check(await advance(func(): return tut.stage == "black", 8000), "termina numa tela preta")
	for i in 3000:
		if tut._black_ready:
			break
		await process_frame
	check(tut.black.visible and is_equal_approx(tut.black.color.a, 1.0), "a tela fica toda preta")
	await shot("fim")
	await key(KEY_ENTER)
	for i in 10:
		await process_frame
	check(current_scene != tut and current_scene != null and current_scene.scene_file_path == "res://main.tscn", "ENTER volta pro jogo")
	check(not Knowledge.sandbox and Knowledge.screen == "tutorials", "volta pra lista de tutoriais")
	check(current_scene.hud.menus.tutorials.visible, "a lista de tutoriais está na tela")
	check(Knowledge.owned.has("mitigate") and not Knowledge.owned.has("pair") and Knowledge.money == 123, "as cartas de verdade voltam como estavam")
	check(Knowledge.mastery.get("stack", 0) == 2 and Knowledge.has(0, "mitigate") and Knowledge.start_hero == 1, "maestria, baralhos e herói inicial intocados")

	# ---- menu de tutoriais
	Engine.time_scale = 1.0
	var menus = current_scene.hud.menus
	await key(KEY_ESCAPE)
	check(menus.title.visible and not menus.tutorials.visible, "ESC na lista volta pro menu principal")
	menus.title.get_node("Stage/BtnTutorial").pressed.emit()
	await process_frame
	check(menus.tutorials.visible and not menus.title.visible, "TUTORIAL DO JOGO abre a lista de tutoriais")
	check(menus.tutorials.LIST[0]["name"] == "TUTORIAL 1" and menus.tutorials.LIST.size() > 1, "a lista tem o TUTORIAL 1 e lugares pros próximos")
	menus.tutorials._focus = 1
	menus.tutorials._go()
	await process_frame
	check(current_scene.scene_file_path == "res://main.tscn", "tutorial que ainda não existe não abre nada")
	menus.tutorials._focus = 0
	await key(KEY_ENTER)
	for i in 10:
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://tutorial.tscn", "ENTER no TUTORIAL 1 começa a aula")
	if shots:
		await create_timer(1.0).timeout
	current_scene._leave()
	for i in 10:
		await process_frame
	await shot("lista")

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
