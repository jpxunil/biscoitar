extends SceneTree
## Teste dos kits de classe (design/classes-v2.md): cada habilidade faz o que a ficha diz.
## godot --headless --path . --script res://ui/tests/test_classes.gd -- --test

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


## Abre a luta com `hero` (índice em Knowledge.HEROES) na mão do jogador, já passada a vinheta.
func fight(hero: int) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	Knowledge.decks = {}
	Knowledge.start_hero = hero
	Knowledge.party = []
	Knowledge.ensure_in_party(hero)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.enrage = 9999.0
	main.start_fight()
	while main.intro_left > 0.0:
		await process_frame
	await process_frame
	return main


func wait(sec: float) -> void:
	await create_timer(sec, false).timeout


func _initialize() -> void:
	await process_frame
	Binds.boot()

	# ================================================================ PALADINO
	var main := await fight(0)
	var u: Unit = main.units[main.ctrl]
	var kit: Array = main.SKILLS["tank"]
	check(u.key == "tank" and u.unit_name == "Paladino", "Paladino na mão")
	var names: Array = []
	for sk in kit:
		names.append(sk["name"])
	check(names == ["Golpe de Juramento", "Baque do Escudo", "Provocação", "Solo Consagrado", "Égide", "Muralha da Fé"], "as seis habilidades, na ordem da ficha: %s" % [names])
	var cds: Array = []
	for sk in kit:
		cds.append(sk["cd"])
	check(cds == [1.5, 8.0, 15.0, 18.0, 25.0, 60.0], "recargas da ficha: %s" % [cds])
	check(main.hud.skill_ui.size() == 6, "a barra mostra os seis slots")

	var before: float = u.dmg_total
	check(main.use_skill(u, 0) and is_equal_approx(u.dmg_total - before, 30.0), "Golpe de Juramento bate")
	before = u.dmg_total
	await key(KEY_K)
	check(is_equal_approx(u.dmg_total - before, 55.0) and u.skill_cd[1] > 7.0, "slot 2 (K): Baque do Escudo dá dano e entra em recarga de 8 s")
	var threat: float = u.enmity
	await key(KEY_L)
	check(u.enmity - threat >= main.PROVOKE_BONUS and u.skill_cd[2] > 14.0, "slot 3 (L): Provocação puxa a boss")

	before = u.dmg_total
	await key(KEY_U)
	check(main.holy.size() == 1, "slot 4 (U): Solo Consagrado cria a área")
	await wait(2.4)
	check(u.dmg_total - before >= main.HOLY_DMG * 2.0, "a área bate na boss enquanto dura (%.0f)" % (u.dmg_total - before))
	await wait(main.HOLY_TIME - 1.8)
	check(main.holy.is_empty(), "e some depois de %d s" % main.HOLY_TIME)

	u.hp = 100.0
	await key(KEY_O)
	await process_frame
	check(u.guard_t > 0.0 and u.regen_t > 0.0 and u.aegis.visible, "slot 5 (O): Égide ergue a barreira dourada")
	var hp0: float = u.hp
	main.hurt(u, 50.0, "teste")
	check(is_equal_approx(hp0 - u.hp, 50.0 * main.MITIGATION), "Égide: 60%% menos dano (tomou %.0f de 50)" % (hp0 - u.hp))
	hp0 = u.hp
	main.phase = "dodgetime"  # a boss para de bater: sobra só a regeneração
	await wait(1.0)
	check(u.hp > hp0 + 3.0, "Égide regenera vida (+%.1f em 1 s)" % (u.hp - hp0))

	var ally: Unit = main.units[2]
	hp0 = ally.hp
	main.hurt(ally, 50.0, "teste")
	check(is_equal_approx(hp0 - ally.hp, 50.0), "sem Muralha, o aliado toma o dano cheio")
	await key(KEY_P)
	var all_walled := true
	for o in main.units:
		if o.wall_t <= 0.0:
			all_walled = false
	check(all_walled and u.skill_cd[5] > 59.0, "slot 6 (P): Muralha da Fé protege a party toda, recarga de 60 s")
	hp0 = ally.hp
	main.hurt(ally, 50.0, "teste")
	check(is_equal_approx(hp0 - ally.hp, 40.0), "Muralha: 20%% menos dano (tomou %.0f de 50)" % (hp0 - ally.hp))
	await process_frame
	check(ally.wall_ring.visible, "quem está protegido mostra o anel dourado")

	# a carta Guarda faz a IA usar a Égide no Esmagar
	Knowledge.owned["mitigate"] = true
	Knowledge.equip(0, "mitigate")
	main.swap_cd = 0.0
	main.set_ctrl(2)
	u.skill_cd[4] = 0.0
	u.guard_t = 0.0
	u.enmity = 99999.0
	main.phase = "idle"
	await wait(0.3)
	main._start_buster(1.6)
	var guarded := false
	for i in 200:
		await process_frame
		if u.guard_t > 0.0:
			guarded = true
		if main.buster == null:
			break
	check(guarded and u.alive, "com a carta Guarda, a IA do Paladino usa a Égide no Esmagar")

	# ================================================================ MALPRACTICE
	main = await fight(4)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	check(u.key == "nurse" and u.unit_name == "Malpractice", "a Gothic Nurse agora se chama Malpractice")
	check(Knowledge.HEROES[4]["name"] == "Malpractice", "o nome novo aparece nos menus")
	check(is_equal_approx(u.max_hp, 80.0), "menos vida: %d" % u.max_hp)
	check(is_equal_approx(main.low_hp_mult(u), 1.0), "vida cheia: sem bônus de dano")
	hp0 = u.hp
	main.use_skill(u, 0)
	check(u.hp < hp0 - 2.0, "Syringe Poke custa vida dela (%.1f)" % (hp0 - u.hp))
	u.skill_cd[2] = 0.0
	u.hp = 40.0
	main.use_skill(u, 2)
	check(is_equal_approx(u.hp, 40.0 + main.CONSUMED_STEAL - 8.0), "Blood Consumed custa 8 e rouba %d: saldo positivo" % main.CONSUMED_STEAL)
	u.hp = 20.0
	check(is_equal_approx(main.low_hp_mult(u), 1.6), "com 25%% de vida: +60%% de dano")
	u.hp = 50.0
	check(main.low_hp_mult(u) > 1.2 and main.low_hp_mult(u) < 1.4, "o bônus cresce conforme a vida cai (%.2f na metade)" % main.low_hp_mult(u))
	u.hp = 20.0
	before = u.dmg_total
	main._damage_boss(u, 100.0, false, false)
	check(is_equal_approx(u.dmg_total - before, 160.0), "o bônus vale no dano de verdade")
	check(is_equal_approx(main.low_hp_mult(main.units[2]), 1.0), "só ela tem esse bônus")

	# parry perfeito devolve a vida
	u.hp = 20.0
	u.skill_cd[1] = 0.0
	main.use_skill(u, 1)
	main.hurt(u, 5.0, "teste")
	await wait(main.TASTE_TIME + 0.2)
	check(u.hp > 60.0, "parry perfeito recupera a vida (20 -> %.0f)" % u.hp)
	# a IA joga uma versão segura: não sangra
	u.skill_cd[0] = 0.0
	hp0 = u.hp
	main.use_skill(u, 0, true)
	check(u.hp >= hp0, "na mão da IA ela não sangra com os golpes")
	# e errar tudo mata
	u.hp = 3.0
	u.skill_cd[0] = 0.0
	main.use_skill(u, 0)
	check(not u.alive, "sem vida pra pagar o golpe, ela morre do próprio dano")

	# ================================================================ ASSASSINA
	main = await fight(2)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	kit = main.SKILLS["assassina"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Talho Relâmpago", "Passo Rasante", "Garras Cruzadas", "Dança Carmesim", "Golpe de Misericórdia", "Frenesi da Fera"], "Assassina: as seis da ficha: %s" % [names])
	check(cds == [0.6, 5.0, 6.0, 12.0, 15.0, 60.0], "Assassina: recargas da ficha: %s" % [cds])
	var right := Vector3(2.5, 0, -6.4)
	var left := Vector3(-2.5, 0, -6.4)
	check(u.side_need == 1 and u.side_left == 3, "começa pedindo 3 golpes na DIREITA")
	await process_frame
	check(main.side_mark.visible and main.side_mark.position.x > 0.0 and main.side_label.text == "DIREITA", "a marca do lado aparece na direita da boss")
	u.position = left
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 10.0) and u.side_left == 3, "Talho do lado errado: dano normal, não gasta o bônus")
	u.position = right
	for n in 3:
		u.skill_cd[0] = 0.0
		before = u.dmg_total
		main.use_skill(u, 0)
		check(is_equal_approx(u.dmg_total - before, 25.0), "Talho do lado certo: +150%% (%d de 3)" % (n + 1))
	check(u.side_need == -1 and u.side_left == 3, "depois de 3, o lado troca pra ESQUERDA")
	check(is_equal_approx(u.skill_cd[0], 0.6), "Talho recarrega em 0,6 s")
	await process_frame
	check(main.side_mark.position.x < 0.0 and main.side_label.text == "ESQUERDA", "a marca vai pro outro lado")

	before = u.dmg_total
	main.use_skill(u, 1)
	await wait(0.25)
	check(u.position.x < -2.0 and is_equal_approx(u.dmg_total - before, 35.0), "Passo Rasante atravessa pro outro lado com um corte")
	check(main._in_range(u), "e ela continua ao alcance da boss")
	before = u.dmg_total
	main.use_skill(u, 2)
	await wait(0.45)
	check(is_equal_approx(u.dmg_total - before, 54.0), "Garras Cruzadas: três cortes de 18")
	before = u.dmg_total
	main.use_skill(u, 3)
	check(is_equal_approx(u.dmg_total - before, 65.0), "Dança Carmesim bate em volta")
	before = u.dmg_total
	main.use_skill(u, 4)
	check(u.parry_t > 0.0 and is_equal_approx(u.dmg_total, before), "Golpe de Misericórdia abre a janela antes do corte")
	await wait(main.MERCY_WINDOW + 0.15)
	check(is_equal_approx(u.dmg_total - before, 120.0), "sem levar golpe, o corte sai forte")
	u.skill_cd[4] = 0.0
	before = u.dmg_total
	hp0 = u.hp
	main.use_skill(u, 4)
	main.hurt(u, 40.0, "teste")
	check(is_equal_approx(u.hp, hp0), "usado como parry: o golpe da boss não entra")
	await wait(main.MERCY_WINDOW + 0.15)
	check(is_equal_approx(u.dmg_total, before), "e aí o corte não dá dano")

	main.use_skill(u, 5)
	await process_frame
	await process_frame
	check(u.frenzy_t > 7.5 and u.frenzy_ring.visible, "Frenesi da Fera: 8 s, com a aura roxa")
	u.position = right  # lado errado agora (pede esquerda)
	u.skill_cd[0] = 0.0
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 11.5), "Frenesi: +15% de dano")
	check(is_equal_approx(u.skill_cd[0], 0.3), "Frenesi: o Talho recarrega na metade do tempo")
	main.swap_cd = 0.0
	main.set_ctrl(0)
	await process_frame
	await process_frame
	check(not main.side_mark.visible, "a marca do lado só aparece jogando de Assassina")

	# ================================================================ SOULFLAME
	main = await fight(1)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	check(u.key == "healer" and u.unit_name == "Soulflame" and Knowledge.HEROES[1]["name"] == "Soulflame", "a Healer agora se chama Soulflame")
	kit = main.SKILLS["healer"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Fagulha Espiritual", "Toque de Brasa", "Lareira Celestial", "Manto de Cinzas", "Asa da Fênix", "Renascimento"], "Soulflame: as seis da ficha: %s" % [names])
	check(cds == [1.0, 1.0, 18.0, 20.0, 30.0, 60.0], "Soulflame: recargas da ficha: %s" % [cds])
	ally = main.units[2]
	var far: Unit = main.units[3]
	ally.position = u.position + Vector3(1.0, 0, 0)
	ally.hold_pos = ally.position
	far.position = u.position + Vector3(0, 0, 7.5) if u.position.z < 0.0 else u.position + Vector3(0, 0, -7.5)
	far.hold_pos = far.position

	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 12.0), "Fagulha Espiritual bate na boss")
	ally.hp = 30.0
	main.sel = 2
	main.use_skill(u, 1)
	check(is_equal_approx(u.channel_t, 1.5), "Toque de Brasa: conjuração de 1,5 s")
	await wait(1.65)
	check(is_equal_approx(ally.hp, 30.0 + main.HEAL_PLAYER), "e cura o aliado escolhido (%.0f)" % ally.hp)

	ally.hp = 30.0
	far.hp = 30.0
	main.use_skill(u, 2)
	check(main.hearths.size() == 1, "Lareira Celestial acende a fogueira")
	await wait(2.3)
	check(ally.hp >= 30.0 + main.HEARTH_HPS * 2.0, "quem está na fogueira é curado por segundo (%.0f)" % ally.hp)
	check(is_equal_approx(far.hp, 30.0), "quem está longe, não")

	main.use_skill(u, 3)
	check(is_equal_approx(ally.shield_hp, ally.max_hp * main.SHIELD_RATIO) and u.skill_cd[3] > 19.0, "Manto de Cinzas: escudo no aliado, 20 s")
	ally.hp = 5.0
	main.use_skill(u, 4)
	check(ally.hp >= 5.0 + 95.0 and u.skill_cd[4] > 29.0, "Asa da Fênix: cura grande e na hora (5 -> %.0f)" % ally.hp)

	main.kill(far, "teste")
	ally.hp = 10.0
	before = u.dmg_total
	check(not far.alive, "um aliado caiu")
	main.use_skill(u, 5)
	check(far.alive, "Renascimento levanta quem caiu")
	check(is_equal_approx(ally.hp, 80.0), "cura todos (10 -> %.0f)" % ally.hp)
	check(is_equal_approx(u.dmg_total - before, main.REBIRTH_DMG), "queima a boss com dano médio")
	check(main.hearths.is_empty(), "a fogueira vira a fênix")
	check(not main.get_dot("brasa").is_empty(), "e deixa um DoT na boss")
	await process_frame
	await process_frame
	check(main.hud.dot_ui.has("brasa"), "o DoT aparece embaixo da vida da boss, com o tempo")
	before = u.dmg_total
	await wait(2.3)
	check(u.dmg_total - before >= main.REBIRTH_DOT * 2.0, "o DoT dá 6 por segundo")
	check(u.skill_cd[5] > 55.0, "Renascimento: recarga de 60 s")
	# IA: a recarga do Toque de Brasa é maior, pra ela não virar uma metralhadora de cura
	u.skill_cd[1] = 0.0
	ally.hp = 20.0
	main.use_skill(u, 1, true, ally)
	await wait(1.65)
	check(u.skill_cd[1] > 3.0, "na mão da IA, o Toque de Brasa tem recarga maior")

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
