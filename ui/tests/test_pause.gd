extends SceneTree
## Teste do menu de pause: ESC abre/fecha, a luta congela, e as opções levam pra tela certa.
## godot --headless --path . --script res://ui/tests/test_pause.gd -- --test   (o argumento desliga o save)

var failed := 0
var passed := 0


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("ok   ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)
	await process_frame
	await process_frame


func _initialize() -> void:
	await process_frame
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.start_fight()
	# espera a vinheta de entrada acabar: antes disso fight_time não anda
	while main.intro_left > 0.0:
		await process_frame
	for i in 5:
		await process_frame

	await key(KEY_ESCAPE)
	check(paused, "ESC na luta congela a árvore")
	check(main.hud.pause.visible, "ESC mostra o menu de pause")
	var t0: float = main.fight_time
	for i in 20:
		await process_frame
	check(is_equal_approx(main.fight_time, t0), "o tempo da luta para enquanto pausado")

	await key(KEY_ESCAPE)
	check(not paused, "ESC de novo despausa")
	check(not main.hud.pause.visible, "ESC de novo esconde o menu")
	for i in 5:
		await process_frame
	check(main.fight_time > t0, "a luta volta a andar depois do pause")

	# clique no CONTINUAR
	main.pause()
	main.hud.pause._btns[0].pressed.emit()
	check(not paused and not main.hud.pause.visible, "botão CONTINUAR volta pra luta")

	# navegação por teclado até MENU PRINCIPAL
	var tries: int = Knowledge.attempts
	await key(KEY_ESCAPE)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	check(main.hud.pause._focus == 4, "↓↓↓↓ chega em MENU PRINCIPAL")
	await key(KEY_ENTER)
	check(not paused, "sair da luta desliga o pause")
	check(Knowledge.screen == "title", "MENU PRINCIPAL abre a tela inicial (screen=%s)" % Knowledge.screen)
	check(Knowledge.attempts == tries + 1, "sair conta como mais uma tentativa")
	for i in 5:
		await process_frame
	var fresh: Node = current_scene
	check(fresh != null and fresh != main, "a cena recarregou")
	if fresh:
		check(fresh.prep, "cena nova abre nos menus (prep)")
		check(fresh.hud.menus.title.visible, "tela inicial está visível")
		# SELEÇÃO DE CARTAS
		fresh.start_fight()
		for i in 5:
			await process_frame
		fresh.pause()
		fresh.hud.pause._btns[3].pressed.emit()
		for i in 5:
			await process_frame
		var third: Node = current_scene
		check(Knowledge.screen == "cards", "SELEÇÃO DE CARTAS abre as cartas (screen=%s)" % Knowledge.screen)
		check(third != null and third.hud.menus.cards.visible, "tela de cartas está visível")
		check(not paused, "cena nova não nasce pausada")
		# ESC nos menus (prep) não abre o pause
		await key(KEY_ESCAPE)
		check(not paused, "ESC na tela de cartas não pausa")

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
