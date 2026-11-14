class_name SkillInfo
## Ficha de cada habilidade pra interface: ícone, tipo e descrição. É a ÚNICA fonte de texto e de
## ícone de habilidade: a barra da luta, o tooltip e a tela SKILLS leem daqui.
## As descrições são montadas com as constantes do game.gd, então mudar um número lá muda o texto.
## Ícones: assets/skills/<chave>_<slot>.svg (slot 1..6); o Modo Dormindo do Sleepwalker usa
## <chave>_s<slot>.svg. Habilidade nova = uma entrada em _desc() e um SVG com o nome certo.

const ICON_DIR := "res://assets/skills/"
## Tipos (a cor do selo sai de TYPE_COL).
const TYPE_COL := {
	"Básico": Color("B9BEEA"), "Ataque": Color("FF5E7A"), "Cura": Color("4CE08A"), "Defesa": Color("4FB8FF"),
	"Suporte": Color("FFC83D"), "Movimento": Color("7CF29C"), "Ultimate": Color("C04BFF"), "Transformação": Color("B9A8FF"),
}

static var _icons := {}


static func game() -> GDScript:
	return load("res://scripts/game.gd")


## Lista de habilidades do herói (`asleep`: a do Modo Dormindo do Sleepwalker).
static func kit(key: String, asleep := false) -> Array:
	var g := game()
	return g.SKILLS_ASLEEP if (key == "sleepwalker" and asleep) else g.SKILLS[key]


## O herói tem uma segunda barra (modo transformado)?
static func has_alt(key: String) -> bool:
	return key == "sleepwalker"


static func icon_path(key: String, slot: int, asleep := false) -> String:
	return "%s%s_%s%d.svg" % [ICON_DIR, key, "s" if (asleep and has_alt(key)) else "", slot + 1]


static func icon(key: String, slot: int, asleep := false) -> Texture2D:
	var p := icon_path(key, slot, asleep)
	if not _icons.has(p):
		_icons[p] = load(p) if ResourceLoader.exists(p) else null
	return _icons[p]


## Ícone da habilidade bônus do herói (a Última Dança da Assassina, que aparece no fim do Frenesi).
static func bonus_icon(key: String) -> Texture2D:
	var p := "%s%s_7.svg" % [ICON_DIR, key]
	if not _icons.has(p):
		_icons[p] = load(p) if ResourceLoader.exists(p) else null
	return _icons[p]


static func _n(v: float) -> String:
	# 1.5 -> "1,5" · 20.0 -> "20"
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.2f" % v).rstrip("0").replace(".", ",")


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## Tudo que a interface mostra de uma habilidade:
## {"name", "type", "desc", "cd" (s), "cast" (s), "cost" (texto, "" = sem custo), "big" (importante)}
static func info(key: String, slot: int, asleep := false) -> Dictionary:
	var g := game()
	var sk: Dictionary = kit(key, asleep)[slot]
	var out := {"name": String(sk["name"]), "type": "Ataque", "desc": "", "cd": float(sk.get("cd", 0.0)),
		"cast": float(sk.get("cast", 0.0)), "cost": "", "big": bool(sk.get("big", false))}
	if g.SELF_COST.has(sk["name"]):
		out["cost"] = "%s de vida" % _n(g.SELF_COST[sk["name"]])
	if sk["name"] == "Bloodbath":
		out["cost"] = "%d de Sangue" % g.BATH_COST
	if sk["name"] == "Salva Astral":
		out["cost"] = "%d Rainbow Shots" % g.SALVO_COST
	if key == "sleepwalker":
		out["cast"] = 0.0 if (asleep and slot == 5) else g.SW_CAST
		if asleep and slot >= 1 and slot <= 4:
			out["cd"] = 0.0  # o 0,6 da tabela é só o respiro entre os passos da sequência
		if asleep and sk.has("cost"):
			out["cost"] = "%s de Torpor" % _n(sk["cost"])
	var d: Array = _desc(g, key, slot, asleep, sk)
	out["type"] = d[0]
	out["desc"] = d[1]
	return out


static func _desc(g: GDScript, key: String, slot: int, asleep: bool, sk: Dictionary) -> Array:
	var dmg := _n(float(sk.get("dmg", 0.0)))
	match key:
		"tank":
			match slot:
				0: return ["Básico", "Golpe de espada. %s de dano." % dmg]
				1: return ["Ataque", "Pancada com o escudo. %s de dano." % dmg]
				2: return ["Suporte", "Provoca a boss: ela volta a atacar você, mesmo que outro herói esteja com a atenção dela."]
				3: return ["Ataque", "Consagra o chão onde você está por %s s. A boss leva %s de dano por segundo enquanto estiver ao alcance da área." % [_n(g.HOLY_TIME), _n(g.HOLY_DMG)]]
				4: return ["Defesa", "Ergue o escudo por %s s: você recebe %s menos dano e regenera %s de vida por segundo." % [_n(g.AEGIS_TIME), _pct(1.0 - g.MITIGATION), _n(g.AEGIS_REGEN)]]
				5: return ["Ultimate", "Uma cruz de luz cobre o grupo: a party inteira recebe %s menos dano por %s s." % [_pct(1.0 - g.WALL_MULT), _n(g.WALL_TIME)]]
		"nurse":
			match slot:
				0: return ["Básico", "Estocada com a seringa. %s de dano e rouba um fio de vida da boss. Com o gauge de Sangue cheio, cada golpe devolve %s da sua vida máxima." % [dmg, _pct(g.GAUGE_STEAL)]]
				1: return ["Defesa", "Parry. Por %s s sua vida sobe a %s do normal. Só apara golpes do inimigo (o custo de vida das suas próprias habilidades não conta). Se um golpe acertar nessa janela, você guarda %s do que ganhou, junta %d de Sangue (só no parry bem-sucedido) e a recarga cai pra %s s.\nDurante o Blood Party vira EXTRAÇÃO: crava a seringa na boss por %s s e recupera %s da vida máxima (recarga de %s s)." % [_n(g.TASTE_TIME), _pct(g.TASTE_HP), _pct(g.TASTE_KEEP), g.TASTE_STACKS, _n(g.TASTE_CD_PARRY), _n(g.EXTRACT_TIME), _pct(g.EXTRACT_HEAL), _n(g.EXTRACT_CD)]]
				2: return ["Ataque", "%s de dano. Rouba %s de vida e junta %d de Sangue." % [dmg, _n(g.CONSUMED_STEAL), g.CONSUMED_STACKS]]
				3: return ["Movimento", "Avança até a boss, causa %s de dano, a provoca e junta %d de Sangue." % [_n(g.RUSH_DMG), g.RUSH_STACKS]]
				5:
					return ["Defesa", "Ergue a seringa e faz chover sangue em volta de você (raio %s): quem for coberto recebe %s menos dano por %s s. Depois dela, Syringe Poke, Blood Taste e Blood Consumed brilham vermelho por %s s: a próxima que você usar sai FORTALECIDA.\nPoke: recarga quase pela metade de novo por %s s. Blood Taste: janela do parry em dobro. Blood Consumed: cura %s da vida máxima, regenera você e põe um Compartilhamento de Sangue (%s por segundo, %s s) na party.\nNo Blood Party: o primeiro sai de graça (o botão brilha), alcança o dobro, vale pras %d próximas habilidades, deixa o DoT Pure Blood na boss (%s por segundo, %s s) e a Extração fortalecida carrega %s s e explode por %s de dano." % [_n(g.BATH_R), _pct(1.0 - g.BATH_MULT), _n(g.BATH_TIME), _n(g.BATH_WINDOW), _n(g.POKE_RUSH_TIME), _pct(g.CONSUMED_BIG_HEAL), _n(g.SHARE_REGEN), _n(g.SHARE_TIME), g.BATH_CHARGES_ULT, _n(g.PURE_DPS), _n(g.PURE_TIME), _n(g.EXTRACT_BIG_TIME), _n(g.EXTRACT_BIG_DMG)]]
				4:
					return ["Ultimate", "Gasta o gauge inteiro (%d de Sangue): joga o escudo fora e se injeta. Sua vida vai a 1 e, por %s s, você não morre, dá %s do dano, tem as recargas pela metade e rouba %s do dano que causa. Cura e escudo de aliados não entram. Se a vida não estiver CHEIA quando o tempo acabar, você morre." % [g.PARTY_NEED, _n(g.PARTY_TIME), _pct(g.PARTY_DMG_MULT), _pct(g.PARTY_STEAL)]]
		"healer":
			match slot:
				0: return ["Básico", "Uma chama pequena na boss. %s de dano." % dmg]
				1: return ["Cura", "Cura %s de vida num aliado (o escolhido no card, ou quem mais precisa)." % _n(g.HEAL_PLAYER)]
				2: return ["Cura", "Acende uma fogueira espiritual no chão por %s s. Quem fica dentro recupera %s de vida por segundo. Se o Renascimento for usado com ela acesa, ela fica FORTE: cura %s por segundo, alcança bem mais longe e volta a durar %s s." % [_n(g.HEARTH_TIME), _n(g.HEARTH_HPS), _n(g.HEARTH_STRONG_HPS), _n(g.HEARTH_STRONG_TIME)]]
				3: return ["Defesa", "Escudo de chamas num aliado: absorve até %s da vida máxima dele por %s s." % [_pct(g.SHIELD_RATIO), _n(g.SHIELD_TIME)]]
				4: return ["Cura", "Cura instantânea de %s num aliado. Com alguém caído, vai nele: REVIVE com %s da vida (o escolhido no card tem prioridade)." % [_n(g.PHOENIX_HEAL), _pct(g.REVIVE_HP)]]
				5: return ["Ultimate", "Uma fênix nasce, grita e atravessa o campo devagar, largando fogo pelo caminho. No nascimento: cura %s em todos e levanta quem caiu. Quando ela chega na boss: causa %s de dano e deixa um DoT de %s por segundo por %s s. Com uma Lareira Celestial acesa, a fênix nasce dela e a Lareira fica fortalecida." % [_n(g.REBIRTH_HEAL), _n(g.REBIRTH_DMG), _n(g.REBIRTH_DOT), _n(g.REBIRTH_DOT_TIME)]]
		"assassina":
			match slot:
				0: return ["Básico", "Corte muito rápido. %s de dano. Do lado certo da boss (marcado no chão) causa %s do dano; a cada %d golpes o lado troca. Com a boss em Ferimento, a recarga cai pra %s s." % [dmg, _pct(g.SIDE_MULT), g.SIDE_HITS, _n(g.WOUND_GCD)]]
				1: return ["Movimento", "Atravessa a boss com um corte e sai do outro lado. %s de dano." % dmg]
				2: return ["Suporte", "%d cortes de só %s de dano cada, que abrem um Ferimento na boss por %s s: a party inteira dá +%s de dano nela. Divide a recarga com o Talho Relâmpago; use pra manter o Ferimento." % [g.CLAW_HITS, dmg, _n(g.WOUND_TIME), _pct(g.WOUND_MULT - 1.0)]]
				3: return ["Ataque", "Gira com as duas lâminas abertas. %s de dano. Em Frenesi da Fera o botão brilha roxo: o giro vira um furacão e dá +%s de dano." % [dmg, _pct(g.DANCE_FRENZY - 1.0)]]
				4: return ["Ataque", "A execução, em %s s: arremessa uma adaga, se puxa por ela até a boss e crava as duas no chão (%s do dano), depois sobe num pulo seco e mergulha (o resto). %s de dano no total, e mais quanto menos vida ela tiver (até +%s com ela no fim). Numa boss com Ferimento dá +%s e renova o Ferimento. Se um golpe te acertar no caminho, você o apara e o que falta não sai. Em Frenesi da Fera o botão brilha roxo: você não toma dano, os dois golpes saem de qualquer jeito, dão +%s de dano e você vai girando como uma serra." % [_n(g.MERCY_WINDOW), _pct(g.MERCY_FIRST), dmg, _pct(g.MERCY_EXEC), _pct(g.MERCY_WOUND - 1.0), _pct(g.MERCY_FRENZY - 1.0)]]
				5: return ["Ultimate", "Por %s s: Talho Relâmpago, Garras Cruzadas e Passo Rasante recarregam na metade do tempo, todo o seu dano sobe %s, a Dança Carmesim e o Golpe de Misericórdia ficam mais fortes, e cada Talho Relâmpago tira %s s da recarga dos dois.\nQuando o Frenesi acaba, este botão brilha por %s s: é a ÚLTIMA DANÇA, uma habilidade bônus (não gasta recarga). Ela se prepara por %s s e vai: uma tempestade de %d cortes de %s, um X de %s que abre o Ferimento e, no fim, o CORTE FINAL: %s de todo o dano que você causou durante o Frenesi volta de uma vez. Você fica intocável enquanto ela dura." % [_n(g.FRENZY_TIME), _pct(g.FRENZY_DMG - 1.0), _n(g.FRENZY_SHAVE), _n(g.FINISH_WINDOW), _n(g.FINISH_WINDUP), g.FINISH_HITS, _n(g.FINISH_HIT), _n(g.FINISH_END), _pct(g.FINISH_ECHO)]]
		"maga":
			match slot:
				0: return ["Básico", "Tiro arcano. %s de dano. Logo depois de gastar uma bala, o próximo Disparo sai fortalecido (%s)." % [dmg, _pct(g.PIERCE_MULT)]]
				1: return ["Ataque", "Só sai com pelo menos uma Rainbow Shot guardada. Gasta uma bala: %s de dano e o efeito da cor dela. Com EXATAMENTE 3 balas, gasta as três num tiro de %s que te empurra pra trás. Você ganha uma bala a cada %s s, até %d.
Vermelha: +20%% de dano por %s s.
Azul: recebe 25%% menos dano por %s s.
Verde: recupera 20 de vida.
Roxa: veneno na boss, 5 por segundo por 8 s.
Amarela: o próximo Disparo Rúnico te joga pra trás." % [_n(g.BULLET_DMG), _n(g.BULLET_TRIPLE), _n(g.BULLET_EVERY), g.BULLET_MAX, _n(g.BULLET_BUFF), _n(g.BULLET_BUFF)]]
				2: return ["Ataque", "Tiro que ricocheteia na boss: %s de dano. Com o escudo da Salva Astral de pé e perto da boss, a bala passa a ricochetear em você também, por até %s s: %s de dano em cada ida e %s de cura em cada volta (o que passar da vida cheia vira escudo). Sem esse escudo, nunca volta em você. Com a Fada Astral em campo, quica entre a boss e a fada de qualquer distância." % [_n(g.RICO_DMG * 2.5), _n(g.RICO_TIME), _n(g.RICO_DMG), _n(g.RICO_HEAL)]]
				3: return ["Ataque", "Projétil pesado em linha reta: %s de dano e marca a boss por %s s. Salva Astral, Canhão Estelar ou Disparo Rúnico fortalecido usados nesse tempo estouram a marca: +%s de dano, uma vez." % [dmg, _n(g.AIM_TIME), _n(g.AIM_BONUS)]]
				4: return ["Ataque", "Consome %d Rainbow Shots. Rajada de %s de dano por bala e um escudo de %s em você. Não tem recarga: só fica disponível com %d balas ou mais.\nCom EXATAMENTE %d balas o botão brilha: a Salva gasta as %d e solta a Fada Astral, que fica %s s perto da boss dando %s de dano por segundo. Com a fada em campo, o Ricochete Prismático quica entre a boss e ela, e cada bala que ela recebe cura a party em %s da vida máxima (o que sobrar vira escudo)." % [g.SALVO_COST, _n(g.SALVO_DMG), _n(g.SALVO_SHIELD), g.SALVO_COST, g.SALVO_FAIRY, g.SALVO_FAIRY, _n(g.FAIRY_TIME), _n(g.FAIRY_DPS), _pct(g.FAIRY_HEAL)]]
				5: return ["Ultimate", "Materializa o canhão (parada) e dispara: %s de dano, mais %s por Rainbow Shot guardada (gasta todas). Com EXATAMENTE %d balas vira o supercanhão arco-íris: +%s de dano, e você fica %s s presa no lugar segurando o disparo." % [_n(g.CANNON_DMG), _n(g.CANNON_PER_BULLET), g.BULLET_MAX, _n(g.CANNON_SUPER_BONUS), _n(g.CANNON_SUPER_TIME)]]
		"burner":
			match slot:
				0: return ["Básico", "Projétil de fogo. %s de dano. A recarga conta desde o começo da conjuração." % dmg]
				1: return ["Ataque", "Marca a boss com um halo por %s s: %s de dano por segundo. O halo fica mais luminoso conforme a marca chega ao fim." % [_n(g.ZENITH_TIME), _n(g.ZENITH_DPS)]]
				2: return ["Ataque", "Uma lança celestial se forma no céu e cai na boss, estourando a Marca do Zênite. Quanto mais perto do fim da marca, mais forte: de %s a %s de dano. O dano é definido quando você começa a conjurar, então a marca pode acabar durante o preparo sem perder o bônus. Nos últimos %s s da marca o botão brilha: é a Lança Perfeita, envolta em fogo. Sem marca, só %s." % [_n(g.LANCE_MIN), _n(g.LANCE_MAX), _n(g.ZENITH_TIME * (1.0 - g.LANCE_PERFECT)), _n(g.LANCE_BARE)]]
				3: return ["Movimento", "Rasante curto que deixa uma explosão. %s de dano." % _n(g.SWOOP_DMG)]
				4: return ["Ataque", "Chuva de chamas na boss: %s de dano por segundo por %s s." % [_n(g.RAIN_DPS), _n(g.RAIN_TIME)]]
				5: return ["Ultimate", "Sobe por %s s abrindo as asas e lança um sol que leva %s s até a boss: %s de dano. Com a boss marcada na hora do uso, %s e um DoT de %s por segundo por %s s (não gasta a marca). Depois de lançar, você flutua %s s e já pode agir." % [_n(g.SOLAR_RISE), _n(g.SOLAR_TRAVEL), _n(g.SOLAR_DMG), _n(g.SOLAR_MARKED), _n(g.SOLAR_DOT), _n(g.SOLAR_DOT_TIME), _n(g.SOLAR_FLOAT)]]
		"ringstar":
			match slot:
				0: return ["Básico", "%s de dano. Começa a sequência e fortalece o Direto de Campeã." % dmg]
				1: return ["Ataque", "Fortalecido pelo Jab: %s de dano e fortalece o Gancho. Fora da sequência: só %s." % [dmg, _n(g.WEAK_HIT)]]
				2: return ["Ataque", "Fortalecido pelo Direto: %s de dano e a sequência recomeça. Fora da sequência: só %s." % [dmg, _n(g.WEAK_HIT)]]
				3: return ["Suporte", "Avança até a boss. Por %s s a recarga dos três golpes cai pra %s s, seu dano sobe %s e você anda %s mais rápido. Não quebra a sequência." % [_n(g.COUNT_TIME), _n(g.COUNT_GCD), _pct(g.COUNT_DMG - 1.0), _pct(g.COUNT_SPEED - 1.0)]]
				4: return ["Ataque", "Pega o microfone e aponta pra boss por %s s; depois dispara uma rajada de estrelas por %s s, de qualquer distância: %s de dano no total. Você continua agindo enquanto isso e a sequência não quebra." % [_n(g.SUPERSTAR_WIND), _n(g.SUPERSTAR_FIRE), _n(g.SUPERSTAR_DMG)]]
				5: return ["Ultimate", "Salta por %s s e despenca na boss: %s de dano em área em volta de onde cair (raio %s). No ar, passa por cima de ataques rentes ao chão." % [_n(g.KNOCKOUT_AIR), _n(g.KNOCKOUT_DMG), _n(g.KNOCKOUT_R)]]
		"apothecary":
			match slot:
				0: return ["Básico", "%s de dano. Com a boss em Decomposição, cura %s no Paciente. Sem Decomposição, a recarga sobe pra %s s." % [dmg, _n(g.PATIENT_HEAL), _n(g.INCISION_SLOW)]]
				1: return ["Ataque", "%s de dano e aplica Decomposição. Renovar com %s s ou menos sobrando rende 1 Vestígio (até %d)." % [dmg, _n(g.VESTIGE_WINDOW), g.VESTIGE_MAX]]
				2: return ["Cura", "Cura %s num aliado e faz dele o Paciente por %s s. Num aliado CAÍDO escolhido no card: prepara o corpo (ele vira o Paciente), primeiro passo pra reanimar." % [_n(g.SUTURE_HEAL), _n(g.PATIENT_TIME)]]
				3: return ["Defesa", "Num aliado: escudo de %s da vida máxima por %s s. Com %d Vestígios, a boss em Decomposição e nenhum aliado escolhido: aplica Contaminação na boss por %s s." % [_pct(g.HEMO_RATIO), _n(g.HEMO_TIME), g.VESTIGE_MAX, _n(g.CONTAM_TIME)]]
				4: return ["Ultimate", "Nuvem Conservante: cura %s em todos e regenera %s por segundo por %s s (gastando %d Vestígios, %s) e dá %s de velocidade de movimento à party por %s s. Com a boss Contaminada vira Nuvem Tóxica: %s de dano e %s por segundo por %s s." % [_n(g.CLOUD_HEAL), _n(g.CLOUD_REGEN), _n(g.CLOUD_TIME), g.VESTIGE_MAX, _pct(g.CLOUD_BOOST), "+" + _pct(g.HASTE_MULT - 1.0), _n(g.HASTE_TIME), _n(g.TOXIC_DMG), _n(g.TOXIC_DPS), _n(g.TOXIC_TIME)]]
				5: return ["Cura", "Cura instantânea de %s num aliado; %s a mais se ele estiver abaixo de %s da vida. Se o Paciente está caído (preparado pela Sutura) e você tem %d Vestígios: gasta os Vestígios e REANIMA ele com %s da vida." % [_n(g.STABILIZE_HEAL), _pct(0.5), _pct(g.STABILIZE_LOW), g.REANIMATE_COST, _pct(g.REANIMATE_HP)]]
		"valsa":
			var bonus := "+%s de dano (até +%s com %d de Embalo)" % [_pct(g.SKIRT_BONUS), _pct(g.SKIRT_BONUS + g.SKIRT_BONUS_PER * g.EMBALO_MAX), g.EMBALO_MAX]
			match slot:
				0: return ["Básico", "Um, dois, TRÊS. Os dois primeiros passos dão %s de dano; o terceiro é o GIRO (o botão brilha): %s de dano, mais %s por ponto de Embalo, e rende 1 de Embalo.\nO Embalo abre a sua saia: aliados dentro dela (o círculo no chão) ganham %s. Você não ganha o bônus: é pra party. Sem girar por %s s, o Embalo começa a cair." % [dmg, _n(g.WALTZ_GIRO), _n(g.WALTZ_GIRO_PER), bonus, _n(g.EMBALO_HOLD)]]
				1: return ["Suporte", "Estende a mão pra um aliado (o escolhido no card; sem escolha, quem mais bate): vocês dois acertam a boss, %s de dano cada, e ele recupera %s de vida. Ele vira o seu PAR: o fio dourado leva o bônus da saia até ele em qualquer lugar da arena, e a cada Giro seu ele acerta a boss junto (%s de dano, mais %s por ponto de Embalo). Depois do Passo a Dois, o próximo Passo de Valsa já é o Giro." % [_n(g.DUET_DMG), _n(g.DUET_HEAL), _n(g.DUET_ECHO), _n(g.DUET_ECHO_PER)]]
				2: return ["Defesa", "Três voltas na ponta do pé, de qualquer lugar: %s de dano se a boss estiver ao alcance, 1 de Embalo, e o Par acompanha. Por %s s, golpe nenhum te acerta. Se um golpe passar por você nesse tempo, é BRAVO!: +%d de Embalo e a recarga da Pirueta cai pela metade." % [_n(g.TWIRL_DMG), _n(g.TWIRL_TIME), g.TWIRL_BRAVO]]
				3: return ["Cura", "Joga o buquê pro alto: quem está na sua dança (dentro da saia, o Par e você) recupera %s de vida na hora e %s por segundo enquanto as pétalas caem, por %s s." % [_n(g.PETAL_BURST), _n(g.PETAL_HPS), _n(g.PETAL_TIME)]]
				4: return ["Suporte", "A música sobe. Por %s s o bônus da saia DOBRA, o Passo de Valsa recarrega em %s s e o Embalo não cai." % [_n(g.CRESC_TIME), _n(g.CRESC_GCD)]]
				5: return ["Ultimate", "A arena vira salão por %s s: a party inteira conta como dentro da saia, onde estiver; o Embalo vai ao máximo e fica lá; e todos os aliados acompanham os seus Giros. No último acorde: %s de dano na boss e %s de cura em todos." % [_n(g.BALL_TIME), _n(g.BALL_END_DMG), _n(g.BALL_END_HEAL)]]
		"sleepwalker":
			var sc: float = g.SW_SCALE
			var near := "Com Perto do Sonho, a conjuração cai pra %s s." % _n(g.SW_CAST_NEAR)
			if asleep:
				var base := _n(float(sk.get("base", 0.0)) * sc)
				match slot:
					0: return ["Ataque", "%s de dano e aplica Pesadelo Persistente (%s por segundo, %s s). Aplicar o DoT dá Perto do Sonho: %s s se renovar nos últimos %s s dele, %s s nos outros casos. Sem Torpor, sai de graça e fraca. Acordar logo depois dela custa só %s de Torpor e %s s sem agir." % [base, _n(g.NIGHTMARE_DPS), _n(g.NIGHTMARE_TIME), _n(g.NEAR_PERFECT), _n(g.NEAR_WINDOW), _n(g.NEAR_OTHER), _n(g.SW_BITE_WAKE), _n(g.SW_LOCK_BITE)]]
					1: return ["Ataque", "Segunda da sequência. %s de dano. Daqui em diante, acordar sem fechar com A Casa que Engole custa %s s sem agir." % [base, _n(g.SW_LOCK_BROKEN)]]
					2: return ["Ataque", "Terceira da sequência. %s de dano." % base]
					3: return ["Ataque", "Quarta da sequência. %s de dano." % base]
					4: return ["Ultimate", "Fecha a sequência: %s de dano e escudo de %s da vida máxima em toda a party por %s s. Você acorda sozinho, sem punição." % [base, _pct(g.HOUSE_SHIELD), _n(g.HOUSE_SHIELD_TIME)]]
					5: return ["Transformação", "Acorda na hora. Se usou só A Mordida dos Mil: perde %s de Torpor e fica %s s sem agir. Sem ter usado nada: perde tudo e %s s. Largando a sequência no meio: perde tudo e %s s." % [_n(g.SW_BITE_WAKE), _n(g.SW_LOCK_BITE), _n(g.SW_LOCK_NONE), _n(g.SW_LOCK_BROKEN)]]
			var a: Dictionary = g.SW_AWAKE[mini(slot, 4)]
			var hit := _n(float(a["base"]) * sc)
			var tp := _n(a["torpor"])
			var win := "Só vale dentro da sequência que começa no Puxar o Lençol: comece a conjurar em até %s s depois da habilidade anterior pra ganhar +%s de Torpor e o efeito completo. Solta, não dá bônus nem abre a próxima." % [_n(g.SW_WINDOW), _n(g.SW_PERFECT_TORPOR)]
			match slot:
				0: return ["Básico", "%s de dano, +%s de Torpor. Acerta as Frestas dos Ecos do Pesadelo (+%s de dano e +%s de Torpor). %s" % [hit, tp, _n(g.ECHO_BASE * sc), _n(g.SW_ECHO_TORPOR), near]]
				1: return ["Ataque", "Abre a sequência. %s de dano, +%s de Torpor e +%d de Vulnerabilidade Onírica (cada acúmulo: +%s de dano seu, até %d, por %s s)." % [hit, tp, int(a["stacks"]), _pct(g.DREAM_PER), g.DREAM_MAX, _n(g.DREAM_TIME)]]
				2: return ["Ataque", "%s de dano, +%s de Torpor. Na janela: +%d de Vulnerabilidade e deixa Migalhas. %s" % [hit, tp, int(a["stacks"]), win]]
				3: return ["Ataque", "%s de dano, +%s de Torpor. Na janela e com Migalhas: +%d de Vulnerabilidade e fica com o Travesseiro Cheio. %s" % [hit, tp, int(a["stacks"]), win]]
				4: return ["Ataque", "%s de dano, +%s de Torpor. Na janela e com o Travesseiro Cheio: dano %s e abre os Ecos do Pesadelo (quatro Frestas pro Bocejo). %s" % [hit, tp, _pct(g.SW_BED_BONUS), win]]
				5: return ["Transformação", "Entra no Modo Dormindo: imóvel, gasta Torpor numa sequência de ordem fixa. Sem Torpor pra próxima, você acorda sozinho. Acordado, o Torpor cai %s por segundo (ao encher, segura cheio por %s s)." % [_n(g.SW_DECAY), _n(g.SW_FULL_HOLD)]]
	return ["Ataque", ""]
