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


func frames_of(n: int) -> void:
	for i in n:
		await process_frame


## Zera as recargas do herói, pra testar uma habilidade depois da outra sem esperar.
func ready(hero: Unit) -> void:
	for n in hero.skill_cd.size():
		hero.skill_cd[n] = 0.0


## Usa uma habilidade do Sleepwalker e conclui a conjuração na hora (o tempo de cast tem teste próprio).
func sw(main: Node, u: Unit, slot: int) -> bool:
	if not main.use_skill(u, slot):
		return false
	if u.channel_t > 0.0:
		u.channel_t = 0.0
		main._resolve_skill(u, slot, false)
	return true


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
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
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
	check(is_equal_approx(main.low_hp_mult(u), 1.0 + main.LOW_HP_BONUS), "com 25%% de vida: +75%% de dano")
	u.hp = 50.0
	check(main.low_hp_mult(u) > 1.2 and main.low_hp_mult(u) < 1.4, "o bônus cresce conforme a vida cai (%.2f na metade)" % main.low_hp_mult(u))
	u.hp = 20.0
	before = u.dmg_total
	main._damage_boss(u, 100.0, false, false)
	check(is_equal_approx(u.dmg_total - before, 100.0 * (1.0 + main.LOW_HP_BONUS)), "o bônus vale no dano de verdade")
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
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	kit = main.SKILLS["assassina"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Talho Relâmpago", "Passo Rasante", "Garras Cruzadas", "Dança Carmesim", "Golpe de Misericórdia", "Frenesi da Fera"], "Assassina: as seis da ficha: %s" % [names])
	check(cds == [1.3, 5.0, 0.6, 15.0, 22.0, 60.0], "Assassina: recargas (Garras divide a do Talho; Dança 15 s; Misericórdia 22 s): %s" % [cds])
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
	check(is_equal_approx(u.skill_cd[0], 1.3), "Talho recarrega em 1,3 s sem Ferimento na boss")
	await process_frame
	check(main.side_mark.position.x < 0.0 and main.side_label.text == "ESQUERDA", "a marca vai pro outro lado")

	before = u.dmg_total
	main.use_skill(u, 1)
	await wait(0.25)
	check(u.position.x < -2.0 and is_equal_approx(u.dmg_total - before, 35.0), "Passo Rasante atravessa pro outro lado com um corte")
	check(main._in_range(u), "e ela continua ao alcance da boss")
	# Garras Cruzadas: dano baixinho, Ferimento, e a recarga dividida com o Talho
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 2)
	check(is_equal_approx(u.skill_cd[2], 0.6) and is_equal_approx(u.skill_cd[0], 0.6), "Garras Cruzadas põe o Talho na mesma recarga (0,6 s)")
	check(not main.use_skill(u, 0), "com as Garras em recarga, o Talho não sai")
	check(not main.get_dot("ferida").is_empty() and is_equal_approx(main.get_dot("ferida")["total"], main.WOUND_TIME), "Garras Cruzadas abre o Ferimento na boss (12 s)")
	await wait(0.45)
	check(u.dmg_total - before < 8.0 and u.dmg_total - before >= 6.0, "e dá um dano bem baixinho: 3 cortes de 2 (%.1f)" % (u.dmg_total - before))
	ready(u)
	main.use_skill(u, 0)
	check(is_equal_approx(u.skill_cd[2], u.skill_cd[0]) and is_equal_approx(u.skill_cd[0], main.WOUND_GCD), "com a boss em Ferimento o Talho recarrega em 0,6 s (e põe as Garras na mesma recarga)")
	var buddy: Unit = main.units[(main.ctrl + 1) % 4]
	before = buddy.dmg_total
	main._damage_boss(buddy, 100.0, false, false)
	check(is_equal_approx(buddy.dmg_total - before, 100.0 * main.WOUND_MULT), "com o Ferimento, a party toda dá +15%% de dano")
	main.remove_dot("ferida")
	before = buddy.dmg_total
	main._damage_boss(buddy, 100.0, false, false)
	check(is_equal_approx(buddy.dmg_total - before, 100.0), "sem o Ferimento, o dano volta ao normal")
	# Dança Carmesim
	ready(u)
	before = u.dmg_total
	var yaw: float = u.visual.rotation.y
	main.use_skill(u, 3)
	check(is_equal_approx(u.dmg_total - before, 95.0), "Dança Carmesim: 95 de dano")
	await wait(0.2)
	check(absf(u.visual.rotation.y - yaw) > 3.0, "e o boneco gira de verdade")
	await wait(0.4)
	check(is_equal_approx(u.visual.rotation.y, yaw), "voltando a olhar pra boss no fim")
	# Golpe de Misericórdia: salto em espiral de 1 s
	u.position = Vector3(2.0, 0, 2.0)
	await frames_of(2)
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 4)
	check(is_equal_approx(u.parry_t, main.MERCY_WINDOW) and is_equal_approx(u.lock_t, 1.0) and is_equal_approx(u.dmg_total, before), "Golpe de Misericórdia: salto de 1 s, o corte ainda não saiu")
	await wait(0.3)
	check(u.position.distance_to(Vector3(2.0, 0, 2.0)) > 0.5 and is_equal_approx(u.dmg_total, before), "ela arremessa a adaga e se puxa por ela até a boss")
	await wait(0.3)
	var slam: float = u.dmg_total - before
	check(slam > 120.0 * main.MERCY_FIRST * 0.95 and slam < 120.0 * 0.6 and main._in_range(u), "a cravada com as duas adagas: 40%% do dano (%.0f)" % slam)
	await wait(0.2)
	check(u.visual.position.y > 1.5 and is_equal_approx(u.dmg_total - before, slam), "depois ela sobe num pulo seco (%.1f)" % u.visual.position.y)
	await wait(0.4)
	var exec: float = 1.0 + main.MERCY_EXEC * (1.0 - (main.boss_hp + (u.dmg_total - before)) / main.boss_max)
	check(absf(u.dmg_total - before - 120.0 * exec) < 1.0 and main._in_range(u), "ela chega na boss e o corte sai: 120 e um pouco pela vida que a boss já perdeu (%.0f)" % (u.dmg_total - before))
	check(u.daggers.size() == 2, "a Assassina tem as duas adagas no boneco")
	# execução: quanto menos vida a boss tem, mais forte; com Ferimento, mais ainda
	u.position = Vector3(2.0, 0, 2.0)
	u.skill_cd[4] = 0.0
	var boss_full: float = main.boss_hp
	main.boss_hp = main.boss_max * 0.25
	before = u.dmg_total
	main.use_skill(u, 4)
	await wait(1.15)
	check(absf(u.dmg_total - before - 120.0 * (1.0 + main.MERCY_EXEC * 0.75)) < 1.0, "boss com 25%% de vida: Misericórdia dá +60%% (%.0f)" % (u.dmg_total - before))
	main.boss_hp = main.boss_max * 0.25
	u.position = Vector3(2.0, 0, 2.0)
	u.skill_cd[4] = 0.0
	main._wound(u)
	main.get_dot("ferida")["t"] = 3.0
	before = u.dmg_total
	main.use_skill(u, 4)
	await wait(1.15)
	check(absf(u.dmg_total - before - 120.0 * (1.0 + main.MERCY_EXEC * 0.75) * main.MERCY_WOUND * main.WOUND_MULT) < 1.5, "com Ferimento na boss: mais +25%% (%.0f)" % (u.dmg_total - before))
	check(main.get_dot("ferida")["t"] > main.WOUND_TIME - 1.0, "e o Ferimento é renovado (na cravada)")
	main.remove_dot("ferida")
	main.boss_hp = boss_full
	check(is_equal_approx(u.visual.position.y, 0.0), "e pousa")
	u.position = Vector3(2.0, 0, 2.0)
	u.skill_cd[4] = 0.0
	before = u.dmg_total
	hp0 = u.hp
	main.use_skill(u, 4)
	await wait(0.3)
	main.hurt(u, 40.0, "teste")
	check(is_equal_approx(u.hp, hp0), "atingida durante o salto: ela apara, o golpe não entra")
	await wait(0.9)
	check(is_equal_approx(u.dmg_total, before), "e aí o corte não dá dano")

	main.use_skill(u, 5)
	await process_frame
	await process_frame
	check(u.frenzy_t > 11.5 and u.frenzy_ring.visible, "Frenesi da Fera: 12 s, com a aura roxa")
	await frames_of(2)
	check(main.hud.party_fx.visible and float(main.hud._party_mat.get_shader_parameter("gain")) > 1.0, "durante o Frenesi a tela pulsa em roxo")
	u.position = right  # lado errado agora (pede esquerda)
	u.skill_cd[0] = 0.0
	u.skill_cd[3] = 5.0
	u.skill_cd[4] = 0.05
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 11.5), "Frenesi: +15% de dano")
	check(is_equal_approx(u.skill_cd[3], 4.7) and is_equal_approx(u.skill_cd[4], 0.0), "Frenesi: cada Talho tira 0,3 s da recarga da Dança e do Misericórdia")
	check(is_equal_approx(u.skill_cd[0], 0.65) and is_equal_approx(u.skill_cd[2], 0.65), "Frenesi: Talho e Garras recarregam na metade do tempo (0,65 s sem Ferimento)")
	u.skill_cd[1] = 0.0
	main.use_skill(u, 1)
	check(is_equal_approx(u.skill_cd[1], 2.5), "Frenesi: o Passo Rasante também (5 s -> 2,5 s)")
	await wait(0.3)
	# Misericórdia em Frenesi: intocável, o corte sai e bate mais forte
	u.position = Vector3(2.0, 0, 2.0)
	u.frenzy_t = 6.0
	u.skill_cd[4] = 0.0
	before = u.dmg_total
	hp0 = u.hp
	main.use_skill(u, 4)
	await wait(0.3)
	main.hurt(u, 40.0, "teste")
	check(is_equal_approx(u.hp, hp0), "Misericórdia em Frenesi: não toma dano no salto")
	await wait(0.9)
	check(u.dmg_total - before >= 120.0 * main.MERCY_FRENZY * main.FRENZY_DMG - 0.5 and u.dmg_total - before < 120.0 * main.MERCY_FRENZY * main.FRENZY_DMG * 1.2, "e o corte sai mesmo assim, mais forte (%.0f)" % (u.dmg_total - before))
	# fim do Frenesi: a Última Dança
	check(is_equal_approx(u.finisher_t, 0.0), "durante o Frenesi a habilidade bônus ainda não existe")
	u.frenzy_t = 0.05
	await wait(0.2)
	check(u.finisher_t > 1.5 and u.finisher_t <= main.FINISH_WINDOW, "quando o Frenesi acaba, abre a janela de 2 s da Última Dança")
	await frames_of(3)
	check(not main.hud.party_fx.visible, "e a tela para de pulsar")
	check(main.hud.skill_ui[5]["ui"].glow and main.hud.skill_ui[5]["ui"].icon == SkillInfo.bonus_icon("assassina") and u.skill_cd[5] > 30.0, "o botão do Frenesi brilha com o ícone da Última Dança, mesmo com o Frenesi em recarga")
	var frenzy_cd: float = u.skill_cd[5]
	before = u.dmg_total
	hp0 = u.hp
	u.frenzy_dmg = 1000.0
	check(main.use_skill(u, 5) and is_equal_approx(u.lock_t, main.FINISH_LOCK) and u.frenzy_t <= 0.0, "apertar: sai a Última Dança (e não outro Frenesi)")
	check(absf(u.skill_cd[5] - frenzy_cd) < 0.1, "sem mexer na recarga do Frenesi")
	await wait(0.35)
	check(u.visual.visible and u.visual.scale.y < 0.9 and is_equal_approx(u.dmg_total, before), "primeiro ela se agacha em posição de ataque por meio segundo")
	await wait(0.95)
	main.hurt(u, 60.0, "teste")
	check(is_equal_approx(u.hp, hp0) or u.invuln > 0.0, "ela é intocável durante a dança")
	var mid: float = u.dmg_total - before
	check(mid > main.FINISH_HIT * 4.0 and mid < main.FINISH_HIT * main.FINISH_HITS * 1.4, "a tempestade de cortes vai batendo (%.0f)" % mid)
	await wait(1.3)
	check(u.dmg_total - before >= main.FINISH_HIT * main.FINISH_HITS + main.FINISH_END, "e fecha com o X gigante: %.0f de dano no total" % (u.dmg_total - before))
	check(not main.get_dot("ferida").is_empty() and u.visual.visible and is_equal_approx(u.visual.position.y, 0.0), "abre o Ferimento, e ela volta ao chão")
	var x_total: float = u.dmg_total - before
	await wait(0.7)
	check(absf(u.dmg_total - before - x_total - 450.0) < 1.0, "o CORTE FINAL devolve 45%% do dano causado no Frenesi (%.0f)" % (u.dmg_total - before - x_total))
	await frames_of(3)
	check(not main.hud.skill_ui[5]["ui"].glow and main.hud.skill_ui[5]["ui"].icon == SkillInfo.icon("assassina", 5), "usada, o botão volta a ser o Frenesi em recarga")
	u.frenzy_t = 0.05
	await wait(2.4)
	check(is_equal_approx(u.finisher_t, 0.0), "sem usar, a janela fecha depois de 2 s")
	check(not main.use_skill(u, 5), "e aí o botão é só o Frenesi, em recarga")
	main.swap_cd = 0.0
	main.set_ctrl(0)
	await process_frame
	await process_frame
	check(not main.side_mark.visible, "a marca do lado só aparece jogando de Assassina")

	# ================================================================ SOULFLAME
	main = await fight(1)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	check(u.key == "healer" and u.unit_name == "Soulflame" and Knowledge.HEROES[1]["name"] == "Soulflame", "a Healer agora se chama Soulflame")
	kit = main.SKILLS["healer"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Fagulha Espiritual", "Toque de Brasa", "Lareira Celestial", "Manto de Cinzas", "Asa da Fênix", "Renascimento"], "Soulflame: as seis da ficha: %s" % [names])
	check(cds == [2.0, 2.0, 18.0, 20.0, 30.0, 60.0], "Soulflame: recargas (Fagulha e Toque de Brasa com 2 s): %s" % [cds])
	for sk in kit:
		var want := 3.0 if sk["name"] == "Renascimento" else 1.2
		check(is_equal_approx(float(sk.get("cast", 0.0)), want), "Soulflame: %s conjura %.1f s" % [sk["name"], want])
	ally = main.units[2]
	var far: Unit = main.units[3]
	ally.position = u.position + Vector3(1.0, 0, 0)
	ally.hold_pos = ally.position
	far.position = u.position + Vector3(0, 0, 7.5) if u.position.z < 0.0 else u.position + Vector3(0, 0, -7.5)
	far.hold_pos = far.position

	before = u.dmg_total
	check(main.use_skill(u, 0) and is_equal_approx(u.channel_t, 1.2) and is_equal_approx(u.dmg_total, before), "Fagulha Espiritual: 1,2 s de conjuração antes de sair")
	Input.action_press("move_left")
	await wait(0.2)
	Input.action_release("move_left")
	check(is_equal_approx(u.channel_t, 0.0) and is_equal_approx(u.skill_cd[0], 0.0), "andar cancela a conjuração sem gastar a recarga")
	u.position = main._atk_pos(u)
	ally.position = u.position + Vector3(1.0, 0, 0)
	ally.hold_pos = ally.position
	await frames_of(2)
	main.use_skill(u, 0)
	await wait(1.35)
	check(is_equal_approx(u.dmg_total - before, 12.0) and u.skill_cd[0] > 1.5, "Fagulha Espiritual bate na boss quando a conjuração termina (recarga de 2 s)")
	ally.hp = 30.0
	main.sel = 2
	main.use_skill(u, 1)
	check(is_equal_approx(u.channel_t, 1.2), "Toque de Brasa: conjuração de 1,2 s")
	await wait(1.35)
	check(is_equal_approx(ally.hp, 30.0 + main.HEAL_PLAYER), "e cura o aliado escolhido (%.0f)" % ally.hp)

	ally.hp = 30.0
	far.hp = 30.0
	sw(main, u, 2)
	check(main.hearths.size() == 1, "Lareira Celestial acende a fogueira")
	await wait(2.3)
	check(ally.hp >= 30.0 + main.HEARTH_HPS * 2.0, "quem está na fogueira é curado por segundo (%.0f)" % ally.hp)
	check(is_equal_approx(far.hp, 30.0), "quem está longe, não")

	sw(main, u, 3)
	check(is_equal_approx(ally.shield_hp, ally.max_hp * main.SHIELD_RATIO) and u.skill_cd[3] > 19.0, "Manto de Cinzas: escudo no aliado, 20 s")
	ally.hp = 5.0
	sw(main, u, 4)
	check(ally.hp >= 5.0 + 95.0 and u.skill_cd[4] > 29.0, "Asa da Fênix: cura grande e na hora (5 -> %.0f)" % ally.hp)

	main.kill(far, "teste")
	ally.hp = 10.0
	before = u.dmg_total
	check(not far.alive, "um aliado caiu")
	sw(main, u, 5)
	check(far.alive, "Renascimento levanta quem caiu")
	check(is_equal_approx(ally.hp, 80.0), "cura todos (10 -> %.0f)" % ally.hp)
	check(is_equal_approx(u.dmg_total, before) and main.get_dot("brasa").is_empty(), "a fênix nasce e grita antes de avançar: ainda sem dano na boss")
	check(main.hearths.size() == 1 and main.hearths[0]["strong"], "a fênix nasce da Lareira, e a Lareira fica FORTE em vez de sumir")
	check(is_equal_approx(main.hearths[0]["r"], main.HEARTH_STRONG_R) and is_equal_approx(main.hearths[0]["hps"], main.HEARTH_STRONG_HPS) and main.hearths[0]["t"] > main.HEARTH_STRONG_TIME - 0.5, "mais alcance, mais cura e dura de novo")
	far.position = main.hearths[0]["node"].position + Vector3(0, 0, 6.0)
	far.hold_pos = far.position
	far.hp = 20.0
	await wait(1.2)
	check(far.hp >= 20.0 + main.HEARTH_STRONG_HPS, "a Lareira forte cura quem está a 6 m (a normal alcança 4,5) e cura mais (%.0f)" % far.hp)
	check(is_equal_approx(u.dmg_total, before), "1,2 s depois ela ainda está a caminho")
	await wait(main.REBIRTH_BIRTH + main.REBIRTH_CRY + main.REBIRTH_FLY - 1.2 + 0.2)
	check(is_equal_approx(u.dmg_total - before, main.REBIRTH_DMG), "quando a fênix chega: queima a boss com dano médio")
	check(not main.get_dot("brasa").is_empty(), "e deixa um DoT na boss")
	await process_frame
	await process_frame
	check(main.hud.dot_ui.has("brasa"), "o DoT aparece embaixo da vida da boss, com o tempo")
	before = u.dmg_total
	await wait(2.3)
	check(u.dmg_total - before >= main.REBIRTH_DOT * 2.0, "o DoT dá 6 por segundo")
	check(u.skill_cd[5] > 48.0, "Renascimento: recarga de 60 s")
	# IA: a recarga do Toque de Brasa é maior, pra ela não virar uma metralhadora de cura
	u.skill_cd[1] = 0.0
	ally.hp = 20.0
	main.use_skill(u, 1, true, ally)
	await wait(1.65)
	check(u.skill_cd[1] > 3.0, "na mão da IA, o Toque de Brasa tem recarga maior")

	# ================================================================ MAGA
	main = await fight(3)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	kit = main.SKILLS["maga"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
		check(sk.has("cast") == (sk["name"] == "Canhão Estelar"), "Maga: só o Canhão Estelar conjura (%s)" % sk["name"])
	check(names == ["Disparo Rúnico", "Rainbow Shots", "Ricochete Prismático", "Tiro Perfurante", "Salva Astral", "Canhão Estelar"], "Maga: as seis da ficha: %s" % [names])
	check(cds == [1.0, 0.3, 8.0, 12.0, 0.0, 60.0], "Maga: recargas (Rainbow Shots só tem o intervalo de 0,3 s; a Salva Astral não tem recarga): %s" % [cds])
	check(u.gun != null, "a Maga tem a pistola na mão")
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 26.0), "Disparo Rúnico sai na hora")
	check(u.bullets.is_empty(), "começa sem balas")
	before = u.dmg_total
	check(not main.use_skill(u, 1) and is_equal_approx(u.dmg_total, before) and is_equal_approx(u.skill_cd[1], 0.0), "Rainbow Shots sem bala não sai (nem gasta o intervalo)")
	await frames_of(3)
	check(not main.hud.skill_ui[1]["ui"].usable, "e o botão fica apagado sem balas")
	u.bullets = [0]
	await frames_of(3)
	check(main.hud.skill_ui[1]["ui"].usable, "com uma bala o botão acende")
	u.bullets = []
	u.bullet_t = main.BULLET_EVERY - 0.1
	await wait(0.3)
	check(u.bullets.size() == 1, "a passiva dá uma bala a cada 8 s")
	await frames_of(3)
	check(main.hud.bullet_row != null and main.hud.bullet_row.visible, "as balas aparecem em cima da barra de habilidades")
	# cada cor faz uma coisa
	ready(u)
	u.bullets = [0]
	before = u.dmg_total
	main.use_skill(u, 1)
	check(is_equal_approx(u.dmg_total - before, main.BULLET_DMG) and u.bullets.is_empty(), "uma bala: 40 de dano")
	check(is_equal_approx(u.skill_cd[1], 0.3), "intervalo de 0,3 s entre balas")
	check(u.power_t > 0.0, "bala vermelha: mais dano por um tempo")
	check(u.pierce_next and main.glow_slot(u) == 0, "depois de uma bala, o Disparo Rúnico fica fortalecido (e o botão brilha)")
	u.power_t = 0.0
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 26.0 * main.PIERCE_MULT) and not u.pierce_next, "Disparo fortalecido: +50%, uma vez")
	ready(u)
	u.bullets = [1]
	main.use_skill(u, 1)
	hp0 = u.hp
	main.hurt(u, 40.0, "teste")
	check(is_equal_approx(hp0 - u.hp, 30.0), "bala azul: toma 25% menos dano")
	ready(u)
	u.bullets = [2]
	u.hp = 50.0
	main.use_skill(u, 1)
	check(is_equal_approx(u.hp, 70.0), "bala verde: recupera 20 de vida")
	ready(u)
	u.bullets = [3]
	main.use_skill(u, 1)
	check(not main.get_dot("veneno").is_empty(), "bala roxa: DoT na boss")
	ready(u)
	u.bullets = [4]
	main.use_skill(u, 1)
	check(u.dash_next, "bala amarela: prepara o dash")
	ready(u)
	var z0: float = u.position.distance_to(main.BOSS_POINT)
	main.use_skill(u, 0)
	await wait(0.25)
	check(u.position.distance_to(main.BOSS_POINT) > z0 + 1.5 or u.position.length() > main.ARENA_R - 0.3, "o próximo Disparo dá o dash pra trás")
	# exatamente 3: tiro triplo com empurrão
	u.position = Vector3(1.6, 0, -1.0)
	ready(u)
	u.bullets = [0, 1, 2]
	before = u.dmg_total
	z0 = u.position.distance_to(main.BOSS_POINT)
	main.use_skill(u, 1)
	await wait(0.25)
	check(is_equal_approx(u.dmg_total - before, main.BULLET_TRIPLE) and u.bullets.is_empty(), "com exatamente 3 balas: um tiro forte que gasta as 3")
	check(u.position.distance_to(main.BOSS_POINT) > z0 + 3.0, "e ela é empurrada pra trás")
	u.bullets = [0, 0, 0, 0, 0, 0, 0]
	u.bullet_t = main.BULLET_EVERY - 0.1
	await wait(0.3)
	check(u.bullets.size() == 8, "a oitava bala entra")
	u.bullet_t = 5.0
	await wait(0.2)
	check(u.bullets.size() == 8 and main.BULLET_MAX == 8, "no máximo 8 balas")
	# ricochete
	u.bullets = []
	u.power_t = 0.0
	u.position = Vector3(1.6, 0, 1.2)
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 2)
	check(is_equal_approx(u.dmg_total - before, 30.0) and u.ricochet_t <= 0.0, "Ricochete de longe: um tiro só")
	u.position = Vector3(1.3, 0, -6.0)
	ready(u)
	u.hp = 50.0
	u.salvo_t = 0.0
	before = u.dmg_total
	main.use_skill(u, 2)
	var rico_dmg: float = u.dmg_total - before  # medido na hora: DoTs antigos na boss continuam contando
	await wait(1.2)
	check(u.ricochet_t <= 0.0 and is_equal_approx(rico_dmg, 30.0) and u.hp <= 50.0 and u.shield_hp <= 0.0, "Ricochete perto da boss SEM o escudo da Salva: um tiro só, não volta nela")
	# com o escudo da Salva Astral de pé, a bala volta nela
	ready(u)
	u.bullets = [0, 1, 2]
	main.use_skill(u, 4)
	check(u.salvo_t > 0.0 and u.shield_hp > 0.0, "a Salva Astral ergue o escudo que habilita o ricochete")
	u.hp = 50.0
	before = u.dmg_total
	main.use_skill(u, 2)
	check(u.ricochet_t > 3.5, "Ricochete perto da boss com o escudo da Salva: a bala fica indo e voltando por 4 s")
	await wait(2.2)
	check(u.dmg_total - before >= main.RICO_DMG * 2.0 and u.hp > 50.0, "cada ida bate na boss, cada volta cura a Maga (%.0f de dano, vida %.0f)" % [u.dmg_total - before, u.hp])
	# a boss bate em outro herói enquanto isso, pra não gastar o escudo que está sendo medido
	main.units[0].enmity = 999999.0
	u.hp = u.max_hp
	u.shield_hp = 1.0
	var got_shield := false
	var until := Time.get_ticks_msec() + 1300
	while Time.get_ticks_msec() < until:
		await process_frame
		u.hp = u.max_hp
		if u.shield_hp > 1.0:
			got_shield = true
	check(got_shield, "com a vida cheia, a cura vira escudo")
	await wait(1.2)
	check(u.ricochet_t <= 0.0, "e acaba depois de 4 s")
	ready(u)
	u.shield_hp = 0.0
	main.use_skill(u, 2)
	await wait(0.8)
	check(u.ricochet_t <= 0.0 and u.salvo_t <= 0.0, "escudo quebrado: o ricochete nela deixa de existir")
	u.position = Vector3(1.6, 0, 1.2)
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 3)
	check(is_equal_approx(u.dmg_total - before, 95.0), "Tiro Perfurante")
	check(is_equal_approx(main.aim_t, main.AIM_TIME) and not main.get_dot("mira").is_empty() and is_instance_valid(main.aim_node), "o Tiro Perfurante marca a boss por 2 s (mira em cima dela e ícone na barra)")
	await wait(1.9)
	check(main.aim_t > 0.0, "com 1,9 s a marca ainda está lá")
	await wait(0.25)
	check(main.aim_t <= 0.0 and main.get_dot("mira").is_empty() and main.aim_node == null, "e some sozinha depois de 2 s")
	# Salva Astral: sem recarga, custa 3 balas
	u.bullets = [0, 1]
	before = u.dmg_total
	await frames_of(3)
	check(not main.use_skill(u, 4) and is_equal_approx(u.dmg_total, before) and u.bullets.size() == 2, "Salva Astral com menos de 3 balas não sai")
	check(not main.hud.skill_ui[4]["ui"].usable, "e o botão fica apagado")
	u.bullets = [0, 1, 2, 3, 4, 0, 1]
	await frames_of(3)
	check(main.hud.skill_ui[4]["ui"].usable, "com 3 ou mais balas o botão acende")
	u.shield_hp = 0.0
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total - before, main.SALVO_DMG * 3.0) and u.bullets.size() == 4, "Salva Astral: consome exatamente 3 balas")
	check(is_equal_approx(u.shield_hp, main.SALVO_SHIELD), "e dá um escudo nela")
	check(is_equal_approx(u.skill_cd[4], 0.0), "sem recarga: com balas, dá pra usar de novo na hora")
	check(main.use_skill(u, 4) and u.bullets.size() == 1 and not main.use_skill(u, 4), "segunda Salva gasta mais 3; com 1 bala sobrando, a terceira não sai")
	check(String(SkillInfo.info("maga", 4)["desc"]).begins_with("Consome 3 Rainbow Shots."), "a descrição diz: Consome 3 Rainbow Shots.")
	# Salva com exatamente 6 balas: Fada Astral
	main._aim_clear()
	ready(u)
	u.bullets = [0, 1, 2, 3, 4, 0, 1]
	await frames_of(3)
	check(not main.hud.skill_ui[4]["ui"].glow, "com 7 balas a Salva não brilha")
	u.bullets = [0, 1, 2, 3, 4, 0]
	await frames_of(3)
	check(main.hud.skill_ui[4]["ui"].glow, "com exatamente 6 balas a Salva brilha")
	before = u.dmg_total
	main.use_skill(u, 4)
	check(u.bullets.is_empty() and is_equal_approx(u.dmg_total - before, main.SALVO_DMG * 6.0), "Salva com 6: gasta as 6")
	check(main.fairy_t > 14.9 and is_instance_valid(main.fairy_node) and not main.get_dot("fada").is_empty(), "e solta a Fada Astral por 15 s (DoT na boss)")
	before = u.dmg_total
	await wait(2.1)
	check(u.dmg_total - before >= main.FAIRY_DPS * 2.0 - 0.5, "a fada dá dano por segundo (%.0f em 2 s)" % (u.dmg_total - before))
	# ricochete na fada: de longe, sem escudo, e curando a party
	u.position = Vector3(1.6, 0, 3.0)
	u.salvo_t = 0.0
	u.shield_hp = 0.0
	for o in main.units:
		o.hp = o.max_hp * 0.5
		o.shield_hp = 0.0
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 2)
	check(u.ricochet_t > 3.5, "com a fada em campo, o Ricochete quica (mesmo longe e sem o escudo da Salva)")
	await wait(1.4)
	var healed_all := true
	for o in main.units:
		if o.hp <= o.max_hp * 0.5:
			healed_all = false
	check(healed_all, "cada bala que bate na fada cura a party toda")
	check(u.dmg_total - before >= main.RICO_DMG * 2.0, "e cada ida bate na boss")
	for o in main.units:
		o.hp = o.max_hp
		o.shield_hp = 0.0
	await wait(1.1)
	check(main.units[0].shield_hp > 0.0 and main.units[0].shield_hp <= main.units[0].max_hp * main.FAIRY_HEAL * 3.0, "com a vida cheia, a cura da fada vira escudo (pequeno: 5%% por bala)")
	await wait(1.8)
	check(u.ricochet_t <= 0.0, "o ricochete na fada acaba no tempo normal")
	main.fairy_t = 0.05
	await wait(0.2)
	check(main.fairy_node == null and main.get_dot("fada").is_empty(), "depois dos 15 s a fada vai embora e o DoT some")
	u.bullets = [0, 1, 2, 3, 4, 0, 1, 2]
	await frames_of(3)
	check(main.hud.skill_ui[5]["ui"].glow and main.hud.skill_ui[5]["ui"].rainbow, "com 8 balas o Canhão Estelar brilha em arco-íris")
	u.bullets = []
	u.position = Vector3(1.6, 0, 1.2)
	await frames_of(3)
	check(not main.hud.skill_ui[5]["ui"].glow, "e apaga sem o pente cheio")
	# marca + consumidores: o bônus sai uma vez só
	ready(u)
	main.use_skill(u, 3)
	u.bullets = [0, 1, 2, 3, 4, 0, 1]  # sete: com seis exatas sairia a fada
	before = u.dmg_total
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total - before, main.SALVO_DMG * 3.0 + main.AIM_BONUS) and main.aim_t <= 0.0, "Salva Astral na boss marcada: estoura a marca (+%d)" % main.AIM_BONUS)
	before = u.dmg_total
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total - before, main.SALVO_DMG * 3.0), "a mesma marca não dá o bônus duas vezes")
	ready(u)
	main.use_skill(u, 3)
	u.pierce_next = false
	before = u.dmg_total
	ready(u)
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 26.0) and main.aim_t > 0.0, "Disparo Rúnico comum não gasta a marca")
	u.pierce_next = true
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 26.0 * main.PIERCE_MULT + main.AIM_BONUS) and main.aim_t <= 0.0, "Disparo Rúnico fortalecido estoura a marca")
	# Canhão Estelar: preparo de 2 s, parada
	u.bullets = []
	ready(u)
	before = u.dmg_total
	check(main.use_skill(u, 5) and is_equal_approx(u.channel_t, 2.0) and u.has_meta("cannon"), "Canhão Estelar: 2 s de preparo, com o canhão se materializando")
	await wait(1.0)
	check(is_equal_approx(u.dmg_total, before), "com 1 s de preparo ainda não disparou")
	Input.action_press("move_left")
	await wait(0.2)
	Input.action_release("move_left")
	check(is_equal_approx(u.channel_t, 0.0) and not u.has_meta("cannon") and is_equal_approx(u.skill_cd[5], 0.0), "andar cancela o preparo, some com o canhão e não gasta a recarga")
	u.position = Vector3(1.6, 0, 1.2)
	await frames_of(2)
	main.use_skill(u, 5)
	await wait(2.15)
	check(is_equal_approx(u.dmg_total - before, main.CANNON_DMG) and u.lock_t <= 0.0, "Canhão Estelar sozinho: %d, sem prender ela" % main.CANNON_DMG)
	ready(u)
	u.bullets = [0, 1, 2, 3, 4, 0, 1]
	before = u.dmg_total
	sw(main, u, 5)
	var cannon: float = u.dmg_total - before
	check(is_equal_approx(cannon, main.CANNON_DMG + 7.0 * main.CANNON_PER_BULLET) and u.bullets.is_empty() and u.lock_t <= 0.0, "Canhão com 7 balas: %.0f, versão normal" % cannon)
	check(cannon > main.CANNON_DMG + 7.0 * main.BULLET_DMG, "guardar as balas pro canhão rende mais do que soltar as 7 e usar o canhão vazio")
	# marca usada no começo do preparo
	ready(u)
	main.use_skill(u, 3)
	before = u.dmg_total
	ready(u)
	main.use_skill(u, 5)
	check(main.aim_t <= 0.0 and is_equal_approx(u.cannon_bonus, main.AIM_BONUS), "começar o Canhão na boss marcada trava o bônus da marca")
	u.channel_t = 0.0
	main._resolve_skill(u, 5, false)
	check(is_equal_approx(u.dmg_total - before, main.CANNON_DMG + main.AIM_BONUS), "e ele sai junto com o disparo")
	# supercanhão: exatamente 8 balas
	await wait(0.4)
	u.position = Vector3(1.6, 0, 1.2)
	ready(u)
	u.bullets = [0, 1, 2, 3, 4, 0, 1, 2]
	before = u.dmg_total
	var gun_at: Vector3 = u.position
	sw(main, u, 5)
	check(is_equal_approx(u.lock_t, main.CANNON_SUPER_TIME) and u.bullets.is_empty(), "com exatamente 8 balas: supercanhão, ela fica 2 s presa no lugar")
	check(not main.use_skill(u, 0), "segurando o supercanhão, não usa mais nada")
	Input.action_press("move_left")
	await wait(1.0)
	Input.action_release("move_left")
	check(u.position.is_equal_approx(gun_at), "nem anda")
	var half: float = u.dmg_total - before
	var super_total: float = main.CANNON_DMG + 8.0 * main.CANNON_PER_BULLET + main.CANNON_SUPER_BONUS
	check(half > super_total * 0.3 and half < super_total * 0.75, "o dano do supercanhão sai ao longo do disparo (%.0f de %.0f na metade)" % [half, super_total])
	await wait(1.3)
	check(is_equal_approx(u.dmg_total - before, super_total), "supercanhão: %.0f no total" % super_total)
	check(u.lock_t <= 0.0 and super_total > cannon + main.CANNON_PER_BULLET, "depois ela se solta; e a oitava bala rende bem mais que as outras")

	# ================================================================ SOULBURNER
	main = await fight(5)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	check(u.key == "burner" and u.unit_name == "Soulburner" and not u.melee, "Soulburner entra na luta (classe nova, à distância)")
	kit = main.SKILLS["burner"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Brasas do Firmamento", "Marca do Zênite", "Lança Serafim", "Rasante Incandescente", "Chuva de Brasas", "Juízo Solar"], "Soulburner: as seis da ficha: %s" % [names])
	check(cds == [2.0, 12.0, 8.0, 10.0, 20.0, 60.0], "Soulburner: recargas da ficha: %s" % [cds])
	before = u.dmg_total
	check(main.use_skill(u, 0) and is_equal_approx(u.channel_t, 1.0) and is_equal_approx(u.dmg_total, before), "Brasas do Firmamento: 1 s de cast")
	await wait(1.1)
	check(is_equal_approx(u.dmg_total - before, 24.0), "e o projétil sai no fim do cast: 24 de dano")
	check(u.skill_cd[0] > 0.7 and u.skill_cd[0] <= 1.0, "a recarga de 2 s conta desde o começo do cast (%.2f)" % u.skill_cd[0])
	ready(u)
	check(u.wings.size() == 2, "o Soulburner tem as duas asas")
	before = u.dmg_total
	check(main.use_skill(u, 2) and is_equal_approx(u.channel_t, 1.0) and u.has_meta("lance"), "Lança Serafim: 1 s de cast, com a lança se formando no céu")
	await wait(1.0 + main.LANCE_FALL + 0.15)
	check(is_equal_approx(u.dmg_total - before, main.LANCE_BARE), "Lança Serafim sem marca: quase nada (%d), no impacto" % main.LANCE_BARE)
	ready(u)
	main.use_skill(u, 1)
	check(not main.get_dot("zenite").is_empty() and is_equal_approx(main.get_dot("zenite")["t"], 10.0), "Marca do Zênite: 10 s na boss")
	check(absf(main.lance_damage() - main.LANCE_MIN) < 3.0, "Lança logo depois de marcar: dano médio (%.0f)" % main.lance_damage())
	check(main.glow_slot(u) != 2, "no começo da marca o botão da Lança não brilha")
	await frames_of(3)
	var sun_ui = main.hud.skill_ui[5]["ui"]
	check(sun_ui.glow and sun_ui.glow_color.g > 0.9 and sun_ui.glow_color.r < 0.5, "boss marcada e Juízo Solar pronto: o botão dele brilha em fogo verde")
	var dim: float = main.zenith_mats[0].albedo_color.g
	main.get_dot("zenite")["t"] = 0.5
	check(main.glow_slot(u) == 2, "nos últimos 2 s da marca o botão da Lança brilha")
	await frames_of(3)
	check(main.zenith_node.get_node("Core").visible and main.zenith_mats[0].albedo_color.g > dim * 2.5, "e o halo fica bem mais luminoso no fim, com o miolo de luz aceso (%.1f -> %.1f)" % [dim, main.zenith_mats[0].albedo_color.g])
	check(main.lance_damage() > main.LANCE_MAX - 8.0, "Lança com a marca quase acabando: dano alto (%.0f)" % main.lance_damage())
	check(is_instance_valid(main.zenith_node), "a marca tem o halo em cima da boss")
	ready(u)
	before = u.dmg_total
	var expect: float = main.lance_damage()
	main.use_skill(u, 2)
	check(absf(u.lance_amount - expect) < 1.0 and u.lance_marked, "o dano da Lança é travado quando o cast começa")
	check(u.get_meta("lance_grade") == 2, "marca nos últimos instantes: Lança Perfeita (grau 2, com o fogo em volta dela)")
	await wait(0.7)
	check(main.get_dot("zenite").is_empty() and is_equal_approx(u.dmg_total, before + 0.0) or main.get_dot("zenite").is_empty(), "a marca expira no meio do cast (faltava 0,5 s)")
	var dot_part: float = u.dmg_total - before
	await wait(0.3 + main.LANCE_FALL + 0.15)
	check(absf(u.dmg_total - before - dot_part - expect) < 1.5, "e a Lança ainda sai com o bônus cheio (%.0f)" % expect)
	await frames_of(2)
	check(main.zenith_node == null, "o halo some com a marca")
	# andar cancela o cast sem gastar
	ready(u)
	main.use_skill(u, 2)
	Input.action_press("move_left")
	await wait(0.2)
	Input.action_release("move_left")
	check(is_equal_approx(u.channel_t, 0.0) and not u.has_meta("lance") and is_equal_approx(u.skill_cd[2], 0.0), "andar cancela a Lança, some com ela e não gasta a recarga")
	u.position = main._atk_pos(u)
	await frames_of(2)
	ready(u)
	main.use_skill(u, 1)
	before = u.dmg_total
	await wait(2.2)
	check(u.dmg_total - before >= main.ZENITH_DPS * 2.0, "a marca é um DoT leve (5 por segundo)")
	await frames_of(3)
	check(main.hud.dot_ui.has("zenite"), "a marca aparece embaixo da vida da boss, com o tempo")
	var p0: Vector3 = u.position
	before = u.dmg_total
	main.use_skill(u, 3)
	await wait(0.25)
	check(u.position.distance_to(p0) > 3.0, "Rasante Incandescente: dash rápido")
	main.use_skill(u, 4)
	check(not main.get_dot("chuva").is_empty() and is_equal_approx(main.get_dot("chuva")["total"], 15.0), "Chuva de Brasas: DoT de 15 s")
	check(main.rain_t > 14.0 and is_instance_valid(main.rain_node), "a chuva cai pelos 15 s, com o círculo no céu")
	main.remove_dot("zenite")
	main.remove_dot("chuva")
	u.position = main._atk_pos(u)
	await frames_of(2)
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 5)
	check(is_equal_approx(u.lock_t, main.SOLAR_RISE) and is_equal_approx(u.dmg_total, before), "Juízo Solar: sobe por 1 s (preso) e ainda sem dano")
	check(not main.use_skill(u, 0), "subindo, ele não usa outra habilidade")
	await wait(1.3)
	check(u.visual.position.y > 2.0 and u.lock_t <= 0.0, "depois de lançar ele flutua (%.1f) e já está solto" % u.visual.position.y)
	ready(u)
	var sun_before: float = u.dmg_total
	check(main.use_skill(u, 0) and u.channel_t > 0.0, "flutuando, as outras habilidades funcionam")
	await frames_of(3)
	check(not main.hud.skill_ui[5]["ui"].glow, "com o Juízo Solar em recarga, o botão dele não brilha")
	await wait(1.9)
	check(is_equal_approx(u.dmg_total - before, main.SOLAR_DMG + 24.0) and main.get_dot("solar").is_empty(), "o sol chega 2 s depois do lançamento: %d, sem DoT sem a marca" % main.SOLAR_DMG)
	await wait(0.6)
	check(is_equal_approx(u.visual.position.y, 0.0), "e ele volta pro chão")
	ready(u)
	main.use_skill(u, 1)
	main.use_skill(u, 5)
	main.remove_dot("zenite")  # a marca valeu na hora do uso
	await wait(0.05)
	before = u.dmg_total
	await wait(3.1)
	check(is_equal_approx(u.dmg_total - before, main.SOLAR_MARKED), "Juízo Solar com a boss marcada na hora do uso: mais dano (%d)" % main.SOLAR_MARKED)
	check(not main.get_dot("solar").is_empty(), "e deixa o DoT")
	ready(u)
	main.use_skill(u, 1)
	u.skill_cd[5] = 0.0
	main.use_skill(u, 5)
	check(not main.get_dot("zenite").is_empty(), "o Juízo Solar NÃO gasta a marca")

	# ================================================================ RINGSTAR
	main = await fight(6)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	check(u.key == "ringstar" and u.unit_name == "Ringstar" and u.melee, "Ringstar entra na luta (classe nova, corpo a corpo)")
	kit = main.SKILLS["ringstar"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Jab Estelar", "Direto de Campeã", "Gancho Meteoro", "Contagem Regressiva", "SUPERSTAR!", "Nocaute Final"], "Ringstar: as seis da ficha: %s" % [names])
	check(cds == [2.0, 2.0, 2.0, 14.0, 20.0, 60.0], "Ringstar: recargas da ficha: %s" % [cds])
	check(main._in_range(u), "começa ao alcance da boss")
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 22.0) and main.glow_slot(u) == 1, "Jab Estelar fortalece o Direto (o botão 2 brilha)")
	check(is_equal_approx(u.skill_cd[0], 2.0) and is_equal_approx(u.skill_cd[1], 2.0) and is_equal_approx(u.skill_cd[2], 2.0), "os três golpes dividem o GCD de 2 s")
	await frames_of(3)
	check(main.hud.skill_ui[1]["ui"].glow and not main.hud.skill_ui[0]["ui"].glow, "na barra, só o botão fortalecido brilha")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 1)
	check(is_equal_approx(u.dmg_total - before, 40.0) and main.glow_slot(u) == 2, "Direto fortalecido: dano cheio, e fortalece o Gancho")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 2)
	check(is_equal_approx(u.dmg_total - before, 70.0) and main.glow_slot(u) == -1, "Gancho fortalecido: dano alto e a sequência recomeça")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 1)
	check(is_equal_approx(u.dmg_total - before, main.WEAK_HIT) and main.glow_slot(u) == -1, "Direto sem Jab: dano mínimo e NÃO fortalece o Gancho")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 2)
	check(is_equal_approx(u.dmg_total - before, main.WEAK_HIT), "Gancho sem fortalecer: dano mínimo")
	ready(u)
	main.use_skill(u, 0)
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 2)
	check(is_equal_approx(u.dmg_total - before, main.WEAK_HIT) and main.glow_slot(u) == -1, "golpe errado no meio (Jab e depois Gancho): perde o fortalecimento")
	# oGCD no meio não quebra
	ready(u)
	main.use_skill(u, 0)
	before = u.dmg_total
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total, before) and main.glow_slot(u) == 1, "SUPERSTAR! no meio da sequência não quebra o fortalecimento (e o dano não sai na hora)")
	await wait(0.9)
	check(is_equal_approx(u.dmg_total, before), "SUPERSTAR!: 1 s de preparo com o microfone, ainda sem dano")
	await wait(1.3)
	check(is_equal_approx(u.dmg_total - before, main.SUPERSTAR_DMG), "e a rajada sai no segundo seguinte: %d no total" % main.SUPERSTAR_DMG)
	check(u.gloves.size() == 2, "a Ringstar tem as duas luvas no boneco")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 1)
	check(is_equal_approx(u.dmg_total - before, 40.0), "e o Direto continua fortalecido depois do oGCD")
	# de longe: SUPERSTAR funciona, Jab não; Contagem aproxima
	u.position = Vector3(0, 0, 4.0)
	ready(u)
	u.chain = 0
	before = u.dmg_total
	check(not main.use_skill(u, 0), "de longe, o Jab não alcança")
	main.use_skill(u, 4)
	await wait(2.2)
	check(is_equal_approx(u.dmg_total - before, main.SUPERSTAR_DMG), "SUPERSTAR! funciona de longe")
	main.use_skill(u, 3)
	await wait(0.25)
	check(main._in_range(u) and u.count_t > 14.0, "Contagem Regressiva: avança até a boss e liga o buff de 15 s")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 22.0 * main.COUNT_DMG), "com a Contagem: +10% de dano")
	check(is_equal_approx(u.skill_cd[0], main.COUNT_GCD) and is_equal_approx(u.skill_cd[2], main.COUNT_GCD), "e o GCD cai pra 1 s")
	check(is_equal_approx(main.move_speed(u), 6.5 * 0.6 * 1.44), "com a Contagem: +44% de velocidade de movimento")
	var count_left: float = u.count_t
	u.count_t = 0.0
	check(is_equal_approx(main.move_speed(u), 6.5 * 0.6), "sem a Contagem, a velocidade volta ao normal")
	u.count_t = count_left
	u.count_t = 0.0
	before = u.dmg_total
	main.use_skill(u, 5)
	check(u.air_t > 0.0, "Nocaute Final: salta (o resto está no bloco NOCAUTE FINAL)")

	# ================================================================ VALSA
	main = await fight(9)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	check(u.key == "valsa" and u.unit_name == "Valsa" and u.melee, "Valsa entra na luta (classe nova, suporte corpo a corpo)")
	kit = main.SKILLS["valsa"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Passo de Valsa", "Passo a Dois", "Pirueta", "Chuva de Pétalas", "Crescendo", "Grande Baile"], "Valsa: as seis da ficha: %s" % [names])
	check(cds == [1.2, 8.0, 9.0, 18.0, 30.0, 60.0], "Valsa: recargas da ficha: %s" % [cds])
	check(u.skirt != null and u.hands.size() == 2 and u.curls.size() == 2 and u.aura != null and u.rose_orbit.get_child_count() == main.EMBALO_MAX, "o boneco dela tem a saia, as mãos, os cachos, a roseta no chão e as rosas do Embalo")
	for n in 6:
		check(SkillInfo.icon("valsa", n) != null and String(SkillInfo.info("valsa", n)["desc"]) != "", "ícone e ficha do slot %d" % (n + 1))
	check(main._in_range(u), "começa ao alcance da boss")
	# o compasso: um, dois, TRÊS
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 16.0) and u.waltz_step == 1 and u.embalo == 0 and main.glow_slot(u) == -1, "primeiro passo: 16 de dano, sem Embalo")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 16.0) and main.glow_slot(u) == 0, "segundo passo: 16, e o botão brilha (o próximo é o Giro)")
	await frames_of(3)
	check(main.hud.skill_ui[0]["ui"].glow, "na barra, o Passo de Valsa brilha antes do Giro")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, main.WALTZ_GIRO) and u.embalo == 1 and u.waltz_step == 0 and main.glow_slot(u) == -1, "terceiro tempo, o Giro: %d de dano, +1 de Embalo e o compasso recomeça" % main.WALTZ_GIRO)
	check(is_equal_approx(u.skill_cd[0], 1.2), "o Passo de Valsa recarrega em 1,2 s")
	for n in 3:
		ready(u)
		before = u.dmg_total
		main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, main.WALTZ_GIRO + main.WALTZ_GIRO_PER) and u.embalo == 2, "o Giro seguinte bate mais (%d por ponto de Embalo) e o Embalo vai a 2" % main.WALTZ_GIRO_PER)
	check(is_equal_approx(main.skirt_r(u), main.SKIRT_R + 2.0 * main.SKIRT_R_PER), "a saia abre com o Embalo: raio %.1f" % main.skirt_r(u))
	# o bônus é de quem está dentro da saia
	var v_ally: Unit = main.units[(main.ctrl + 1) % 4]
	var v_near: Vector3 = u.position + Vector3(1.0, 0, 0)
	v_ally.position = v_near
	check(is_equal_approx(main.valsa_bonus(v_ally), main.SKIRT_BONUS + 2.0 * main.SKIRT_BONUS_PER), "aliado dentro da saia: +%d%% de dano com 2 de Embalo" % roundi(main.valsa_bonus(v_ally) * 100.0))
	check(main.valsa_bonus(u) == 0.0, "ela não fortalece a si mesma")
	var v_a0: float = v_ally.dmg_total
	main._damage_boss(v_ally, 100.0, false, false)
	var v_in: float = v_ally.dmg_total - v_a0
	v_ally.position = u.position + Vector3(main.skirt_r(u) + 1.0, 0, 0)
	check(main.valsa_bonus(v_ally) == 0.0, "fora da saia: sem bônus")
	v_a0 = v_ally.dmg_total
	main._damage_boss(v_ally, 100.0, false, false)
	check(is_equal_approx(v_in / (v_ally.dmg_total - v_a0), 1.1), "o mesmo golpe do aliado sai 10% maior dentro da saia")
	main._tick_valsa_view(0.0)
	check(u.aura.visible and not main.valsa_marks[v_ally.idx].visible and not main.valsa_marks[u.idx].visible, "no mundo: a roseta dela aparece; quem está fora não tem a voluta nos pés")
	v_ally.position = v_near
	main._tick_valsa_view(0.0)
	check(main.valsa_marks[v_ally.idx].visible, "... e quem está dentro tem")
	# Passo a Dois
	v_ally.position = Vector3(0, 0, 6.0)
	ready(u)
	before = u.dmg_total
	v_a0 = v_ally.dmg_total
	var v_hp: float = v_ally.max_hp - 50.0
	v_ally.hp = v_hp
	check(main.use_skill(u, 1, false, v_ally) and u.partner == v_ally, "Passo a Dois: o aliado vira o Par")
	check(is_equal_approx(u.dmg_total - before, main.DUET_DMG) and main.glow_slot(u) == 0, "ela acerta %d e o próximo Passo de Valsa já é o Giro" % main.DUET_DMG)
	check(v_ally.hp >= v_hp + main.DUET_HEAL - 0.01, "o Par recupera %d de vida" % main.DUET_HEAL)
	check(main.valsa_bonus(v_ally) > 0.0, "o Par recebe o bônus da saia de qualquer lugar da arena")
	await wait(0.4)
	check(v_ally.dmg_total - v_a0 >= main.DUET_DMG, "e o Par acerta a boss junto (%d a mais no DPS dele)" % int(v_ally.dmg_total - v_a0))
	check(main.valsa_threads.has(u.idx) and main.valsa_threads[u.idx]["root"].visible, "o fio dourado liga as duas")
	ready(u)
	v_a0 = v_ally.dmg_total
	main.use_skill(u, 0)
	await wait(0.4)
	check(u.embalo == 3 and v_ally.dmg_total - v_a0 >= main.DUET_ECHO + main.DUET_ECHO_PER * 3.0, "no Giro, o Par acompanha com um golpe dele")
	# Pirueta e BRAVO!
	ready(u)
	u.shield_hp = 0.0
	main.use_skill(u, 2)
	check(u.twirl_t > 0.0 and u.embalo == 4, "Pirueta: gira por %.1f s e rende 1 de Embalo" % main.TWIRL_TIME)
	var v_hp0: float = u.hp
	var v_cd: float = u.skill_cd[2]
	main.hurt(u, 30.0, "teste")
	check(is_equal_approx(u.hp, v_hp0) and u.embalo == 5 and is_equal_approx(u.skill_cd[2], v_cd * main.TWIRL_REFUND), "BRAVO!: o golpe passa por ela, o Embalo sobe e a recarga cai pela metade")
	main.hurt(u, 30.0, "teste")
	check(is_equal_approx(u.hp, v_hp0) and is_equal_approx(u.skill_cd[2], v_cd * main.TWIRL_REFUND), "outro golpe no mesmo giro também passa, mas o BRAVO vale uma vez só")
	await wait(0.8)
	main.hurt(u, 10.0, "teste")
	check(u.hp < v_hp0, "acabou o giro: o golpe entra normalmente")
	u.position = Vector3(0, 0, 6.0)
	ready(u)
	check(not main.use_skill(u, 0) and main.use_skill(u, 2), "de longe o Passo de Valsa não alcança, mas a Pirueta sai (é o desvio dela)")
	u.position = v_near
	await wait(0.8)
	# Chuva de Pétalas
	ready(u)
	u.hp = 30.0
	main.use_skill(u, 3)
	check(is_equal_approx(u.hp, 30.0 + main.PETAL_BURST) and u.petal_t > 0.0, "Chuva de Pétalas: %d de cura na hora" % main.PETAL_BURST)
	await wait(1.3)
	check(u.hp >= 30.0 + main.PETAL_BURST + main.PETAL_HPS - 0.01, "... e %d por segundo enquanto as pétalas caem" % main.PETAL_HPS)
	# Crescendo
	ready(u)
	var v_b0: float = main.valsa_bonus(v_ally)
	main.use_skill(u, 4)
	check(u.crescendo_t > 0.0 and is_equal_approx(main.valsa_bonus(v_ally), v_b0 * main.CRESC_MULT), "Crescendo: o bônus da saia dobra (+%d%%)" % roundi(main.valsa_bonus(v_ally) * 100.0))
	u.position = Vector3(1.3, 0, -5.2)
	u.skill_cd[0] = 0.0
	main.use_skill(u, 0)
	check(is_equal_approx(u.skill_cd[0], main.CRESC_GCD), "... e o compasso acelera: Passo de Valsa em %.1f s" % main.CRESC_GCD)
	u.embalo = 3
	u.embalo_t = 0.05
	await wait(0.3)
	check(u.embalo == 3, "... e o Embalo não cai durante o Crescendo")
	u.crescendo_t = 0.0
	u.embalo_t = 0.05
	await wait(0.3)
	check(u.embalo == 2, "parou de girar: o Embalo cai um ponto")
	# Grande Baile
	ready(u)
	u.partner = null
	v_ally.position = Vector3(0, 0, 6.0)
	u.position = Vector3(1.3, 0, -5.2)
	check(main.valsa_bonus(v_ally) == 0.0, "(sem Par e longe: sem bônus)")
	main.use_skill(u, 5)
	check(u.ball_t > 0.0 and u.embalo == main.EMBALO_MAX and is_equal_approx(main.valsa_bonus(v_ally), main.SKIRT_BONUS + main.SKIRT_BONUS_PER * main.EMBALO_MAX), "Grande Baile: Embalo no máximo e a party toda conta como dentro da saia, onde estiver")
	check(main.ball_node != null and main.ball_spots.size() == 4, "a arena vira salão (chão, lustre e um foco por herói)")
	u.ball_t = 0.05
	before = u.dmg_total
	await wait(0.3)
	check(is_equal_approx(u.dmg_total - before, main.BALL_END_DMG) and main.ball_node == null, "o último acorde: %d de dano, e o salão se desfaz" % main.BALL_END_DMG)
	# IA sem a carta Rotação: dança sozinha
	main.set_ctrl((main.ctrl + 1) % 4)
	u.embalo = 0
	u.partner = null
	u.position = Vector3(1.3, 0, -5.2)
	u.ai_waltz = main.AI_WALTZ_EVERY - 0.05
	main._ai_waltz(u, 0.1)
	check(u.embalo == 1 and u.partner != null and u.partner.controlled, "na mão da IA ela gira sozinha, junta Embalo e faz Par com quem o jogador controla")
	u.die()
	await frames_of(3)
	check(not u.aura.visible and u.embalo == 0, "caída: a roseta some e o Embalo zera")
	# andar é patinar
	main = await fight(9)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	check(u.legs.size() == 2 and u.pose != null and u.glide < 0.05, "parada, ela fica de pé (duas pernas no chão)")
	var v_foot: int = u.glide_foot
	var v_t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - v_t0 < 700:
		u.position.x += 3.5 * main.get_process_delta_time()
		await process_frame
	check(u.glide > 0.8 and u.legs[1 - u.glide_foot].rotation.x < -0.8 and absf(u.legs[u.glide_foot].rotation.x) < 0.3, "andando ela desliza: a perna livre estende pra trás e a de apoio fica no chão")
	check(u.pose.rotation.x < -0.2 and u.hands[0].position.x < u._hand_home(-1.0).x - 0.5 and u.hands[1].position.x > u._hand_home(1.0).x + 0.5, "... o corpo inclina e os braços abrem")
	u.glide_swap = 0.0
	v_t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - v_t0 < 700:
		u.position.x -= 3.5 * main.get_process_delta_time()
		await process_frame
	check(u.glide_foot != v_foot and u.legs[v_foot].rotation.x < -0.8, "de tempos em tempos ela troca o pé de apoio")
	await wait(1.2)
	check(u.glide < 0.1 and absf(u.legs[0].rotation.x) < 0.15 and absf(u.legs[1].rotation.x) < 0.15, "parou: volta à pose normal")

	# ================================================================ APOTECÁRIO
	main = await fight(7)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	check(u.key == "apothecary" and u.unit_name == "Apotecário", "Apotecário entra na luta (classe nova, healer)")
	kit = main.SKILLS["apothecary"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Incisão", "Necropsia", "Sutura", "Solução Hemostática", "Tanatopraxia", "Estabilização"], "Apotecário: as seis da ficha: %s" % [names])
	check(cds == [1.0, 7.0, 1.0, 20.0, 45.0, 60.0], "Apotecário: recargas da ficha: %s" % [cds])
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 16.0) and is_equal_approx(u.skill_cd[0], 3.0), "Incisão sem Decomposição: recarga de 3 s")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 1)
	check(is_equal_approx(u.dmg_total - before, 60.0) and is_equal_approx(main.get_dot("decomp")["t"], 8.0), "Necropsia: dano alto + Decomposição de 8 s")
	check(u.vestiges == 0, "a primeira aplicação não dá Vestígio")
	main.use_skill(u, 0)
	check(is_equal_approx(u.skill_cd[0], 1.0), "com Decomposição, a Incisão volta pra 1 s")
	ready(u)
	main.get_dot("decomp")["t"] = 5.0
	main.use_skill(u, 1)
	check(u.vestiges == 0, "renovar cedo demais: sem Vestígio")
	for n in 3:
		ready(u)
		main.get_dot("decomp")["t"] = 0.8
		main.use_skill(u, 1)
		check(u.vestiges == n + 1, "renovar com 1 s ou menos sobrando: Vestígio %d" % (n + 1))
	ready(u)
	main.get_dot("decomp")["t"] = 0.8
	main.use_skill(u, 1)
	check(u.vestiges == 3, "no máximo 3 Vestígios")
	await frames_of(3)
	check(main.hud.bullet_row.visible, "os Vestígios aparecem em cima da barra de habilidades")
	u.vestiges = 0
	main.remove_dot("decomp")
	ready(u)
	main.use_skill(u, 1)
	check(u.vestiges == 0, "reaplicar depois que expirou: sem Vestígio")

	ally = main.units[2]
	ally.hp = 20.0
	main.sel = 2
	ready(u)
	main.use_skill(u, 2)
	check(is_equal_approx(u.channel_t, 1.5), "Sutura: conjuração de 1,5 s")
	await wait(1.65)
	check(is_equal_approx(ally.hp, 20.0 + main.SUTURE_HEAL) and u.patient == ally and u.patient_t > 13.0, "cura o aliado e marca ele como Paciente por 15 s")
	ready(u)
	hp0 = ally.hp
	main.use_skill(u, 0)
	check(is_equal_approx(ally.hp - hp0, main.PATIENT_HEAL), "Incisão com a boss em Decomposição cura um pouco o Paciente")
	ready(u)
	ally.shield_hp = 0.0
	main.use_skill(u, 3)
	check(is_equal_approx(ally.shield_hp, ally.max_hp * main.HEMO_RATIO) and is_equal_approx(ally.shield_t, 8.0), "Solução Hemostática num aliado: escudo de 18%% por 8 s")
	check(main.get_dot("contam").is_empty(), "sem 3 Vestígios, não contamina a boss")
	# 3 Vestígios + Decomposição, sem aliado escolhido: vai na boss
	main.sel = -1
	u.vestiges = 3
	ready(u)
	main.use_skill(u, 3)
	check(not main.get_dot("contam").is_empty() and u.vestiges == 3, "com 3 Vestígios e Decomposição: Contaminação na boss")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total - before, main.TOXIC_DMG) and not main.get_dot("toxica").is_empty(), "Tanatopraxia na boss contaminada vira Nuvem Tóxica: dano + DoT")
	check(u.vestiges == 0 and main.get_dot("contam").is_empty(), "consome os 3 Vestígios e a Contaminação")
	for o in main.units:
		o.hp = 10.0
	ready(u)
	main.use_skill(u, 4)
	check(is_equal_approx(ally.hp, 10.0 + main.CLOUD_HEAL) and ally.mend_t > 7.0, "Tanatopraxia normal: cura a party e deixa regeneração de 8 s")
	for o in main.units:
		o.hp = 10.0
	u.vestiges = 3
	ready(u)
	main.use_skill(u, 4)
	var big_one: Unit = main.units[0]  # o Paladino tem vida de sobra pra mostrar a cura inteira
	check(is_equal_approx(big_one.hp, 10.0 + main.CLOUD_HEAL * main.CLOUD_BOOST) and u.vestiges == 0, "com 3 Vestígios: cura bem maior (10 -> %.0f)" % big_one.hp)
	main.sel = 2
	ally.hp = 40.0
	ally.mend_t = 0.0
	ready(u)
	main.use_skill(u, 5)
	check(is_equal_approx(ally.hp, minf(ally.max_hp, 40.0 + main.STABILIZE_HEAL)), "Estabilização: cura grande na hora")
	ally.hp = 10.0
	ready(u)
	main.use_skill(u, 5)
	check(ally.hp >= 99.0, "abaixo de 25%% de vida, cura 50%% mais (10 -> %.0f)" % ally.hp)
	# IA de healer com a carta Instinto
	Knowledge.owned["instinct"] = true
	check(Knowledge.equip(7, "instinct"), "o Apotecário pode usar a carta Instinto")
	main.swap_cd = 0.0
	main.set_ctrl(2)
	ready(u)
	main.units[0].hp = 20.0
	var healed := false
	for i in 400:
		await process_frame
		if main.units[0].hp > 60.0:
			healed = true
			break
	check(healed, "com Instinto, a IA do Apotecário socorre quem está com pouca vida")

	# ================================================================ SLEEPWALKER
	main = await fight(8)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	check(u.key == "sleepwalker" and not u.melee and not u.asleep, "Sleepwalker entra na luta, acordado (classe nova, à distância)")
	names = []
	for sk in main.kit(u):
		names.append(sk["name"])
	check(names == ["Bocejo", "Puxar o Lençol", "Visitantes debaixo da Cama", "Senhor Travesseiro", "A Cama Caiu!", "Sono Profundo"], "Modo Acordado: os seis botões: %s" % [names])
	var sc: float = main.SW_SCALE
	# conjuração de verdade: 1,25 s parado; andar cancela sem gastar nada
	before = u.dmg_total
	check(main.use_skill(u, 1) and is_equal_approx(u.channel_t, 1.25) and is_equal_approx(u.dmg_total, before), "toda habilidade dele conjura 1,25 s antes de sair")
	check(not main.use_skill(u, 0), "conjurando, não dá pra usar outra")
	Input.action_press("move_left")
	await wait(0.2)
	Input.action_release("move_left")
	check(is_equal_approx(u.channel_t, 0.0) and is_equal_approx(u.skill_cd[1], 0.0) and is_equal_approx(u.dmg_total, before) and main.dream_stacks == 0, "andar cancela a conjuração, sem dano e sem gastar a recarga")
	u.position = main._atk_pos(u)
	await frames_of(3)
	main.use_skill(u, 0)
	await wait(1.0)
	check(u.channel_t > 0.0 and is_equal_approx(u.dmg_total, before), "com 1 s de conjuração o Bocejo ainda não saiu")
	await wait(0.4)
	check(is_equal_approx(u.dmg_total - before, 50.0 * sc) and is_equal_approx(u.channel_t, 0.0), "e sai quando a conjuração termina")
	check(u.skill_cd[0] <= 0.75 and u.skill_cd[0] > 0.3, "a recarga do Bocejo (2 s) conta desde o começo da conjuração")
	for slot in 5:
		check(is_equal_approx(main.sw_cast(u, slot), main.SW_CAST), "slot %d acordado: conjuração de 1,25 s" % (slot + 1))
	check(is_equal_approx(main.sw_cast(u, 5), main.SW_CAST), "Sono Profundo também conjura")
	check(not main.SKILLS["maga"][0].has("cast") and not main.SKILLS["ringstar"][0].has("cast"), "as outras classes continuam sem conjuração nova")
	# daqui pra baixo, sw() conclui a conjuração na hora (o tempo dela já foi testado acima)
	ready(u)
	u.torpor = 0.0
	before = u.dmg_total
	sw(main, u, 0)
	check(is_equal_approx(u.dmg_total - before, 50.0 * sc) and is_equal_approx(u.torpor, 3.0), "Bocejo: dano e +3 de Torpor")
	# sequência perfeita
	u.torpor = 0.0
	sw(main, u, 1)
	check(main.dream_stacks == 2 and u.window_slot == 2 and is_equal_approx(u.window_t, 1.0), "Puxar o Lençol: 2 stacks e abre 1 s pros Visitantes")
	check(main.glow_slot(u) == 2, "o botão da janela brilha")
	await wait(0.4)
	sw(main, u, 2)
	check(main.dream_stacks == 5 and u.crumbs and u.window_slot == 3, "Visitantes na janela: 3 mordidas (5 stacks) e Migalhas")
	await wait(0.4)
	sw(main, u, 3)
	check(main.dream_stacks == 7 and u.pillow_full and u.window_slot == 4, "Senhor Travesseiro na janela: come as Migalhas (7 stacks) e fica Cheio")
	await wait(0.4)
	before = u.dmg_total
	sw(main, u, 4)
	check(main.dream_stacks == 8, "A Cama Caiu! fecha os 8 stacks de Vulnerabilidade Onírica")
	check(is_equal_approx(u.dmg_total - before, 200.0 * main.SW_BED_BONUS * sc * 1.16), "com Travesseiro Cheio e 8 stacks: %.0f de dano" % (u.dmg_total - before))
	check(main.echoes.size() == 4, "e ativa os Ecos do Pesadelo (4 Frestas)")
	check(u.torpor > 48.5 and u.torpor < 51.5, "Torpor do ciclo perfeito: 33 das habilidades + 18 das interações, menos a perda (%.1f)" % u.torpor)
	check(u.torpor < 55.0, "um ciclo perfeito não paga A Casa que Engole inteira: precisa de dois")
	check(is_equal_approx(u.skill_cd[4], 15.0 - main.SW_CAST), "cada habilidade da sequência tem 15 s de recarga, contados do começo da conjuração")
	# Fresta: abre 1 s depois, por 0,5 s
	await wait(1.1)
	await frames_of(2)
	check(main.echo_mark.visible, "a primeira Fresta abre 1 s depois da Cama")
	ready(u)
	before = u.dmg_total
	sw(main, u, 0)
	check(is_equal_approx(u.dmg_total - before, (50.0 + main.ECHO_BASE) * sc * 1.16), "Bocejo na Fresta aberta: dano extra")
	await wait(0.6)
	await frames_of(2)
	check(not main.echo_mark.visible, "a Fresta fecha depois de 0,5 s")
	# janela perdida
	main.echoes.clear()
	main.dream_stacks = 0
	ready(u)
	sw(main, u, 1)
	await wait(1.25)
	check(u.window_slot == -1, "a janela de 1 s passa")
	var t0: float = u.torpor
	sw(main, u, 2)
	check(main.dream_stacks == 3 and not u.crumbs, "Visitantes fora da janela: só 1 stack e sem Migalhas")
	check(u.torpor - t0 < 7.5, "e sem o Torpor extra da interação")
	sw(main, u, 3)
	sw(main, u, 4)
	check(main.dream_stacks < 8 and main.echoes.is_empty(), "com uma janela perdida, não chega nos 8 stacks nem ativa os Ecos (%d)" % main.dream_stacks)
	t0 = u.torpor
	await wait(1.0)
	check(u.torpor < t0 - 0.8, "acordado, o Torpor cai 1 por segundo")

	# a sequência só começa no Puxar o Lençol
	for start in [2, 3, 4]:
		ready(u)
		main.dream_stacks = 0
		main.echoes.clear()
		u.window_slot = -1
		u.window_t = 0.0
		u.crumbs = false
		u.pillow_full = false
		u.torpor = 0.0
		before = u.dmg_total
		sw(main, u, start)
		check(u.window_slot == -1 and main.glow_slot(u) == -1, "%s solta não abre a janela da próxima" % main.SKILLS["sleepwalker"][start]["name"])
		check(is_equal_approx(u.torpor, float(main.SW_AWAKE[start]["torpor"])) and not u.crumbs and not u.pillow_full, "e não dá o Torpor extra nem o efeito da sequência")
		if start < 4:
			await wait(0.2)
			sw(main, u, start + 1)
			check(main.echoes.is_empty() and not u.pillow_full and u.window_slot == -1, "seguir daí também não vale: sem Lençol não tem sequência")
	ready(u)
	u.torpor = 0.0
	main.dream_stacks = 0
	sw(main, u, 3)
	sw(main, u, 4)
	check(is_equal_approx(u.dmg_total - before, 0.0) or main.echoes.is_empty(), "Travesseiro e Cama soltos não ativam os Ecos")
	# Torpor cheio segura 3 s; Fresta dá Torpor
	u.torpor = 99.0
	u.torpor_hold = 0.0
	ready(u)
	sw(main, u, 0)
	check(is_equal_approx(u.torpor, 100.0) and is_equal_approx(u.torpor_hold, main.SW_FULL_HOLD), "chegar em 100 de Torpor segura a barra cheia")
	await wait(2.5)
	check(is_equal_approx(u.torpor, 100.0), "com 2,5 s, o Torpor ainda está em 100")
	await wait(1.5)
	check(u.torpor < 99.6 and u.torpor > 98.0, "depois de 3 s ele volta a cair (%.1f)" % u.torpor)
	u.torpor = 10.0
	u.torpor_hold = 0.0
	ready(u)
	main.echoes = [{"wait": 0.0, "open": 0.4, "hit": false, "warned": true}]
	sw(main, u, 0)
	check(is_equal_approx(u.torpor, 10.0 + 3.0 + main.SW_ECHO_TORPOR), "acertar a Fresta: +4 de Torpor além do Bocejo")
	main.echoes.clear()
	sw(main, u, 1)  # deixa uma recarga do Modo Acordado correndo, pra conferir que ela é guardada

	# Modo Dormindo
	u.torpor = 100.0
	main.dream_stacks = 0
	sw(main, u, 5)
	check(u.asleep and is_equal_approx(u.skill_cd[5], 3.0), "Sono Profundo transforma (3 s de recarga)")
	names = []
	for sk in main.kit(u):
		names.append(sk["name"])
	check(names == ["A Mordida dos Mil", "Senhor Travesseiro: Devorador", "O Abraço Impossível", "A Porta Errada", "A Casa que Engole", "Acordar"], "Modo Dormindo: os seis botões: %s" % [names])
	await frames_of(3)
	check(main.hud.skill_ui[0]["ui"].icon == SkillInfo.icon("sleepwalker", 0, true) and main.hud.skill_ui[0]["ui"].icon != SkillInfo.icon("sleepwalker", 0, false), "a barra de habilidades troca junto (ícones do Modo Dormindo)")
	check(main.hud.skill_ui[5]["ui"].icon == SkillInfo.icon("sleepwalker", 5, true) and main.hud.skill_ui[5]["ui"].key_text == Binds.label("skill_6"), "o slot 6 troca de habilidade e continua na mesma tecla")
	check(u.awake_cd[1] > 10.0, "as recargas do Modo Acordado ficam guardadas")
	p0 = u.position
	main.use_skill(u, 0)
	Input.action_press("move_left")
	await wait(0.3)
	Input.action_release("move_left")
	main._try_dash()
	check(u.position.is_equal_approx(p0) and u.dash_cd <= 0.0, "dormindo, ele não anda nem desvia")
	check(u.channel_t > 0.0, "e apertar direção dormindo não cancela a conjuração")
	u.channel_t = 0.0
	check(is_equal_approx(main.sw_cast(u, 0), main.SW_CAST) and is_equal_approx(main.sw_cast(u, 5), 0.0), "dormindo: as cinco da sequência conjuram; só Acordar é na hora")
	check(not sw(main, u, 2) and is_equal_approx(u.torpor, 100.0), "fora de ordem, a habilidade não sai")
	check(main.glow_slot(u) == 0, "a próxima da ordem brilha")
	before = u.dmg_total
	sw(main, u, 0)
	check(is_equal_approx(u.torpor, 95.0) and not main.get_dot("pesadelo").is_empty(), "A Mordida dos Mil: 5 de Torpor e aplica o Pesadelo Persistente")
	check(is_equal_approx(u.near_t, 10.0), "primeira aplicação: Perto do Sonho por 10 s")
	check(is_equal_approx(main.sw_cast(u, 1), main.SW_CAST_NEAR), "com Perto do Sonho, a conjuração cai pra 0,75 s")
	for n in range(1, 5):
		ready(u)
		check(main.glow_slot(u) == n, "passo %d da sequência é o que brilha" % (n + 1))
		sw(main, u, n)
	check(is_equal_approx(u.dmg_total - before, 1300.0 * sc), "a sequência completa dá o dano total da ficha (1300 na escala do jogo: %.0f)" % (u.dmg_total - before))
	check(not u.asleep and is_equal_approx(u.torpor, 0.0), "A Casa que Engole gasta o resto do Torpor e acorda sozinho")
	check(is_equal_approx(u.silence_t, 0.0), "fechar com A Casa que Engole não tem punição")
	check(is_equal_approx(main.units[0].shield_hp, main.units[0].max_hp * 0.08), "e dá escudo de 8%% da vida máxima nos aliados")
	check(u.skill_cd[1] > 5.0, "ao acordar, as recargas do Modo Acordado voltam de onde estavam")
	# com Perto do Sonho: recargas 1 s menores e conjuração de 0,75 s
	ready(u)
	check(main.use_skill(u, 1) and is_equal_approx(u.channel_t, main.SW_CAST_NEAR), "Perto do Sonho: Puxar o Lençol conjura em 0,75 s")
	u.channel_t = 0.0
	main._resolve_skill(u, 1, false)
	check(is_equal_approx(u.skill_cd[1], 14.0 - main.SW_CAST_NEAR), "Perto do Sonho: Puxar o Lençol com 14 s de recarga")

	# punições ao acordar
	ready(u)
	u.silence_t = 0.0
	u.bite_cd = 0.0
	u.torpor = 100.0
	sw(main, u, 5)
	ready(u)
	sw(main, u, 5)
	check(not u.asleep and is_equal_approx(u.silence_t, main.SW_LOCK_NONE), "acordar sem ter usado nada: 2 s sem agir")
	ready(u)
	check(not main.use_skill(u, 0) and not main.use_skill(u, 1) and not main.use_skill(u, 5), "punido, nenhuma habilidade sai")
	p0 = u.position
	Input.action_press("move_left")
	await wait(0.3)
	Input.action_release("move_left")
	check(not u.position.is_equal_approx(p0), "mas ele anda normalmente")
	u.position = main._atk_pos(u)
	await wait(1.9)
	check(is_equal_approx(u.silence_t, 0.0) and main.use_skill(u, 0), "passados os 2 s, volta a agir")
	u.channel_t = 0.0
	# só a Mordida: 1 s
	ready(u)
	u.torpor = 100.0
	main.get_dot("pesadelo")["t"] = 10.0
	sw(main, u, 5)
	ready(u)
	sw(main, u, 0)
	check(is_equal_approx(u.near_t, 10.0), "renovar cedo (faltando 10 s): só 10 s de Perto do Sonho")
	check(is_equal_approx(u.skill_cd[0], 17.0), "a Mordida tem 18 s de recarga (17 com o buff)")
	ready(u)
	sw(main, u, 5)
	check(not u.asleep and is_equal_approx(u.silence_t, main.SW_LOCK_BITE), "acordar depois de usar só A Mordida dos Mil: 1 s sem agir")
	check(is_equal_approx(u.torpor, 100.0 - 5.0 - main.SW_BITE_WAKE), "e perde só 15 de Torpor, não tudo (%.0f)" % u.torpor)
	# sequência largada no meio: 3 s
	u.silence_t = 0.0
	ready(u)
	u.bite_cd = 0.0
	u.torpor = 100.0
	main.get_dot("pesadelo")["t"] = 1.5
	sw(main, u, 5)
	ready(u)
	sw(main, u, 0)
	check(is_equal_approx(u.near_t, 20.0), "renovar nos últimos 2 s: Perto do Sonho por 20 s")
	ready(u)
	sw(main, u, 1)
	ready(u)
	sw(main, u, 2)
	ready(u)
	main.use_skill(u, 3)
	check(u.channel_t > 0.0, "(conjurando a quarta da sequência)")
	main.use_skill(u, 5)
	check(not u.asleep and is_equal_approx(u.silence_t, main.SW_LOCK_BROKEN) and is_equal_approx(u.torpor, 0.0), "largar a sequência sem A Casa que Engole: 3 s sem agir e Torpor zerado")
	check(is_equal_approx(u.channel_t, 0.0), "e a conjuração em curso é cancelada: nada sai durante a punição")
	main.remove_dot("pesadelo")  # o DoT que já estava na boss continuaria batendo; aqui interessa só o que ele faz
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	main.use_skill(u, 1)
	await wait(1.5)
	check(is_equal_approx(u.dmg_total, before) and u.silence_t > 1.0, "nenhum dano dele durante o bloqueio")
	# sem Torpor: Mordida de graça e fraca, e acorda sozinho
	u.silence_t = 0.0
	ready(u)
	u.bite_cd = 0.0
	u.torpor = 3.0
	main.dream_stacks = 0
	sw(main, u, 5)
	ready(u)
	before = u.dmg_total
	sw(main, u, 0)
	check(is_equal_approx(u.dmg_total - before, 100.0 * 0.2 * sc) and is_equal_approx(u.torpor, 3.0), "com menos de 5 de Torpor, a Mordida sai de graça e bem fraca")
	check(u.asleep and u.wake_t > 0.0, "sem Torpor pra próxima, avisa que vai acordar")
	await wait(1.15)
	check(not u.asleep and is_equal_approx(u.torpor, 0.0), "e acorda 1 s depois, perdendo o Torpor que sobrou")
	check(u.silence_t > 0.0 and u.silence_t <= main.SW_LOCK_BITE, "acordar sozinho também cobra a punição (só a Mordida: 1 s)")
	main.remove_dot("pesadelo")
	await frames_of(3)
	check(is_equal_approx(u.near_t, 0.0), "se o Pesadelo Persistente cai, o Perto do Sonho vai junto")

	# ================================================================ NOCAUTE FINAL (salto)
	main = await fight(6)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	u.position = Vector3(0, 0, 4.0)
	await frames_of(2)
	before = u.dmg_total
	var hp_before: float = u.hp
	main.use_skill(u, 5)
	check(is_equal_approx(u.air_t, main.KNOCKOUT_AIR) and is_equal_approx(u.dmg_total, before), "Nocaute Final: salta por 0,8 s e ainda não deu dano")
	check(not main.use_skill(u, 0), "no ar, ela não usa outra habilidade")
	# ataque baixo (rente ao chão) e ataque comum, os dois estourando com ela no ar
	main._add_hazard({"shape": "circle", "pos": Vector3(0, 0, 0), "r": 30.0, "total": 0.35, "dmg": 10.0, "card": "dodge", "why": "teste baixo", "low": true})
	await wait(0.5)
	check(u.air_t > 0.0 and u.visual.position.y > 3.0, "no meio do salto ela está no alto (%.1f)" % u.visual.position.y)
	check(is_equal_approx(u.hp, hp_before), "ataque baixo passa por baixo dela")
	check(main.units[(main.ctrl + 1) % 4].hp < main.units[(main.ctrl + 1) % 4].max_hp, "mas acerta quem está no chão")
	main._add_hazard({"shape": "circle", "pos": Vector3(0, 0, 0), "r": 30.0, "total": 0.1, "dmg": 10.0, "card": "dodge", "why": "teste alto"})
	await wait(0.2)
	check(u.hp < hp_before, "ataque comum acerta mesmo no ar: o salto não é invulnerabilidade")
	await wait(0.3)
	check(is_equal_approx(u.air_t, 0.0) and is_equal_approx(u.visual.position.y, 0.0), "ela aterrissa")
	check(is_equal_approx(u.dmg_total - before, main.KNOCKOUT_DMG), "o dano (%d) sai na aterrissagem" % main.KNOCKOUT_DMG)
	check(u.position.distance_to(main.BOSS_POINT) <= main.KNOCKOUT_R, "ela cai perto da boss, dentro do raio da onda de choque")
	hp_before = u.hp
	main._add_hazard({"shape": "circle", "pos": Vector3(0, 0, 0), "r": 30.0, "total": 0.1, "dmg": 10.0, "card": "dodge", "why": "teste baixo", "low": true})
	await wait(0.25)
	check(u.hp < hp_before, "no chão, o ataque baixo acerta normalmente")
	# longe demais: a onda não alcança
	main = await fight(6)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	before = u.dmg_total
	main._knockout_land(u)
	u.position = Vector3(0, 0, 12.0)
	var far_before: float = u.dmg_total
	main._knockout_land(u)
	check(is_equal_approx(u.dmg_total, far_before), "se a boss está fora da onda de choque, o Nocaute não dá dano")

	# ================================================================ MALPRACTICE (gauge de sangue)
	main = await fight(4)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	u.position = main._atk_pos(u)
	await frames_of(2)
	u.hp = 40.0
	u.stacks = main.PARTY_NEED - 1
	main.use_skill(u, 0)
	check(u.hp < 37.0, "gauge incompleto: a estocada só custa vida (%.1f)" % u.hp)
	ready(u)
	u.hp = 40.0
	u.stacks = main.PARTY_NEED
	main.use_skill(u, 0)
	check(u.hp > 39.0 and u.hp < 40.0, "gauge cheio: cada golpe devolve 4%% da vida máxima (40 -> %.1f)" % u.hp)
	await frames_of(3)
	check(main.hud.bullet_row.visible, "o gauge de Sangue aparece em cima da barra")
	check(main.hud.skill_ui[4]["ui"].usable, "com o gauge cheio, o Blood Party acende")
	u.stacks = 3
	await frames_of(3)
	check(not main.hud.skill_ui[4]["ui"].usable, "e apaga quando falta Sangue")

	# ================================================================ ÍCONES, FICHAS E DESTAQUE
	var miss := ""
	var seen := {}
	for h in Knowledge.HEROES:
		var key: String = h["key"]
		for mode in ([false, true] if SkillInfo.has_alt(key) else [false]):
			var list: Array = SkillInfo.kit(key, mode)
			for n in list.size():
				var p := SkillInfo.icon_path(key, n, mode)
				if SkillInfo.icon(key, n, mode) == null:
					miss += p.get_file() + " "
				if seen.has(p):
					miss += "repetido:" + p.get_file() + " "
				seen[p] = true
				var info := SkillInfo.info(key, n, mode)
				if String(info["desc"]).length() < 15 or String(info["name"]) != String(list[n]["name"]) or not SkillInfo.TYPE_COL.has(info["type"]):
					miss += "ficha:%s " % list[n]["name"]
	check(miss == "" and seen.size() == 66, "as 66 habilidades (incluindo as do Modo Dormindo) têm ícone próprio e ficha completa %s" % miss)
	check(SkillInfo.info("sleepwalker", 0, false)["cast"] == main.SW_CAST and SkillInfo.info("sleepwalker", 4, true)["cost"] == "50 de Torpor", "a ficha do Sleepwalker traz conjuração e custo de Torpor")
	check(String(SkillInfo.info("ringstar", 5)["desc"]).contains(str(int(main.KNOCKOUT_DMG))), "a descrição usa os números do jogo (Nocaute Final: %d)" % main.KNOCKOUT_DMG)
	var bigs := 0
	for h in Knowledge.HEROES:
		for sk in main.SKILLS[h["key"]]:
			if sk.get("big", false):
				bigs += 1
	check(bigs == 9 and main.SKILLS_ASLEEP[4].get("big", false), "cada herói tem uma habilidade de destaque (a do Sleepwalker é A Casa que Engole)")
	# destaque só pro personagem controlado
	main = await fight(6)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	main.phase_dur = 9999.0  # a boss fica parada neste passo: o teste é do herói
	var other: Unit = main.units[(main.ctrl + 1) % 4]
	main.hud.skill_cut(u, "TESTE")
	var first: Control = main.hud._cut
	check(first != null and is_instance_valid(first), "habilidade de destaque abre a apresentação")
	main.hud.skill_cut(u, "TESTE 2")
	await frames_of(2)
	check(not is_instance_valid(first) and is_instance_valid(main.hud._cut), "usar outra troca a apresentação: nunca duas ao mesmo tempo")
	main.hud._cut.queue_free()
	await frames_of(2)
	main.use_skill(u, 5)
	check(is_instance_valid(main.hud._cut), "Nocaute Final do jogador dispara o destaque")
	main.hud._cut.queue_free()
	await frames_of(2)
	for o in main.units:
		if o != u:
			for n in o.skill_cd.size():
				o.skill_cd[n] = 0.0
			main.use_skill(o, o.skill_cd.size() - 1, true)
	await frames_of(2)
	check(main.hud._cut == null or not is_instance_valid(main.hud._cut), "habilidades da IA não disparam o destaque")
	check(other != null, "(party com aliados na IA)")
	# tooltip
	var ui0: SkillSlot = main.hud.skill_ui[2]["ui"]
	ui0.mouse_entered.emit()
	await frames_of(3)
	check(main.hud.skill_tip.visible and main.hud.skill_tip._name.text == "GANCHO METEORO" and main.hud.skill_tip._desc.text == SkillInfo.info("ringstar", 2)["desc"], "passar o mouse num slot mostra a ficha da habilidade")
	check(ui0.key_text == Binds.label("skill_3"), "o slot mostra a tecla configurada, não o número do slot")
	ui0.mouse_exited.emit()
	check(not main.hud.skill_tip.visible, "e a ficha some ao sair")

	# ================================================================ VELOCIDADE DE MOVIMENTO
	var base_speed := 6.5
	for spec in [[2, 1.0], [4, 1.0], [5, 0.6], [3, 0.6], [0, 0.6], [1, 0.6], [6, 0.6], [8, 0.35], [7, 0.35]]:
		main = await fight(spec[0])
		u = main.units[main.ctrl]
		check(is_equal_approx(main.move_speed(u), base_speed * spec[1]), "%s na sua mão anda a %d%% da velocidade-base" % [u.unit_name, roundi(spec[1] * 100.0)])
		if spec[0] == 5:
			var npc: Unit = main.units[(main.ctrl + 1) % 4]
			check(is_equal_approx(main.move_speed(npc), base_speed), "a IA continua na velocidade-base (as mecânicas foram medidas com ela)")
			main.phase = "dodgetime"
			main.phase_dur = 9999.0
			var x0: float = u.position.x
			Input.action_press("move_left")
			await wait(1.0)
			Input.action_release("move_left")
			check(absf(absf(u.position.x - x0) - base_speed * 0.6) < 0.5, "andando 1 s, o Soulburner cobre %.1f m (era 6,5)" % absf(u.position.x - x0))
	# Apotecário: a nuvem de cura dá pressa pra party toda
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	u = main.units[main.ctrl]
	check(u.key == "apothecary", "(Apotecário no controle)")
	ready(u)
	main.use_skill(u, 4)
	var all_fast := true
	for o in main.units:
		if o.haste_t < main.HASTE_TIME - 0.1:
			all_fast = false
	check(all_fast and is_equal_approx(main.move_speed(u), base_speed * 0.35 * main.HASTE_MULT), "a Nuvem Conservante dá velocidade de movimento à party toda por %d s" % int(main.HASTE_TIME))
	u.haste_t = 0.05
	await wait(0.2)
	check(is_equal_approx(main.move_speed(u), base_speed * 0.35), "e a pressa acaba")

	# ================================================================ REVIVER DO APOTECÁRIO (em etapas)
	var dead: Unit = main.units[(main.ctrl + 1) % 4]
	var dead_i: int = (main.ctrl + 1) % 4
	main.kill(dead, "teste", true)
	check(not dead.alive, "(um aliado caiu)")
	ready(u)
	u.vestiges = 3
	main.sel = -1
	main.units[(main.ctrl + 2) % 4].hp = 20.0
	sw(main, u, 2)
	check(not dead.alive and u.patient != dead, "Sutura sem escolher o caído cura um vivo, como sempre")
	ready(u)
	main.use_skill(u, 5)
	check(not dead.alive and u.vestiges == 3, "Estabilização sem o corpo preparado não reanima nem gasta Vestígios")
	ready(u)
	main.sel = dead_i
	sw(main, u, 2)
	check(not dead.alive and u.patient == dead and u.patient_t > 0.0, "passo 1: Sutura no caído escolhido prepara o corpo (vira o Paciente)")
	u.vestiges = 2
	ready(u)
	check(not main.use_skill(u, 5) and not dead.alive and is_equal_approx(u.skill_cd[5], 0.0), "passo 2 sem os 3 Vestígios: não sai, e não gasta a recarga")
	u.vestiges = 3
	check(main.use_skill(u, 5) and dead.alive, "passo 2: Estabilização com 3 Vestígios reanima o Paciente")
	check(is_equal_approx(dead.hp, dead.max_hp * main.REANIMATE_HP) and u.vestiges == 0 and dead.weak_t > 0.0, "ele volta com 40%% da vida, com Fraqueza, e os Vestígios são gastos")
	check(SkillInfo.info("apothecary", 5)["desc"].contains("REANIMA") and SkillInfo.info("apothecary", 2)["desc"].contains("prepara o corpo"), "as fichas explicam os dois passos")

	# ================================================================ REVIVER DA SOULFLAME (simples)
	main = await fight(1)
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	u = main.units[main.ctrl]
	dead = main.units[(main.ctrl + 1) % 4]
	var dead2: Unit = main.units[(main.ctrl + 2) % 4]
	main.units[(main.ctrl + 3) % 4].hp = 10.0
	ready(u)
	sw(main, u, 4)
	check(main.units[(main.ctrl + 3) % 4].hp > 100.0 or main.units[(main.ctrl + 3) % 4].hp >= main.units[(main.ctrl + 3) % 4].max_hp, "Asa da Fênix sem ninguém caído: a cura grande de sempre")
	main.kill(dead, "teste", true)
	main.kill(dead2, "teste", true)
	main.units[(main.ctrl + 3) % 4].hp = 10.0
	ready(u)
	main.sel = -1
	sw(main, u, 4)
	check(dead.alive and is_equal_approx(dead.hp, dead.max_hp * main.REVIVE_HP) and not dead2.alive, "com alguém caído, a Asa da Fênix revive (50%% da vida), mesmo com um vivo ferido")
	ready(u)
	main.kill(dead, "teste", true)
	main.sel = (main.ctrl + 2) % 4
	sw(main, u, 4)
	check(dead2.alive and not dead.alive, "o caído escolhido no card tem prioridade")
	check(SkillInfo.info("healer", 4)["desc"].contains("REVIVE"), "a ficha da Asa da Fênix fala do reviver")

	# ================================================================ CLIQUE NAS HABILIDADES
	main = await fight(6)
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	u = main.units[main.ctrl]
	u.position = main._atk_pos(u)
	await frames_of(3)
	var slot_click := InputEventMouseButton.new()
	slot_click.button_index = MOUSE_BUTTON_LEFT
	slot_click.pressed = true
	before = u.dmg_total
	main.hud.skill_ui[0]["ui"].gui_input.emit(slot_click)
	check(is_equal_approx(u.dmg_total - before, 22.0) and u.skill_cd[0] > 0.0, "clicar num slot da barra usa a habilidade")
	main.hud.skill_ui[3]["ui"].gui_input.emit(slot_click)
	check(u.count_t > 0.0, "vale pra qualquer slot (Contagem Regressiva)")
	main.lb = 1.0
	await frames_of(3)
	check(main.hud.lb_button.visible, "com a barra cheia, o Limit Break vira um botão")
	main.hud.lb_button.pressed.emit()
	check(u.channel_t > 0.0 and u.channel_slot == -1, "clicar nele dispara o Limit Break")

	# ================================================================ CLIQUE: FOCO E TROCA
	main = await fight(1)
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	var me0: int = main.ctrl
	var other_i: int = (main.ctrl + 1) % 4
	main.sel = -1
	var card_click := InputEventMouseButton.new()
	card_click.button_index = MOUSE_BUTTON_LEFT
	card_click.pressed = true
	main.hud._on_card_input(card_click, other_i)
	await frames_of(3)
	check(main.sel == other_i and main.ctrl == me0, "um clique no card foca o herói, sem trocar o controle")
	check(main.units[other_i].chosen and main.units[other_i].chosen_ring.visible and not main.units[me0].chosen_ring.visible, "o focado ganha o círculo em volta, e só ele")
	main.hud._on_card_input(card_click, other_i)
	check(main.sel == other_i, "clicar de novo no mesmo card mantém o foco")
	main.swap_cd = 0.0
	card_click.double_click = true
	main.hud._on_card_input(card_click, other_i)
	check(main.ctrl == other_i, "dois cliques no card trocam o controle pra ele")
	# no boneco 3D
	main.swap_cd = 0.0
	var third: int = (main.ctrl + 2) % 4
	var where: Vector2 = main.cam.unproject_position(main.units[third].position + Vector3(0, 1.0, 0))
	check(main.unit_at(where) == third and main.unit_at(Vector2(20, 20)) == -1, "o clique acha o boneco que está embaixo do mouse (e nada, no vazio)")
	var world_click := InputEventMouseButton.new()
	world_click.button_index = MOUSE_BUTTON_LEFT
	world_click.pressed = true
	world_click.position = where
	main._unhandled_input(world_click)
	check(main.sel == third and main.ctrl == other_i, "um clique no boneco 3D foca ele")
	world_click.double_click = true
	main._unhandled_input(world_click)
	check(main.ctrl == third, "dois cliques no boneco 3D trocam o controle pra ele")
	main.swap_cd = 0.0
	var corpse: int = (main.ctrl + 1) % 4
	main.kill(main.units[corpse], "teste", true)
	main.click_unit(corpse, true)
	check(main.sel == corpse and main.ctrl == third, "caído: os cliques só focam (pra reviver), não dá pra controlar")

	# ================================================================ MALPRACTICE: SERINGA, ESCUDO E BLOOD PARTY
	main = await fight(4)
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	u = main.units[main.ctrl]
	u.position = main._atk_pos(u)
	await frames_of(2)
	check(u.syringe != null and u.med_shield != null and u.syringe_liquid != null, "a Malpractice tem a seringa gigante e o escudo médico no boneco")
	check(main.units[(main.ctrl + 1) % 4].syringe == null, "só ela tem")
	var fill0: float = u.syringe_liquid.scale.y
	ready(u)
	u.hp = 60.0
	main.use_skill(u, 2)
	await wait(0.3)
	check(u.syringe_liquid.scale.y > fill0 + 0.3, "Blood Consumed: o reservatório da seringa enche de sangue (%.2f -> %.2f)" % [fill0, u.syringe_liquid.scale.y])
	await wait(1.0)
	check(u.syringe_liquid.scale.y < 0.6, "e esvazia depois")
	# Blood Taste: Sangue só no parry bem-sucedido, e só golpe do inimigo conta
	ready(u)
	u.stacks = 0
	u.hp = 60.0
	main.use_skill(u, 1)
	check(u.taste_t > 0.0 and u.stacks == 0, "Blood Taste não dá Sangue só por ser usado")
	main._bleed(u, 4.0)
	check(not u.taste_hit, "o custo de vida das próprias habilidades não conta como parry")
	await wait(main.TASTE_TIME + 0.15)
	check(u.stacks == 0 and u.skill_cd[1] > 15.0, "parry que não aparou nada: sem Sangue e a recarga cheia")
	ready(u)
	main.use_skill(u, 1)
	main.hurt(u, 20.0, "teste")
	check(u.taste_hit, "golpe do inimigo durante a janela: parry")
	await wait(main.TASTE_TIME + 0.15)
	check(u.stacks == main.TASTE_STACKS, "parry bem-sucedido: +%d de Sangue" % main.TASTE_STACKS)
	# Bloodbath
	check(main.SKILLS["nurse"].size() == 6 and main.SKILLS["nurse"][5]["name"] == "Bloodbath" and SkillInfo.icon("nurse", 5) != null, "Bloodbath é a sexta habilidade dela, com ícone próprio")
	ready(u)
	u.stacks = main.BATH_COST - 1
	check(not main.use_skill(u, 5), "Bloodbath com menos de 10 de Sangue não sai")
	u.stacks = 14
	var near_ally: Unit = main.units[(main.ctrl + 1) % 4]
	var far_ally: Unit = main.units[(main.ctrl + 2) % 4]
	near_ally.position = u.position + Vector3(2.0, 0, 0)
	near_ally.hold_pos = near_ally.position
	far_ally.position = u.position + Vector3(0, 0, 9.0)
	far_ally.hold_pos = far_ally.position
	await frames_of(2)
	main.use_skill(u, 5)
	check(u.stacks == 4, "Bloodbath gasta 10 de Sangue")
	check(u.bath_t > 9.5 and near_ally.bath_t > 9.5 and far_ally.bath_t <= 0.0, "cobre quem está na área (raio 6) por 10 s, e só eles")
	hp0 = near_ally.hp
	main.hurt(near_ally, 50.0, "teste")
	check(is_equal_approx(hp0 - near_ally.hp, 40.0), "quem foi coberto toma 20%% menos dano")
	check(is_equal_approx(u.bath_window, main.BATH_WINDOW) and u.bath_charges == 1, "abre 2 s pra escolher UMA habilidade fortalecida")
	await frames_of(3)
	var reds := 0
	for n in 6:
		if main.hud.skill_ui[n]["ui"].glow and main.hud.skill_ui[n]["ui"].glow_color.r > 0.9 and main.hud.skill_ui[n]["ui"].glow_color.g < 0.4:
			reds += 1
	check(reds == 3 and not main.hud.skill_ui[3]["ui"].glow, "Poke, Blood Taste e Consumed brilham vermelho; Emergency Response não")
	ready(u)
	var blood0: int = u.stacks
	var tags0: int = main.hud.fight_ui.get_child_count()
	main.use_skill(u, 3)
	check(u.bath_charges == 1, "Emergency Response não gasta a carga do Bloodbath")
	check(u.stacks == blood0 + 1, "Emergency Response junta 1 de Sangue")
	var provoked := false
	for c in main.hud.fight_ui.get_children():
		if c is Chip and c.text == "PROVOKE!":
			provoked = true
	check(provoked and main.hud.fight_ui.get_child_count() > tags0 and main.hud.biscoito.modulate.a <= 0.01, "provocar mostra a etiqueta PROVOKE! ao lado da boss, sem a imagem do biscoito")
	ready(u)
	u.position = main._atk_pos(u)
	await frames_of(2)
	main.use_skill(u, 0)
	check(u.poke_rush_t > 2.9 and u.bath_charges == 0 and is_equal_approx(u.skill_cd[0], 1.0 * main.POKE_RUSH_CD), "Poke fortalecido: 3 s de estocadas em rajada (recarga %.2f s)" % u.skill_cd[0])
	await frames_of(3)
	check(not main.hud.skill_ui[0]["ui"].glow, "usada a carga, o brilho vermelho some")
	u.poke_rush_t = 0.0
	# Consumed fortalecido
	ready(u)
	u.stacks = 12
	main.use_skill(u, 5)
	near_ally.hp = 20.0
	u.hp = 30.0
	ready(u)
	main.use_skill(u, 2)
	check(u.hp >= 30.0 + u.max_hp * main.CONSUMED_BIG_HEAL, "Blood Consumed fortalecido: cura 20%% da vida máxima além do roubo normal (%.0f)" % u.hp)
	check(u.mend_t > 4.5 and near_ally.mend_t > 4.5 and is_equal_approx(near_ally.mend_rate, main.SHARE_REGEN), "regeneração nela e Compartilhamento de Sangue na party por 5 s")
	await wait(1.1)
	check(near_ally.hp >= 20.0 + main.SHARE_REGEN * 0.9, "os aliados vão recuperando vida (%.0f)" % near_ally.hp)
	# a janela expira
	ready(u)
	u.stacks = 12
	main.use_skill(u, 5)
	await wait(2.15)
	check(u.bath_charges == 0 and u.bath_window <= 0.0, "passados os 2 s sem escolher, a carga se perde")
	ready(u)
	u.hp = 30.0
	main.use_skill(u, 2)
	check(u.hp < 30.0 + u.max_hp * main.CONSUMED_BIG_HEAL, "e a habilidade sai normal")
	# parry fortalecido
	ready(u)
	u.stacks = 12
	main.use_skill(u, 5)
	main.use_skill(u, 1)
	check(is_equal_approx(u.taste_t, main.TASTE_TIME * main.TASTE_BIG), "Blood Taste fortalecido: janela do parry em dobro")
	await wait(1.2)
	# Blood Party
	ready(u)
	u.stacks = main.PARTY_NEED
	u.hp = 55.0
	main.use_skill(u, 4)
	check(is_equal_approx(u.party_t, main.PARTY_TIME) and is_equal_approx(main.PARTY_TIME, 10.0) and is_equal_approx(u.hp, 1.0), "Blood Party: 10 s, começando com 1 de vida")
	await wait(0.9)
	check(not u.med_shield.visible, "ela joga o escudo fora")
	main.hurt(u, 500.0, "teste")
	check(u.alive and is_equal_approx(u.hp, 1.0), "golpe pesado: ela não morre enquanto dura")
	main.kill(u, "teste")
	check(u.alive, "nem mecânica que mata na hora")
	u.hp = 50.0
	u.shield_hp = 30.0
	await frames_of(3)
	check(is_equal_approx(u.hp, 1.0) and is_equal_approx(u.shield_hp, 0.0), "cura e escudo de fora não entram")
	before = u.dmg_total
	var mult: float = main.low_hp_mult(u)
	main._damage_boss(u, 40.0, false, false)
	var dealt: float = u.dmg_total - before
	check(is_equal_approx(dealt, 40.0 * mult * main.PARTY_DMG_MULT), "dano dobrado (%.0f)" % dealt)
	check(is_equal_approx(u.hp, 1.0 + dealt * main.PARTY_STEAL), "rouba 25%% do dano causado (vida %.0f)" % u.hp)
	await frames_of(3)
	check(u.hp > 20.0, "e essa cura, que é dela, fica")
	ready(u)
	main.use_skill(u, 0)
	check(is_equal_approx(u.skill_cd[0], 0.5), "recargas pela metade (Poke: 0,5 s)")
	hp0 = u.hp
	main.use_skill(u, 0)
	check(u.hp >= hp0, "e os golpes não custam vida durante o Blood Party")
	# Extração no lugar do parry
	ready(u)
	u.hp = 5.0
	u.party_hp = 5.0
	check(main.use_skill(u, 1) and is_equal_approx(u.lock_t, main.EXTRACT_TIME) and u.taste_t <= 0.0, "no Blood Party o slot do parry vira a Extração: 1 s com a seringa na boss")
	await wait(0.5)
	check(u.hp < 5.0 + u.max_hp * main.EXTRACT_HEAL, "no meio da extração a cura ainda não veio")
	await wait(0.65)
	check(u.hp >= 5.0 + u.max_hp * main.EXTRACT_HEAL, "no fim, recupera 40%% da vida máxima ou mais (%.0f)" % u.hp)
	check(is_equal_approx(u.skill_cd[1], main.EXTRACT_CD - 1.15) or (u.skill_cd[1] > 2.0 and u.skill_cd[1] < 4.0), "a Extração volta em 4 s: dá pra usar de novo na mesma Ultimate")
	# Bloodbath no Blood Party: de graça, o dobro do alcance, três cargas e o DoT Pure Blood
	await frames_of(3)
	check(main.hud.party_fx.visible, "no Blood Party a tela pulsa (vermelho e roxo)")
	var urge0: float = main.hud._party_mat.get_shader_parameter("urgency")
	u.party_t = 2.0
	await frames_of(3)
	check(float(main.hud._party_mat.get_shader_parameter("urgency")) > urge0 + 0.3, "e fica mais intensa conforme o tempo acaba")
	u.party_t = 9.0
	ready(u)
	u.stacks = 0
	far_ally.position = u.position + Vector3(0, 0, 9.0)
	far_ally.hold_pos = far_ally.position
	far_ally.bath_t = 0.0
	await frames_of(2)
	check(u.bath_free and main.hud.skill_ui[5]["ui"].glow and main.hud.skill_ui[5]["ui"].usable, "no Blood Party o Bloodbath brilha: está de graça")
	check(main.use_skill(u, 5) and u.stacks == 0 and not u.bath_free, "e sai sem gastar Sangue")
	check(far_ally.bath_t > 9.0, "e alcança o dobro (cobre quem está a 9 m)")
	check(u.bath_charges == main.BATH_CHARGES_ULT, "valendo pras três próximas habilidades")
	check(not main.get_dot("pure").is_empty(), "deixa o DoT Pure Blood na boss")
	var kept_window: float = u.bath_window
	var kept_charges: int = u.bath_charges
	ready(u)
	await frames_of(3)
	check(not main.hud.skill_ui[5]["ui"].usable and not main.use_skill(u, 5), "só uma vez: o segundo, no mesmo Blood Party, pede Sangue")
	u.stacks = 10
	check(main.use_skill(u, 5) and u.stacks == 0, "com 10 de Sangue ele sai de novo")
	u.bath_window = kept_window
	u.bath_charges = kept_charges
	u.hp = 10.0
	u.party_hp = 10.0
	main.plain_hit = true
	main._damage_boss(u, 50.0, false, false)
	main.plain_hit = false
	check(is_equal_approx(u.hp, 10.0), "o Pure Blood não alimenta o roubo de vida")
	ready(u)
	main.use_skill(u, 0)
	check(u.bath_charges == 2 and is_equal_approx(u.bath_window, main.BATH_WINDOW), "cada fortalecida gasta uma carga e reabre os 2 s")
	# Extração fortalecida: 2,5 s carregando e uma explosão enorme
	ready(u)
	u.hp = 5.0
	u.party_hp = 5.0
	u.party_t = 9.0
	before = u.dmg_total
	check(main.use_skill(u, 1) and is_equal_approx(u.lock_t, main.EXTRACT_BIG_TIME) and u.bath_charges == 1, "Extração fortalecida: 2,5 s carregando a seringa na boss")
	await wait(1.5)
	check(u.hp < u.max_hp * 0.6 and not main.use_skill(u, 0), "no meio da carga ela está presa e a cura ainda não veio")
	await wait(1.2)
	check(u.dmg_total - before >= main.EXTRACT_BIG_DMG and u.hp >= 5.0 + u.max_hp * main.EXTRACT_BIG_HEAL - 1.0, "ao soltar: %d de dano ou mais, e quase a vida toda de volta (%.0f)" % [int(main.EXTRACT_BIG_DMG), u.hp])
	check(u.lock_t <= 0.0 and u.channel_t <= 0.0, "e ela se solta")
	# fim sem a vida cheia: morre
	u.hp = 40.0
	u.party_hp = 40.0
	u.party_t = 0.05
	await wait(0.25)
	check(not u.alive, "acabou o tempo sem a vida cheia: ela morre")
	check(String(main.log_lines[-1]).contains("Blood Party"), "e o motivo fica registrado")
	# fim com a vida cheia: sobrevive
	main = await fight(4)
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	u = main.units[main.ctrl]
	u.stacks = main.PARTY_NEED
	main.use_skill(u, 4)
	await wait(0.2)
	u.hp = u.max_hp
	u.party_hp = u.max_hp
	u.party_t = 0.05
	await wait(0.6)
	check(u.alive and is_equal_approx(u.hp, u.max_hp) and u.party_t <= 0.0, "com a vida cheia no fim, ela sobrevive")
	check(not u.bath_free, "o Bloodbath grátis não usado se perde quando o Blood Party acaba")
	check(u.med_shield.visible and is_equal_approx(u.visual.scale.x, 1.0), "e o escudo volta")
	check(SkillInfo.info("nurse", 4)["desc"].contains("você morre") and SkillInfo.info("nurse", 1)["desc"].contains("EXTRAÇÃO"), "as fichas explicam a regra do Blood Party e a Extração")

	# ---------- ordem da barra escolhida na tela SKILLS
	main = await fight(2)
	main.phase = "dodgetime"
	main.phase_dur = 9999.0
	u = main.units[main.ctrl]
	u.position = main._atk_pos(u)
	Knowledge.layouts[2] = [3, 1, 2, 0, 4, 5]
	Knowledge.layout_rev += 1
	await frames_of(3)
	var bar: Array = main.hud.skill_ui
	check(bar[0]["slot"] == 3 and bar[3]["slot"] == 0 and bar[0]["ui"].icon == SkillInfo.icon("assassina", 3), "a barra da luta segue a ordem arrumada na tela SKILLS")
	check(bar[0]["ui"].key_text == Binds.label("skill_1") and bar[3]["ui"].key_text == Binds.label("skill_4"), "as teclas continuam sendo das posições")
	ready(u)
	Binds.apply()
	var press: InputEvent = Binds.event_of(KEY_J)
	press.pressed = true
	main._unhandled_input(press)
	check(u.skill_cd[3] > 10.0 and u.skill_cd[0] <= 0.0, "a tecla da posição 1 solta a habilidade que está lá (Dança Carmesim)")
	check(Knowledge.pos_of(2, 0) == 3, "e o ataque básico de segurar passa pra tecla da posição 4")
	Knowledge.layouts.erase(2)
	Knowledge.layout_rev += 1

	# ---------- TROVÃO-KUN: boss que anda, pulo e ventilador de raios
	Knowledge.boss = 4
	Knowledge.know = {}
	main = await fight(2)
	u = main.units[main.ctrl]
	check(main.roam and main.boss_def["name"] == "TROVÃO-KUN" and main.boss_pos.length() < 0.1, "TROVÃO-KUN fica no meio da arena")
	check(main._in_range(u) and u.position.distance_to(main.boss_pos) < 4.5, "a party se arruma em volta dele (%.1f)" % u.position.distance_to(main.boss_pos))
	check(main.jump(u) and u.airborne() and is_equal_approx(u.hop_t, main.JUMP_AIR), "pulo: fica no ar por um instante")
	check(not main.jump(u), "não dá pra pular de novo no ar")
	await wait(0.3)
	check(u.visual.position.y > 0.6, "o boneco sobe de verdade (%.1f)" % u.visual.position.y)
	await wait(0.7)
	check(not u.airborne() and is_equal_approx(u.visual.position.y, 0.0) and main.jump(u), "volta pro chão e pode pular de novo")
	await wait(0.9)
	# salto do boss
	main.step = 0
	main._next_step()
	check(main.phase == "leap" and main.hazards.size() == 1 and main.hazards[0]["shape"] == "circle", "Salto Trovejante marca um círculo vermelho no chão")
	var land: Vector3 = main.leap_to
	await wait(1.95)
	check(main.boss_pos.distance_to(land) < 0.7 and main.phase == "chase", "ele cai no ponto marcado e começa a perseguir")
	var tanky: Unit = main.units[0]
	for o in main.units:
		o.enmity = 0.0
		o.hp = o.max_hp
	tanky.enmity = 999.0
	tanky.position = main.boss_pos + Vector3(8.0, 0, 0)
	var d0: float = main.boss_pos.distance_to(tanky.position)
	var hp_near: float = u.hp
	u.position = main.boss_pos + Vector3(0, 0, 1.0)
	await wait(1.0)
	check(main.storm_target == tanky and main.boss_pos.distance_to(tanky.position) < d0 - 0.8, "na perseguição ele anda atrás de quem está no topo do aggro")
	check(is_equal_approx(u.hp, hp_near) or u.hp > hp_near - 0.5, "encostar nele não dá dano: dá pra bater de perto")
	# faíscas
	main.step = 4
	main._next_step()
	check(main.phase == "orbs" and main.eye_ring != null and main.eye_ring.visible, "nas faíscas aparece o anel do olho da tempestade")
	for o in main.units:
		o.invuln = 9.0  # ninguém estoura as faíscas enquanto o teste olha pra elas
	await wait(1.1)
	check(main.phase == "orbs" and main.orbs.size() > 6 and main.orbs.size() < main.ORB_COUNT, "Enxame de Faíscas: uma onda em roda, com buracos (%d)" % main.orbs.size())
	var spark: Dictionary = main.orbs[0]
	var s0: Vector3 = spark["node"].position
	await wait(0.4)
	check(is_instance_valid(spark["node"]) and (spark["node"].position - s0).normalized().dot(spark["dir"]) > 0.95, "as faíscas andam em linha reta, sem seguir ninguém")
	var nearest := 99.0
	for o in main.orbs:
		nearest = minf(nearest, Vector2(o["node"].position.x - main.boss_pos.x, o["node"].position.z - main.boss_pos.z).length())
	check(nearest >= main.ORB_START - 0.1 and main.ORB_START > main.MELEE_RANGE, "elas nascem fora do alcance corpo a corpo: perto dele é seguro (%.1f)" % nearest)
	var kinds: Array = []
	for st in main.STEPS_STORM:
		kinds.append(st["t"])
	check(kinds.has("buster") and kinds.has("raid") and kinds.has("stack"), "o ciclo tem trabalho de party: Esmagar no tank, Trovoada e Comunhão")
	main.step = 7
	main._next_step()
	check(main.phase == "fan" and main.fan_beams.size() == 3 and not main.fan_on, "Ventilador de Raios: três raios, primeiro só o aviso")
	check(is_equal_approx(main.arena_r, 13.5) and main.arena_r > main.ARENA_R, "a arena dele é bem maior que a normal")
	check(not main.boss_focus and main.boss_at(main.cam.unproject_position(main.boss_pos + Vector3(0, 1.8, 0))), "dá pra clicar no boss")
	main.boss_focus = true
	await frames_of(2)
	check(main.range_ring != null and main.range_ring.visible and is_equal_approx(main.range_ring_r, u.atk_range), "com o boss em foco aparece o anel do seu alcance máximo")
	main.boss_focus = false
	for o in main.units:
		o.hp = o.max_hp
		o.invuln = 0.0
	main.fan_speed = 0.0
	await wait(main.FAN_WARN + 0.1)
	check(main.fan_on, "depois do aviso os raios ligam")
	# de pé em cima de um raio: apanha
	u.position = main.boss_pos + main._fan_dir(0) * 4.0
	u.fan_safe_t = 0.0
	u.invuln = 0.0
	u.hp = u.max_hp
	var hp_fan: float = u.hp
	await frames_of(3)
	check(u.hp < hp_fan, "de pé no raio: toma o dano do ventilador")
	# no ar em cima de um raio: passa, e o herói aprende
	u.fan_safe_t = 0.0
	u.hop_cd = 0.0
	hp_fan = u.hp
	var k0: float = Knowledge.knowledge(u.hero, "fan")
	var mate: Unit = main.units[(main.ctrl + 1) % 4]
	var m0: float = Knowledge.knowledge(mate.hero, "fan")
	main.jump(u)
	await frames_of(3)
	check(is_equal_approx(u.hp, hp_fan), "pulando, o raio passa por baixo")
	check(is_equal_approx(Knowledge.knowledge(u.hero, "fan"), k0 + main.LEARN_HAND), "passar na mão ensina o herói (+%d)" % main.LEARN_HAND)
	check(Knowledge.knowledge(mate.hero, "fan") >= m0 + main.LEARN_WATCH, "e quem viu aprende um pouco também")
	check(is_equal_approx(Knowledge.knowledge(8, "fan"), Knowledge.KNOW_START), "quem não estava na luta continua no começo")
	# a IA: com pouco conhecimento quase nunca pula; com muito, quase sempre
	var tries := [0, 0]
	for pass_i in 2:
		Knowledge.know[mate.hero] = {"fan": 2.0 if pass_i == 0 else 98.0}
		for n in 60:
			mate.ai_fan_decided = false
			mate.ai_hop_at = -1.0
			mate.ai_run = false
			mate.set_meta("fan_eta", 0.0)
			mate.position = main.boss_pos + main._fan_dir(0).rotated(Vector3.UP, -0.5) * 4.0
			main.fan_speed = 0.75
			main._fan_ai(mate, 0.0)
			if mate.ai_hop_at >= 0.0:
				tries[pass_i] += 1
	main.fan_speed = 0.0
	check(tries[0] < 15 and tries[1] > 50, "o conhecimento muda a CHANCE de a IA tentar o pulo (%d e %d de 60)" % [tries[0], tries[1]])
	# ---------- MEL-CHAN: boss de desvio (pulo, ferrões, corações)
	Knowledge.boss = 5
	Knowledge.know = {}
	main = await fight(2)
	u = main.units[main.ctrl]
	check(main.bee and main.roam and main.boss_def["name"] == "MEL-CHAN", "MEL-CHAN é uma boss que anda")
	check(main.phase == "bee_idle" and main.bee_act == 1, "a luta abre com uma folga, no 1º ato")
	# segura a luta num passo parado, pra testar cada peça na mão
	main.bee_events.clear()
	main.phase = "bee_hold"
	main.phase_dur = 999.0
	main.auto_t = -9999.0
	main.boss_pos = Vector3(0, 0, -6.0)
	u.position = Vector3(0, 0, 3.0)
	u.invuln = 0.0
	main._bee_wave(Vector3(0, 0, 1), 0.0, 7.0)
	var honey: Dictionary = main.bee_waves[-1]
	await wait(0.8)
	check(is_equal_approx(float(honey["s"]), -(main.arena_r + 0.8)) and main.bee_hearts[u.idx] == 0, "Onda de Mel: avisa parada na borda antes de correr")
	while main.bee_waves.has(honey) and float(honey["s"]) < u.position.z + 1.0:
		await process_frame
	check(main.bee_hearts[u.idx] == 1 and u.invuln > 0.0, "no chão a onda pega: +1 coração e um instante sem tomar outro golpe")
	u.invuln = 0.0
	u.hp = u.max_hp
	main._bee_wave(Vector3(0, 0, 1), 0.0, 7.0)
	honey = main.bee_waves[-1]
	while float(honey["s"]) < u.position.z - 1.5:
		await process_frame
	main.jump(u)
	await wait(0.5)
	check(main.bee_hearts[u.idx] == 1, "pulando, a onda passa por baixo")
	u.invuln = 0.0
	u.position = main.boss_pos + Vector3(0, 0, 4.0)
	main._bee_ring(6.0)
	await wait(0.9)
	check(main.bee_hearts[u.idx] == 2, "a onda de choque da Batida do Palco também é pra pular")
	# ferrões: a leva pesada vai em quem o jogador controla
	for o in main.bee_shots:
		o["node"].queue_free()
	main.bee_shots.clear()
	main.bee_focus = u
	u.invuln = 5.0
	main._bee_volley(0)
	var aim: Vector3 = (u.position - main.boss_pos).normalized()
	check(main.bee_shots.size() == 6 and (main.bee_shots[2]["dir"] as Vector3).dot(aim) > 0.99, "Rajada de Ferrões: leque de 5 mirado em você, mais um ferrão num colega")
	await wait(0.7)
	check(main.bee_hearts[u.idx] == 2, "com invulnerabilidade (dash) o ferrão passa direto")
	u.invuln = 0.0
	main._bee_shot(main.boss_pos, aim, 9.0)
	await wait(0.5)
	check(main.bee_hearts[u.idx] == 3, "sem ela, o ferrão dá o 3º coração")
	# 4º coração: encantado
	main.boss_hp = main.boss_max * 0.9
	var hp_boss: float = main.boss_hp
	main._bee_heart(u)
	check(main.bee_hearts[u.idx] == 0 and u.lock_t > 2.0 and main.bee_power > 1.05 and main.boss_hp > hp_boss, "4 corações: o herói fica encantado, ela se cura e fica mais forte")
	# corte no primeiro do aggro
	var tanky2: Unit = main.units[0]
	for o in main.units:
		o.enmity = 0.0
	tanky2.enmity = 999.0
	tanky2.position = main.boss_pos + Vector3(5.0, 0, 0)
	main.hazards.clear()
	main._bee_start({"t": "bee_slash", "dur": 2.0})
	check(main.hazards.size() == 1 and (main.hazards[0]["dir"] as Vector3).dot(Vector3(1, 0, 0)) > 0.99, "Corte Ferroado sai na direção de quem está no topo do aggro")
	# virada de ato pela vida dela
	main.bee_events.clear()
	main.boss_hp = main.boss_max * 0.6
	main.bee_hearts[u.idx] = 2
	main._next_step()
	check(main.phase == "bee_finale" and main.bee_act == 2 and main.bee_shots.is_empty() and main.bee_waves.is_empty(), "abaixo de 66% ela canta o Finale e limpa a arena")
	for o in main.units:
		o.hp = o.max_hp
	await wait(3.6)
	check(main.bee_hearts[u.idx] == 0 and main.phase == "bee_idle" and main.bee_homing.size() == 2, "o Finale zera os corações e o 2º ato apresenta os corações teleguiados")
	check(main.bee_homing[0]["unit"] == u, "o primeiro coração teleguiado persegue quem o jogador controla")
	# aprendizado das cartas: só conta a mecânica que apareceu na luta
	Knowledge.owned["final"] = true
	Knowledge.owned["stack"] = true
	Knowledge.passive = {}
	Knowledge.progress = {}
	Knowledge.equip(u.hero, "final")
	Knowledge.equip(u.hero, "stack")
	main.died = {}
	main.card_fail = {}
	main.fight_mechs = {"dodge": true, "stack": true}
	main._learn_cards()
	check(is_equal_approx(Knowledge.learn_progress(u.hero, "final"), 0.0), "carta de uma mecânica que não apareceu na luta não ganha aprendizado")
	check(is_equal_approx(Knowledge.learn_progress(u.hero, "stack"), Knowledge.LEARN_WIN) and is_equal_approx(Knowledge.learn_progress(u.hero, "dodge"), Knowledge.LEARN_WIN), "a que apareceu, e foi resolvida limpa, ganha")
	main.card_fail = {u.hero: {"dodge": true}}
	main._learn_cards()
	check(is_equal_approx(Knowledge.learn_progress(u.hero, "dodge"), Knowledge.LEARN_WIN) and Knowledge.learn_progress(u.hero, "stack") > 60.0, "quem tomou a mecânica nesta luta não ganha por ela")
	Knowledge.passive = {}
	Knowledge.progress = {}
	Knowledge.learned_now.clear()
	# aprendizado: as ondas de mel e o ritmo do HELL TIME são dois saberes, e aparecem no painel
	check(Knowledge.BOSS_MECHS[5].has("honey") and Knowledge.BOSS_MECHS[5].has("hell") and Knowledge.mech_name("hell") == "Ritmo do HELL TIME", "o painel da MEL-CHAN lista as ondas de mel e o ritmo do HELL TIME")
	check(is_equal_approx(main.BEE_JUMP_CD, 0.6) and main.BEE_JUMP_CD < main.HELL_BEAT * 2.0 - 0.15, "o pulo recarrega com folga pro intervalo das ondas do HELL TIME")
	# HELL TIME: abaixo de metade da vida ela volta pro meio e toca a partitura
	main.boss_pos = Vector3(4.0, 0, -3.0)
	main.boss_hp = main.boss_max * 0.49
	main._next_step()
	check(main.phase == "bee_hell" and main.bee_hell and main.bee_events.size() > 100, "abaixo de metade da vida começa o HELL TIME, com a partitura inteira marcada (%d eventos)" % main.bee_events.size())
	check(is_equal_approx(main.phase_dur, main.HELL_PRE + (main.HELL_BARS * 4 + 1) * main.HELL_BEAT), "ele dura a subida mais os 32 compassos da música")
	for o in main.units:
		o.invuln = 30.0
	await wait(main.HELL_PRE + 0.25)
	check(main.boss_pos.length() < 0.2 and main.bee_rings.size() >= 1, "ela chega no meio do palco junto com a primeira batida")
	check(main.hell_fire.visible and main.hell_glow > 0.9, "o fogo roxo sobe atrás do cenário")
	var hk0: float = Knowledge.knowledge(u.hero, "hell")
	var honey0: float = Knowledge.knowledge(u.hero, "honey")
	u.invuln = 0.0
	u.hop_cd = 0.0
	u.hop_t = 0.0
	u.position = Vector3(3.0, 0, 0)
	main.jump(u)
	check(is_equal_approx(u.hop_cd, main.BEE_JUMP_CD), "nesta luta o pulo usa a recarga curta")
	main._bee_low_touch(u, {"done": {}}, "ring", "teste")
	check(is_equal_approx(Knowledge.knowledge(u.hero, "hell"), hk0 + main.LEARN_HAND) and is_equal_approx(Knowledge.knowledge(u.hero, "honey"), honey0), "pular uma onda no HELL TIME ensina o ritmo do HELL TIME, não as ondas de mel")
	main.phase_t = main._hb(8, 0.5)
	await frames_of(3)
	check(main.bee_hell_dir != 0.0 and main.boss_pos.length() < 0.2, "na seção B o pólen gira e ela continua parada no meio")
	main.phase_t = main.phase_dur - 0.2
	await wait(0.5)
	check(main.phase == "bee_idle" and not main.bee_hell and main.bee_hell_done, "no fim da música a luta volta ao normal, e o HELL TIME não repete")
	await wait(1.4)
	check(not main.hell_fire.visible, "e o fogo apaga")
	Knowledge.boss = 1
	Knowledge.know = {}

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
