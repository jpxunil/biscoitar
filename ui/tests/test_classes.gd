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

	# ================================================================ MAGA
	main = await fight(3)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	kit = main.SKILLS["maga"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
		check(not sk.has("cast"), "Maga: %s não tem conjuração" % sk["name"])
	check(names == ["Disparo Rúnico", "Rainbow Shots", "Ricochete Prismático", "Tiro Perfurante", "Salva Astral", "Canhão Estelar"], "Maga: as seis da ficha: %s" % [names])
	check(cds == [1.0, 0.3, 8.0, 12.0, 20.0, 60.0], "Maga: recargas (Rainbow Shots só tem o intervalo de 0,3 s): %s" % [cds])
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 26.0), "Disparo Rúnico sai na hora")
	check(u.bullets.is_empty(), "começa sem balas")
	before = u.dmg_total
	main.use_skill(u, 1)
	check(is_equal_approx(u.dmg_total, before), "Rainbow Shots sem bala não atira")
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
	u.bullet_t = 5.0
	await wait(0.2)
	check(u.bullets.size() == 7, "no máximo 7 balas")
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
	before = u.dmg_total
	main.use_skill(u, 2)
	check(u.ricochet_t > 3.5, "Ricochete perto da boss: a bala fica indo e voltando por 4 s")
	await wait(2.2)
	check(u.dmg_total - before >= main.RICO_DMG * 2.0 and u.hp > 50.0, "cada ida bate na boss, cada volta cura a Maga (%.0f de dano, vida %.0f)" % [u.dmg_total - before, u.hp])
	# a boss bate em outro herói enquanto isso, pra não gastar o escudo que está sendo medido
	main.units[0].enmity = 999999.0
	u.hp = u.max_hp
	u.shield_hp = 0.0
	var got_shield := false
	var until := Time.get_ticks_msec() + 1300
	while Time.get_ticks_msec() < until:
		await process_frame
		u.hp = u.max_hp
		if u.shield_hp > 0.0:
			got_shield = true
	check(got_shield, "com a vida cheia, a cura vira escudo")
	await wait(1.2)
	check(u.ricochet_t <= 0.0, "e acaba depois de 4 s")
	u.position = Vector3(1.6, 0, 1.2)
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 3)
	check(is_equal_approx(u.dmg_total - before, 95.0), "Tiro Perfurante")
	u.bullets = [0, 1]
	before = u.dmg_total
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total, before) and u.bullets.size() == 2 and u.skill_cd[4] <= 0.0, "Salva Astral precisa de 3 balas (sem elas, nem gasta a recarga)")
	u.bullets = [0, 1, 2, 3]
	u.shield_hp = 0.0
	main.use_skill(u, 4)
	check(is_equal_approx(u.dmg_total - before, main.SALVO_DMG * 3.0) and u.bullets.size() == 1, "Salva Astral: gasta 3 balas, dano em área")
	check(is_equal_approx(u.shield_hp, main.SALVO_SHIELD), "e dá um escudo nela")
	u.bullets = []
	before = u.dmg_total
	main.use_skill(u, 5)
	check(is_equal_approx(u.dmg_total - before, main.CANNON_DMG), "Canhão Estelar sozinho: %d" % main.CANNON_DMG)
	ready(u)
	u.bullets = [0, 1, 2, 3, 4, 0, 1]
	before = u.dmg_total
	main.use_skill(u, 5)
	var cannon: float = u.dmg_total - before
	check(is_equal_approx(cannon, main.CANNON_DMG + 7.0 * main.CANNON_PER_BULLET) and u.bullets.is_empty(), "Canhão com as 7 balas guardadas: %.0f" % cannon)
	check(cannon > main.CANNON_DMG + 7.0 * main.BULLET_DMG, "guardar as balas pro canhão rende mais do que soltar as 7 e usar o canhão vazio")

	# ================================================================ SOULBURNER
	main = await fight(5)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
	check(u.key == "burner" and u.unit_name == "Soulburner" and not u.melee, "Soulburner entra na luta (classe nova, à distância)")
	kit = main.SKILLS["burner"]
	names = []
	cds = []
	for sk in kit:
		names.append(sk["name"])
		cds.append(sk["cd"])
	check(names == ["Brasas do Firmamento", "Marca do Zênite", "Lança Serafim", "Rasante Incandescente", "Chuva de Brasas", "Juízo Solar"], "Soulburner: as seis da ficha: %s" % [names])
	check(cds == [1.0, 12.0, 8.0, 10.0, 20.0, 60.0], "Soulburner: recargas da ficha: %s" % [cds])
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 24.0), "Brasas do Firmamento")
	before = u.dmg_total
	main.use_skill(u, 2)
	check(is_equal_approx(u.dmg_total - before, main.LANCE_BARE), "Lança Serafim sem marca: quase nada (%d)" % main.LANCE_BARE)
	ready(u)
	main.use_skill(u, 1)
	check(not main.get_dot("zenite").is_empty() and is_equal_approx(main.get_dot("zenite")["t"], 10.0), "Marca do Zênite: 10 s na boss")
	check(absf(main.lance_damage() - main.LANCE_MIN) < 3.0, "Lança logo depois de marcar: dano médio (%.0f)" % main.lance_damage())
	main.get_dot("zenite")["t"] = 0.5
	check(main.lance_damage() > main.LANCE_MAX - 8.0, "Lança com a marca quase acabando: dano alto (%.0f)" % main.lance_damage())
	before = u.dmg_total
	var expect: float = main.lance_damage()
	main.use_skill(u, 2)
	check(absf(u.dmg_total - before - expect) < 1.0 and main.get_dot("zenite").is_empty(), "a Lança usa e remove a marca")
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
	main.remove_dot("zenite")
	before = u.dmg_total
	main.use_skill(u, 5)
	check(is_equal_approx(u.dmg_total - before, main.SOLAR_DMG) and main.get_dot("solar").is_empty(), "Juízo Solar sem marca: %d e sem DoT" % main.SOLAR_DMG)
	ready(u)
	main.use_skill(u, 1)
	before = u.dmg_total
	main.use_skill(u, 5)
	check(is_equal_approx(u.dmg_total - before, main.SOLAR_MARKED), "Juízo Solar com a boss marcada: mais dano (%d)" % main.SOLAR_MARKED)
	check(not main.get_dot("solar").is_empty() and not main.get_dot("zenite").is_empty(), "deixa um DoT médio e NÃO gasta a marca")

	# ================================================================ RINGSTAR
	main = await fight(6)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
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
	check(main.hud.skill_ui[1]["slab"].modulate != Color(1, 1, 1) and main.hud.skill_ui[0]["slab"].modulate == Color(1, 1, 1), "na barra, só o botão fortalecido brilha")
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
	check(is_equal_approx(u.dmg_total - before, main.SUPERSTAR_DMG) and main.glow_slot(u) == 1, "SUPERSTAR! no meio da sequência não quebra o fortalecimento")
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
	check(is_equal_approx(u.dmg_total - before, main.SUPERSTAR_DMG), "SUPERSTAR! funciona de longe")
	main.use_skill(u, 3)
	await wait(0.25)
	check(main._in_range(u) and u.count_t > 14.0, "Contagem Regressiva: avança até a boss e liga o buff de 15 s")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 22.0 * main.COUNT_DMG), "com a Contagem: +10% de dano")
	check(is_equal_approx(u.skill_cd[0], main.COUNT_GCD) and is_equal_approx(u.skill_cd[2], main.COUNT_GCD), "e o GCD cai pra 1 s")
	u.count_t = 0.0
	before = u.dmg_total
	main.use_skill(u, 5)
	check(is_equal_approx(u.dmg_total - before, main.KNOCKOUT_DMG), "Nocaute Final: %d" % main.KNOCKOUT_DMG)

	# ================================================================ APOTECÁRIO
	main = await fight(7)
	u = main.units[main.ctrl]
	main.phase = "dodgetime"
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
	check(u.key == "sleepwalker" and not u.melee and not u.asleep, "Sleepwalker entra na luta, acordado (classe nova, à distância)")
	names = []
	for sk in main.kit(u):
		names.append(sk["name"])
	check(names == ["Bocejo", "Puxar o Lençol", "Visitantes debaixo da Cama", "Senhor Travesseiro", "A Cama Caiu!", "Sono Profundo"], "Modo Acordado: os seis botões: %s" % [names])
	var sc: float = main.SW_SCALE
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 50.0 * sc) and is_equal_approx(u.torpor, 4.0) and is_equal_approx(u.skill_cd[0], 2.0), "Bocejo: dano, +4 Torpor, recarga de 2 s")
	# sequência perfeita
	u.torpor = 0.0
	main.use_skill(u, 1)
	check(main.dream_stacks == 2 and u.window_slot == 2 and is_equal_approx(u.window_t, 1.0), "Puxar o Lençol: 2 stacks e abre 1 s pros Visitantes")
	check(main.glow_slot(u) == 2, "o botão da janela brilha")
	await wait(0.4)
	main.use_skill(u, 2)
	check(main.dream_stacks == 5 and u.crumbs and u.window_slot == 3, "Visitantes na janela: 3 mordidas (5 stacks) e Migalhas")
	await wait(0.4)
	main.use_skill(u, 3)
	check(main.dream_stacks == 7 and u.pillow_full and u.window_slot == 4, "Senhor Travesseiro na janela: come as Migalhas (7 stacks) e fica Cheio")
	await wait(0.4)
	before = u.dmg_total
	main.use_skill(u, 4)
	check(main.dream_stacks == 8, "A Cama Caiu! fecha os 8 stacks de Vulnerabilidade Onírica")
	check(is_equal_approx(u.dmg_total - before, 200.0 * main.SW_BED_BONUS * sc * 1.16), "com Travesseiro Cheio e 8 stacks: %.0f de dano" % (u.dmg_total - before))
	check(main.echoes.size() == 4, "e ativa os Ecos do Pesadelo (4 Frestas)")
	check(u.torpor > 73.0 and u.torpor < 75.5, "Torpor do ciclo perfeito: 60 das habilidades + 15 das interações, menos a perda (%.1f)" % u.torpor)
	check(is_equal_approx(u.skill_cd[4], 15.0), "cada habilidade da sequência tem 15 s de recarga")
	# Fresta: abre 1 s depois, por 0,5 s
	await wait(1.1)
	await frames_of(2)
	check(main.echo_mark.visible, "a primeira Fresta abre 1 s depois da Cama")
	ready(u)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, (50.0 + main.ECHO_BASE) * sc * 1.16), "Bocejo na Fresta aberta: dano extra")
	await wait(0.6)
	await frames_of(2)
	check(not main.echo_mark.visible, "a Fresta fecha depois de 0,5 s")
	# janela perdida
	main.echoes.clear()
	main.dream_stacks = 0
	ready(u)
	main.use_skill(u, 1)
	await wait(1.25)
	check(u.window_slot == -1, "a janela de 1 s passa")
	var t0: float = u.torpor
	main.use_skill(u, 2)
	check(main.dream_stacks == 3 and not u.crumbs, "Visitantes fora da janela: só 1 stack e sem Migalhas")
	check(u.torpor - t0 < 12.5, "e sem o Torpor extra da interação")
	main.use_skill(u, 3)
	main.use_skill(u, 4)
	check(main.dream_stacks < 8 and main.echoes.is_empty(), "com uma janela perdida, não chega nos 8 stacks nem ativa os Ecos (%d)" % main.dream_stacks)
	t0 = u.torpor
	await wait(1.0)
	check(u.torpor < t0 - 0.8, "acordado, o Torpor cai 1 por segundo")

	# Modo Dormindo
	u.torpor = 100.0
	main.dream_stacks = 0
	main.use_skill(u, 5)
	check(u.asleep and is_equal_approx(u.skill_cd[5], 3.0), "Sono Profundo transforma (3 s de recarga)")
	names = []
	for sk in main.kit(u):
		names.append(sk["name"])
	check(names == ["A Mordida dos Mil", "Senhor Travesseiro: Devorador", "O Abraço Impossível", "A Porta Errada", "A Casa que Engole", "Acordar"], "Modo Dormindo: os seis botões: %s" % [names])
	await frames_of(3)
	check(main.hud.skill_ui[0]["name"].text == "A MORDIDA DOS MIL", "a barra de habilidades troca junto")
	check(is_equal_approx(u.awake_cd[4], u.awake_cd[4]) and u.awake_cd[1] > 10.0, "as recargas do Modo Acordado ficam guardadas")
	p0 = u.position
	Input.action_press("move_left")
	await wait(0.3)
	Input.action_release("move_left")
	main._try_dash()
	check(u.position.is_equal_approx(p0) and u.dash_cd <= 0.0, "dormindo, ele não anda nem desvia")
	main.use_skill(u, 2)
	check(is_equal_approx(u.torpor, 100.0), "fora de ordem, a habilidade não sai")
	check(main.glow_slot(u) == 0, "a próxima da ordem brilha")
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.torpor, 95.0) and not main.get_dot("pesadelo").is_empty(), "A Mordida dos Mil: 5 de Torpor e aplica o Pesadelo Persistente")
	check(is_equal_approx(u.near_t, 10.0), "primeira aplicação: Perto do Sonho por 10 s")
	for n in range(1, 5):
		ready(u)
		check(main.glow_slot(u) == n, "passo %d da sequência é o que brilha" % (n + 1))
		main.use_skill(u, n)
	check(is_equal_approx(u.dmg_total - before, 1300.0 * sc), "a sequência completa dá o dano total da ficha (1300 na escala do jogo: %.0f)" % (u.dmg_total - before))
	check(not u.asleep and is_equal_approx(u.torpor, 0.0), "A Casa que Engole gasta o resto do Torpor e acorda sozinho")
	check(is_equal_approx(main.units[0].shield_hp, main.units[0].max_hp * 0.08), "e dá escudo de 8%% da vida máxima nos aliados")
	check(u.skill_cd[1] > 5.0, "ao acordar, as recargas do Modo Acordado voltam de onde estavam")
	# com Perto do Sonho: tudo 1 s mais rápido
	ready(u)
	main.use_skill(u, 0)
	check(is_equal_approx(u.skill_cd[0], 1.0), "Perto do Sonho: Bocejo com 1 s")
	main.use_skill(u, 1)
	check(is_equal_approx(u.skill_cd[1], 14.0), "Perto do Sonho: Puxar o Lençol com 14 s")
	# renovação perfeita e imperfeita
	ready(u)
	u.bite_cd = 0.0
	u.torpor = 20.0
	main.get_dot("pesadelo")["t"] = 10.0
	main.use_skill(u, 5)
	main.use_skill(u, 0)
	check(is_equal_approx(u.near_t, 10.0), "renovar cedo (faltando 10 s): só 10 s de Perto do Sonho")
	check(is_equal_approx(u.skill_cd[0], 17.0), "a Mordida tem 18 s de recarga (17 com o buff)")
	ready(u)
	main.use_skill(u, 5)
	ready(u)
	u.bite_cd = 0.0
	main.get_dot("pesadelo")["t"] = 1.5
	main.use_skill(u, 5)
	main.use_skill(u, 0)
	check(is_equal_approx(u.near_t, 20.0), "renovar nos últimos 2 s: Perto do Sonho por 20 s")
	# sem Torpor: Mordida de graça e fraca, e acorda sozinho
	ready(u)
	main.use_skill(u, 5)
	ready(u)
	u.bite_cd = 0.0
	u.torpor = 3.0
	main.dream_stacks = 0
	main.use_skill(u, 5)
	before = u.dmg_total
	main.use_skill(u, 0)
	check(is_equal_approx(u.dmg_total - before, 100.0 * 0.2 * sc) and is_equal_approx(u.torpor, 3.0), "com menos de 5 de Torpor, a Mordida sai de graça e bem fraca")
	check(u.asleep and u.wake_t > 0.0, "sem Torpor pra próxima, avisa que vai acordar")
	await wait(1.15)
	check(not u.asleep and is_equal_approx(u.torpor, 0.0), "e acorda 1 s depois, perdendo o Torpor que sobrou")
	main.remove_dot("pesadelo")
	await frames_of(3)
	check(is_equal_approx(u.near_t, 0.0), "se o Pesadelo Persistente cai, o Perto do Sonho vai junto")

	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
