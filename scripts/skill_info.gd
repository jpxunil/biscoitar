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
				1: return ["Defesa", "Parry. Por %s s sua vida sobe a %s do normal. Se um golpe acertar nessa janela, você guarda %s do que ganhou, junta %d de Sangue e a recarga cai pra %s s." % [_n(g.TASTE_TIME), _pct(g.TASTE_HP), _pct(g.TASTE_KEEP), g.TASTE_STACKS, _n(g.TASTE_CD_PARRY)]]
				2: return ["Ataque", "%s de dano. Rouba %s de vida e junta %d de Sangue." % [dmg, _n(g.CONSUMED_STEAL), g.CONSUMED_STACKS]]
				3: return ["Movimento", "Avança até a boss, causa %s de dano e a provoca." % _n(g.RUSH_DMG)]
				4:
					return ["Ultimate", "Gasta o gauge inteiro (%d de Sangue). Sua vida vai a 1 e você fica invulnerável por %s s, com uma aura que causa %s de dano a cada %s s na boss próxima." % [g.PARTY_NEED, _n(g.PARTY_TIME), _n(g.PARTY_DMG), _n(g.PARTY_TICK)]]
		"healer":
			match slot:
				0: return ["Básico", "Uma chama pequena na boss. %s de dano." % dmg]
				1: return ["Cura", "Cura %s de vida num aliado (o escolhido no card, ou quem mais precisa)." % _n(g.HEAL_PLAYER)]
				2: return ["Cura", "Acende uma fogueira espiritual no chão por %s s. Quem fica dentro recupera %s de vida por segundo." % [_n(g.HEARTH_TIME), _n(g.HEARTH_HPS)]]
				3: return ["Defesa", "Escudo de chamas num aliado: absorve até %s da vida máxima dele por %s s." % [_pct(g.SHIELD_RATIO), _n(g.SHIELD_TIME)]]
				4: return ["Cura", "Cura instantânea de %s num aliado." % _n(g.PHOENIX_HEAL)]
				5: return ["Ultimate", "Uma fênix atravessa o campo: cura %s em todos, levanta quem caiu, causa %s de dano na boss e deixa um DoT de %s por segundo por %s s." % [_n(g.REBIRTH_HEAL), _n(g.REBIRTH_DMG), _n(g.REBIRTH_DOT), _n(g.REBIRTH_DOT_TIME)]]
		"assassina":
			match slot:
				0: return ["Básico", "Corte muito rápido. %s de dano. Do lado certo da boss (marcado no chão) causa %s do dano; a cada %d golpes o lado troca." % [dmg, _pct(g.SIDE_MULT), g.SIDE_HITS]]
				1: return ["Movimento", "Atravessa a boss com um corte e sai do outro lado. %s de dano." % dmg]
				2: return ["Ataque", "%d cortes seguidos de %s de dano cada." % [g.CLAW_HITS, dmg]]
				3: return ["Ataque", "Gira com as lâminas. %s de dano." % dmg]
				4: return ["Ataque", "Um corte de %s de dano que sai depois de %s s. Se a boss te acertar nesse instante, o golpe dela é aparado (parry) e o corte não sai." % [dmg, _n(g.MERCY_WINDOW)]]
				5: return ["Ultimate", "Por %s s: o Talho Relâmpago recarrega na metade do tempo e todo o seu dano sobe %s." % [_n(g.FRENZY_TIME), _pct(g.FRENZY_DMG - 1.0)]]
		"maga":
			match slot:
				0: return ["Básico", "Tiro arcano. %s de dano. Logo depois de gastar uma bala, o próximo Disparo sai fortalecido (%s)." % [dmg, _pct(g.PIERCE_MULT)]]
				1: return ["Ataque", "Gasta uma bala Rainbow: %s de dano e o efeito da cor dela. Com EXATAMENTE 3 balas, gasta as três num tiro de %s que te empurra pra trás. Você ganha uma bala a cada %s s, até %d." % [_n(g.BULLET_DMG), _n(g.BULLET_TRIPLE), _n(g.BULLET_EVERY), g.BULLET_MAX]]
				2: return ["Ataque", "Só perto da boss. O tiro vai e volta entre ela e você por até %s s: %s de dano em cada ida e %s de cura em cada volta (o que passar da vida cheia vira escudo)." % [_n(g.RICO_TIME), _n(g.RICO_DMG), _n(g.RICO_HEAL)]]
				3: return ["Ataque", "Projétil concentrado em linha reta. %s de dano." % dmg]
				4: return ["Ataque", "Gasta %d balas: %s de dano por bala e um escudo de %s em você." % [g.SALVO_COST, _n(g.SALVO_DMG), _n(g.SALVO_SHIELD)]]
				5: return ["Ultimate", "Canhão enorme: %s de dano, mais %s por bala Rainbow guardada (gasta todas)." % [_n(g.CANNON_DMG), _n(g.CANNON_PER_BULLET)]]
		"burner":
			match slot:
				0: return ["Básico", "Projétil de fogo. %s de dano." % dmg]
				1: return ["Ataque", "Marca a boss com um halo por %s s: %s de dano por segundo." % [_n(g.ZENITH_TIME), _n(g.ZENITH_DPS)]]
				2: return ["Ataque", "Uma lança cai na boss e estoura a Marca do Zênite. Quanto mais perto do fim da marca, mais forte: de %s a %s de dano. Sem marca, só %s." % [_n(g.LANCE_MIN), _n(g.LANCE_MAX), _n(g.LANCE_BARE)]]
				3: return ["Movimento", "Rasante curto que deixa uma explosão. %s de dano." % _n(g.SWOOP_DMG)]
				4: return ["Ataque", "Chuva de chamas na boss: %s de dano por segundo por %s s." % [_n(g.RAIN_DPS), _n(g.RAIN_TIME)]]
				5: return ["Ultimate", "Um sol explode: %s de dano. Com a boss marcada, %s e um DoT de %s por segundo por %s s (não gasta a marca)." % [_n(g.SOLAR_DMG), _n(g.SOLAR_MARKED), _n(g.SOLAR_DOT), _n(g.SOLAR_DOT_TIME)]]
		"ringstar":
			match slot:
				0: return ["Básico", "%s de dano. Começa a sequência e fortalece o Direto de Campeã." % dmg]
				1: return ["Ataque", "Fortalecido pelo Jab: %s de dano e fortalece o Gancho. Fora da sequência: só %s." % [dmg, _n(g.WEAK_HIT)]]
				2: return ["Ataque", "Fortalecido pelo Direto: %s de dano e a sequência recomeça. Fora da sequência: só %s." % [dmg, _n(g.WEAK_HIT)]]
				3: return ["Suporte", "Avança até a boss. Por %s s a recarga dos três golpes cai pra %s s e seu dano sobe %s. Não quebra a sequência." % [_n(g.COUNT_TIME), _n(g.COUNT_GCD), _pct(g.COUNT_DMG - 1.0)]]
				4: return ["Ataque", "Pega o microfone e aponta pra boss por %s s; depois dispara uma rajada de estrelas por %s s, de qualquer distância: %s de dano no total. Você continua agindo enquanto isso e a sequência não quebra." % [_n(g.SUPERSTAR_WIND), _n(g.SUPERSTAR_FIRE), _n(g.SUPERSTAR_DMG)]]
				5: return ["Ultimate", "Salta por %s s e despenca na boss: %s de dano em área em volta de onde cair (raio %s). No ar, passa por cima de ataques rentes ao chão." % [_n(g.KNOCKOUT_AIR), _n(g.KNOCKOUT_DMG), _n(g.KNOCKOUT_R)]]
		"apothecary":
			match slot:
				0: return ["Básico", "%s de dano. Com a boss em Decomposição, cura %s no Paciente. Sem Decomposição, a recarga sobe pra %s s." % [dmg, _n(g.PATIENT_HEAL), _n(g.INCISION_SLOW)]]
				1: return ["Ataque", "%s de dano e aplica Decomposição. Renovar com %s s ou menos sobrando rende 1 Vestígio (até %d)." % [dmg, _n(g.VESTIGE_WINDOW), g.VESTIGE_MAX]]
				2: return ["Cura", "Cura %s num aliado e faz dele o Paciente por %s s." % [_n(g.SUTURE_HEAL), _n(g.PATIENT_TIME)]]
				3: return ["Defesa", "Num aliado: escudo de %s da vida máxima por %s s. Com %d Vestígios, a boss em Decomposição e nenhum aliado escolhido: aplica Contaminação na boss por %s s." % [_pct(g.HEMO_RATIO), _n(g.HEMO_TIME), g.VESTIGE_MAX, _n(g.CONTAM_TIME)]]
				4: return ["Ultimate", "Nuvem Conservante: cura %s em todos e regenera %s por segundo por %s s (gastando %d Vestígios, %s). Com a boss Contaminada vira Nuvem Tóxica: %s de dano e %s por segundo por %s s." % [_n(g.CLOUD_HEAL), _n(g.CLOUD_REGEN), _n(g.CLOUD_TIME), g.VESTIGE_MAX, _pct(g.CLOUD_BOOST), _n(g.TOXIC_DMG), _n(g.TOXIC_DPS), _n(g.TOXIC_TIME)]]
				5: return ["Cura", "Cura instantânea de %s num aliado; %s a mais se ele estiver abaixo de %s da vida." % [_n(g.STABILIZE_HEAL), _pct(0.5), _pct(g.STABILIZE_LOW)]]
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
