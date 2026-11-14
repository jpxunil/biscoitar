extends SceneTree
## Teste da progressão por save e das recompensas de run:
##   pistas das cartas desconhecidas · cada save com as suas cartas · carta ganha na luta só vale
##   quando a run termina (sair e TENTAR NOVAMENTE descartam) · treino livre sem progresso ·
##   GEAR fora do menu principal · tela de saves (selecionar x entrar x apagar) · artes dos heróis.
## Usa uma pasta de saves só do teste (user://test_saves/): o progresso do jogador não é tocado.
## Rodar SEM argumentos depois de "--" (argumento de teste desliga o save, e aqui o save é o assunto):
##   godot --headless --path . --script res://ui/tests/test_progress.gd

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


func frames(n: int) -> void:
	for i in n:
		await process_frame


func clean() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))


func disk(n: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Knowledge.save_path(n)))


func open_main() -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(3)
	return main


func fight(main: Node) -> void:
	main.start_fight()
	while main.intro_left > 0.0:
		await process_frame
	await frames(3)


func click(row: Control, twice := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.double_click = twice
	row.gui_input.emit(e)


func _initialize() -> void:
	Knowledge.save_dir = DIR
	clean()
	await process_frame

	# ---------------------------------------------------------------- pistas
	var bad := ""
	for id in Knowledge.CARDS:
		var c: Dictionary = Knowledge.CARDS[id]
		if not Knowledge.SECRETS.has(id):
			bad += id + " (sem pista) "
			continue
		var both: String = (Knowledge.mystery(id) + " " + Knowledge.hint(id)).to_lower()
		if Knowledge.mystery(id).length() < 8 or Knowledge.hint(id).length() < 20:
			bad += id + " (curta) "
		if both.contains(String(c["name"]).to_lower()):
			bad += id + " (entrega o nome) "
		for info in Knowledge.BOSS_INFO:
			if both.contains(String(info["name"]).to_lower()):
				bad += id + " (cita o boss) "
		if Knowledge.hint(id).length() > 112 or Knowledge.mystery(id).length() > 48:
			bad += id + " (não cabe no painel) "
	check(bad == "", "toda carta tem mistério e pista, sem entregar nome de carta nem de boss %s" % bad)

	# ---------------------------------------------------------------- cada save com as suas cartas
	Knowledge.select_slot(1)
	Knowledge.set_party([0, 1, 2, 3])
	Knowledge.grant("stack")
	Knowledge.money = 300
	Knowledge.shop_unlocked = true
	check(Knowledge.buy("potion") and Knowledge.equip(0, "potion"), "save 1 compra e equipa a Poção")
	Knowledge.fresh = {}  # a compra chega como NOVA; os avisos têm um bloco próprio mais abaixo
	Knowledge.save()
	Knowledge.select_slot(2)
	check(not Knowledge.owned.has("stack") and not Knowledge.owned.has("potion") and Knowledge.money == 0, "save 2 começa sem as cartas, o item e as moedas do save 1")
	check(Knowledge.inventory(0).is_empty() and not Knowledge.has(0, "potion"), "save 2: inventário e baralho vazios")
	Knowledge.set_party([4, 5, 6, 7])
	Knowledge.grant("spread")
	Knowledge.select_slot(1)
	check(Knowledge.owned.has("stack") and Knowledge.has(0, "potion") and not Knowledge.owned.has("spread"), "voltar pro save 1 traz as cartas e o gear dele, e nada do save 2")
	check(Knowledge.money == 220 and Knowledge.party == [0, 1, 2, 3], "save 1: moedas e party dele")
	check(disk(2)["owned"].has("spread") and not disk(2)["owned"].has("stack"), "arquivo do save 2 só tem o que é dele")
	check(not Knowledge.is_owned_by(0, "spread"), "carta do save 2 continua desconhecida no save 1")

	# ---------------------------------------------------------------- menu principal sem GEAR
	var main := await open_main()
	var menus = main.hud.menus
	check(not menus.title.has_node("Stage/BtnGear"), "menu principal não tem mais o botão GEAR")
	check(menus.title._btns.size() == 4 and menus.title.has_node("Stage/BtnSkills") and not menus.title.has_node("Stage/BtnShop"), "menu principal: JOGAR, SKILLS, TUTORIAL e OPÇÕES (a loja fica no save)")
	menus.title.get_node("Stage/BtnSkills").pressed.emit()
	await frames(3)
	var sks = menus.skills
	check(sks.visible and sks._rows.size() == 6, "SKILLS abre a consulta de habilidades (6 slots)")
	var first_hero: int = sks.hero
	var seen_heroes := {}
	for n in Knowledge.HEROES.size():
		seen_heroes[sks.hero] = true
		sks._switch(1)
	check(seen_heroes.size() == Knowledge.HEROES.size() and sks.hero == first_hero, "as setas passam por todos os personagens")
	sks.open(8)
	check(sks._mode_btn.visible and sks._d_name.text == "BOCEJO", "Sleepwalker: tem o botão de modo")
	sks._toggle_mode()
	check(sks.asleep and sks._d_name.text == "A MORDIDA DOS MIL" and sks._d_icon.texture == SkillInfo.icon("sleepwalker", 0, true), "TAB mostra as habilidades (e os ícones) do Modo Dormindo")
	sks.open(0)
	check(not sks._mode_btn.visible, "os outros personagens não têm segundo modo")
	Binds.assign("skill_2", 0, KEY_M)
	sks.open(0)
	var found_key := false
	for c in sks._rows[1]["root"].get_children():
		if c is Chip and c.text == "M":
			found_key = true
	check(found_key, "a tela mostra a tecla configurada do slot, não o número")
	Binds.reset("skill_2")
	# arrumar a barra: segurar uma linha e soltar em cima de outra troca as duas de posição
	sks.open(2)
	var drag = sks._drag_row(0)
	check(sks._can_drop_row(3, drag) and sks._drop_at == 3 and not sks._can_drop_row(0, drag), "arrastar: dá pra soltar em outra linha (que acende), não na mesma")
	sks._drop_row(3, drag)
	check(Knowledge.layout(2) == [3, 1, 2, 0, 4, 5] and sks.sel == 3 and sks._d_name.text == "TALHO RELÂMPAGO", "soltar troca as duas habilidades de posição")
	check(sks._rows[0]["slot"].icon == SkillInfo.icon("assassina", 3) and sks._rows[3]["slot"].icon == SkillInfo.icon("assassina", 0), "e as linhas mostram a ordem nova")
	check(Knowledge.layout(0) == [0, 1, 2, 3, 4, 5], "só a barra desse herói muda")
	Knowledge.select_slot(2)
	check(Knowledge.layout(2) == [0, 1, 2, 3, 4, 5], "a ordem da barra é de cada save")
	Knowledge.select_slot(1)
	check(Knowledge.layout(2) == [3, 1, 2, 0, 4, 5], "e fica gravada no save")
	sks.open(2)
	var r_key := InputEventKey.new()
	r_key.physical_keycode = KEY_R
	r_key.pressed = true
	sks._unhandled_input(r_key)
	check(Knowledge.layout(2) == [0, 1, 2, 3, 4, 5] and sks._rows[0]["slot"].icon == SkillInfo.icon("assassina", 0), "R restaura a ordem original")
	sks.back_pressed.emit()
	await frames(2)
	check(menus.title.visible, "VOLTAR retorna ao menu principal")
	menus.show_screen("bosses")
	await frames(2)
	check(menus.bosses.visible and menus.bosses.has_node("BtnGear"), "o gear do save abre pela tela de bosses (CARTAS)")
	menus.bosses.get_node("BtnGear").pressed.emit()
	await frames(2)
	check(menus.cards.visible and not menus.cards._show_ready, "CARTAS abre as cartas do save, sem botão de luta")
	# botão SKILLS da tela de cartas
	check(menus.cards._skills_btn.visible, "a tela de cartas tem o botão SKILLS")
	var seen_hero: int = menus.cards.hero
	menus.cards._skills_btn.pressed.emit()
	await frames(3)
	check(menus.skills.visible and menus.skills.hero == seen_hero, "ele abre a tela SKILLS no herói que estava sendo visto")
	menus.skills.back_pressed.emit()
	await frames(3)
	check(menus.cards.visible and not menus.title.visible, "VOLTAR da tela SKILLS retorna pras cartas (e não pro menu principal)")
	menus.cards.back_pressed.emit()
	await frames(2)
	check(menus.bosses.visible, "voltar do gear cai na tela de bosses")

	# carta desconhecida: nome oculto, mistério e pista no painel
	menus.bosses.get_node("BtnGear").pressed.emit()
	await frames(2)
	var cards = menus.cards
	var at := -1
	for k in cards._hand.size():
		if cards._hand[k] == "spread":
			at = k
	cards._set_focus(at)
	await frames(2)
	check(cards._d_name.text == "???", "carta não liberada aparece como ???")
	check(cards._d_desc.text == Knowledge.mystery("spread") and cards._d_hint.text == Knowledge.hint("spread"), "com a frase de mistério e a pista")
	for k in cards._hand.size():
		if cards._hand[k] == "stack":
			at = k
	cards._set_focus(at)
	await frames(2)
	check(cards._d_name.text == "LARANJA JUNTO" and cards._d_hint.text == "" and cards._d_desc.text == Knowledge.CARDS["stack"]["desc"], "carta liberada mostra nome e descrição normais")
	menus.cards.back_pressed.emit()

	# ---------------------------------------------------------------- run: sair descarta
	var before := FileAccess.get_file_as_string(Knowledge.save_path(1))
	await fight(main)
	check(Knowledge.in_run, "a luta abre uma run")
	for n in 3:
		main._master("link")
	check(Knowledge.owned.has("link") and Knowledge.run_cards() == ["link"], "carta ganha na luta fica como provisória")
	var equipped := false
	for h in Knowledge.HEROES.size():
		if Knowledge.has(h, "link"):
			equipped = true
	check(not equipped, "carta nova NÃO é equipada sozinha em ninguém")
	check(Knowledge.is_new(main.units[main.ctrl].hero, "link") and Knowledge.has_new(main.units[main.ctrl].hero), "ela fica marcada como NOVA pro herói que a conquistou")
	check(FileAccess.get_file_as_string(Knowledge.save_path(1)) == before, "nada é gravado no meio da run")
	var tries: int = Knowledge.attempts
	main.leave_fight("cards")
	await frames(6)
	check(not Knowledge.in_run and not Knowledge.owned.has("link") and Knowledge.mastery_of("link") == 0, "sair pelo pause descarta a carta e a maestria da tentativa")
	check(not Knowledge.has(0, "link") and Knowledge.fresh.is_empty(), "e some o aviso de carta nova que ela tinha gerado")
	check(Knowledge.owned.has("stack") and Knowledge.has(0, "potion"), "o que já era do save continua lá")
	check(FileAccess.get_file_as_string(Knowledge.save_path(1)) == before, "o arquivo do save fica igual ao de antes da luta")
	check(Knowledge.attempts == tries + 1, "sair conta uma tentativa")

	# ---------------------------------------------------------------- TENTAR NOVAMENTE
	main = current_scene
	check(main.prep and main.hud.menus.cards.visible, "depois de sair: tela de cartas")
	main.select_hero(2)
	await fight(main)
	for n in 3:
		main._master("link")
	main.units[0].hp = 5.0
	main.boss_hp = main.boss_max * 0.5
	main.pause()
	var pause = main.hud.pause
	check(pause._btns.size() == 5 and pause._btns[0].text == "CONTINUAR" and pause._btns[1].text == "TENTAR NOVAMENTE", "pause: TENTAR NOVAMENTE logo abaixo de CONTINUAR")
	tries = Knowledge.attempts
	pause._btns[1].pressed.emit()
	await frames(8)
	var again: Node = current_scene
	check(again != main and not paused, "TENTAR NOVAMENTE recarrega a luta sem ficar pausado")
	check(not again.prep and not again.ended, "a luta recomeça direto, sem passar pelos menus")
	check(is_equal_approx(again.boss_hp, again.boss_max) and again.fight_time < 1.0, "boss com a vida cheia e o relógio no zero")
	check(again.units[0].hp == again.units[0].max_hp, "party com a vida cheia")
	check(Knowledge.party == [0, 1, 2, 3] and again.units[again.ctrl].hero == 2, "mesma party e mesmo herói no controle")
	check(not Knowledge.owned.has("link") and Knowledge.mastery_of("link") == 0, "a carta da tentativa anterior não ficou")
	check(Knowledge.in_run and Knowledge.attempts == tries + 1, "é uma run nova, e conta uma tentativa")
	check(Knowledge.slot == 1 and not Knowledge.slot_exists(3) and not Knowledge.slot_exists(4), "retry não cria save")
	check(FileAccess.get_file_as_string(Knowledge.save_path(1)) == before, "o save continua igual")

	# ---------------------------------------------------------------- terminar a run confirma
	while again.intro_left > 0.0:
		await process_frame
	for n in 3:
		again._master("link")
	again._end(false)
	await frames(2)
	check(again.ended and not Knowledge.in_run, "wipe termina a run")
	check(Knowledge.owned.has("link") and disk(1)["owned"].has("link"), "morrer com a carta ganha: ela é gravada no save")
	check(not disk(2)["owned"].has("link"), "e só no save ativo")
	again.retry()
	await frames(6)
	main = current_scene
	check(Knowledge.owned.has("link"), "a carta continua depois de sair da tela de fim")
	# ---------------------------------------------------------------- cartas novas: avisos
	var who: int = Knowledge.start_hero
	check(Knowledge.is_new(who, "link") and disk(1)["fresh"].has(str(who)), "a carta confirmada continua NOVA, e isso vai pro save")
	var deck_before: String = JSON.stringify(Knowledge.deck(who))
	Knowledge.mark_new("pair", who)
	Knowledge.owned["pair"] = true
	var other_hero: int = Knowledge.party[0] if Knowledge.party[0] != who else Knowledge.party[1]
	check(not Knowledge.has_new(other_hero), "só o herói que ganhou tem o aviso")
	var cs = main.hud.menus.cards
	main.hud.menus.show_screen("cards")
	cs.open(who, true)
	await frames(4)
	check(cs._tiles[who].fresh and not cs._tiles[other_hero].fresh, "no seletor, o aviso aparece só no rosto dele")
	check(JSON.stringify(Knowledge.deck(who)) == deck_before, "abrir as cartas não mexe no baralho")
	var news: Array = []
	for info in cs._spokes:
		if info["cv"].fresh:
			news.append(info)
	check(news.size() == 2, "as duas cartas novas têm o selo NOVO (%d)" % news.size())
	check(Knowledge.has_new(who), "abrir a tela não tira o aviso: precisa passar o mouse na carta")
	news[0]["cv"].mouse_entered.emit()
	await frames(2)
	check(not news[0]["cv"].fresh and news[1]["cv"].fresh and cs._tiles[who].fresh, "passar o mouse numa tira o selo dela; o aviso do herói continua pela outra")
	news[1]["cv"].mouse_entered.emit()
	await frames(2)
	check(not Knowledge.has_new(who) and not cs._tiles[who].fresh, "vistas as duas, o aviso do herói some")
	check(not disk(1)["fresh"].has(str(who)), "e o save guarda que já foram vistas")
	Knowledge.owned.erase("pair")
	Knowledge.money = 500
	Knowledge.buy("sharpen")
	check(Knowledge.is_new(Knowledge.start_hero, "sharpen") and Knowledge.holder("sharpen") == -1, "carta comprada também chega como NOVA e sem equipar")
	Knowledge.see_new(Knowledge.start_hero, "sharpen")
	await fight(main)
	for n in 3:
		main._master("pair")
	var coins: int = Knowledge.money
	main.boss_hp = 0.0
	main._end(true)
	await frames(2)
	check(main.won and Knowledge.owned.has("pair") and disk(1)["owned"].has("pair"), "vencer confirma a carta da run")
	check(Knowledge.money > coins and int(disk(1)["money"]) == Knowledge.money and disk(1)["rank"].has("1"), "e grava moedas e ranking")
	main.retry()
	await frames(6)

	# ---------------------------------------------------------------- treino livre
	main = current_scene
	menus = main.hud.menus
	menus.show_screen("bosses")
	await frames(2)
	var bosses = menus.bosses
	check(bosses.has_node("Practice"), "a tela de bosses tem o TREINO LIVRE")
	bosses.sel = bosses._practice_at
	bosses._mark()
	check(not bosses.get_node("BtnConfirm").disabled, "o treino pode ser confirmado")
	before = FileAccess.get_file_as_string(Knowledge.save_path(1))
	tries = Knowledge.attempts
	bosses._confirm()
	await frames(8)
	main = current_scene
	check(Knowledge.practice and main.boss_def["name"] == "DUMMY DE TREINO", "confirmar o treino carrega o dummy")
	check(main.hud.menus.cards.visible, "o treino passa pela tela de cartas, com a party e os baralhos do save")
	check(Knowledge.party == [0, 1, 2, 3] and Knowledge.has(0, "potion"), "party e gear do save ativo")
	await fight(main)
	var u = main.units[main.ctrl]
	var hp0: float = main.boss_hp
	main._damage_boss(u, 500.0, false, false)
	check(main.boss_hp < hp0, "o dummy recebe dano normalmente")
	main._damage_boss(u, 9999999.0, false, false)
	check(not main.ended and is_equal_approx(main.boss_hp, main.boss_max), "o dummy não morre: a vida enche de novo")
	for n in 3:
		main._master("spread")
	check(not Knowledge.owned.has("spread") and Knowledge.mastery_of("spread") == 0, "treino não dá maestria nem carta")
	main.fight_time = 400.0
	await create_timer(2.5).timeout
	var hurt := false
	for o in main.units:
		if o.hp < o.max_hp and o.key != "nurse":
			hurt = true
	check(not hurt and not main.fury and not main.ended, "o dummy não ataca e não existe Fúria")
	main.leave_fight("cards")
	await frames(6)
	check(FileAccess.get_file_as_string(Knowledge.save_path(1)) == before, "sair do treino deixa o save exatamente como estava")
	check(Knowledge.attempts == tries and not Knowledge.best_rank.has(4), "treino não conta tentativa nem vitória")
	main = current_scene
	main.hud.menus.show_screen("bosses")
	await frames(2)
	main.hud.menus.bosses.sel = 1
	main.hud.menus.bosses._confirm()
	await frames(8)
	main = current_scene
	check(not Knowledge.practice and main.boss_def["name"] == "MINI-CHAN", "escolher um boss sai do treino")

	# ---------------------------------------------------------------- tela de saves
	menus = main.hud.menus
	menus.show_screen("saves")
	await frames(4)
	var saves = menus.saves
	var chosen: Array = []
	saves.slot_chosen.connect(func(n: int): chosen.append(n), CONNECT_DEFERRED)
	saves._focus = 0
	saves._mark()
	saves._rows[1].mouse_entered.emit()
	check(saves._focus == 0, "passar o mouse por outro save não muda a seleção")
	click(saves._rows[1])
	await frames(2)
	check(saves._focus == 1 and chosen.is_empty(), "um clique seleciona o save e não entra nele")
	check(saves._rows[1].get_node("Ring").visible and saves._rows[1].get_node("Picked").visible and not saves._rows[0].get_node("Ring").visible, "o selecionado fica destacado, e só ele")
	check(saves._erase.text == "APAGAR SAVE 2" and not saves._erase.disabled, "APAGAR diz qual save vai apagar")
	click(saves._rows[0], true)
	await frames(2)
	check(saves._focus == 0 and chosen.is_empty(), "duplo clique que começou em outro save só seleciona")
	click(saves._rows[1])
	saves._erase.pressed.emit()
	check(saves._dialog.visible and saves._dialog_title.text == "APAGAR O SAVE 2?", "a confirmação identifica o save")
	saves._rows[0].mouse_entered.emit()
	click(saves._rows[0])
	check(saves._focus == 1 and saves._erase_slot == 2, "com a confirmação aberta, mouse e clique não trocam o alvo")
	saves._close_dialog()
	check(Knowledge.slot_exists(2), "CANCELAR não apaga nada")
	saves._erase.pressed.emit()
	saves._focus = 0  # mesmo que a seleção mudasse, o alvo da confirmação está travado
	saves._erase_now()
	await frames(2)
	check(not Knowledge.slot_exists(2) and Knowledge.slot_exists(1), "APAGAR remove só o save confirmado")
	check(saves._info[1].is_empty() and not saves._info[0].is_empty(), "a lista mostra o slot 2 vazio e o 1 intacto")
	saves._focus = 3
	saves._mark()
	check(saves._erase.disabled and saves._play.text == "CRIAR", "slot vazio: nada pra apagar, JOGAR vira CRIAR")
	click(saves._rows[0])
	click(saves._rows[0], true)
	await frames(2)
	check(chosen == [1], "dois cliques no mesmo save entram nele")
	await frames(6)
	check(current_scene != null and current_scene.scene_file_path == "res://lobby.tscn" and Knowledge.slot == 1, "entrar no save leva pra cafeteria")
	check(Knowledge.owned.has("link") and Knowledge.owned.has("pair") and Knowledge.has(0, "potion"), "com o inventário daquele save")

	# ---------------------------------------------------------------- artes
	var missing := ""
	for h in Knowledge.HEROES:
		var art := "res://assets/portraits/%s_art.webp" % h["key"]
		var face := "res://assets/portraits/%s_face.png" % h["key"]
		if not ResourceLoader.exists(art) or not ResourceLoader.exists(face):
			missing += h["key"] + " "
			continue
		var img: Image = (load(art) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		# fundo recortado: o canto é transparente e a figura ocupa uma parte razoável do quadro
		var solid := 0
		for gy in 20:
			for gx in 20:
				if img.get_pixel(int((gx + 0.5) * img.get_width() / 20.0), int((gy + 0.5) * img.get_height() / 20.0)).a > 0.5:
					solid += 1
		if img.get_pixel(0, 0).a > 0.05 or solid < 80 or solid > 360:
			missing += h["key"] + "(fundo %d) " % solid
		var fs := (load(face) as Texture2D).get_size()
		if absf(fs.x / fs.y - 5.0 / 7.0) > 0.01:
			missing += h["key"] + "(proporção do retrato) "
	check(missing == "", "todo herói tem arte de corpo inteiro com fundo transparente e retrato 5:7 %s" % missing)
	var lobby: Node = current_scene
	var sprites := 0
	for f in lobby.figs:
		for c in f.get_children():
			# a arte (a outra Sprite3D do herói é a sombra dela, escura)
			if c is Sprite3D and not f.visual.visible and c.modulate == Color.WHITE:
				var ts: Vector2 = c.texture.get_size()
				if c.pixel_size * ts.y <= lobby.FIG_H + 0.01 and c.pixel_size * ts.x <= lobby.FIG_W + 0.01:
					sprites += 1
	check(sprites == Knowledge.HEROES.size(), "cafeteria: os %d personagens usam a arte nova, sem esticar (%d)" % [Knowledge.HEROES.size(), sprites])

	# ---------- aprendizado, passivas, equipamentos e as duas lojas
	Knowledge.select_slot(1)
	Knowledge.decks = {}
	Knowledge.gear = {}
	Knowledge.passive = {}
	Knowledge.progress = {}
	Knowledge.learned_now.clear()
	Knowledge.owned["stack"] = true
	Knowledge.owned["eshield"] = true
	Knowledge.owned["sharpen"] = true
	Knowledge.owned["heart"] = true
	check(Knowledge.role("stack") == "learn" and Knowledge.role("eshield") == "pref" and Knowledge.role("sharpen") == "gear" and Knowledge.role("potion") == "item", "cada carta tem um papel: aprendizado, critério, equipamento ou item")
	check(Knowledge.equip(2, "sharpen") and Knowledge.gear_of(2).has("sharpen") and not Knowledge.deck(2)["white"].has("sharpen") and Knowledge.has(2, "sharpen"), "buff é equipamento: vai pro slot de gear, não pro baralho")
	check(not Knowledge.inventory(2).has("heart") and Knowledge.gear_bag(2).has("heart"), "equipamento não aparece na mão de cartas, só na mochila do gear")
	Knowledge.equip(2, "heart")
	check(is_equal_approx(Knowledge.gear_stats(2)["hp"], 20.0) and is_equal_approx(Knowledge.gear_stats(0)["hp"], 0.0), "Coração de Açúcar: +20 de vida só pra quem equipou")
	check(Knowledge.shop_list("", "gear").has("dice") and Knowledge.shop_list("", "gear").has("potion") and not Knowledge.shop_list("", "gear").has("eshield"), "a loja de itens vende equipamentos e consumíveis")
	check(Knowledge.shop_list("", "cards").has("eshield") and not Knowledge.shop_list("", "cards").has("sharpen"), "a loja de cartas não vende buff")
	Knowledge.equip(2, "stack")
	Knowledge.equip(2, "eshield")
	check(Knowledge.in_deck(2, "stack") and is_equal_approx(Knowledge.learn_progress(2, "stack"), 0.0), "carta de aprendizado começa em 0%")
	check(not Knowledge.add_progress(2, "stack", Knowledge.LEARN_WIN) and not Knowledge.add_progress(2, "stack", Knowledge.LEARN_WIN), "duas lutas limpas ainda não bastam")
	check(Knowledge.learn_progress(2, "stack") > 60.0 and Knowledge.in_deck(2, "stack"), "a barra sobe e a carta continua no slot")
	check(Knowledge.add_progress(2, "stack", Knowledge.LEARN_WIN), "na terceira ela chega em 100%")
	check(Knowledge.is_passive(2, "stack") and not Knowledge.in_deck(2, "stack") and Knowledge.has(2, "stack"), "virou passiva: saiu do baralho e continua valendo")
	check(not Knowledge.is_passive(0, "stack") and not Knowledge.has(0, "stack"), "a passiva é do herói que aprendeu")
	check(not Knowledge.add_progress(2, "eshield", 100.0) and not Knowledge.is_passive(2, "eshield"), "carta de critério nunca vira passiva")
	check(Knowledge.learned_now == [[2, "stack"]], "a carta aprendida entra na fila da comemoração")
	Knowledge.save()
	Knowledge.select_slot(2)
	check(not Knowledge.is_passive(2, "stack") and Knowledge.gear_of(2) == ["", "", "", ""], "passivas e gear são de cada save")
	Knowledge.select_slot(1)
	check(Knowledge.is_passive(2, "stack") and Knowledge.gear_of(2).has("sharpen") and Knowledge.gear_of(2).has("heart"), "e ficam gravados no save")
	# os menus: botões novos, tela de gear e a comemoração
	Knowledge.learned_now = [[2, "stack"]]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(3)
	menus = main.hud.menus
	menus.show_screen("bosses")
	await frames(3)
	check(menus.bosses.has_node("BtnShop") and menus.bosses.has_node("BtnEquip"), "a tela de bosses tem os botões LOJA e GEAR")
	# painel "o que a party sabe" de cada boss
	Knowledge.know = {2: {"fan": 40.0}}
	check(is_equal_approx(Knowledge.understanding(2, "stack"), 100.0) and is_equal_approx(Knowledge.understanding(2, "fan"), 40.0), "entendimento: 100% com passiva ou carta, senão o que aprendeu na prática")
	Knowledge.solved = {}
	check(not Knowledge.mech_seen("fan") and not Knowledge.mech_seen("dodge"), "o nome da mecânica fica escondido enquanto o jogador não a resolveu na mão")
	Knowledge.solve("fan")
	check(not Knowledge.mech_seen("fan"), "uma vez só ainda não revela")
	Knowledge.solve("fan")
	check(Knowledge.mech_seen("fan") and not Knowledge.mech_seen("eye"), "na segunda vez o nome aparece; as outras continuam escondidas")
	menus.bosses.open_info(4)
	await frames(2)
	var info_panel = menus.bosses._info
	check(info_panel != null and info_panel.find_child("Cell_1_0", true, false) != null and info_panel.find_child("Cell_4_3", true, false) != null, "o botão ? abre o painel com as mecânicas do boss e os quatro heróis da party")
	var shown := 0
	for lbl in info_panel.find_children("*", "Label", true, false):
		if lbl.text == "??????":
			shown += 1
	var named := false
	for lbl in info_panel.find_children("*", "Label", true, false):
		if lbl.text == "PULO NO VENTILADOR DE RAIOS":
			named = true
	check(shown >= 3 and named, "só a mecânica já resolvida tem nome; as outras aparecem como ?????? (%d)" % shown)
	menus.bosses.close_info()
	await frames(2)
	check(menus.bosses._info == null, "FECHAR fecha o painel")
	Knowledge.know = {}
	Knowledge.solved = {}
	check(menus._pop != null and is_instance_valid(menus._pop), "voltando da luta, a carta que virou passiva é comemorada")
	menus._pop.queue_free()
	menus._pop = null
	menus.bosses.get_node("BtnEquip").pressed.emit()
	await frames(3)
	check(menus.gear_screen.visible and menus.gear_screen.hero == Knowledge.start_hero, "GEAR abre a tela de equipamentos do herói")
	menus.gear_screen.back_pressed.emit()
	await frames(2)
	Knowledge.shop_unlocked = true
	menus.bosses.open()
	check(not menus.bosses.has_node("BtnItems"), "a loja tem uma entrada só")
	menus.bosses.get_node("BtnShop").pressed.emit()
	await frames(3)
	check(menus.shop.visible and menus.shop.mode == "cards" and menus.shop.get_node("Vendor").who == "cards", "LOJA abre a loja de cartas, com a Shopkeeper")
	menus.shop.get_node("BtnSwap").pressed.emit()
	await frames(2)
	check(menus.shop.mode == "gear" and menus.shop.get_node("TitlePanel/Title").text == "ITENS" and menus.shop.get_node("Vendor").who == "gear", "a troca leva pro balcão de itens, com a vendedora dele")
	check(menus.shop.get_node("Vendor")._art() != null, "a vendedora de itens tem a arte dela")
	menus.shop.get_node("BtnSwap").pressed.emit()
	await frames(2)
	check(menus.shop.mode == "cards" and menus.shop.get_node("TitlePanel/Title").text == "LOJA", "e a troca de novo volta pra loja de cartas")
	menus.shop.back_pressed.emit()
	await frames(2)
	menus.bosses.get_node("BtnShop").pressed.emit()
	await frames(3)
	check(menus.shop.mode == "cards", "a loja sempre abre no balcão de cartas")
	main.queue_free()
	await frames(2)

	clean()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
