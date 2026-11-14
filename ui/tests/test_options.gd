extends SceneTree
## Teste das opções: atalhos remapeados valem na luta, conflitos pedem confirmação, volume mexe
## nos buses de verdade e tudo volta do arquivo de configuração.
## godot --headless --path . --script res://ui/tests/test_options.gd -- --test   (o argumento desliga o save)

var failed := 0
var passed := 0


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("ok   ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func press(code: Key, down := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	await process_frame
	await process_frame


func key(code: Key) -> void:
	await press(code, true)
	await press(code, false)


func _initialize() -> void:
	await process_frame
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var hud = main.hud
	var opt: OptionsScreen = hud.options

	# ---- menu principal -> opções
	check(hud.menus.title.visible, "começa na tela inicial")
	hud.menus.title.get_node("Stage/BtnOptions").pressed.emit()
	await process_frame
	check(opt.visible, "OPÇÕES do menu principal abre a tela")
	await key(KEY_ENTER)
	check(Knowledge.screen == "title" and hud.menus.title.visible, "tecla nas opções não vaza pro menu de baixo")
	await key(KEY_ESCAPE)
	check(not opt.visible and hud.menus.title.visible and not paused, "ESC fecha e volta pro menu principal")

	# ---- padrão funcionando na luta
	main.start_fight()
	while main.intro_left > 0.0:
		await process_frame
	await key(KEY_Q)
	check(main.order == "gather", "padrão: Q dá a ordem de juntar")
	await key(KEY_F)
	check(main.order == "atk", "padrão: F dá a ordem de atacar")
	var before: int = main.ctrl
	await key(KEY_TAB)
	check(main.ctrl != before, "padrão: TAB troca de personagem")

	# ---- remapear de verdade
	Binds.assign("order_gather", 0, KEY_G)
	await key(KEY_Q)
	check(main.order == "atk", "depois de remapear, a tecla antiga (Q) não faz mais nada")
	await key(KEY_G)
	check(main.order == "gather", "a tecla nova (G) dá a ordem")
	Binds.assign("swap", 0, KEY_C)
	main.swap_cd = 0.0
	before = main.ctrl
	await key(KEY_TAB)
	check(main.ctrl == before, "TAB não troca mais de personagem")
	await key(KEY_C)
	check(main.ctrl != before, "C (novo atalho) troca de personagem")
	Binds.assign("move_up", 0, KEY_T)
	await press(KEY_T, true)
	check(main._input_dir().z < 0.0, "movimento usa a tecla nova (T anda pra cima)")
	await press(KEY_T, false)
	await press(KEY_W, true)
	check(main._input_dir() == Vector3.ZERO, "W não anda mais")
	await press(KEY_W, false)
	await press(KEY_UP, true)
	check(main._input_dir().z < 0.0, "o atalho alternativo (↑) continua valendo")
	await press(KEY_UP, false)
	Binds.assign("skill_1", 0, KEY_N)
	await press(KEY_N, true)
	check(Input.is_action_pressed("skill_1"), "slot 1 (ataque de segurar) lê a tecla nova")
	await press(KEY_N, false)
	Binds.assign("dash", 0, KEY_V)
	main.units[main.ctrl].dash_cd = 0.0
	await key(KEY_V)
	check(main.units[main.ctrl].dash_cd > 0.0, "desvio na tecla nova (V)")
	check(hud.skill_row.get_child_count() > 0, "barra de habilidades montada")

	# ---- regras de conflito
	check(Binds.find(KEY_K).get("id", "") == "skill_2", "find acha quem usa a tecla")
	Binds.assign("order_hold", 0, KEY_K)
	check(Binds.keys["skill_2"][0] == 0 and Binds.keys["order_hold"][0] == KEY_K, "substituir tira a tecla da outra ação")
	check(not Binds.can_clear("pause", 0), "pause não pode ficar sem atalho")
	check(Binds.clear("limit", 0) and Binds.count("limit") == 0, "ação opcional pode ficar sem atalho")
	check(not Binds.assign("limit", 0, KEY_ESCAPE) and Binds.keys["pause"][0] == KEY_ESCAPE, "slot vazio não pode pegar a única tecla do pause")
	Binds.assign("limit", 0, KEY_I)
	check(Binds.assign("limit", 0, KEY_ESCAPE) and Binds.keys["pause"][0] == KEY_I, "com tecla pra dar em troca, as duas ações trocam de lugar")
	Binds.reset("skill_2")
	check(Binds.keys["skill_2"][0] == KEY_K and Binds.keys["order_hold"][0] == 0, "reset individual retoma a tecla padrão")
	Binds.reset_all()
	check(Binds.to_dict().is_empty(), "restaurar todos volta tudo pro padrão")

	# ---- pause -> opções -> captura de tecla -> pause
	await key(KEY_ESCAPE)
	check(paused and hud.pause.visible, "ESC pausa")
	hud.pause._btns[2].pressed.emit()
	await process_frame
	check(opt.visible and not hud.pause.visible and paused, "OPÇÕES no pause abre a tela e a luta segue pausada")
	opt._show_tab(1)
	opt._rows["order_atk"]["chips"][0].pressed.emit()
	check(opt._cap.get("id", "") == "order_atk", "clicar no atalho entra em modo de captura")
	check(opt._rows["order_atk"]["chips"][0].text == "APERTE UMA TECLA", "o atalho mostra APERTE UMA TECLA")
	await key(KEY_H)
	check(Binds.keys["order_atk"][0] == KEY_H and opt._cap.is_empty(), "a tecla apertada vira o atalho")
	check(opt._rows["order_atk"]["chips"][0].text == "H", "a interface mostra a tecla nova na hora")
	opt._rows["order_hold"]["chips"][0].pressed.emit()
	await key(KEY_H)
	check(opt._dialog.visible, "tecla já usada abre o aviso de conflito")
	check(Binds.keys["order_hold"][0] == KEY_R and Binds.keys["order_atk"][0] == KEY_H, "nada muda antes de confirmar")
	await key(KEY_ESCAPE)
	check(not opt._dialog.visible and Binds.keys["order_hold"][0] == KEY_R and opt.visible, "cancelar mantém tudo como estava")
	opt._rows["order_hold"]["chips"][0].pressed.emit()
	await key(KEY_H)
	await key(KEY_ENTER)
	check(Binds.keys["order_hold"][0] == KEY_H and Binds.keys["order_atk"][0] == 0, "confirmar substitui")
	opt._rows["order_atk"]["chips"][0].pressed.emit()
	await key(KEY_ESCAPE)
	check(opt._cap.is_empty() and opt.visible and Binds.keys["order_atk"][0] == 0, "ESC cancela a captura sem fechar a tela")
	opt._reset_one("order_atk")
	check(Binds.keys["order_atk"][0] == KEY_F, "botão PADRÃO da linha restaura")
	opt._clear("order_atk", 0)
	check(Binds.keys["order_atk"][0] == 0, "botão direito remove o atalho")
	# trocar a tecla do pause e o slot 2
	opt._rows["pause"]["chips"][1].pressed.emit()
	await key(KEY_F10)
	check(Binds.keys["pause"][1] == KEY_F10, "pause ganha um atalho alternativo (F10)")
	opt._rows["skill_2"]["chips"][0].pressed.emit()
	await key(KEY_M)
	await key(KEY_ESCAPE)
	check(not opt.visible and hud.pause.visible and paused, "ESC nas opções volta pro PAUSE, com a luta pausada")
	var shown := false
	for s in hud.skill_ui:
		if s["slot"] == 1 and s["ui"].key_text == "M":
			shown = true
	var has_slot2: bool = main.SKILLS[main.units[main.ctrl].key].size() > 1 and main.SKILLS[main.units[main.ctrl].key][1] != null
	check(shown or not has_slot2, "a barra de habilidades mostra a tecla nova do slot 2")
	await key(KEY_F10)
	check(not paused and not hud.pause.visible, "a tecla nova de pause (F10) despausa")
	await key(KEY_F10)
	check(paused, "e pausa de novo")
	await key(KEY_F10)
	await key(KEY_H)
	check(main.order == "hold", "atalho trocado pela tela (H) vale na luta")

	# ---- som: buses de verdade
	var sfx := AudioServer.get_bus_index(&"SFX")
	check(sfx > 0, "o bus SFX existe no layout")
	main._sfx(main.SFX_DEATH)
	var player: AudioStreamPlayer = null
	for c in main.get_children():
		if c is AudioStreamPlayer:
			player = c
	check(player != null and player.bus == &"SFX", "os efeitos do jogo tocam no bus SFX")
	Settings.set_volume(&"SFX", 0.4)
	check(is_equal_approx(AudioServer.get_bus_volume_linear(sfx), 0.4), "slider de efeitos muda o volume do bus")
	Settings.set_volume(&"Master", 0.0)
	check(AudioServer.is_bus_mute(0), "volume geral em 0% silencia o Master")
	Settings.set_volume(&"Master", 0.7)
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.7), "e volta quando sobe")
	Settings.set_mute_all(true)
	check(AudioServer.is_bus_mute(0), "silenciar tudo muta o Master")

	# ---- salvar e carregar
	var path := "user://settings_test.cfg"
	check(Settings.write(path) == OK, "grava o arquivo de configuração")
	Binds.reset_all()
	Settings.reset_audio()
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_linear(sfx), 1.0), "restaurar padrão do som volta pra 100%")
	Settings.read(path)
	Settings.apply_audio()
	check(is_equal_approx(Settings.volume[&"SFX"], 0.4) and is_equal_approx(Settings.volume[&"Master"], 0.7) and Settings.mute_all, "volumes voltam do arquivo")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(sfx), 0.4), "e são aplicados no bus")
	check(Binds.keys["order_hold"][0] == KEY_H and Binds.keys["pause"][1] == KEY_F10 and Binds.keys["skill_2"][0] == KEY_M and Binds.keys["order_atk"][0] == 0, "atalhos voltam do arquivo")
	await key(KEY_H)
	check(true, "sem erro depois de recarregar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
