extends SceneTree
## Teste do alternador CARTAS | GEAR (ui/kit/duo_toggle.gd) dentro do menu de verdade (menus.gd):
## clique de MOUSE na metade apagada troca de tela nos dois sentidos, TAB também, o herói é mantido
## e as cartas abertas pra uma luta continuam de luta depois de ir ao GEAR e voltar.
## Também confere a roleta em anel da tela de cartas (cartas trancadas de enfeite, giro que dá a volta).
## Não grava nada (Knowledge.persist = false):
##   godot --headless --path . --script res://ui/tests/test_toggle.gd

var failed := 0
var passed := 0


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("ok   ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Clique de verdade: o evento entra pelo Input e passa pelo GUI inteiro (quem estiver por cima come).
func mouse_click(canvas_at: Vector2) -> void:
	# sem janela (--headless) a raiz tem 64x64 e o palco é encolhido: converte pra coordenada de janela
	var at := root.get_final_transform() * canvas_at
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await frames(2)


func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await frames(2)


## Ponto no meio da metade apagada (a clicável) do alternador, em coordenadas do canvas.
func other_half(toggle: Control) -> Vector2:
	var x := toggle.size.x - 44.0 if toggle.active == 0 else 44.0
	return toggle.get_global_transform() * Vector2(x, toggle.size.y * 0.5)


func _initialize() -> void:
	Knowledge.persist = false
	await process_frame
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(3)
	var menus = main.hud.menus
	Knowledge.party = [0, 1, 2, 3]
	Knowledge.owned["stack"] = true
	var before := JSON.stringify([Knowledge.owned, Knowledge.mastery, Knowledge.fresh])

	# ---------------------------------------------------------------- cartas abertas pelo botão CARTAS (sem luta)
	menus._gear = true
	menus._cards_hero = 2
	menus.show_screen("cards")
	await frames(3)
	var cards = menus.cards
	var gear = menus.gear_screen
	check(cards.visible and cards.hero == 2 and not cards._ready_btn.visible, "cartas abertas sem luta, na Assassina")
	check(cards._toggle.active == 0 and not cards._toggle.solo and not cards._boss.visible, "o título é o alternador, com CARTAS ativa (e sem a etiqueta rosa que parecia botão)")
	await mouse_click(other_half(cards._toggle))
	await frames(2)
	check(gear.visible and not cards.visible, "clique de mouse na metade GEAR abre a tela GEAR")
	check(gear.hero == 2, "no mesmo herói")
	check(gear._toggle.active == 1 and gear._toggle.position == cards._toggle.position and gear._toggle.size == cards._toggle.size, "lá o alternador está no mesmo lugar, com GEAR ativa")
	await mouse_click(other_half(gear._toggle))
	await frames(2)
	check(cards.visible and not gear.visible and cards.hero == 2 and not cards._ready_btn.visible, "clique na metade CARTAS volta pras cartas, ainda sem luta")
	await key(KEY_TAB)
	check(gear.visible and gear.hero == 2, "TAB nas cartas vira pro GEAR")
	gear._switch(1)
	var seen: int = gear.hero
	await key(KEY_TAB)
	check(cards.visible and not gear.visible, "TAB no GEAR vira pras cartas")
	check(cards.hero == seen or not Knowledge.party.has(seen), "levando o herói que estava sendo visto (se ele é da party)")

	# ---------------------------------------------------------------- cartas no caminho de uma luta
	menus._gear = false
	menus._cards_hero = 0
	menus.show_screen("cards")
	await frames(3)
	check(cards._ready_btn.visible and cards._boss.visible, "cartas de luta: botão de luta e etiqueta da boss")
	await mouse_click(other_half(cards._toggle))
	check(gear.visible, "das cartas de luta também dá pra ir ao GEAR")
	await mouse_click(other_half(gear._toggle))
	check(cards.visible and cards._ready_btn.visible, "e a volta mantém o botão de luta")
	cards.back_pressed.emit()
	await frames(2)

	# ---------------------------------------------------------------- roleta em anel
	menus._gear = true
	menus._cards_hero = 0
	menus.show_screen("cards")
	await frames(3)
	var n: int = cards._hand.size()
	check(cards._spokes.size() == n and cards._ring == maxi(n, cards.RING_MIN) and cards._fillers.size() == cards._ring - n, "o anel tem as cartas da mão e, se faltar, trancadas de enfeite (%d + %d)" % [n, cards._fillers.size()])
	var left := 0
	var right := 0
	for info in cards._spokes + cards._fillers:
		if info["spoke"].visible:
			if info["spoke"].rotation < -0.01:
				left += 1
			elif info["spoke"].rotation > 0.01:
				right += 1
	check(left >= 3 and right >= 3, "a carta em foco tem companhia dos dois lados (%d à esquerda, %d à direita)" % [left, right])
	cards._set_focus(n - 1)
	cards._spin(1)
	check(cards._focus == 0, "da última carta, girar pra frente dá a volta até a primeira")
	cards._spin(-1)
	check(cards._focus == n - 1, "e pra trás, da primeira volta pra última")
	await create_timer(0.9).timeout
	check(is_equal_approx(cards._spokes[cards._focus]["spoke"].rotation, 0.0), "a carta em foco para no topo da roleta")

	# mão pequena (como na aula): o anel é completado com trancadas, que não são cartas
	cards.tutor = {"card": "stack", "art": "res://assets/portraits/tank_art.webp"}
	cards.open(0, false)
	await frames(3)
	n = cards._hand.size()
	check(n < cards.RING_MIN and cards._fillers.size() == cards.RING_MIN - n, "mão pequena: %d cartas + %d trancadas fecham o anel" % [n, cards._fillers.size()])
	var inert := true
	for fl in cards._fillers:
		if fl["cv"].mouse_filter != Control.MOUSE_FILTER_IGNORE or fl["spoke"].mouse_filter != Control.MOUSE_FILTER_IGNORE or fl.has("id"):
			inert = false
	check(inert, "as trancadas não recebem mouse nem têm id de carta")
	for k in n + 2:
		cards._spin(1)
		check(cards._focus >= 0 and cards._focus < n, "girar nunca para numa trancada (foco %d)" % cards._focus)
	check(cards._toggle.solo, "na aula o alternador vira só o título")
	await key(KEY_TAB)
	check(cards.visible and not gear.visible, "e TAB não sai da aula")
	cards.tutor = {}
	check(JSON.stringify([Knowledge.owned, Knowledge.mastery, Knowledge.fresh]) == before, "nada disso mexeu no que o jogador tem (cartas, maestria, avisos)")

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
