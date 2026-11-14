extends SceneTree
## Teste do fluxo novo de entrada: PLAY -> saves -> cafeteria (party de 4) -> bosses -> cartas -> luta.
## Usa uma pasta de saves só do teste (user://test_saves/): o progresso do jogador não é tocado.
## Rodar SEM argumentos depois de "--" (argumento de teste desliga o save, e aqui o save é o assunto):
##   godot --headless --path . --script res://ui/tests/test_party.gd

const DIR := "user://test_saves/"

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


func frames(n: int) -> void:
	for i in n:
		await process_frame


func clean() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))


## Foca o herói `hero` na cafeteria e confirma a entrada dele na party.
func add(lobby: Node, hero: int) -> void:
	for k in lobby.figs.size():
		if lobby.figs[k].hero == hero:
			lobby._set_focus(k)
	lobby.card_btn.pressed.emit()
	await key(KEY_ENTER)


func _initialize() -> void:
	Knowledge.save_dir = DIR
	clean()
	# um save do formato antigo (arquivo único), como o que o jogador tem hoje
	var old := FileAccess.open(DIR + "save.json", FileAccess.WRITE)
	old.store_string(JSON.stringify({"owned": ["dodge", "stack"], "money": 77, "tickets": 1, "tank": 4, "hero": 2, "rank": {"1": 6}, "decks": {}}))
	old.close()
	await process_frame

	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(3)
	var menus = main.hud.menus
	check(Knowledge.slot_exists(1) and FileAccess.file_exists(DIR + "save.json"), "o save antigo vira o SAVE 1 (e o arquivo antigo fica de cópia)")
	check(Knowledge.slot == 0, "sem save escolhido ao abrir o jogo pela primeira vez")
	check(menus.title.visible and menus.title.get_node("Stage/BtnPlay").text == "JOGAR" and not menus.title.has_node("Stage/BtnBosses"), "menu principal: JOGAR no lugar de BOSSES")

	menus.show_screen("bosses")
	check(not menus.bosses.visible and menus.saves.visible, "sem save e party, os bosses não abrem (cai nos saves)")
	menus.show_screen("title")
	menus.title.get_node("Stage/BtnPlay").pressed.emit()
	await frames(2)
	check(menus.saves.visible, "PLAY abre a seleção de saves")
	check(menus.saves._rows.size() == 4, "quatro slots de save")
	check(not menus.saves._info[0].is_empty() and menus.saves._info[0]["money"] == 77, "o SAVE 1 mostra o progresso antigo")
	check(menus.saves._info[1].is_empty() and menus.saves._info[3].is_empty(), "os outros slots estão vazios")

	# ---- save novo no slot 2 -> cafeteria
	menus.saves._focus = 1
	menus.saves._mark()
	check(menus.saves._play.text == "CRIAR", "slot vazio: o botão cria o save")
	await key(KEY_ENTER)
	await frames(6)
	var lobby: Node = current_scene
	check(lobby != null and lobby.scene_file_path == "res://lobby.tscn", "escolher o save leva pra cafeteria")
	check(Knowledge.slot == 2 and Knowledge.slot_exists(2), "o save 2 foi criado")
	check(Knowledge.money == 0 and not Knowledge.owned.has("stack"), "save novo não herda cartas nem moedas do save 1")
	check(lobby.figs.size() == Knowledge.HEROES.size(), "todos os heróis estão na cafeteria (%d)" % lobby.figs.size())
	check(lobby.figs.size() >= 7, "incluindo as classes novas (Soulburner e Ringstar)")
	check(lobby.team.is_empty() and lobby.ready_btn.disabled, "os quatro lugares começam vazios e READY TO PLAY bloqueado")
	check(lobby.focus == -1 and not lobby.card.visible, "ninguém em foco no começo")
	var where := {}
	var first_spots: Array = []
	for u in lobby.figs:
		where[u.position] = true
		first_spots.append(u.position)
	check(where.size() == lobby.figs.size(), "cada herói num lugar diferente do salão")

	# ---- navegação espacial, com os heróis em lugares conhecidos
	#        C (fundo)
	#   A    B    D
	#        E (frente)
	# o desenho abaixo usa cinco heróis: os outros saem do salão só pra esta parte do teste
	var everyone: int = lobby.figs.size()
	for k in range(5, lobby.figs.size()):
		lobby.figs[k].visible = false
	lobby.figs.resize(5)
	lobby.marks.resize(5)
	var a: Unit = lobby.figs[0]
	var b: Unit = lobby.figs[1]
	var c: Unit = lobby.figs[2]
	var d: Unit = lobby.figs[3]
	var e: Unit = lobby.figs[4]
	a.position = Vector3(-4, 0, 0)
	b.position = Vector3(0, 0, 0)
	c.position = Vector3(0, 0, -4)
	d.position = Vector3(4, 0, 0)
	e.position = Vector3(0, 0, 3)
	await frames(2)
	await key(KEY_RIGHT)
	check(lobby.focus == 1, "sem foco, a primeira seta foca quem está mais perto do centro da tela")
	check(lobby.card.visible and lobby.card_name.text == b.unit_name.to_upper(), "a ficha mostra o herói em foco")
	check(lobby.team.is_empty(), "focar não põe ninguém na party")
	lobby._set_focus(0)
	await key(KEY_RIGHT)
	check(lobby.focus == 1, "→ em A vai pro B (o mais próximo à direita), não pro C nem pro D")
	await key(KEY_UP)
	check(lobby.focus == 2, "↑ em B vai pro C, que está atrás")
	await key(KEY_UP)
	check(lobby.focus == 2, "↑ de novo: não tem ninguém pra lá, o foco não muda")
	await key(KEY_DOWN)
	check(lobby.focus == 1, "↓ volta pro B")
	await key(KEY_DOWN)
	check(lobby.focus == 4, "↓ em B vai pro E, que está na frente")
	lobby._set_focus(1)
	await key(KEY_RIGHT)
	check(lobby.focus == 3, "→ em B vai pro D")
	await key(KEY_RIGHT)
	check(lobby.focus == 3, "→ em D: ninguém à direita, não pula pro outro lado")
	await key(KEY_LEFT)
	await key(KEY_LEFT)
	check(lobby.focus == 0, "← ← volta até o A")
	await key(KEY_LEFT)
	check(lobby.focus == 0, "← no A: ninguém à esquerda, fica")

	# ---- mouse
	var at: Vector2 = lobby._screen(3)
	check(lobby._pick(at) == 3 and lobby._pick(Vector2(4, 4)) == -1, "clique: acerta o herói embaixo do ponteiro, e nada no vazio")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	click.global_position = at
	lobby._unhandled_input(click)
	check(lobby.focus == 3, "clicar num herói foca nele")

	# ---- escolher e confirmar
	lobby.card_btn.pressed.emit()
	check(lobby.dialog.visible and lobby.team.is_empty(), "SELECT FOR PARTY pede confirmação antes de adicionar")
	await key(KEY_ESCAPE)
	check(not lobby.dialog.visible and lobby.team.is_empty() and current_scene == lobby, "cancelar não adiciona (e não sai da cafeteria)")
	lobby.card_btn.pressed.emit()
	await key(KEY_ENTER)
	check(lobby.team == [d.hero], "confirmar põe o herói na party")
	check(lobby.slots[0]["face"].visible and lobby.slots[1]["plus"].visible, "o primeiro lugar enche na hora; os outros seguem vazios")
	check(lobby.marks[3]["in"].visible and lobby.marks[3]["focus"].visible, "o herói mostra que está na party (e o foco é outra marca)")
	lobby.card_btn.pressed.emit()
	check(not lobby.dialog.visible and lobby.card_btn.disabled and lobby.team.size() == 1, "não dá pra escolher o mesmo herói duas vezes")
	await add(lobby, a.hero)
	await add(lobby, c.hero)
	check(lobby.team.size() == 3 and lobby.ready_btn.disabled, "com três, READY TO PLAY segue bloqueado")
	lobby._ready_to_play()
	check(current_scene == lobby, "e não dá pra avançar com menos de quatro")
	await add(lobby, e.hero)
	check(lobby.team.size() == 4 and not lobby.ready_btn.disabled, "com quatro, READY TO PLAY libera")
	lobby._set_focus(1)
	check(lobby.card_btn.disabled and lobby.card_btn.text == "PARTY CHEIA", "o quinto não entra: party cheia")
	lobby._remove(a.hero)
	check(lobby.team.size() == 3 and lobby.ready_btn.disabled and not lobby.marks[0]["in"].visible, "clicar num lugar cheio tira o herói")
	await add(lobby, b.hero)
	var team: Array = lobby.team.duplicate()
	check(team.size() == 4 and not team.has(a.hero), "party final: %s" % [team])

	# ---- READY TO PLAY -> bosses -> cartas -> luta
	lobby.ready_btn.pressed.emit()
	await frames(8)
	main = current_scene
	check(main != null and main.scene_file_path == "res://main.tscn" and main.hud.menus.bosses.visible, "READY TO PLAY leva pra seleção de bosses")
	check(Knowledge.party == team and Knowledge.slot_info(2)["party"] == team, "a party fica gravada no save")
	var names: Array = []
	for u in main.units:
		names.append(u.hero)
	check(names == team, "a luta é montada com os quatro escolhidos, na ordem: %s" % [names])
	var in_reach := true
	for u in main.units:
		if u.melee and not main._in_range(u):
			in_reach = false
	check(in_reach, "quem luta de perto começa ao alcance da boss, em qualquer lugar da party")
	menus = main.hud.menus
	menus.bosses._confirm()
	await frames(8)
	main = current_scene
	menus = main.hud.menus
	check(menus.cards.visible, "escolher o boss abre as cartas")
	var row: Array = menus.cards._row.duplicate()
	row.sort()
	var sorted_team := team.duplicate()
	sorted_team.sort()
	check(row == sorted_team, "as cartas mostram só os quatro da party")
	menus.cards.ready_pressed.emit()
	await frames(3)
	check(not main.prep and main.units[main.ctrl].hero == menus.cards.hero, "READY FOR BATTLE começa a luta com o herói escolhido")

	# ---- os saves são independentes
	main.leave_fight("saves")
	await frames(8)
	main = current_scene
	menus = main.hud.menus
	check(menus.saves.visible and menus.saves._info[1]["party"] == team, "o SAVE 2 aparece na lista com a party dele")
	menus.saves._focus = 0
	menus.saves._go()
	await frames(6)
	lobby = current_scene
	check(Knowledge.slot == 1 and Knowledge.money == 77 and Knowledge.owned.has("stack"), "o SAVE 1 tem as cartas e moedas dele")
	check(lobby.team.is_empty(), "save de antes da cafeteria chega sem party: o jogador monta")
	lobby._back()
	await frames(8)
	main = current_scene
	menus = main.hud.menus
	check(menus.saves.visible, "VOLTAR da cafeteria cai nos saves")
	menus.saves._focus = 1
	menus.saves._go()
	await frames(6)
	lobby = current_scene
	check(Knowledge.slot == 2 and Knowledge.money == 0 and not Knowledge.owned.has("stack"), "voltar pro SAVE 2 não traz nada do SAVE 1")
	check(lobby.team == team and not lobby.ready_btn.disabled, "save com party volta com ela nos lugares")
	# sorteio: em algumas entradas seguidas, pelo menos um herói aparece em outro lugar
	var moved := false
	for attempt in 4:
		for k in lobby.figs.size():
			if not lobby.figs[k].position.is_equal_approx(first_spots[k]):
				moved = true
		if moved:
			break
		reload_current_scene()
		await frames(6)
		lobby = current_scene
	check(moved, "os heróis são sorteados de novo a cada entrada")

	# ---- apagar
	lobby._back()
	await frames(8)
	menus = current_scene.hud.menus
	menus.saves._focus = 1
	menus.saves._mark()
	menus.saves._ask_erase()
	check(menus.saves._dialog.visible and Knowledge.slot_exists(2), "APAGAR pede confirmação")
	menus.saves._erase_now()
	check(not Knowledge.slot_exists(2) and menus.saves._info[1].is_empty() and Knowledge.slot_exists(1), "confirmar apaga só aquele save")

	clean()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
