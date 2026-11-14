extends Node3D
## Protótipo: 1 arena, party de 4, bosses em sequência.
## Boss 1 (MINI-CHAN): só ataques de desviar — círculo, linha, facas, explosão.
## Boss 2 (PROTÓTIPO-CHAN): círculos + Marca Elemental (zona oposta) + Cataclismo.

const EL_NAME := ["Fogo", "Água", "Terra", "Ar"]
const EL_COL := [
	Color(1.0, 0.5, 0.1), Color(0.2, 0.5, 1.0),
	Color(0.5, 0.8, 0.25), Color(0.88, 0.95, 1.0),
]
const OPP := [1, 0, 3, 2]
const DANGER := Color(1.0, 0.12, 0.32)

const ARENA_R := 8.6
const BOSS_POINT := Vector3(0, 0, -9.0)
const MELEE_RANGE := 4.8
const RANGED_RANGE := 13.0  # quem ataca de longe também tem limite: o fundo da arena fica fora
const ZONE_R := 2.2
const SHELTER_R := 2.7
const CIRCLE_R := 1.9
const STACK_R := 2.5
const PAIR_R := 1.8
## Dano total de cada círculo laranja, dividido por igual entre quem está dentro.
const STACK_TOTAL := 120.0
const PAIR_TOTAL := 60.0
const BUSTER_DMG := 170.0
const MITIGATION := 0.4  # Mitigação: o Tank toma 40% do dano (reduz 60%)
const STACK_COL := Color(1.0, 0.6, 0.1)
## Spread (círculo roxo): quem estiver dentro do círculo de outro herói leva dano.
## É grande o bastante pra só caber um herói em cada canto da arena.
const SPREAD_COL := Color(0.72, 0.35, 1.0)
const SPREAD_R := 9.5
const SPREAD_DMG := 55.0
## Canto de cada herói (Tank NO, Healer SO, Assassina NE, Maga SE): a IA com Dispersão vai pro dela.
const CORNERS := [Vector3(-5.6, 0, -5.6), Vector3(-5.6, 0, 5.6), Vector3(5.6, 0, -5.6), Vector3(5.6, 0, 5.6)]
const BLAST_RATIO := 0.7
const DODGE_PHASES := ["dodgetime", "combo", "grid", "nova", "core", "blast"]
## Dentro do Dodge Time as duplas doem pouco: o dano de verdade é a explosão do fim.
const DODGE_PAIR_TOTAL := 24.0

const ZONE_POS := [
	Vector3(-4.8, 0, -2.5), Vector3(4.8, 0, -2.5),
	Vector3(-4.8, 0, 4.2), Vector3(4.8, 0, 4.2),
]
const SPREAD_POS := [
	Vector3(-5.5, 0, -3.5), Vector3(5.5, 0, -3.5),
	Vector3(-5.5, 0, 4.0), Vector3(5.5, 0, 4.0),
]
const ATK_POS := [
	Vector3(1.3, 0, -6.2), Vector3(3.6, 0, 0.6),
	Vector3(-1.9, 0, -6.0), Vector3(-3.6, 0, 0.2),
]
# corpo a corpo já começa dentro do alcance: o primeiro ataque do jogador tem que funcionar
const START_POS := [
	Vector3(1.3, 0, -5.2), Vector3(3.0, 0, 1.5),
	Vector3(-1.9, 0, -5.0), Vector3(-3.0, 0, 1.5),
]
## A party é livre (quaisquer 4 heróis), então o lugar de atacar depende de quem ocupa o lugar:
## quem luta de perto usa MELEE_POS e quem luta de longe usa RANGED_POS, pelo índice na party.
const MELEE_POS := [Vector3(1.3, 0, -6.2), Vector3(3.1, 0, -6.3), Vector3(-1.9, 0, -6.0), Vector3(-3.2, 0, -6.3)]
const RANGED_POS := [Vector3(1.6, 0, 1.2), Vector3(3.6, 0, 0.6), Vector3(-1.6, 0, 1.4), Vector3(-3.6, 0, 0.2)]

const UNIT_DEFS := [
	{"name": "Paladino", "range": MELEE_RANGE, "key": "tank", "color": Color(0.3, 0.5, 1.0), "hp": 160.0, "melee": true, "ai_dps": 6.0, "hit": 8.0, "tank": true},
	{"name": "Soulflame", "range": RANGED_RANGE, "key": "healer", "color": Color(0.4, 0.95, 0.55), "hp": 90.0, "melee": false, "ai_dps": 3.0, "hit": 6.0},
	{"name": "Assassina", "range": MELEE_RANGE, "key": "assassina", "color": Color(0.78, 0.38, 1.0), "hp": 100.0, "melee": true, "ai_dps": 10.0, "hit": 17.0},
	{"name": "Maga", "range": RANGED_RANGE, "key": "maga", "color": Color(1.0, 0.72, 0.25), "hp": 90.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
	# os quatro da luta vêm de Knowledge.fight_party(): qualquer combinação destes heróis
	{"name": "Malpractice", "range": MELEE_RANGE, "key": "nurse", "color": Color(0.36, 0.4, 0.95), "hp": 80.0, "melee": true, "ai_dps": 6.0, "hit": 8.0, "tank": true},
	{"name": "Soulburner", "range": RANGED_RANGE, "key": "burner", "color": Color(1.0, 0.55, 0.25), "hp": 90.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
	{"name": "Ringstar", "range": MELEE_RANGE, "key": "ringstar", "color": Color(1.0, 0.45, 0.75), "hp": 110.0, "melee": true, "ai_dps": 9.0, "hit": 14.0},
	{"name": "Apotecário", "range": RANGED_RANGE, "key": "apothecary", "color": Color(0.35, 0.8, 0.66), "hp": 90.0, "melee": false, "ai_dps": 5.0, "hit": 8.0},
	{"name": "Sleepwalker", "range": RANGED_RANGE, "key": "sleepwalker", "color": Color(0.55, 0.58, 1.0), "hp": 85.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
]

## Cada passo: t = tipo, dur = quanto dura até o próximo. Ataques de desvio:
## stack need 4 (um círculo laranja: todos os vivos dentro) · stack need 2 (dois círculos: exatamente 2 em cada)
## buster (golpe pesado no alvo 1: a tank precisa da defesa dela)
## circles (n alvos) · line (n faixas largas) · knives (n faixas finas e rápidas)
## core (explosão no centro: saia) · nova (explosão nas bordas: vá pro centro)
## spread (círculo roxo enorme em n heróis: cada um num canto) · dodgetime (cast de 5 s sem bater)
## combo (2 spreads + 1 dupla ao mesmo tempo) · grid (grade de faixas + duas duplas) · blast (70% da vida em todos)
const STEPS_DODGE := [
	{"t": "idle", "dur": 2.5},
	{"t": "circles", "n": 2, "dur": 2.4},
	{"t": "idle", "dur": 1.0},
	{"t": "buster", "dur": 3.0},
	{"t": "idle", "dur": 1.0},
	{"t": "line", "n": 1, "dur": 2.6},
	{"t": "idle", "dur": 1.0},
	{"t": "knives", "n": 3, "dur": 2.4},
	{"t": "idle", "dur": 1.0},
	{"t": "stack", "need": 4, "dur": 5.5},
	{"t": "idle", "dur": 1.0},
	{"t": "spread", "n": 4, "dur": 5.5},
	{"t": "idle", "dur": 1.0},
	{"t": "core", "dur": 3.0},
	{"t": "idle", "dur": 1.0},
	{"t": "circles", "n": 3, "dur": 2.4},
	{"t": "line", "n": 2, "dur": 2.8},
	{"t": "idle", "dur": 1.0},
	{"t": "stack", "need": 2, "dur": 5.5},
	{"t": "idle", "dur": 1.0},
	{"t": "buster", "dur": 3.0},
	{"t": "idle", "dur": 1.0},
	# --- Dodge Time: 5 s de cast sem bater, depois uma sequência rápida de desvios
	{"t": "dodgetime", "dur": 5.0},
	{"t": "combo", "dur": 5.0},
	{"t": "idle", "dur": 0.6},
	{"t": "grid", "dur": 5.0},
	{"t": "idle", "dur": 0.5},
	{"t": "nova", "dur": 2.5, "total": 2.4},
	{"t": "core", "dur": 2.4, "total": 2.2},
	{"t": "blast", "dur": 3.5, "ratio": 0.2},
	{"t": "idle", "dur": 2.0},
	{"t": "spread", "n": 1, "dur": 5.0},
	{"t": "knives", "n": 4, "dur": 2.4},
	{"t": "circles", "n": 2, "dur": 2.0},
	{"t": "idle", "dur": 1.5},
]
## Boss de fusão: tudo dos dois primeiros, mais a Contagem.
## count (Contagem): cada herói ganha um número; os golpes saem na ordem,
## ímpar = corte em círculo em cima do herói, par = investida em linha do boss até ele.
const STEPS_FUSION := [
	{"t": "idle", "dur": 2.5},
	{"t": "circles", "n": 2, "dur": 2.4},
	{"t": "idle", "dur": 1.0},
	{"t": "buster", "dur": 3.0},
	{"t": "idle", "dur": 1.0},
	{"t": "count", "dur": 9.0},
	{"t": "idle", "dur": 1.0},
	{"t": "stack", "need": 4, "dur": 5.5},
	{"t": "idle", "dur": 1.0},
	{"t": "mark", "dur": 2.0},
	{"t": "zones", "dur": 9.0, "volley_at": 3.0},
	{"t": "cata", "dur": 12.0, "volley_at": 4.5},
	{"t": "burn", "dur": 8.0},
	{"t": "spread", "n": 4, "dur": 5.5},
	{"t": "idle", "dur": 1.0},
	{"t": "knives", "n": 3, "dur": 2.4},
	{"t": "buster", "dur": 3.0},
	{"t": "idle", "dur": 1.0},
	{"t": "dodgetime", "dur": 5.0},
	{"t": "combo", "dur": 5.0},
	{"t": "idle", "dur": 0.6},
	{"t": "grid", "dur": 5.0},
	{"t": "idle", "dur": 0.5},
	{"t": "nova", "dur": 2.5, "total": 2.4},
	{"t": "core", "dur": 2.4, "total": 2.2},
	{"t": "blast", "dur": 3.5},
	# depois da explosão vem só desvio, pra dar tempo de curar antes da próxima volta
	{"t": "idle", "dur": 3.0},
	{"t": "count", "dur": 9.0},
	{"t": "idle", "dur": 3.0},
]
const STEPS_ELEMENT := [
	{"t": "idle", "dur": 3.0},
	{"t": "circles", "n": 2, "dur": 2.3},
	{"t": "idle", "dur": 1.5},
	{"t": "circles", "n": 2, "dur": 2.3},
	{"t": "idle", "dur": 1.5},
	{"t": "mark", "dur": 2.0},
	{"t": "zones", "dur": 9.0, "volley_at": 3.0},
	{"t": "cata", "dur": 12.0, "volley_at": 4.5},
	{"t": "burn", "dur": 8.0},
]
## Habilidades com recarga: J é o ataque básico (1 s), K e L as especiais. A IA só usa a Cura, e pior que o jogador:
## burst, mitigação e reviver são motivo pra você assumir o personagem.
const PROVOKE := {"name": "Bora Biscoitar", "cd": 20.0}
## Uma lista por herói, na ordem dos slots da barra (até Binds.SKILL_SLOTS). null = slot sem habilidade.
## As teclas de cada slot são do jogador (scripts/binds.gd); o padrão é J, K, L, U, O, P.
## Provocar (Provocação do Paladino, Emergency Response da Malpractice) é o "Bora Biscoitar":
## quem usa puxa o boss pra si.
const SKILLS := {
	# Paladino: o mais simples do jogo. Sem recurso nem combo: bate, provoca e aperta a defesa.
	"tank": [{"name": "Golpe de Juramento", "cd": 1.5, "dmg": 30.0},
		{"name": "Baque do Escudo", "cd": 8.0, "dmg": 55.0},
		{"name": "Provocação", "cd": 15.0},
		{"name": "Solo Consagrado", "cd": 18.0},
		{"name": "Égide", "cd": 25.0},
		{"name": "Muralha da Fé", "cd": 60.0}],
	# Malpractice (tank de sangue, "de papel"): cada golpe custa vida dela (SELF_COST). O slot 1 estoca
	# e rouba um fio de vida, o 2 é o parry, o 3 rouba vida fixa e junta acúmulos, o 4 avança e provoca,
	# o 5 é o ultimate (não tem recarga: gasta PARTY_NEED acúmulos). Quanto menos vida, mais dano.
	"nurse": [{"name": "Syringe Poke", "cd": 1.0, "dmg": 8.0},
		{"name": "Blood Taste", "cd": 20.0}, {"name": "Blood Consumed", "cd": 5.0, "dmg": 40.0},
		{"name": "Emergency Response", "cd": 8.0}, {"name": "Blood Party", "cd": 0.0, "stacks": 20}],
	# Soulflame: healer direta, sem recurso. "ai_cd" é a recarga quando quem usa é a IA.
	"healer": [{"name": "Fagulha Espiritual", "cd": 1.0, "dmg": 12.0},
		{"name": "Toque de Brasa", "cd": 1.0, "cast": 1.5, "ai_cd": 3.5},
		{"name": "Lareira Celestial", "cd": 18.0},
		{"name": "Manto de Cinzas", "cd": 20.0},
		{"name": "Asa da Fênix", "cd": 30.0},
		{"name": "Renascimento", "cd": 60.0}],
	# Assassina: velocidade pura. O Talho (slot 1) bate MUITO mais forte do lado certo da boss:
	# três de um lado, três do outro (unit.side_need / side_left), pra sempre.
	"assassina": [{"name": "Talho Relâmpago", "cd": 0.6, "dmg": 10.0},
		{"name": "Passo Rasante", "cd": 5.0, "dmg": 35.0},
		{"name": "Garras Cruzadas", "cd": 6.0, "dmg": 18.0},
		{"name": "Dança Carmesim", "cd": 12.0, "dmg": 65.0},
		{"name": "Golpe de Misericórdia", "cd": 15.0, "dmg": 120.0},
		{"name": "Frenesi da Fera", "cd": 60.0}],
	# Maga: atiradora. Nada de cast: ela dispara, junta balas Rainbow (passiva) e decide onde gastar.
	# "pow" = dano de habilidade que não exige o alcance normal de ataque.
	"maga": [{"name": "Disparo Rúnico", "cd": 1.0, "dmg": 26.0},
		{"name": "Rainbow Shots", "cd": 0.3},
		{"name": "Ricochete Prismático", "cd": 8.0},
		{"name": "Tiro Perfurante", "cd": 12.0, "dmg": 95.0},
		{"name": "Salva Astral", "cd": 20.0},
		{"name": "Canhão Estelar", "cd": 60.0}],
	# Soulburner: marcar (Marca do Zênite) e estourar a marca (Lança Serafim) o mais tarde possível.
	"burner": [{"name": "Brasas do Firmamento", "cd": 1.0, "dmg": 24.0},
		{"name": "Marca do Zênite", "cd": 12.0},
		{"name": "Lança Serafim", "cd": 8.0},
		{"name": "Rasante Incandescente", "cd": 10.0},
		{"name": "Chuva de Brasas", "cd": 20.0},
		{"name": "Juízo Solar", "cd": 60.0}],
	# Ringstar: Jab -> Direto -> Gancho, cada um fortalece o seguinte (unit.chain). Os três dividem
	# a recarga (GCD); os slots 4 e 5 são oGCD e não quebram a sequência.
	"ringstar": [{"name": "Jab Estelar", "cd": 2.0, "dmg": 22.0},
		{"name": "Direto de Campeã", "cd": 2.0, "dmg": 40.0},
		{"name": "Gancho Meteoro", "cd": 2.0, "dmg": 70.0},
		{"name": "Contagem Regressiva", "cd": 14.0},
		{"name": "SUPERSTAR!", "cd": 20.0},
		{"name": "Nocaute Final", "cd": 60.0}],
	# Apotecário: healer com rotação ofensiva. Recurso: Vestígios (unit.vestiges, até 3), ganhos
	# renovando a Decomposição (DoT da Necropsia) com 1 s ou menos sobrando.
	"apothecary": [{"name": "Incisão", "cd": 1.0, "dmg": 16.0},
		{"name": "Necropsia", "cd": 7.0, "dmg": 60.0},
		{"name": "Sutura", "cd": 1.0, "cast": 1.5, "ai_cd": 3.5},
		{"name": "Solução Hemostática", "cd": 20.0},
		{"name": "Tanatopraxia", "cd": 45.0},
		{"name": "Estabilização", "cd": 60.0}],
	# Sleepwalker, Modo Acordado (o Modo Dormindo é SKILLS_ASLEEP; quem escolhe a lista é kit()).
	"sleepwalker": [{"name": "Bocejo", "cd": 2.0},
		{"name": "Puxar o Lençol", "cd": 15.0},
		{"name": "Visitantes debaixo da Cama", "cd": 15.0},
		{"name": "Senhor Travesseiro", "cd": 15.0},
		{"name": "A Cama Caiu!", "cd": 15.0},
		{"name": "Sono Profundo", "cd": 3.0}],
}
## Sleepwalker, Modo Dormindo: sequência obrigatória; "cost" é o Torpor gasto.
const SKILLS_ASLEEP := [
	{"name": "A Mordida dos Mil", "cd": 18.0, "cost": 5.0, "base": 100.0},
	{"name": "Senhor Travesseiro: Devorador", "cd": 0.6, "cost": 10.0, "base": 150.0},
	{"name": "O Abraço Impossível", "cd": 0.6, "cost": 15.0, "base": 200.0},
	{"name": "A Porta Errada", "cd": 0.6, "cost": 20.0, "base": 250.0},
	{"name": "A Casa que Engole", "cd": 0.6, "cost": 50.0, "base": 600.0},
	{"name": "Acordar", "cd": 3.0},
]
## Cast curto trava o personagem no lugar; cast longo pode ser interrompido andando.
const LOCKED_CAST := 1.0
## DPS da IA com a carta roxa Rotação (sem ela vale o ai_dps de UNIT_DEFS).
## Assassina e Maga, além disso, soltam o golpe forte de 20 s (Lâmina Final / Ruína) sempre que dá.
const ROTATION_DPS := {"tank": 10.0, "nurse": 4.0, "healer": 6.0, "assassina": 14.0, "maga": 10.0, "burner": 11.0, "ringstar": 12.0, "apothecary": 8.0, "sleepwalker": 12.0}
## Cura em Área: metade da Cura, em todo mundo perto do Healer.
const AOE_HEAL_R := 6.0
## Quanto tempo Maga e Healer ficam presos no cast quando um vermelho aparece e não têm Cautela.
const CAST_STUCK := 0.9
const HEAL_PLAYER := 55.0
## Escudo da Healer: metade da vida máxima do alvo, por SHIELD_TIME segundos.
const SHIELD_RATIO := 0.5
const SHIELD_TIME := 12.0
const HEAL_AI := 45.0
const SFX_FART := preload("res://assets/sfx/fart.wav")
const SFX_DEATH := preload("res://assets/sfx/death.wav")
const COOKIE_COL := Color(0.86, 0.6, 0.3)
const AUTO_EVERY := 2.0
const AUTO_DMG := 6.0
const GUARD_TIME := 4.0
## Kit do Paladino.
const AEGIS_TIME := 6.0        # Égide: mitigação de 60% (MITIGATION) ...
const AEGIS_REGEN := 5.0       # ... e essa vida por segundo enquanto dura
const WALL_TIME := 8.0         # Muralha da Fé: a party toda ...
const WALL_MULT := 0.8         # ... toma 20% menos dano
const WALL_SHOW := 3.0         # ... e a cruz dourada fica esse tempo no ar
const HOLY_TIME := 6.0         # Solo Consagrado: quanto a área dura
const HOLY_R := 4.6
const HOLY_TICK := 1.0
const HOLY_DMG := 9.0          # ... por batida, se a boss estiver ao alcance da área
const GOLD := Color(1.0, 0.82, 0.3)
## Kit da Assassina.
const SIDE_HITS := 3           # Talho Relâmpago: golpes fortalecidos de cada lado da boss
const SIDE_MULT := 2.5         # ... +150% de dano no Talho dado do lado certo
const SIDE_MIN := 0.6          # ... quão pra fora do meio (em x) já conta como um lado
const CLAW_HITS := 3           # Garras Cruzadas: três cortes ...
const CLAW_GAP := 0.1          # ... com esse intervalo
const MERCY_WINDOW := 0.35     # Golpe de Misericórdia: janela de parry antes do corte sair
const FRENZY_TIME := 8.0       # Frenesi da Fera
const FRENZY_DMG := 1.15       # ... +15% de dano
const FRENZY_HASTE := 0.5      # ... e o Talho recarrega na metade do tempo
const SIDE_COL := Color(0.3, 1.0, 0.55)
## Kit da Maga. Balas Rainbow: uma a cada BULLET_EVERY segundos, até BULLET_MAX. A cor diz o efeito
## que a bala dá quando sai sozinha pelo Rainbow Shots.
const BULLETS := [
	{"name": "DANO", "col": Color(1.0, 0.25, 0.3)},      # vermelha: +20% de dano por 6 s
	{"name": "GUARDA", "col": Color(0.3, 0.6, 1.0)},     # azul: toma 25% menos dano por 6 s
	{"name": "VIDA", "col": Color(0.35, 0.95, 0.5)},     # verde: recupera 20 de vida
	{"name": "VENENO", "col": Color(0.72, 0.35, 1.0)},   # roxa: DoT de 5/s por 8 s na boss
	{"name": "IMPULSO", "col": Color(1.0, 0.85, 0.25)},  # amarela: o próximo Disparo dá um dash pra trás
]
const BULLET_EVERY := 8.0
const BULLET_MAX := 7
const BULLET_DMG := 40.0       # Rainbow Shots: uma bala
const BULLET_TRIPLE := 170.0   # ... com EXATAMENTE 3 guardadas: um tiro só, forte, e ela é empurrada pra trás
const BULLET_KNOCK := 5.0
const BULLET_BUFF := 6.0
const PIERCE_MULT := 1.5       # Disparo Rúnico fortalecido depois de uma bala
const RICO_TIME := 4.0         # Ricochete Prismático: no máximo 4 s ...
const RICO_STEP := 0.5         # ... uma ida a cada meio segundo (boss, ela, boss, ela...)
const RICO_DMG := 12.0
const RICO_HEAL := 6.0         # ... o que passar da vida cheia vira escudo
const SALVO_COST := 3          # Salva Astral: gasta 3 balas
const SALVO_DMG := 45.0        # ... por bala
const SALVO_SHIELD := 40.0
const CANNON_DMG := 220.0      # Canhão Estelar sozinho ...
const CANNON_PER_BULLET := 75.0  # ... e por bala guardada: bem mais que os 40 de soltá-las uma a uma
## Kit do Soulburner.
const ZENITH_TIME := 10.0      # Marca do Zênite: DoT leve ...
const ZENITH_DPS := 5.0
const LANCE_BARE := 15.0       # Lança Serafim sem marca: quase nada
const LANCE_MIN := 90.0        # ... com a marca recém-posta: dano médio
const LANCE_MAX := 190.0       # ... com a marca quase acabando: dano alto
const SWOOP_DIST := 5.0        # Rasante Incandescente
const SWOOP_DMG := 45.0
const RAIN_TIME := 15.0        # Chuva de Brasas
const RAIN_DPS := 6.0
const SOLAR_DMG := 200.0       # Juízo Solar ...
const SOLAR_MARKED := 300.0    # ... com a boss marcada (não gasta a marca)
const SOLAR_DOT := 12.0        # ... e aí deixa um DoT médio
const SOLAR_DOT_TIME := 15.0
const FIRE := Color(1.0, 0.55, 0.2)
## Kit da Ringstar.
const WEAK_HIT := 8.0          # Direto ou Gancho sem estar fortalecido: dano mínimo
const COUNT_TIME := 15.0       # Contagem Regressiva: duração ...
const COUNT_GCD := 1.0         # ... o GCD dos três golpes cai de 2 s pra 1 s ...
const COUNT_DMG := 1.1         # ... e +10% de dano
const SUPERSTAR_DMG := 110.0
const KNOCKOUT_DMG := 380.0
const STAR := Color(1.0, 0.45, 0.75)
## Kit do Apotecário.
const DECOMP_TIME := 8.0       # Decomposição (DoT da Necropsia)
const DECOMP_DPS := 6.0
const VESTIGE_WINDOW := 1.0    # renovar com isso ou menos sobrando dá 1 Vestígio
const VESTIGE_MAX := 3
const INCISION_SLOW := 3.0     # recarga da Incisão sem Decomposição na boss
const PATIENT_TIME := 15.0     # Paciente (quem recebeu Sutura)
const PATIENT_HEAL := 4.0      # ... cura por Incisão acertada com a boss em Decomposição
const SUTURE_HEAL := 60.0
const HEMO_RATIO := 0.18       # Solução Hemostática num aliado: escudo de 18% da vida máxima ...
const HEMO_TIME := 8.0         # ... por 8 s
const CONTAM_TIME := 20.0      # ... na boss (3 Vestígios + Decomposição): Contaminação
const CLOUD_HEAL := 60.0       # Tanatopraxia clínica: cura em todos ...
const CLOUD_REGEN := 5.0       # ... e regeneração por segundo ...
const CLOUD_TIME := 8.0        # ... durante 8 s
const CLOUD_BOOST := 1.8       # ... gastando 3 Vestígios: cura e regeneração 80% maiores
const TOXIC_DMG := 120.0       # Tanatopraxia tóxica (boss com Contaminação): dano inicial ...
const TOXIC_DPS := 20.0        # ... e por segundo ...
const TOXIC_TIME := 8.0
const STABILIZE_HEAL := 100.0  # Estabilização
const STABILIZE_LOW := 0.25    # ... alvo abaixo de 25%: cura 50% maior
const CHEM := Color(0.35, 0.8, 0.66)
## Em que slot cada healer guarda cada tipo de socorro (a IA e as cartas de healer usam isso). -1 = não tem.
const HEAL_SLOTS := {
	"healer": {"shield": 3, "revive": 5, "area": 2, "big": 4, "heal": 1},
	"apothecary": {"shield": 3, "revive": -1, "area": 4, "big": 5, "heal": 2},
}
## Kit do Sleepwalker. Os danos da ficha (50, 60, 120...) são relativos; SW_SCALE traz pra escala do jogo.
const SW_SCALE := 0.45
const SW_AWAKE := [  # dano-base, Torpor gerado, stacks de Vulnerabilidade com a interação certa / sem ela
	{"base": 50.0, "torpor": 4.0, "stacks": 0, "weak": 0},
	{"base": 60.0, "torpor": 8.0, "stacks": 2, "weak": 2},
	{"base": 120.0, "torpor": 12.0, "stacks": 3, "weak": 1},
	{"base": 140.0, "torpor": 16.0, "stacks": 2, "weak": 1},
	{"base": 200.0, "torpor": 24.0, "stacks": 1, "weak": 0},
]
const SW_WINDOW := 1.0         # janela entre uma habilidade da sequência e a seguinte
const SW_PERFECT_TORPOR := 5.0 # Torpor extra por interação acertada
const SW_BED_BONUS := 1.5      # A Cama Caiu! com Travesseiro Cheio
const SW_DECAY := 1.0          # Torpor perdido por segundo, acordado
const DREAM_MAX := 8           # Vulnerabilidade Onírica: até 8 stacks ...
const DREAM_PER := 0.02        # ... +2% de dano dela cada ...
const DREAM_TIME := 30.0       # ... por 30 s
const NIGHTMARE_TIME := 20.0   # Pesadelo Persistente (DoT da Mordida)
const NIGHTMARE_DPS := 6.0
const NEAR_PERFECT := 20.0     # Perto do Sonho: renovação nos últimos NEAR_WINDOW segundos do DoT ...
const NEAR_OTHER := 10.0       # ... cedo, tarde ou primeira aplicação
const NEAR_WINDOW := 2.0
const ECHO_AT := [1.0, 4.0, 7.0, 10.0]  # Ecos do Pesadelo: quando cada Fresta abre, depois da Cama
const ECHO_OPEN := 0.5         # ... e por quanto tempo fica aberta
const ECHO_BASE := 80.0        # dano extra do Bocejo que acerta a Fresta
const HOUSE_SHIELD := 0.08     # A Casa que Engole: escudo de 8% da vida máxima nos aliados ...
const HOUSE_SHIELD_TIME := 5.0
const DREAM := Color(0.55, 0.58, 1.0)
## Kit da Soulflame.
const FLAME := Color(0.3, 0.95, 0.8)
const HEARTH_TIME := 8.0       # Lareira Celestial: quanto dura ...
const HEARTH_R := 4.5
const HEARTH_HPS := 7.0        # ... e quanto cura por segundo quem está dentro
const PHOENIX_HEAL := 110.0    # Asa da Fênix
const REBIRTH_HEAL := 70.0     # Renascimento: cura em todos ...
const REBIRTH_DMG := 90.0      # ... dano médio na boss ...
const REBIRTH_DOT := 6.0       # ... e um DoT leve por segundo ...
const REBIRTH_DOT_TIME := 12.0 # ... durante esse tempo
## Em que slot fica o golpe forte que a IA com a carta Rotação solta, e que a carta Golpe Lapidado melhora.
const BIG_SLOT := {"assassina": 4, "maga": 3}
## Em que slot cada tank guarda a defesa e a provocação (as cartas Guarda e Biscoiteiro usam isso).
const DEF_SLOT := {"tank": 4, "nurse": 1}
const PROVOKE_SLOT := {"tank": 2, "nurse": 3}
## Kit da Malpractice. Ela é "de papel": pouca vida e cada golpe custa sangue (SELF_COST).
## Quem erra o parry ou segura mal as recargas morre do próprio dano; quem joga bem vive no fio
## e bate mais forte por isso (LOW_HP_BONUS).
const SELF_COST := {"Syringe Poke": 4.0, "Blood Consumed": 8.0, "Emergency Response": 6.0}
const LOW_HP_BONUS := 0.6      # +60% de dano com a vida em LOW_HP_FLOOR ou menos; some com a vida cheia
const LOW_HP_FLOOR := 0.25
const BLOOD := Color(0.86, 0.08, 0.2)
const POKE_STEAL := 0.0001     # Syringe Poke: rouba 0,01% da vida ATUAL da boss por estocada
const TASTE_TIME := 0.5        # Blood Taste: janela do parry
const TASTE_HP := 2.3          # ... vida (e vida máxima) vão a 230% da máxima normal: com 80 de vida, é o que aguenta o Esmagar
const TASTE_KEEP := 0.3        # ... parry perfeito guarda 30% da vida ganha
const TASTE_CD_PARRY := 10.0   # ... e a recarga cai de 20 s pra 10 s
const TASTE_STACKS := 5
const CONSUMED_STEAL := 18.0   # Blood Consumed: vida fixa roubada por acerto (custa 8: saldo de +10)
const CONSUMED_STACKS := 2
const RUSH_DIST := 20.0        # Emergency Response: alcance do avanço
const RUSH_DMG := 12.0
const PARTY_NEED := 20         # Blood Party: acúmulos gastos
const PARTY_TIME := 5.0
const PARTY_TICK := 0.5        # ... a aura bate a cada meio segundo
const PARTY_DMG := 25.0
const PARTY_R := 6.5           # ... em boss a até essa distância
## Enmity (ameaça): dano causado e cura feita geram enmity; o boss bate em quem tem mais.
## A postura do Tank multiplica a dele, então em condições normais ele segura o boss.
const TANK_STANCE := 5.0
const HEAL_ENMITY := 0.5
const PROVOKE_BONUS := 400.0
const SWAP_CD := 2.5

## DPS check: a luta tem tempo. Contas do MINI-CHAN (120 s, 7400 de vida), com você na Assassina
## e os outros três na IA (~12 de DPS somados):
##   jogando muito bem (~58 seu)  -> ~8400 de dano: mata sem Limit Break
##   jogando bem (~46 seu)        -> ~6960: só mata com o Limit Break de DPS (10% = 740)
##   mais ou menos (~36 seu)      -> ~5760: não mata nem com ele
## O PROTÓTIPO-CHAN segue a mesma lógica, mas os números dele ainda são estimativa.
const LB_NEED := 0.5       # a barra enche quando a party causa 50% da vida do boss
const LB_CAST := 2.5
const LB_DPS_CUT := 0.10   # Limit Break de DPS: tira 10% da vida máxima do boss
const LB_IMMORTAL := 2.0   # Limit Break do Tank: party imortal por 2 s
const WEAK_TIME := 30.0    # revivido pelo Reviver comum: metade do dano por 30 s

## Grande final da MINI-CHAN: entra uma vez, perto do fim da luta, e depois a luta volta ao normal.
## raid (cast + dano em todos, ratio = fração da vida máxima) · linkcleave (Elo Perdido em dois heróis
## + dois golpes de meia arena, um de cada lado, avisados pela mão que ela levanta) ·
## collapse (cast + raidwide; a arena vira dois quadrados e o resto é vazio) · towers (uma torre por herói) ·
## buster + window (o Tank segura o Esmagar e abre uma janela de dano dobrado) · raid final com a arena de volta.
const STEPS_FINALE := [
	{"t": "raid", "dur": 5.0, "ratio": 0.5, "name": "Gran Finale"},
	{"t": "linkcleave", "dur": 5.6},
	{"t": "collapse", "dur": 4.0, "ratio": 0.2},
	{"t": "towers", "dur": 5.0},
	{"t": "buster", "dur": 3.0},
	{"t": "window", "dur": 5.0},
	{"t": "raid", "dur": 4.0, "ratio": 0.3, "name": "Cortina Final", "restore": true},
	{"t": "idle", "dur": 1.0},
]
## O final começa quando passa essa fração do tempo, ou com a boss abaixo dessa vida.
const FINALE_AT := 0.635
const FINALE_HP := 0.3
## Os dois quadrados que sobram quando a arena desaba, e a torre de cada herói
## (Tank e Assassina nas da frente, ao alcance da boss; Healer e Maga nas de trás).
const SQUARES := [Vector3(-3.6, 0, -4.4), Vector3(3.6, 0, -4.4)]
const SQ_HALF := 2.4
const TOWER_POS := [Vector3(-2.4, 0, -5.6), Vector3(-4.8, 0, -3.2), Vector3(2.4, 0, -5.6), Vector3(4.8, 0, -3.2)]
const TOWER_R := 1.1
const TOWER_COL := Color(0.55, 0.9, 1.0)
const CLEAVE_DMG := 40.0
## A mão sobe e brilha esse tempo antes do golpe; a marca no chão só aparece no último meio segundo.
const CLEAVE_TELL := 1.9
const LINK_COL := Color(1.0, 0.4, 0.75)
const LINK_BREAK := 9.0
const LINK_TICK := 0.5
const LINK_DMG := 3.0
const LINK_MAX := 8.0
const ENRAGE_CAST := 10.0

## Mini boss: poucos ataques, todos simples. Serve pra juntar moedas antes do boss de verdade.
const STEPS_COOKIE := [
	{"t": "idle", "dur": 3.0},
	{"t": "circles", "n": 2, "dur": 2.6},
	{"t": "idle", "dur": 2.0},
	{"t": "line", "n": 1, "dur": 2.8},
	{"t": "idle", "dur": 2.0},
	{"t": "stack", "need": 4, "dur": 6.0},
	{"t": "idle", "dur": 2.0},
	{"t": "knives", "n": 2, "dur": 2.6},
	{"t": "idle", "dur": 2.5},
]
## Mesma ordem de Knowledge.BOSS_INFO.
const BOSSES := [
	{"name": "BISCOITO-KUN", "hp": 2600.0, "enrage": 100.0, "steps": STEPS_COOKIE, "look": "cookie", "hair": Color(0.86, 0.6, 0.3), "scale": 0.8},
	{"name": "MINI-CHAN", "hp": 7000.0, "enrage": 120.0, "steps": STEPS_DODGE, "finale": true, "hair": Color(0.25, 0.8, 0.9), "scale": 0.95},
	{"name": "PROTÓTIPO-CHAN", "hp": 10400.0, "enrage": 150.0, "steps": STEPS_ELEMENT, "elements": true, "hair": Color(1.0, 0.38, 0.66), "scale": 1.2},
	# haste: tudo dela (passos, avisos, casts) corre esse tanto mais rápido
	{"name": "FUSÃO-CHAN", "hp": 11500.0, "enrage": 165.0, "steps": STEPS_FUSION, "elements": true, "haste": 1.2, "hair": Color(0.75, 0.45, 1.0), "scale": 1.3},
]

var units: Array[Unit] = []
var ctrl := 0
var swap_cd := 0.0
var lb := 0.0  # carga do Limit Break, 0..1, da party toda
var enrage := 120.0
var win_test := 0.0   # só pra teste: --win=N vence a luta aos N segundos (pra ver ranking e recompensa)
var card_test := 0.0  # só pra teste: --cardtest=N mostra o aviso de carta nova aos N segundos
var swap_test := 0.0  # só pra teste: --swaptest=N troca de herói aos N segundos
var pause_test := 0.0  # só pra teste: --pausetest=N abre o menu de pause aos N segundos
var lb_test := 0.0  # só pra teste: --lbtest=N dispara o Limit Break aos N segundos
var sel := -1  # alvo escolhido no card (cura, reviver); -1 = automático
var order := "atk"  # atk | gather | spread | hold

var boss: Node3D
var boss_def: Dictionary
var steps: Array
var boss_max := 1.0
var boss_hp := 1.0
var shield := false
var vulnerable := false

var step := -1
var phase := "idle"
var phase_t := 0.0
var phase_dur := 1.0
var volley_done := false
var cast_name := ""

var hazards: Array = []
var holy: Array = []  # áreas de Solo Consagrado ativas
var hearths: Array = []  # Lareiras Celestiais acesas
var boss_dots: Array = []  # efeitos de dano por segundo na boss (ver add_dot)
var dream_stacks := 0  # Vulnerabilidade Onírica (Sleepwalker)
var dream_t := 0.0
var echoes: Array = []  # Frestas dos Ecos do Pesadelo: {"wait", "open", "hit", "warned"}
var echo_mark: MeshInstance3D
var _tones := {}
var side_mark: Node3D  # Assassina: marca do lado da boss que está valendo
var side_pips: Array = []
var side_label: Label3D
var stacks: Array = []  # círculos laranjas ativos
var enrage_k := 0.0
var haste := 1.0
var cur_step: Dictionary = {}
## Contagem: ordem dos golpes, qual é o próximo e quanto falta pra ele.
var count_order: Array = []
var count_labels: Array = []
var count_i := 0
var count_t := 0.0
var spreads: Array = []  # círculos roxos ativos
var spread_t := 0.0
var spread_total := 1.0
var stack_need := 4
var stack_dmg := 0.0
var stack_t := 0.0
var stack_total := 1.0
var buster = null  # Dictionary enquanto o Esmagar está carregando
var zones: Array = []
var zones_active := false
var pair_timer := [0.0, 0.0]
var shelter_pos = null
var shelter_node: Node3D

var prep := true
var intro_left := 0.0
var ended := false
var won := false
## Fúria: o tempo do DPS check acabou e os biscoitos estão caindo.
var fury := false
var log_lines: Array[String] = []
var rot_unit := -1
var rot_buckets: Array[float] = []
var hit_count := {}
## Pro ranking: dano que a party tomou e quantas mortes aconteceram na luta.
var dmg_taken := 0.0
var deaths := 0
var void_on := false
var void_warn := false
## 0 = ainda não veio · 1 = rolando · 2 = já passou
var finale_state := 0
var fin_i := -1
var link = null       # {"a","b","node","t","tick"}
var cleaves: Array = []  # {"side": -1|1, "t": segundos até o golpe, "shown": bool}
var cleave_side := 0  # lado que vai ser atingido agora (0 = nenhum)
var cleave_fail := false
var towers: Array = []   # {"pos","node","fill","unit"}
var tower_t := 0.0
var tower_total := 1.0  # só pro relatório de teste: quantas vezes cada motivo acertou alguém
var auto_t := 0.0
var target: Unit
var heal_focus: Unit
var fight_time := 0.0
var bucket_t := 0.0
var hud
var fx_root: Node3D
var floor_mat: ShaderMaterial

var autoplay := false
var auto_left := 0.0
var shot_left := -1.0


func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	# qualquer argumento de teste desliga o save: não lê nem suja o progresso do jogador
	if args.size() > 0:
		Knowledge.persist = false
	Knowledge.load_save()
	Settings.boot()  # volume e atalhos do jogador
	for a in args:
		if a.begins_with("--boss="):
			Knowledge.boss = clampi(int(a.trim_prefix("--boss=")), 0, BOSSES.size() - 1)
	boss_def = BOSSES[Knowledge.boss]
	steps = boss_def["steps"]
	boss_max = boss_def["hp"]
	enrage = boss_def["enrage"]
	haste = boss_def.get("haste", 1.0)
	for a in args:
		if a.begins_with("--hero="):
			Knowledge.start_hero = clampi(int(a.trim_prefix("--hero=")), 0, Knowledge.HEROES.size() - 1)
			Knowledge.ensure_in_party(Knowledge.start_hero)
		if a.begins_with("--enrage="):
			enrage = float(a.trim_prefix("--enrage="))
	boss_hp = boss_max

	_build_world()
	_build_units()
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(self)
	_next_step()

	if args.has("--autotest"):
		# Roda a luta sozinha com tudo ensinado, pra validar a lógica.
		autoplay = true
		auto_left = minf(150.0, enrage - 2.0)
		Engine.time_scale = 6.0
		_test_decks()
	if args.has("--naive"):
		autoplay = true
		auto_left = 90.0
		Engine.time_scale = 6.0
	if args.has("--known"):
		# tudo liberado, pra conferir os menus
		for id in Knowledge.CARDS:
			Knowledge.owned[id] = true
		for def in UNIT_DEFS:
			Knowledge.dps_known[def["key"]] = true
		Knowledge.money = 500
		Knowledge.tickets = 1
		Knowledge.shop_unlocked = true
		Knowledge.mastery["link"] = 2
	if args.has("--rich"):
		Knowledge.money = 600
		Knowledge.tickets = 2
		Knowledge.shop_unlocked = true
	prep = not autoplay
	if Knowledge.autostart:
		Knowledge.autostart = false
		start_fight.call_deferred()
	hud.set_prep(prep)
	for a in args:
		if a.begins_with("--win="):
			win_test = float(a.trim_prefix("--win="))
		if a.begins_with("--cardtest="):
			card_test = float(a.trim_prefix("--cardtest="))
		if a.begins_with("--swaptest="):
			swap_test = float(a.trim_prefix("--swaptest="))
		if a.begins_with("--pausetest="):
			pause_test = float(a.trim_prefix("--pausetest="))
		if a.begins_with("--lbtest="):
			lb_test = float(a.trim_prefix("--lbtest="))
		if a.begins_with("--sel="):
			select_target(int(a.trim_prefix("--sel=")))
	if args.has("--start"):
		start_fight()
	for a in args:
		if a.begins_with("--shot="):
			shot_left = float(a.trim_prefix("--shot="))


# ---------------------------------------------------------------- mundo

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.012, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.7)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.05, 0.2)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 9, -17)
	rim.light_color = Color(1.0, 0.3, 0.7)
	rim.light_energy = 2.2
	rim.omni_range = 26.0
	add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 12, 23), Vector3(0, 5.0, -3))

	floor_mat = ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/floor.gdshader")
	floor_mat.set_shader_parameter("arena_r", ARENA_R + 0.35)
	floor_mat.set_shader_parameter("melee_center", Vector2(BOSS_POINT.x, BOSS_POINT.z))
	floor_mat.set_shader_parameter("melee_r", MELEE_RANGE)
	Fx.inst(self, Fx.disc(ARENA_R + 0.7, 0.5), floor_mat, Vector3(0, -0.25, 0))

	# colunas de luz no fundo, só pra dar profundidade
	for i in 9:
		var a := lerpf(-1.25, 1.25, i / 8.0)
		var p := Vector3(sin(a) * 26.0, 7.0, -cos(a) * 26.0 - 2.0)
		var col := Color(0.55, 0.25, 1.0) if i % 2 == 0 else Color(0.25, 0.5, 1.0)
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 22.0 + (i % 3) * 5.0, 0.35)
		Fx.inst(self, b, Fx.mat(col, 1.6, true), p)

	boss = preload("res://scripts/boss.gd").new()
	boss.hair_color = boss_def["hair"]
	boss.look = boss_def.get("look", "girl")
	boss.position = Vector3(0, 0, -13.3)
	boss.scale = Vector3.ONE * float(boss_def["scale"])
	add_child(boss)

	fx_root = Node3D.new()
	add_child(fx_root)

	# Sleepwalker: a Fresta dos Ecos do Pesadelo, uma rachadura clara no corpo da boss
	var crack := BoxMesh.new()
	crack.size = Vector3(0.5, 3.4, 0.2)
	echo_mark = Fx.inst(self, crack, Fx.mat(Color(1, 1, 1), 5.0, true), Vector3(0, 4.2, -12.0))
	echo_mark.rotation.z = 0.5
	echo_mark.visible = false
	# Assassina: marca do lado da boss em que o Talho Relâmpago está valendo
	side_mark = Node3D.new()
	add_child(side_mark)
	Fx.inst(side_mark, Fx.torus(1.05, 1.25), Fx.mat(SIDE_COL, 3.5, true), Vector3(0, 0.06, 0))
	Fx.inst(side_mark, Fx.disc(1.05), Fx.mat(Color(SIDE_COL.r, SIDE_COL.g, SIDE_COL.b, 0.2), 0.0, true), Vector3(0, 0.05, 0))
	for n in SIDE_HITS:
		side_pips.append(Fx.inst(side_mark, Fx.sphere(0.2), Fx.mat(SIDE_COL, 4.0, true), Vector3(cos(n * TAU / SIDE_HITS) * 0.6, 1.7, sin(n * TAU / SIDE_HITS) * 0.6)))
	side_label = Fx.label(side_mark, "", Vector3(0, 2.5, 0), 40)
	side_label.modulate = SIDE_COL
	side_mark.visible = false


func _build_units() -> void:
	for i in 4:
		var u := Unit.new()
		add_child(u)
		u.setup(i, UNIT_DEFS[Knowledge.hero_at(i)])
		u.hero = Knowledge.hero_at(i)
		u.position = _atk_pos(u) + Vector3(0, 0, 0.6 if u.melee else 0.9)
		u.face(BOSS_POINT - u.position)
		units.append(u)
	ctrl = maxi(0, Knowledge.slot_of(Knowledge.start_hero))
	units[ctrl].set_controlled(true)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# toda tecla da luta passa pelo Binds (scripts/binds.gd): aqui só existem ações, nunca teclas fixas
	if ended:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			retry()
		return
	if prep:
		return  # os menus cuidam das próprias teclas
	var id := _pressed_action(event)
	if id == "":
		return
	if id == "pause":
		pause()
		get_viewport().set_input_as_handled()
		return
	if fury:
		return
	match id:
		"swap": _cycle_ctrl()
		"dash": _try_dash()
		"limit": use_lb()
		"order_gather": give_order("gather")
		"order_spread": give_order("spread")
		"order_hold": give_order("hold")
		"order_atk": give_order("atk")
		_:
			var n := int(id.get_slice("_", 1)) - 1
			if id.begins_with("hero_"):
				pick_hero(n)
			elif id.begins_with("target_"):
				select_target(n)
			elif id.begins_with("skill_") and n > 0:
				# o slot 1 é o ataque básico: vale enquanto segura, e quem lê é o _process
				use_skill(units[ctrl], n)


## Ação do Binds que este evento acabou de apertar ("" se nenhuma).
func _pressed_action(event: InputEvent) -> String:
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed or event.is_echo():
		return ""
	for a in Binds.ACTIONS:
		if event.is_action_pressed(a["id"]):
			return a["id"]
	return ""


## ESC no meio da luta: congela tudo e abre o menu de pause (ui/screens/pause_menu.gd).
func pause() -> void:
	get_tree().paused = true
	hud.pause.open()


func resume() -> void:
	hud.pause.close()
	get_tree().paused = false


## Sai da luta pelo menu de pause. Conta como desistência (mais uma tentativa), igual ao wipe.
## `screen` é a tela que abre depois: "cards" (seleção de cartas) ou "title" (menu principal).
func leave_fight(screen: String) -> void:
	Knowledge.attempts += 1
	Knowledge.screen = screen
	_reload()


func start_fight() -> void:
	prep = false
	hud.set_prep(false)
	intro_left = hud.play_intro()
	_fight_setup()


## Efeitos de carta que valem "no começo da luta".
func _fight_setup() -> void:
	for u in units:
		_spawn_cards(u)
		if Knowledge.has(u.hero, "cookie"):
			lb = minf(1.0, lb + 0.25)


## Segunda Pele: entra na luta (e volta de um reviver) com um escudo pequeno.
func _spawn_cards(u: Unit) -> void:
	if Knowledge.has(u.hero, "secondskin"):
		u.shield_hp = maxf(u.shield_hp, 30.0)
		u.shield_t = 600.0


## Sai da luta. Vitória leva pra loja; derrota ou desistência volta pras cartas.
func retry() -> void:
	if won:
		Knowledge.attempts = 1
		Knowledge.screen = "shop"
	else:
		Knowledge.attempts += 1
		Knowledge.screen = "cards"
	_reload()


## Recarrega a cena da luta. O pause é da árvore, não da cena: sem desligar, a cena nova nasce congelada.
func _reload() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


## Baralho "tudo ensinado" dos testes automáticos: todas as cartas liberadas e as de mecânica equipadas.
func _test_decks() -> void:
	for id in Knowledge.CARDS:
		Knowledge.owned[id] = true
	var whites := ["dodge", "stack", "pair", "spread"]
	if Knowledge.boss == 2:
		whites = ["dodge", "zone", "partner", "shelter"]
	var golds := [["mitigate", "provoke", "final"], ["instinct", "eshield", "final"], ["final"], ["final"]]
	for slot in 4:
		var i := units[slot].hero
		for id in whites + golds[slot]:
			Knowledge.equip(i, id)
		# só no teste: o Quebra-Elo entra como quinta branca, pra validar a luta com tudo ensinado
		if Knowledge.boss == 1:
			Knowledge.deck(i)["white"].append("link")
		if Knowledge.boss == 3:
			Knowledge.equip(i, "mark")


## Onde este herói fica pra atacar: perto da boss se luta de perto, mais atrás se luta de longe.
func _atk_pos(u: Unit) -> Vector3:
	return MELEE_POS[u.idx] if u.melee else RANGED_POS[u.idx]


## `i` é o herói (índice em Knowledge.HEROES) que o jogador vai controlar no começo da luta.
## Devolve false se ele não está na party.
func select_hero(i: int) -> bool:
	var at := Knowledge.slot_of(i)
	if at < 0:
		return false
	Knowledge.start_hero = i
	units[ctrl].set_controlled(false)
	ctrl = at
	units[at].set_controlled(true)
	return true


func select_boss(i: int) -> void:
	Knowledge.boss = i
	Knowledge.attempts = 1
	Knowledge.screen = "cards"
	Knowledge.save()
	get_tree().reload_current_scene()


## Clique num card: escolhe aquele personagem como alvo das suas habilidades de suporte.
func select_target(i: int) -> void:
	sel = -1 if sel == i else i
	for u in units:
		u.chosen = u.idx == sel


func mechanic_active() -> bool:
	return zones_active or phase == "cata" or not stacks.is_empty() or not spreads.is_empty()


func set_ctrl(i: int) -> void:
	# trocar tem recarga: a troca vira uma decisão, não um botão pra apertar sem parar
	if i == ctrl or not units[i].alive or swap_cd > 0.0:
		return
	swap_cd = SWAP_CD
	var old := units[ctrl]
	old.set_controlled(false)
	old.channel_t = 0.0
	# Quem você posicionou na mão fica onde você deixou até a mecânica acabar.
	if old.alive and mechanic_active():
		old.hold_pos = old.position
	ctrl = i
	units[i].hold_pos = null
	units[i].set_controlled(true)
	_burst(units[i].position, units[i].color, 1.6)


## Tab: assume o herói focado (card ou teclas 1-4). Sem foco, vai pro próximo vivo.
## Clique no card ou atalho "controlar herói N": assume o herói na hora.
## Quem está morto (ou você mesmo) não dá pra assumir, então vira alvo (ex.: Reviver).
func pick_hero(i: int) -> void:
	if i != ctrl and units[i].alive:
		set_ctrl(i)
	else:
		select_target(i)


func _cycle_ctrl() -> void:
	for n in range(1, 4):
		var i := (ctrl + n) % 4
		if units[i].alive:
			set_ctrl(i)
			return


func give_order(o: String) -> void:
	order = o
	for u in units:
		if u.controlled or not u.alive:
			continue
		u.hold_pos = u.position if o == "hold" else null
	var names := {"atk": "ATACAR", "gather": "REUNIR", "spread": "ESPALHAR", "hold": "MANTER POSIÇÃO"}
	hud.toast(names[o], 1.0)


func _try_dash() -> void:
	var u := units[ctrl]
	if not u.alive or u.dash_cd > 0.0 or u.asleep:
		return
	var d := _input_dir()
	if d == Vector3.ZERO:
		d = Vector3(sin(u.visual.rotation.y) * -1.0, 0, cos(u.visual.rotation.y) * -1.0)
	u.dash_dir = d.normalized()
	u.dash_t = 0.22
	u.invuln = 0.4
	u.dash_cd = 0.9
	u.dash_fx()


func _input_dir() -> Vector3:
	var d := Vector3.ZERO
	if Input.is_action_pressed("move_up"): d.z -= 1.0
	if Input.is_action_pressed("move_down"): d.z += 1.0
	if Input.is_action_pressed("move_left"): d.x -= 1.0
	if Input.is_action_pressed("move_right"): d.x += 1.0
	return d.normalized()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if shot_left >= 0.0 and pause_test <= 0.0:  # com --pausetest a captura sai depois do pause
		shot_left -= delta
		if shot_left < 0.0:
			get_viewport().get_texture().get_image().save_png("user://shot.png")
			print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
			get_tree().quit()
			return
	if autoplay:
		auto_left -= delta
		if auto_left <= 0.0 or (ended and shot_left < 0.0):
			_print_report()
			get_tree().quit()
			return
	if prep or ended or fury:
		return
	if intro_left > 0.0:
		intro_left -= delta
		return

	fight_time += delta
	if win_test > 0.0 and fight_time >= win_test:
		win_test = 0.0
		boss_hp = 0.0
		_end(true)
		return
	if card_test > 0.0 and fight_time >= card_test:
		card_test = 0.0
		hud.card_unlocked("stack")
	if swap_test > 0.0 and fight_time >= swap_test:
		swap_test = 0.0
		_cycle_ctrl()
	if pause_test > 0.0 and fight_time >= pause_test:
		pause_test = 0.0
		pause()
		if shot_left >= 0.0:
			# com a árvore congelada este _process para; o timer "process_always" tira a captura
			await get_tree().create_timer(maxf(shot_left, 0.4), true).timeout
			get_viewport().get_texture().get_image().save_png("user://shot.png")
			print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
			get_tree().quit()
		return
	if lb_test > 0.0 and fight_time >= lb_test:
		lb_test = 0.0
		lb = 1.0
		use_lb()
	swap_cd = maxf(0.0, swap_cd - delta)
	_tick_boss(delta)
	_tick_hazards(delta)
	_tick_stacks(delta)
	_tick_spreads(delta)
	_tick_count(delta)
	_tick_link(delta)
	_tick_cleaves(delta)
	_tick_towers(delta)
	_tick_buster(delta)
	_tick_pairs(delta)
	_tick_holy(delta)
	_tick_hearths(delta)
	_tick_dots(delta)
	_tick_echoes(delta)
	if dream_stacks > 0:
		dream_t -= delta
		if dream_t <= 0.0:
			dream_stacks = 0
	for u in units:
		if ended:
			return
		if not u.alive:
			continue
		u.invuln = maxf(0.0, u.invuln - delta)
		u.guard_t = maxf(0.0, u.guard_t - delta)
		u.wall_t = maxf(0.0, u.wall_t - delta)
		u.frenzy_t = maxf(0.0, u.frenzy_t - delta)
		u.count_t = maxf(0.0, u.count_t - delta)
		u.power_t = maxf(0.0, u.power_t - delta)
		u.ward_t = maxf(0.0, u.ward_t - delta)
		if u.key == "maga":
			_tick_bullets(u, delta)
			_tick_ricochet(u, delta)
		if u.key == "sleepwalker":
			_tick_sleep(u, delta)
		u.patient_t = maxf(0.0, u.patient_t - delta)
		if u.mend_t > 0.0:
			u.mend_t -= delta
			u.hp = minf(u.max_hp, u.hp + u.mend_rate * delta)
		if u.parry_t > 0.0:
			u.parry_t -= delta
			if u.parry_t <= 0.0 and not u.parry_hit:
				_mercy_hit(u)
		if u.regen_t > 0.0:
			u.regen_t -= delta
			u.hp = minf(u.max_hp, u.hp + AEGIS_REGEN * delta)
		_tick_blood(u, delta)
		if ended:
			return
		u.weak_t = maxf(0.0, u.weak_t - delta)
		u.immortal_t = maxf(0.0, u.immortal_t - delta)
		for n in u.skill_cd.size():
			u.skill_cd[n] = maxf(0.0, u.skill_cd[n] - delta)
		if u.hp < u.max_hp and Knowledge.has(u.hero, "breath"):
			u.hp = minf(u.max_hp, u.hp + delta)
		u.cancel_t = maxf(0.0, u.cancel_t - delta)
		u.shield_t = maxf(0.0, u.shield_t - delta)
		if u.shield_t <= 0.0:
			u.shield_hp = 0.0
		_shield_fx(u)
		u.dash_cd = maxf(0.0, u.dash_cd - delta)
		var before := u.position
		if u.controlled and not autoplay:
			_tick_player(u, delta)
		else:
			_tick_ai(u, delta)
			# a IA nunca pisa no vazio por conta própria
			if void_on and _in_square(before) and not _in_square(u.position):
				u.position = before
		_clamp_to_arena(u)
		if void_on and u.alive and not _in_square(u.position, 0.15):
			kill(u, "caiu no vazio")
	_tick_auto(delta)
	_tick_dps(delta)

	# Fúria chegando: nos últimos segundos ela vai ficando vermelha e tremendo
	enrage_k = clampf((fight_time - (enrage - ENRAGE_CAST)) / ENRAGE_CAST, 0.0, 1.0)
	boss.enrage_k = enrage_k

	# DPS check: acabou o tempo, acabou a luta
	if fight_time >= enrage and not ended:
		_start_fury()
		return

	# arco no chão = até onde o personagem controlado alcança o boss
	var me := units[ctrl]
	floor_mat.set_shader_parameter("melee_r", me.atk_range)
	floor_mat.set_shader_parameter("melee_on", 1.0 if me.alive else 0.0)
	floor_mat.set_shader_parameter("melee_in", 1.0 if _in_range(me) else 0.0)
	_tick_side_mark()


func _print_report() -> void:
	print("--- REPORT ---")
	for line in log_lines:
		print("morte: ", line)
	print("acertos: ", hit_count)
	print("boss=", boss_def["name"], " ended=", ended, " won=", won, " boss_hp=", int(boss_hp), "/", int(boss_max), " phase=", phase, " t=", int(fight_time))
	for u in units:
		print(u.unit_name, " alive=", u.alive, " hp=", int(u.hp), " dps=", int(u.dmg_total / maxf(fight_time, 1.0)))
	for l in log_lines:
		print("LOG: ", l)


func _clamp_to_arena(u: Unit) -> void:
	var flat := Vector2(u.position.x, u.position.z)
	if flat.length() > ARENA_R:
		flat = flat.normalized() * ARENA_R
		u.position = Vector3(flat.x, 0, flat.y)


## DPS "ao vivo": média dos últimos ~4 segundos, pra reagir rápido sem ficar pulando.
func _tick_dps(delta: float) -> void:
	bucket_t += delta
	for u in units:
		var recent := 0.0
		for b in u.dmg_buckets:
			recent += b
		u.dps = (recent + u.dmg_bucket) / (u.dmg_buckets.size() + bucket_t)
	if bucket_t >= 1.0:
		bucket_t -= 1.0
		_tick_rotation(units[ctrl])
		for u in units:
			u.dmg_buckets.append(u.dmg_bucket)
			u.dmg_bucket = 0.0
			if u.dmg_buckets.size() > 3:
				u.dmg_buckets.pop_front()


## Carta roxa Rotação: segure um DPS bom pra classe por DPS_WINDOW segundos seguidos
## no controle do herói e a IA dele aprende a bater assim. Chamado uma vez por segundo.
func _tick_rotation(u: Unit) -> void:
	if autoplay or not u.alive or Knowledge.dps_known.has(u.key):
		return
	if rot_unit != u.idx:
		rot_unit = u.idx
		rot_buckets.clear()
	rot_buckets.append(u.dmg_bucket)
	if rot_buckets.size() > Knowledge.DPS_WINDOW:
		rot_buckets.pop_front()
	if rot_buckets.size() < Knowledge.DPS_WINDOW:
		return
	var sum := 0.0
	for b in rot_buckets:
		sum += b
	if sum / Knowledge.DPS_WINDOW >= Knowledge.DPS_GOAL[u.key]:
		Knowledge.dps_known[u.key] = true
		Knowledge.equip(u.hero, "dps")
		Knowledge.save()
		hud.card_unlocked("dps")


# ---------------------------------------------------------------- jogador

func _tick_player(u: Unit, delta: float) -> void:
	var moving := _input_dir() != Vector3.ZERO or u.dash_t > 0.0
	if _tick_cast(u, delta, moving):
		return

	if u.asleep:
		pass  # Sleepwalker dormindo: não anda nem desvia
	elif u.dash_t > 0.0:
		u.dash_t -= delta
		u.position += u.dash_dir * 19.0 * delta
	else:
		var d := _input_dir()
		if d != Vector3.ZERO:
			u.position += d * u.speed * delta
			u.face(d)

	# J é o ataque básico: uma habilidade com 1 s de recarga (segurar repete)
	var want_attack := Input.is_action_pressed("skill_1")
	if want_attack:
		use_skill(u, 0)
	if want_attack and not _in_range(u):
		u.set_action("Longe demais", 2)
	elif u.channel_t <= 0.0:
		u.set_action("", 0)


## Avança o cast em andamento. Devolve true enquanto o personagem está conjurando.
func _tick_cast(u: Unit, delta: float, moving: bool) -> bool:
	if u.channel_t <= 0.0:
		return false
	if moving:
		# andar ou esquivar interrompe qualquer cast, sem gastar a recarga
		u.cancel_ratio = 1.0 - u.channel_t / u.channel_total
		u.cancel_t = 0.7
		if u.channel_slot >= 0:
			u.skill_cd[u.channel_slot] = 0.0
		u.channel_t = 0.0
		return false
	u.channel_t -= delta
	u.set_action("LIMIT BREAK" if u.channel_slot == -1 else "Conjurando", 1)
	if u.channel_t <= 0.0:
		u.channel_t = 0.0
		if u.channel_slot == -1:
			_resolve_lb(u)
		else:
			_resolve_skill(u, u.channel_slot, u.cast_ai)
	return true


func _in_range(u: Unit) -> bool:
	return u.position.distance_to(BOSS_POINT) <= u.atk_range


# ---------------------------------------------------------------- IA da party

func _tick_ai(u: Unit, delta: float) -> void:
	# conjurando (a Cura da IA também tem cast): fica parado até soltar
	var i := u.idx
	var caster := u.key == "healer" or u.key == "maga"
	var careful := not caster or Knowledge.has(u.hero, "safe_cast")
	# Cautela: larga o cast (sem gastar a recarga) se um vermelho aparecer embaixo
	var rot_card: bool = Knowledge.has(u.hero, "dps") and (u.key == "assassina" or u.key == "maga")
	if careful and u.channel_t > 0.0 and u.channel_slot >= 0:
		# o golpe forte da Rotação também é largado se uma mecânica de juntar começar
		var must_move: bool = rot_card and u.channel_slot == BIG_SLOT.get(u.key, -1) and not stacks.is_empty()
		if must_move or _danger_at(u.position, u, true, 0.1):
			u.skill_cd[u.channel_slot] = 0.0
			u.channel_t = 0.0
	if _tick_cast(u, delta, false):
		return
	var goal = null
	var text := "Atacando"
	var kind := 0

	# Prioridade: cartas do deck > ordem manual > comportamento padrão.
	var plan = _card_plan(u)
	if plan != null:
		goal = plan[0]
		text = plan[1]
		kind = 1
	elif u.hold_pos != null:
		goal = u.hold_pos
		text = "Mantendo posição"
	elif order == "gather":
		var ang2 := i * TAU / 4.0
		goal = units[ctrl].position + Vector3(cos(ang2), 0, sin(ang2)) * 1.1
		text = "Reunindo"
	elif order == "spread":
		# com a arena desabando, "espalhar" manda cada um pra própria torre
		goal = TOWER_POS[i] if (void_on or void_warn) else SPREAD_POS[i]
		text = "Espalhando"
	else:
		goal = _atk_pos(u)
		# Sem carta pra isso: o personagem recebe a mecânica e não sabe o que fazer.
		if (zones_active or phase == "cata") and u.element >= 0:
			text = "???"
			kind = 2
		elif not stacks.is_empty() or not spreads.is_empty():
			text = "???"
			kind = 2
		elif phase == "cata" and shelter_pos != null:
			text = "???"
			kind = 2

	# Desvio: cada personagem só enxerga os ataques pros quais tem a carta amarela.
	var in_danger := _danger_at(u.position, u, true, 0.1)
	if u.dodge_goal != null and not in_danger and (hazards.is_empty() or u.position.distance_to(u.dodge_goal) <= 0.15):
		u.dodge_goal = null  # chegou na saída (ou o ataque já passou)
	if not in_danger:
		u.in_red = false
	elif not u.in_red:
		u.in_red = true
		u.stuck_t = 0.0 if careful else CAST_STUCK
	if in_danger and u.stuck_t > 0.0:
		# sem Cautela: termina o cast que estava fazendo antes de pensar em sair
		u.stuck_t -= delta
		goal = u.position
		text = "Conjurando"
		kind = 2
	elif in_danger:
		# escolhe uma saída e vai até ela; só troca se a saída deixar de ser segura
		if u.dodge_goal == null or _danger_at(u.dodge_goal, u, true, 0.3):
			# folga diferente a cada desvio: ninguém para colado na borda do ataque
			u.dodge_goal = _safe_point(u, goal, randf_range(0.9, 1.6))
			if u.dodge_goal == null:
				u.dodge_goal = _safe_point(u, goal, 0.45)
		if u.dodge_goal != null:
			goal = u.dodge_goal
		text = "Desviando"
		kind = 1
	elif u.dodge_goal != null and not _danger_at(u.dodge_goal, u, true, 0.3):
		# saiu da área por pouco: termina de chegar na saída antes de voltar a atacar
		goal = u.dodge_goal
		text = "Desviando"
		kind = 1
	elif _danger_at(u.position, u, false, 0.0):
		text = "???"
		kind = 2
	elif goal != null and _danger_at(goal, u, true, 0.3):
		# o destino está perigoso: espera onde está em vez de entrar e sair
		goal = u.position
		text = "Esperando"
		kind = 1

	if goal != null:
		var to: Vector3 = goal - u.position
		to.y = 0
		var dist := to.length()
		if dist > 0.12:
			u.position += to / dist * minf(u.speed * delta, dist)
			u.face(to)
		elif _in_range(u):
			u.face(BOSS_POINT - u.position)

	var hs: Dictionary = HEAL_SLOTS.get(u.key, {})
	if not hs.is_empty() and not (careful and in_danger):
		# Escudo de Emergência: só no cast do ESMAGAR, e a tempo de sair antes do golpe
		if Knowledge.has(u.hero, "eshield") and buster != null and u.skill_cd[hs["shield"]] <= 0.0 and buster["t"] > 0.3 \
				and buster["target"].alive and buster["target"].shield_hp <= 0.0:
			if use_skill(u, hs["shield"], true, buster["target"]):
				u.set_action("Escudo no " + buster["target"].unit_name, 1)
				return
		# Reviver Automático: o Renascimento (slot 6) levanta quem caiu
		if Knowledge.has(u.hero, "revive") and hs["revive"] >= 0 and u.skill_cd[hs["revive"]] <= 0.0:
			for o in units:
				if not o.alive:
					if use_skill(u, hs["revive"], true):
						u.set_action("Revivendo " + o.unit_name, 1)
						return
					break

	# Instinto: só reage a pouca vida, então não fica gastando cura à toa.
	if Knowledge.has(u.hero, "instinct") and not hs.is_empty():
		# no Dodge Time a explosão do fim tira 70% da vida: ele enche todo mundo antes
		var topping: bool = DODGE_PHASES.has(phase) or finale_state == 1
		var low: float = 0.95 if topping else Knowledge.LOW_HP
		# primeiro ele mesmo: healer morto não cura ninguém
		var ht: Unit = u if u.hp / u.max_hp < Knowledge.LOW_HP else _heal_target()
		# o Tank é socorrido mais cedo: ele precisa de folga pra aguentar o Esmagar
		if ht != null and ht.hp / ht.max_hp < low + (0.3 if ht.tank and not topping else 0.0):
			heal_focus = ht
		# começou a socorrer alguém, termina o serviço antes de parar
		if heal_focus != null and (not heal_focus.alive or heal_focus.hp / heal_focus.max_hp >= (0.97 if topping else 0.9)):
			heal_focus = null
		# vários machucados por perto: a cura em área rende mais que a de um alvo só
		var hurt_near := 0
		for o in units:
			if o.alive and o.hp / o.max_hp < (0.9 if topping else 0.7) and o.position.distance_to(u.position) <= AOE_HEAL_R:
				hurt_near += 1
		if careful and in_danger:
			pass  # Cautela: primeiro sai do vermelho, depois cura
		elif hurt_near >= (2 if topping else 3) and u.skill_cd[hs["area"]] <= 0.0:
			use_skill(u, hs["area"], true)  # Lareira Celestial / Tanatopraxia
		elif heal_focus != null and heal_focus.hp / heal_focus.max_hp < 0.35 and u.skill_cd[hs["big"]] <= 0.0:
			use_skill(u, hs["big"], true, heal_focus)  # Asa da Fênix / Estabilização: socorro grande e na hora
		elif heal_focus != null and u.skill_cd[hs["heal"]] <= 0.0:
			use_skill(u, hs["heal"], true, heal_focus)  # Toque de Brasa / Sutura

	if u.tank and Knowledge.has(u.hero, "provoke") and target != null and target != u and u.skill_cd[PROVOKE_SLOT[u.key]] <= 0.0:
		use_skill(u, PROVOKE_SLOT[u.key], true)

	# Rotação: o golpe forte sai quando não tem nada pra resolver e ele já está no lugar
	if rot_card and u.skill_cd[BIG_SLOT[u.key]] <= 0.0 and _in_range(u) and not in_danger and stacks.is_empty() \
			and (goal == null or u.position.distance_to(goal) < 0.3):
		if use_skill(u, BIG_SLOT[u.key], true):
			u.set_action("Conjurando", 1)
			return

	# Auto-ataque conservador: bem mais fraco que o jogador no controle.
	if _in_range(u):
		# carta roxa Rotação: a IA usa a rotação que você mostrou jogando bem com esse herói
		var rate: float = ROTATION_DPS[u.key] if Knowledge.has(u.hero, "dps") else u.ai_dps
		_damage_boss(u, rate * delta, false, false)
		if u.key == "nurse":
			# as estocadas da IA também roubam um fio de vida; com a Rotação ela usa o Blood Consumed
			u.hp = minf(u.max_hp, u.hp + boss_hp * POKE_STEAL * delta)
			if Knowledge.has(u.hero, "dps") and u.skill_cd[2] <= 0.0 and not in_danger:
				use_skill(u, 2, true)
		u.dmg_acc += rate * delta * _dmg_mult()
		u.dmg_timer += delta
		if u.dmg_timer >= 1.2:
			_popup(int(u.dmg_acc), Color(0.75, 0.75, 0.8), 30)
			u.dmg_acc = 0.0
			u.dmg_timer = 0.0
	elif text == "Atacando":
		text = "Indo atacar"
	u.set_action(text, kind)


## Bolha do escudo em volta do herói; criada na primeira vez que ele recebe um.
func _shield_fx(u: Unit) -> void:
	var fx: MeshInstance3D = u.get_node_or_null("ShieldFx")
	if u.shield_hp <= 0.0 or not u.alive:
		if fx != null:
			fx.visible = false
		return
	if fx == null:
		fx = Fx.inst(u, Fx.sphere(1.05), Fx.mat(Color(0.45, 0.9, 1.0, 0.22), 1.2, true), Vector3(0, 1.0, 0))
		fx.name = "ShieldFx"
	fx.visible = true
	# a bolha encolhe conforme o escudo é gasto
	var k := clampf(u.shield_hp / (u.max_hp * SHIELD_RATIO), 0.3, 1.0)
	fx.scale = Vector3.ONE * lerpf(0.75, 1.0, k)


## O que as cartas de mecânica mandam o herói fazer agora: [posição, texto], ou null.
## Cada carta é uma ação única; sem a carta, o herói não sabe resolver aquela mecânica.
func _card_plan(u: Unit):
	var i := u.idx
	# Guarda: aperta a defesa no Esmagar, como você faria. O Paladino solta a Égide no fim do cast;
	# a Malpractice espera o último instante, porque a janela do Blood Taste é de meio segundo.
	if u.tank and Knowledge.has(u.hero, "mitigate") and buster != null and buster["target"] == u and buster["t"] <= (0.35 if u.key == "nurse" else 1.2):
		use_skill(u, DEF_SLOT[u.key], true)
	# Quebra-Elo: os dois presos correm em sentidos opostos até a corrente arrebentar
	if link != null and (link["a"] == u or link["b"] == u) and Knowledge.has(u.hero, "link"):
		var first: bool = link["a"] == u
		var lx := clampf(u.position.x, -3.5, 3.5)
		if cleave_side != 0:
			lx = -cleave_side * 3.5
		return [Vector3(lx, 0, -6.5 if first else 6.5), "Quebrando o elo"]
	if Knowledge.has(u.hero, "final"):
		# a mão dela subiu: sai daquele lado antes da marca aparecer no chão
		if cleave_side != 0 and u.position.x * cleave_side > -1.4:
			return [Vector3(-cleave_side * 3.2, 0, u.position.z), "→ Lado seguro"]
		if void_warn or void_on:
			return [TOWER_POS[i], "→ Torre"]
	# Dispersão: marcado de roxo vai pro próprio canto. Sem dupla pra formar, todo mundo vai.
	if not spreads.is_empty() and Knowledge.has(u.hero, "spread") and (_spread_on(u) or stacks.is_empty()):
		return [CORNERS[i], "→ Canto"]
	# a Marca Elemental (roxa) vale pelas três brancas de elemento
	var mark := Knowledge.has(u.hero, "mark")
	if zones_active and (mark or Knowledge.has(u.hero, "zone")):
		var rz = _act(u, "zone_opp")
		if rz != null:
			return rz
	if phase == "cata":
		if u.element >= 0 and (mark or Knowledge.has(u.hero, "partner")):
			var rp = _act(u, "partner")
			if rp != null:
				return rp
		if mark or Knowledge.has(u.hero, "shelter"):
			var rs = _act(u, "shelter")
			if rs != null:
				return rs
	if not stacks.is_empty():
		if stack_need == 4 and Knowledge.has(u.hero, "stack"):
			var r4 = _act(u, "to_marked")
			if r4 != null:
				return r4
		if stack_need == 2 and Knowledge.has(u.hero, "pair"):
			var r2 = _pair_plan(u)
			if r2 != null:
				return r2
	return null


func _act(u: Unit, a: String):
	var ang := u.idx * TAU / 4.0
	var off := Vector3(cos(ang), 0, sin(ang))
	match a:
		"to_marked":
			# vai pro marcado mais próximo. Com dois círculos isso junta gente demais num só.
			var near = null
			for st in stacks:
				var m: Unit = st["target"]
				if m == u:
					return [u.position, "Esperando a party"]
				if near == null or m.position.distance_to(u.position) < near.position.distance_to(u.position):
					near = m
			if near != null:
				return [near.position + off * 0.9, "→ " + near.unit_name]
		"pair_up":
			if stacks.is_empty() or stack_need != 2:
				return null
			return _pair_plan(u)
		"zone_opp", "zone_same":
			if u.element < 0:
				return null
			var z = _zone_for(OPP[u.element] if a == "zone_opp" else u.element)
			if z != null:
				return [z["pos"], "→ Zona de " + EL_NAME[z["el"]]]
		"partner":
			var p = _partner(u)
			if p != null:
				return [p.position, "→ " + p.unit_name]
		"shelter":
			if shelter_pos != null:
				return [shelter_pos + off, "→ Abrigo"]
		"center":
			return [off * 0.9, "→ Centro"]
		"stay":
			return [u.position, "Parado"]
	return null


func _partner(u: Unit):
	if u.element < 0:
		return null
	for o in units:
		if o != u and o.alive and o.element == OPP[u.element]:
			return o
	return null


func _zone_for(el: int):
	for z in zones:
		if z["el"] == el:
			return z
	return null


# ---------------------------------------------------------------- aggro e golpes do boss

## Quem o boss bate: o vivo com mais enmity. No empate (começo da luta), o Tank.
func _aggro_target() -> Unit:
	var best: Unit = null
	for u in units:
		if u.alive and (best == null or u.enmity > best.enmity):
			best = u
	return best


## Golpe básico do boss, fora das habilidades: não dá pra desviar, tem que aguentar e curar.
func _tick_auto(delta: float) -> void:
	target = _aggro_target()
	for u in units:
		u.targeted = u == target
	if target == null:
		return
	if phase == "dodgetime":
		return  # conjurando o Dodge Time: ela não bate
	auto_t += delta
	if auto_t < AUTO_EVERY:
		return
	auto_t = 0.0
	var victim := target
	var from := Vector3(randf_range(-2.5, 2.5), 6.0, -11.5)
	var mi := Fx.inst(fx_root, Fx.sphere(0.3), Fx.mat(DANGER, 3.0, true), from)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", victim.position + Vector3(0, 1.0, 0), 0.14)
	tw.tween_callback(mi.queue_free)
	tw.tween_callback(func(): hurt(victim, AUTO_DMG, "apanhou do boss"))


# ---------------------------------------------------------------- habilidades

## Quem mais precisa de cura. O Tank pesa mais: ele é quem segura o boss.
func _heal_target() -> Unit:
	var best: Unit = null
	var best_score := 10.0
	for u in units:
		if not u.alive or u.hp >= u.max_hp:
			continue
		var score := u.hp / u.max_hp - (0.2 if u.tank else 0.0)
		if score < best_score:
			best_score = score
			best = u
	return best


## Tenta usar a habilidade. Com cast, só começa a conjurar; o efeito sai em _resolve_skill.
func use_skill(u: Unit, slot: int, by_ai := false, forced: Unit = null) -> bool:
	var list: Array = kit(u)
	if not u.alive or slot >= list.size() or list[slot] == null or u.skill_cd[slot] > 0.0 or u.channel_t > 0.0 or intro_left > 0.0:
		return false
	var sk: Dictionary = list[slot]
	# segurar o ataque básico andando não fica começando e cancelando cast a cada frame
	if slot == 0 and sk.has("cast") and not by_ai and _input_dir() != Vector3.ZERO:
		return false
	u.cast_target = null
	if sk.has("dmg") and not _in_range(u):
		u.set_action("Longe demais", 2)
		return false
	match sk["name"]:
		"Blood Taste":
			if u.taste_t > 0.0 or u.party_t > 0.0:
				return false
		"Blood Party":
			if u.stacks < PARTY_NEED or u.party_t > 0.0 or u.taste_t > 0.0:
				return false
		"Toque de Brasa", "Asa da Fênix", "Sutura", "Estabilização":
			var ht := _heal_target()
			# na sua mão, o alvo escolhido no card tem prioridade
			if not by_ai and sel >= 0 and units[sel].alive and units[sel].hp < units[sel].max_hp:
				ht = units[sel]
			if forced != null:
				ht = forced
			if ht == null:
				return false
			u.cast_target = ht
		"Solução Hemostática":
			# com 3 Vestígios e a boss em Decomposição, sem aliado escolhido: vai na boss (Contaminação)
			var ally: Unit = target if target != null else u
			if not by_ai and sel >= 0 and units[sel].alive:
				ally = units[sel]
			elif not by_ai and u.vestiges >= VESTIGE_MAX and not get_dot("decomp").is_empty():
				ally = null
			if forced != null:
				ally = forced
			u.cast_target = ally
		"Manto de Cinzas":
			# no alvo focado; sem foco, em quem o boss está batendo
			var st: Unit = target if target != null else u
			if not by_ai and sel >= 0 and units[sel].alive:
				st = units[sel]
			if forced != null:
				st = forced
			u.cast_target = st

	if sk.has("cast"):
		var cast: float = sk["cast"]
		# Golpe Lapidado: a Maga conjura o golpe forte mais rápido
		if u.key == "maga" and slot == BIG_SLOT["maga"] and Knowledge.has(u.hero, "burst"):
			cast -= 0.7
		u.channel_t = cast
		u.channel_total = cast
		u.channel_slot = slot
		u.cast_ai = by_ai
		if u.cast_target != null:
			# liga quem conjura a quem vai receber enquanto o cast corre
			u.face(u.cast_target.position - u.position)
			_beam(u.position, u.cast_target.position, Color(0.4, 1.0, 0.6, 0.7), sk["cast"] + 0.15)
		elif sk.has("dmg"):
			u.face(BOSS_POINT - u.position)
		# cast curto já gasta a recarga ao começar; cast longo só gasta se sair
		if sk["cast"] < LOCKED_CAST:
			u.skill_cd[slot] = sk["cd"] * (1.15 if by_ai else 1.0)
		return true
	_resolve_skill(u, slot, by_ai)
	return true


func _resolve_skill(u: Unit, slot: int, by_ai: bool) -> void:
	var sk: Dictionary = kit(u)[slot]
	if u.key == "sleepwalker":
		_sleep_skill(u, slot)
		return
	if not (sk.has("cast") and sk["cast"] < LOCKED_CAST):
		u.skill_cd[slot] = sk.get("ai_cd", sk["cd"] * 1.15) if by_ai else sk["cd"]
	if slot == 0 and u.frenzy_t > 0.0:
		u.skill_cd[slot] *= FRENZY_HASTE
	if u.key == "ringstar" and slot <= 2:
		# os três golpes dividem a recarga; com a Contagem Regressiva ela cai pela metade
		var gcd: float = COUNT_GCD if u.count_t > 0.0 else sk["cd"]
		for n in 3:
			u.skill_cd[n] = gcd
	match sk["name"]:
		"Égide":
			# ergue o escudo: barreira dourada na frente do corpo (unit.gd), 60% menos dano e regeneração
			u.guard_t = AEGIS_TIME
			u.regen_t = AEGIS_TIME
			u.punch()
			_burst(u.position, GOLD, 2.8)
		"Muralha da Fé":
			for o in units:
				if o.alive:
					o.wall_t = WALL_TIME
					_burst(o.position, GOLD, 2.0)
			_faith_cross()
			hud.flash(Color(GOLD.r, GOLD.g, GOLD.b, 0.3))
			hud.toast("MURALHA DA FÉ", 1.6)
		"Solo Consagrado":
			_start_holy(u)
		"Provocação":
			_provoke(u, by_ai)
		"Blood Taste":
			# a vida vai a TASTE_HP por meio segundo; quando acaba, volta ao que era (ver _end_taste)
			u.taste_prev = u.hp
			u.max_hp = u.base_hp * TASTE_HP
			u.hp = u.max_hp
			u.taste_t = TASTE_TIME
			u.taste_hit = false
			_add_stacks(u, TASTE_STACKS)
			_burst(u.position, BLOOD, 2.4)
		"Emergency Response":
			# avança até encostar na boss (no máximo RUSH_DIST) e puxa ela pra si
			var to_boss := BOSS_POINT - u.position
			to_boss.y = 0.0
			var go := clampf(to_boss.length() - (MELEE_RANGE - 1.0), 0.0, RUSH_DIST)
			u.face(to_boss)
			u.dash_fx()
			var tw := u.create_tween()
			tw.tween_property(u, "position", u.position + to_boss.normalized() * go, 0.12)
			tw.tween_callback(func():
				_clamp_to_arena(u)
				if u.alive and _in_range(u):
					u.punch()
					_damage_boss(u, RUSH_DMG, true, false))
			_provoke(u, by_ai)
		"Blood Party":
			# gasta os acúmulos, fica com 1 de vida e invulnerável; a aura bate em _tick_blood
			u.stacks -= PARTY_NEED
			u.hp = 1.0
			u.party_t = PARTY_TIME
			u.party_tick = 0.0
			u.immortal_t = maxf(u.immortal_t, PARTY_TIME)
			hud.flash(Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.45))
			_burst(u.position, BLOOD, 6.0)
			hud.toast("BLOOD PARTY", 1.6)
		"Manto de Cinzas":
			var st: Unit = u.cast_target
			if st == null or not st.alive:
				st = u
			st.shield_hp = st.max_hp * SHIELD_RATIO
			st.shield_t = SHIELD_TIME
			u.enmity += st.shield_hp * HEAL_ENMITY * 0.5
			_beam(u.position, st.position, Color(0.45, 0.9, 1.0, 0.95), 0.3)
			_burst(st.position, Color(0.45, 0.9, 1.0), 2.2)
		"Lareira Celestial":
			_start_hearth(u)
		"Necropsia":
			_necropsy(u)
		"Solução Hemostática":
			_hemostatic(u)
		"Tanatopraxia":
			_thanato(u)
		"Renascimento":
			_rebirth(u)
		"Rainbow Shots":
			_rainbow(u)
		"Ricochete Prismático":
			_ricochet(u)
		"Salva Astral":
			_salvo(u)
		"Canhão Estelar":
			_cannon(u)
		"Marca do Zênite":
			add_dot("zenite", "Marca do Zênite", Color(1.0, 0.9, 0.45), ZENITH_TIME, ZENITH_DPS, u)
			_burst(Vector3(0, 7.5, -12.5), Color(1.0, 0.9, 0.45), 3.0)
		"Lança Serafim":
			_lance(u)
		"Rasante Incandescente":
			_swoop(u)
		"Chuva de Brasas":
			add_dot("chuva", "Chuva de Brasas", FIRE, RAIN_TIME, RAIN_DPS, u)
			for n in 8:
				_burst(Vector3(randf_range(-3.0, 3.0), randf_range(1.0, 5.0), -11.5), FIRE, 1.0)
		"Juízo Solar":
			_solar(u)
		"Contagem Regressiva":
			_countdown(u)
		"SUPERSTAR!":
			# à distância, sem preparo: uma rajada de luvas de luz
			for n in 4:
				_attack_fx(u, true)
			_burst(Vector3(0, 4, -11.5), STAR, 5.0)
			_damage_boss(u, SUPERSTAR_DMG, true, true)
		"Nocaute Final":
			_burst(Vector3(0, 4.5, -11.5), STAR.lightened(0.3), 9.0)
			hud.flash(Color(STAR.r, STAR.g, STAR.b, 0.4))
			hud.toast("NOCAUTE FINAL", 1.6)
			_damage_boss(u, KNOCKOUT_DMG, true, true)
		"Passo Rasante":
			_dash_cut(u, sk["dmg"])
		"Garras Cruzadas":
			# três cortes seguidos, cada um com a silhueta dela num lugar
			for n in CLAW_HITS:
				get_tree().create_timer(n * CLAW_GAP, false).timeout.connect(_claw.bind(u, n, sk["dmg"]))
		"Dança Carmesim":
			u.punch()
			for n in 6:
				var a := n * TAU / 6.0
				_afterimage(u, Vector3(cos(a), 0, sin(a)) * 1.3, Color(0.9, 0.1, 0.25))
			_burst(u.position, Color(0.9, 0.1, 0.25), 3.4)
			if _in_range(u):
				_damage_boss(u, sk["dmg"], true, true)
		"Golpe de Misericórdia":
			u.face(BOSS_POINT - u.position)
			if by_ai:
				_mercy_hit(u)
			else:
				# o corte sai no fim da janela; se um golpe chegar antes, vira parry e não dá dano
				u.parry_t = MERCY_WINDOW
				u.parry_hit = false
				_burst(u.position, Color(1, 1, 1), 1.6)
		"Frenesi da Fera":
			u.frenzy_t = FRENZY_TIME
			u.skill_cd[0] = 0.0
			_burst(u.position, Color(0.75, 0.2, 1.0), 4.0)
			hud.toast("FRENESI DA FERA", 1.4)
		"Bora Biscoitar":
			_provoke(u, by_ai)
		"Toque de Brasa", "Asa da Fênix", "Sutura", "Estabilização":
			var ht: Unit = u.cast_target
			if ht == null or not ht.alive:
				ht = _heal_target()
			if ht == null:
				return
			var amount := HEAL_AI if by_ai else HEAL_PLAYER
			if sk["name"] == "Asa da Fênix":
				amount = PHOENIX_HEAL
				_burst(ht.position + Vector3(0, 1.0, 0), Color(1.0, 0.6, 0.2), 3.2)
			elif sk["name"] == "Sutura":
				if not by_ai:
					amount = SUTURE_HEAL
				# quem recebe a Sutura vira o Paciente: as Incisões seguintes mantêm ele de pé
				u.patient = ht
				u.patient_t = PATIENT_TIME
			elif sk["name"] == "Estabilização":
				amount = STABILIZE_HEAL * (1.5 if ht.hp / ht.max_hp < STABILIZE_LOW else 1.0)
				_burst(ht.position + Vector3(0, 1.0, 0), CHEM, 3.2)
			# socorreu na mão alguém com pouca vida: conta pra maestria do Instinto
			if not by_ai and ht.hp / ht.max_hp < Knowledge.LOW_HP:
				_master("heal")
			ht.hp = minf(ht.max_hp, ht.hp + amount)
			u.enmity += amount * HEAL_ENMITY
			_beam(u.position, ht.position, Color(0.5, 1.0, 0.65, 0.95), 0.3)
			_burst(ht.position, Color(0.4, 1.0, 0.6), 1.8)
			_popup(int(amount), Color(0.5, 1.0, 0.65), 64, ht.position + Vector3(0, 2.6, 0), "+")
		_:
			# habilidades de dano (incluindo o ataque básico)
			if not _in_range(u):
				u.set_action("Longe demais", 2)
				return
			var big := slot > 0
			u.face(BOSS_POINT - u.position)
			u.punch()
			_attack_fx(u, big)
			if sk.has("cast") and sk["cast"] >= LOCKED_CAST:
				_burst(Vector3(0, 4, -11.5), u.color.lightened(0.3), 6.0)
			var amount: float = sk["dmg"]
			if slot == BIG_SLOT.get(u.key, -1) and Knowledge.has(u.hero, "burst"):
				amount *= 1.3 if u.key == "assassina" else 1.15
			if sk["name"] == "Incisão":
				big = false
				if get_dot("decomp").is_empty():
					u.skill_cd[0] = INCISION_SLOW  # sem Decomposição na boss o bisturi fica lento
				elif u.patient != null and u.patient.alive and u.patient_t > 0.0 and u.patient.hp < u.patient.max_hp:
					u.patient.hp = minf(u.patient.max_hp, u.patient.hp + PATIENT_HEAL)
					u.enmity += PATIENT_HEAL * HEAL_ENMITY
					_popup(int(PATIENT_HEAL), Color(0.5, 1.0, 0.85), 36, u.patient.position + Vector3(0, 2.6, 0), "+")
			if sk["name"] == "Disparo Rúnico":
				big = false
				if u.pierce_next:
					# fortalecido por uma bala Rainbow: perfura
					u.pierce_next = false
					amount *= PIERCE_MULT
					big = true
					_beam(u.position, Vector3(0, 2.0, -13.0), Color(1, 1, 1, 0.9), 0.25)
				if u.dash_next:
					u.dash_next = false
					_knock_back(u, 3.0)
			if u.key == "ringstar":
				amount = _combo_hit(u, slot, amount)
				big = amount > 30.0
			if sk["name"] == "Talho Relâmpago":
				big = false
				if u.frenzy_t > 0.0:
					_afterimage(u, Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.5, 0.5)), Color(0.75, 0.2, 1.0))
				# do lado certo da boss: gasta um dos três golpes fortalecidos; acabou, troca de lado
				if not by_ai and _side_of(u) == u.side_need:
					amount *= SIDE_MULT
					big = true
					u.side_left -= 1
					if u.side_left <= 0:
						u.side_need = -u.side_need
						u.side_left = SIDE_HITS
						_burst(_side_pos(u.side_need), SIDE_COL, 2.4)
			if sk["name"] == "Baque do Escudo":
				# golpe de escudo: mais pesado na tela. (Interromper fica pra quando existir cast interrompível.)
				_burst(BOSS_POINT + Vector3(0, 1.2, 2.0), Color(1.0, 0.95, 0.8), 2.6)
				boss.hit_flash()
			if sk["name"] == "Syringe Poke":
				# o roubo é em cima da vida ATUAL da boss: vai rendendo menos conforme a luta anda
				var steal := boss_hp * POKE_STEAL
				amount += steal
				_lifesteal(u, steal)
			elif sk["name"] == "Blood Consumed":
				amount += CONSUMED_STEAL
				_lifesteal(u, CONSUMED_STEAL)
				_add_stacks(u, CONSUMED_STACKS)
			_damage_boss(u, amount, true, big)
	# Malpractice: o golpe saiu, o sangue foi. Só na mão do jogador: a IA joga uma versão segura dela.
	if not by_ai and SELF_COST.has(sk["name"]):
		_bleed(u, SELF_COST[sk["name"]])


# ---------------------------------------------------------------- Assassina

## De que lado da boss o herói está: 1 = direita (x positivo), -1 = esquerda, 0 = no meio.
func _side_of(u: Unit) -> int:
	if u.position.x > SIDE_MIN:
		return 1
	if u.position.x < -SIDE_MIN:
		return -1
	return 0


## Onde fica, no chão, a marca do lado pedido.
func _side_pos(side: int) -> Vector3:
	return Vector3(side * 2.9, 0.0, -6.4)


## Sombra da personagem que fica pra trás e some (Garras, Dança, Frenesi).
func _afterimage(u: Unit, offset: Vector3, col: Color) -> void:
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.55), 1.5, true)
	var mi := Fx.inst(fx_root, Fx.capsule(0.38, 1.3), m, u.position + offset + Vector3(0, 0.7, 0))
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.32)
	tw.tween_callback(mi.queue_free)


## Passo Rasante: atravessa a boss pro outro lado com um corte, deixando um rastro verde.
func _dash_cut(u: Unit, dmg: float) -> void:
	var from := u.position
	var to := Vector3(-from.x, 0, from.z)
	if absf(from.x) < SIDE_MIN + 0.4:
		to.x = u.side_need * 2.6  # estava no meio: vai pro lado que está valendo
	var flat := Vector2(to.x, to.z)
	if flat.length() > ARENA_R:
		flat = flat.normalized() * ARENA_R
		to = Vector3(flat.x, 0, flat.y)
	u.face(to - from)
	u.dash_fx()
	u.invuln = maxf(u.invuln, 0.2)
	_beam(from, to, SIDE_COL, 0.5)
	_afterimage(u, Vector3.ZERO, SIDE_COL)
	var tw := u.create_tween()
	tw.tween_property(u, "position", to, 0.1)
	tw.tween_callback(func():
		u.face(BOSS_POINT - u.position)
		if u.alive:
			_damage_boss(u, dmg, true, true))


func _claw(u: Unit, n: int, dmg: float) -> void:
	if not u.alive or ended:
		return
	_afterimage(u, Vector3((n - 1) * 0.9, 0, -0.4), u.color.lightened(0.3))
	u.punch()
	if _in_range(u):
		_attack_fx(u, false)
		_damage_boss(u, dmg, true, n == CLAW_HITS - 1)


## O corte do Golpe de Misericórdia de fato (quando a janela passa sem ninguém bater nela).
func _mercy_hit(u: Unit) -> void:
	if not u.alive or not _in_range(u):
		return
	var amount: float = SKILLS["assassina"][BIG_SLOT["assassina"]]["dmg"]
	if Knowledge.has(u.hero, "burst"):
		amount *= 1.3
	u.punch()
	_attack_fx(u, true)
	_burst(BOSS_POINT + Vector3(0, 1.4, 1.8), Color(1.0, 0.95, 0.9), 3.0)
	_damage_boss(u, amount, true, true)


## Marca no chão do lado em que o Talho está valendo, com os golpes que faltam. Só pra quem
## está jogando de Assassina.
func _tick_side_mark() -> void:
	var me := units[ctrl]
	var on: bool = me.key == "assassina" and me.alive and not prep and not ended
	side_mark.visible = on
	if not on:
		return
	side_mark.position = _side_pos(me.side_need)
	side_mark.rotation.y += get_process_delta_time() * 1.5
	for n in side_pips.size():
		side_pips[n].visible = n < me.side_left
	side_label.text = "DIREITA" if me.side_need > 0 else "ESQUERDA"


# ---------------------------------------------------------------- Maga

## Empurra o herói pra longe da boss (recuo do tiro forte, dash da bala amarela).
func _knock_back(u: Unit, dist: float) -> void:
	var away := u.position - BOSS_POINT
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
	var to := u.position + away * dist
	var flat := Vector2(to.x, to.z)
	if flat.length() > ARENA_R:
		flat = flat.normalized() * ARENA_R
		to = Vector3(flat.x, 0, flat.y)
	u.dash_fx()
	u.invuln = maxf(u.invuln, 0.25)
	u.create_tween().tween_property(u, "position", to, 0.14).set_ease(Tween.EASE_OUT)


## Passiva: uma bala nova a cada BULLET_EVERY segundos, de cor sorteada.
func _tick_bullets(u: Unit, delta: float) -> void:
	if u.bullets.size() >= BULLET_MAX:
		u.bullet_t = 0.0
		return
	u.bullet_t += delta
	if u.bullet_t >= BULLET_EVERY:
		u.bullet_t = 0.0
		u.bullets.append(randi() % BULLETS.size())
		if u.controlled:
			_burst(u.position + Vector3(0, 2.2, 0), BULLETS[u.bullets[u.bullets.size() - 1]]["col"], 0.9)


func _shot_fx(u: Unit, col: Color, big: bool) -> void:
	var from := u.position + Vector3(0, 1.2, 0)
	var to := Vector3(randf_range(-0.8, 0.8), randf_range(2.5, 4.0), -11.0)
	var mi := Fx.inst(fx_root, Fx.sphere(0.34 if big else 0.2), Fx.mat(col, 4.0, true), from)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to, 0.08)
	tw.tween_callback(mi.queue_free)
	tw.tween_callback(_burst.bind(to, col, 2.6 if big else 1.2))


## Rainbow Shots: gasta a próxima bala. Com exatamente 3 guardadas, gasta as 3 num tiro só.
func _rainbow(u: Unit) -> void:
	if u.bullets.is_empty():
		u.set_action("Sem balas", 2)
		return
	u.face(BOSS_POINT - u.position)
	if u.bullets.size() == 3:
		u.bullets.clear()
		_shot_fx(u, Color(1, 1, 1), true)
		_damage_boss(u, BULLET_TRIPLE, true, true)
		_knock_back(u, BULLET_KNOCK)
		hud.toast("TIRO TRIPLO", 0.9)
		return
	var kind: int = u.bullets.pop_front()
	var col: Color = BULLETS[kind]["col"]
	_shot_fx(u, col, false)
	_damage_boss(u, BULLET_DMG, true, false)
	u.pierce_next = true
	match kind:
		0: u.power_t = BULLET_BUFF
		1: u.ward_t = BULLET_BUFF
		2:
			u.hp = minf(u.max_hp, u.hp + 20.0)
			_popup(20, Color(0.5, 1.0, 0.65), 48, u.position + Vector3(0, 2.6, 0), "+")
		3: add_dot("veneno", "Bala Venenosa", col, 8.0, 5.0, u)
		4: u.dash_next = true
	_burst(u.position + Vector3(0, 1.0, 0), col, 1.3)


## Ricochete Prismático: perto da boss, a bala fica indo e voltando entre ela e a Maga.
## Longe, é um tiro só que ricocheteia uma vez.
func _ricochet(u: Unit) -> void:
	u.face(BOSS_POINT - u.position)
	if u.position.distance_to(BOSS_POINT) > MELEE_RANGE:
		_shot_fx(u, Color(0.8, 0.95, 1.0), false)
		_damage_boss(u, RICO_DMG * 2.5, true, false)
		return
	u.ricochet_t = RICO_TIME
	u.ricochet_tick = 0.0
	u.ricochet_out = true


func _tick_ricochet(u: Unit, delta: float) -> void:
	if u.ricochet_t <= 0.0:
		return
	u.ricochet_t -= delta
	u.ricochet_tick -= delta
	if u.ricochet_tick > 0.0:
		return
	u.ricochet_tick = RICO_STEP
	if u.position.distance_to(BOSS_POINT) > MELEE_RANGE:
		u.ricochet_t = 0.0  # saiu de perto: a bala se perde
		return
	var col := Color(0.8, 0.95, 1.0, 0.95)
	if u.ricochet_out:
		_beam(u.position, Vector3(0, 2.0, -11.5), col, RICO_STEP)
		_damage_boss(u, RICO_DMG, true, false)
	else:
		_beam(Vector3(0, 2.0, -11.5), u.position, col, RICO_STEP)
		var room := u.max_hp - u.hp
		u.hp = minf(u.max_hp, u.hp + RICO_HEAL)
		if room < RICO_HEAL:
			# o que passou da vida cheia vira escudo
			u.shield_hp += RICO_HEAL - maxf(room, 0.0)
			u.shield_t = maxf(u.shield_t, SHIELD_TIME)
		_burst(u.position + Vector3(0, 1.0, 0), Color(0.8, 0.95, 1.0), 1.0)
	u.ricochet_out = not u.ricochet_out


## Salva Astral: descarrega 3 balas de uma vez numa área e ganha um escudo.
func _salvo(u: Unit) -> void:
	if u.bullets.size() < SALVO_COST:
		u.set_action("Precisa de 3 balas", 2)
		u.skill_cd[4] = 0.0
		return
	u.face(BOSS_POINT - u.position)
	for n in SALVO_COST:
		var col: Color = BULLETS[u.bullets.pop_front()]["col"]
		get_tree().create_timer(n * 0.09, false).timeout.connect(_shot_fx.bind(u, col, false))
	_damage_boss(u, SALVO_DMG * SALVO_COST, true, true)
	u.shield_hp = maxf(u.shield_hp, SALVO_SHIELD)
	u.shield_t = SHIELD_TIME
	_burst(u.position, Color(0.45, 0.9, 1.0), 2.2)


## Canhão Estelar: gasta TODAS as balas guardadas; cada uma vale bem mais aqui do que solta.
func _cannon(u: Unit) -> void:
	u.face(BOSS_POINT - u.position)
	var loaded := u.bullets.size()
	u.bullets.clear()
	var amount := CANNON_DMG + CANNON_PER_BULLET * loaded
	_beam(u.position, Vector3(0, 3.0, -12.0), Color(1, 1, 1, 0.98), 0.6)
	_burst(Vector3(0, 4, -11.5), u.color.lightened(0.4), 6.0 + loaded)
	hud.flash(Color(1.0, 0.9, 0.6, 0.35))
	hud.toast("CANHÃO ESTELAR" + (" ×%d" % loaded if loaded > 0 else ""), 1.6)
	_damage_boss(u, amount, true, true)
	_knock_back(u, 2.0)


# ---------------------------------------------------------------- Soulburner

## Lança Serafim: quase nada sem a marca. Com ela, o dano cresce conforme a marca envelhece
## (médio no começo, alto perto do fim) e a marca é consumida.
func lance_damage() -> float:
	var mark := get_dot("zenite")
	if mark.is_empty():
		return LANCE_BARE
	var aged := clampf(1.0 - mark["t"] / mark["total"], 0.0, 1.0)
	return lerpf(LANCE_MIN, LANCE_MAX, aged)


func _lance(u: Unit) -> void:
	var amount := lance_damage()
	var marked := not get_dot("zenite").is_empty()
	remove_dot("zenite")
	var m := Fx.mat(Color(1.0, 0.8, 0.35, 0.95), 4.0, true)
	var spear := Fx.inst(fx_root, Fx.cyl(0.02, 0.45, 9.0), m, Vector3(0, 16, -12.5))
	var tw := spear.create_tween()
	tw.tween_property(spear, "position:y", 4.5, 0.16)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(spear.queue_free)
	_burst(Vector3(0, 3, -11.5), FIRE if marked else Color(0.6, 0.6, 0.6), 5.0 if marked else 1.6)
	_damage_boss(u, amount, true, amount > 60.0)


## Rasante Incandescente: dash rápido (na direção que está andando, ou pra trás) com explosão no ponto de partida.
func _swoop(u: Unit) -> void:
	var d := _input_dir() if u.controlled else Vector3.ZERO
	if d == Vector3.ZERO:
		d = (u.position - BOSS_POINT).normalized()
		d.y = 0.0
	var from := u.position
	var to := from + d.normalized() * SWOOP_DIST
	var flat := Vector2(to.x, to.z)
	if flat.length() > ARENA_R:
		flat = flat.normalized() * ARENA_R
		to = Vector3(flat.x, 0, flat.y)
	u.dash_fx()
	u.invuln = maxf(u.invuln, 0.35)
	_beam(from, to, FIRE, 0.5)
	_burst(from, FIRE, 3.2)
	u.create_tween().tween_property(u, "position", to, 0.12)
	_damage_boss(u, SWOOP_DMG, true, false)


## Juízo Solar: um sol enorme explode na boss. Marcada, leva mais e fica queimando (a marca não é gasta).
func _solar(u: Unit) -> void:
	var marked := not get_dot("zenite").is_empty()
	var m := Fx.mat(Color(1.0, 0.85, 0.35, 0.9), 5.0, true)
	var sun := Fx.inst(fx_root, Fx.sphere(1.0), m, Vector3(0, 9, -12.0))
	sun.scale = Vector3.ONE * 0.4
	var tw := sun.create_tween()
	tw.tween_property(sun, "scale", Vector3.ONE * 4.5, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(sun.queue_free)
	hud.flash(Color(1.0, 0.85, 0.35, 0.4))
	hud.toast("JUÍZO SOLAR", 1.6)
	_damage_boss(u, SOLAR_MARKED if marked else SOLAR_DMG, true, true)
	if marked:
		add_dot("solar", "Queimadura Solar", Color(1.0, 0.75, 0.2), SOLAR_DOT_TIME, SOLAR_DOT, u)


# ---------------------------------------------------------------- Ringstar

## Qual slot da Ringstar está fortalecido agora (-1 = nenhum). É o que faz o botão brilhar na barra.
func glow_slot(u: Unit) -> int:
	if u.key == "ringstar" and u.chain > 0:
		return u.chain
	if u.key == "maga" and u.pierce_next:
		return 0
	if u.key == "sleepwalker":
		if u.asleep:
			return u.dream_step  # como combo de FFXIV: a próxima da ordem brilha
		if u.window_t > 0.0:
			return u.window_slot
	return -1


## Aplica a sequência no golpe do slot (0 Jab, 1 Direto, 2 Gancho) e devolve o dano que ele dá.
func _combo_hit(u: Unit, slot: int, full: float) -> float:
	var amount := full
	if slot == 0:
		u.chain = 1  # Jab sempre (re)começa a sequência
	elif slot == u.chain:
		u.chain = 2 if slot == 1 else 0  # fortalecido: dano cheio e passa a vez
		if slot == 2:
			_burst(BOSS_POINT + Vector3(0, 1.6, 1.8), STAR, 3.4)
	else:
		amount = WEAK_HIT  # fora de ordem: dano mínimo e a sequência se perde
		u.chain = 0
	if u.count_t > 0.0:
		amount *= COUNT_DMG
	return amount


## Contagem Regressiva: avança até a boss e abre uma arena de luz em volta dela mesma.
func _countdown(u: Unit) -> void:
	var to_boss := BOSS_POINT - u.position
	to_boss.y = 0.0
	var go := maxf(0.0, to_boss.length() - (MELEE_RANGE - 1.0))
	u.face(to_boss)
	if go > 0.1:
		u.dash_fx()
		u.create_tween().tween_property(u, "position", u.position + to_boss.normalized() * go, 0.12)
	u.count_t = COUNT_TIME
	for n in 3:
		u.skill_cd[n] = minf(u.skill_cd[n], COUNT_GCD)
	_burst(u.position, STAR, 4.0)
	hud.toast("CONTAGEM REGRESSIVA", 1.2)


# ---------------------------------------------------------------- Apotecário

## Lista de habilidades que vale pro herói agora (o Sleepwalker tem uma lista por modo).
func kit(u: Unit) -> Array:
	return SKILLS_ASLEEP if (u.key == "sleepwalker" and u.asleep) else SKILLS[u.key]


## Necropsia: dano alto + Decomposição. Renovar com VESTIGE_WINDOW ou menos sobrando dá 1 Vestígio.
func _necropsy(u: Unit) -> void:
	if not _in_range(u):
		u.set_action("Longe demais", 2)
		u.skill_cd[1] = 0.0
		return
	var old := get_dot("decomp")
	if not old.is_empty() and old["t"] <= VESTIGE_WINDOW and u.vestiges < VESTIGE_MAX:
		u.vestiges += 1
		_burst(u.position + Vector3(0, 2.2, 0), CHEM, 1.2)
		if u.controlled:
			hud.toast("VESTÍGIO %d/%d" % [u.vestiges, VESTIGE_MAX], 0.9)
	u.face(BOSS_POINT - u.position)
	u.punch()
	_attack_fx(u, true)
	_damage_boss(u, SKILLS["apothecary"][1]["dmg"], true, true)
	add_dot("decomp", "Decomposição", Color(0.6, 0.75, 0.3), DECOMP_TIME, DECOMP_DPS, u)
	u.skill_cd[0] = minf(u.skill_cd[0], 1.0)  # a Incisão volta ao ritmo normal


## Solução Hemostática: escudo num aliado, ou Contaminação na boss (cast_target null).
func _hemostatic(u: Unit) -> void:
	var ally: Unit = u.cast_target
	if ally == null:
		if u.vestiges >= VESTIGE_MAX and not get_dot("decomp").is_empty():
			add_dot("contam", "Contaminação", Color(0.75, 0.3, 0.9), CONTAM_TIME, 0.0, u)
			_beam(u.position, Vector3(0, 3.0, -11.5), Color(0.75, 0.3, 0.9, 0.95), 0.4)
			hud.toast("CONTAMINAÇÃO", 1.2)
			return
		ally = u
	if not ally.alive:
		ally = u
	ally.shield_hp = maxf(ally.shield_hp, ally.max_hp * HEMO_RATIO)
	ally.shield_t = HEMO_TIME
	u.enmity += ally.shield_hp * HEAL_ENMITY * 0.5
	_beam(u.position, ally.position, Color(CHEM.r, CHEM.g, CHEM.b, 0.95), 0.3)
	_burst(ally.position, CHEM, 2.0)


## Tanatopraxia: nuvem tóxica se a boss está com Contaminação; senão, nuvem que cura a party.
func _thanato(u: Unit) -> void:
	if not get_dot("contam").is_empty():
		remove_dot("contam")
		u.vestiges = 0
		_burst(Vector3(0, 3, -11.5), Color(0.6, 0.85, 0.2), 7.0)
		hud.flash(Color(0.6, 0.85, 0.2, 0.3))
		hud.toast("NUVEM TÓXICA", 1.6)
		_damage_boss(u, TOXIC_DMG, true, true)
		add_dot("toxica", "Nuvem Tóxica", Color(0.6, 0.85, 0.2), TOXIC_TIME, TOXIC_DPS, u)
		return
	var boost := 1.0
	if u.vestiges >= VESTIGE_MAX:
		u.vestiges = 0
		boost = CLOUD_BOOST
	_burst(u.position, CHEM, 7.0)
	hud.toast("NUVEM CONSERVANTE" + (" +" if boost > 1.0 else ""), 1.4)
	for o in units:
		if not o.alive:
			continue
		var each := CLOUD_HEAL * boost
		o.hp = minf(o.max_hp, o.hp + each)
		o.mend_t = CLOUD_TIME
		o.mend_rate = CLOUD_REGEN * boost
		u.enmity += each * HEAL_ENMITY * 0.5
		_burst(o.position, CHEM, 1.6)
		_popup(int(each), Color(0.5, 1.0, 0.85), 52, o.position + Vector3(0, 2.6, 0), "+")


# ---------------------------------------------------------------- Sleepwalker

## Recarga de uma habilidade do Sleepwalker, já com o -1 s do Perto do Sonho.
func _sw_cd(u: Unit, base: float) -> float:
	return maxf(0.3, base - (1.0 if u.near_t > 0.0 else 0.0))


func _dream_add(n: int) -> void:
	if n <= 0:
		return
	dream_stacks = mini(DREAM_MAX, dream_stacks + n)
	dream_t = DREAM_TIME


func _sw_hit(u: Unit, base: float, big: bool) -> void:
	u.face(BOSS_POINT - u.position)
	_attack_fx(u, big)
	_damage_boss(u, base * SW_SCALE, true, big)


## Todas as habilidades do Sleepwalker passam por aqui (acordado e dormindo).
func _sleep_skill(u: Unit, slot: int) -> void:
	if slot == 5:
		_sw_toggle(u)
		return
	if u.asleep:
		_sw_dream(u, slot)
		return
	var def: Dictionary = SW_AWAKE[slot]
	u.skill_cd[slot] = _sw_cd(u, SKILLS["sleepwalker"][slot]["cd"])
	if not _in_range(u):
		u.set_action("Longe demais", 2)
		u.skill_cd[slot] = 0.0
		return
	var amount: float = def["base"]
	var gain: float = def["torpor"]
	if slot == 0:
		# Bocejo: acerta a Fresta que estiver aberta
		for e in echoes:
			if e["open"] > 0.0 and not e["hit"]:
				e["hit"] = true
				amount += ECHO_BASE
				_burst(Vector3(0, 3.5, -11.5), Color(1, 1, 1), 3.4)
				if u.controlled:
					hud.toast("FRESTA!", 0.6)
				break
		u.torpor = minf(100.0, u.torpor + gain)
		_sw_hit(u, amount, amount > 60.0)
		return
	# sequência Lençol (1) -> Visitantes (2) -> Travesseiro (3) -> Cama (4): cada uma abre 1 s pra próxima
	var perfect: bool = slot == 1 or (u.window_slot == slot and u.window_t > 0.0)
	var stacks: int = def["stacks"] if perfect else def["weak"]
	if slot > 1 and perfect:
		gain += SW_PERFECT_TORPOR
	match slot:
		2:
			u.crumbs = perfect
		3:
			perfect = perfect and u.crumbs
			stacks = def["stacks"] if perfect else def["weak"]
			u.pillow_full = perfect
			u.crumbs = false
		4:
			perfect = perfect and u.pillow_full
			stacks = def["stacks"] if perfect else def["weak"]
			if perfect:
				amount *= SW_BED_BONUS
				_start_echoes()
			u.pillow_full = false
	if slot > 1 and not perfect:
		gain = def["torpor"]
		if u.controlled:
			hud.toast("JANELA PERDIDA", 0.8)
	elif slot > 1 and u.controlled:
		hud.toast("PERFEITO", 0.5)
	_dream_add(stacks)
	u.torpor = minf(100.0, u.torpor + gain)
	# abre a janela da próxima (a Cama é a última)
	u.window_slot = slot + 1 if slot < 4 else -1
	u.window_t = SW_WINDOW if slot < 4 else 0.0
	_sw_hit(u, amount, true)


## Sono Profundo / Acordar.
func _sw_toggle(u: Unit) -> void:
	u.skill_cd[5] = 3.0
	if u.asleep:
		_sw_wake(u, true)
		return
	u.asleep = true
	u.dream_step = 0
	u.window_slot = -1
	u.window_t = 0.0
	# as recargas do Modo Acordado ficam guardadas (e continuam correndo em _tick_sleep);
	# as do sonho começam prontas, menos a Mordida, que tem recarga própria
	for n in 5:
		u.awake_cd[n] = u.skill_cd[n]
		u.skill_cd[n] = 0.0
	u.skill_cd[0] = u.bite_cd
	_burst(u.position, DREAM, 3.0)
	if u.controlled:
		hud.toast("DORMINDO", 0.9)


## Acorda. `lose`: perde o Torpor que sobrou (acordou no meio, ou faltou Torpor).
func _sw_wake(u: Unit, lose: bool) -> void:
	u.bite_cd = u.skill_cd[0]
	u.asleep = false
	u.dream_step = 0
	u.wake_t = 0.0
	if lose:
		u.torpor = 0.0
	for n in 5:
		u.skill_cd[n] = u.awake_cd[n]
	_burst(u.position, Color(1, 1, 1), 2.0)


## Uma habilidade da sequência do Modo Dormindo. Fora de ordem não sai.
func _sw_dream(u: Unit, slot: int) -> void:
	var sk: Dictionary = SKILLS_ASLEEP[slot]
	if slot != u.dream_step or u.wake_t > 0.0:
		u.set_action("Fora de ordem", 2)
		return
	var cost: float = sk["cost"]
	var amount: float = sk["base"]
	if slot == 0:
		# A Mordida dos Mil: mantém o Pesadelo Persistente. Sem Torpor pra pagar, sai de graça e fraca.
		if u.torpor < cost:
			cost = 0.0
			amount *= 0.2
		var old := get_dot("pesadelo")
		var perfect: bool = not old.is_empty() and old["t"] <= NEAR_WINDOW
		add_dot("pesadelo", "Pesadelo Persistente", DREAM, NIGHTMARE_TIME, NIGHTMARE_DPS, u)
		u.near_t = NEAR_PERFECT if perfect else NEAR_OTHER
		if u.controlled:
			hud.toast("PERTO DO SONHO %d s" % int(u.near_t), 0.9)
		u.skill_cd[0] = _sw_cd(u, sk["cd"])
	elif u.torpor < cost:
		return
	u.torpor -= cost
	_sw_hit(u, amount, slot >= 3)
	if slot == 4:
		# A Casa que Engole: fecha a sequência, protege a party e acorda sozinho
		hud.flash(Color(DREAM.r, DREAM.g, DREAM.b, 0.4))
		hud.toast("A CASA QUE ENGOLE", 1.4)
		for o in units:
			if o.alive:
				o.shield_hp = maxf(o.shield_hp, o.max_hp * HOUSE_SHIELD)
				o.shield_t = maxf(o.shield_t, HOUSE_SHIELD_TIME)
		_sw_wake(u, false)
		return
	u.dream_step = slot + 1
	for n in range(1, 5):
		u.skill_cd[n] = 0.6
	if u.torpor < float(SKILLS_ASLEEP[u.dream_step]["cost"]):
		# não dá pra pagar a próxima: acorda sozinho daqui a 1 s e perde o que sobrou
		u.wake_t = 1.0
		if u.controlled:
			hud.toast("SEM TORPOR NECESSÁRIO, ACORDANDO", 1.0)


## Ecos do Pesadelo: quatro Frestas abrem na boss depois de A Cama Caiu! perfeita.
func _start_echoes() -> void:
	echoes.clear()
	for at in ECHO_AT:
		echoes.append({"wait": at, "open": 0.0, "hit": false, "warned": false})


func _tick_echoes(delta: float) -> void:
	if echoes.is_empty():
		echo_mark.visible = false
		return
	var showing := false
	for e in echoes.duplicate():
		if e["wait"] > 0.0:
			e["wait"] -= delta
			if e["wait"] <= 0.45 and not e["warned"]:
				# aviso: algo vai abrir (som de invocação)
				e["warned"] = true
				_sfx(_tone(520.0, 0.18, false), -8.0)
			if e["wait"] <= 0.0:
				e["open"] = ECHO_OPEN
				_sfx(_tone(160.0, 0.12, true), -2.0)  # o "PA!": é agora
			continue
		e["open"] -= delta
		if e["open"] > 0.0 and not e["hit"]:
			showing = true
		if e["open"] <= 0.0:
			echoes.erase(e)
	echo_mark.visible = showing
	if showing:
		echo_mark.scale = Vector3.ONE * (1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.04))


## Som curto gerado na hora (o projeto não tem áudio pra isso): tom que some, ou um estalo.
func _tone(freq: float, dur: float, snap: bool) -> AudioStreamWAV:
	var key := "%d_%d_%s" % [int(freq), int(dur * 1000.0), snap]
	if _tones.has(key):
		return _tones[key]
	var rate := 22050
	var count := int(rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var env := pow(1.0 - float(i) / count, 3.0 if snap else 1.5)
		var v := sin(TAU * freq * t * (1.0 if snap else 1.0 + t * 2.0))
		if snap:
			v = v * 0.6 + randf_range(-1.0, 1.0) * 0.4
		data.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_tones[key] = wav
	return wav


## Sleepwalker, a cada frame: Torpor, janelas, buffs e o despertar por falta de Torpor.
func _tick_sleep(u: Unit, delta: float) -> void:
	if not u.asleep:
		u.torpor = maxf(0.0, u.torpor - SW_DECAY * delta)
	else:
		for n in 5:
			u.awake_cd[n] = maxf(0.0, u.awake_cd[n] - delta)
	if u.window_t > 0.0:
		u.window_t -= delta
		if u.window_t <= 0.0:
			u.window_slot = -1
	u.near_t = maxf(0.0, u.near_t - delta)
	if get_dot("pesadelo").is_empty():
		u.near_t = 0.0  # o DoT caiu: o buff vai junto
	if not u.asleep:
		u.bite_cd = maxf(0.0, u.bite_cd - delta)
	if u.wake_t > 0.0:
		u.wake_t -= delta
		if u.wake_t <= 0.0:
			_sw_wake(u, true)


# ---------------------------------------------------------------- Soulflame

## Lareira Celestial: fogueira espiritual no chão, onde a Soulflame está. Cura quem fica dentro.
func _start_hearth(u: Unit) -> void:
	var node := Node3D.new()
	fx_root.add_child(node)
	node.position = Vector3(u.position.x, 0.05, u.position.z)
	Fx.inst(node, Fx.disc(HEARTH_R), Fx.mat(Color(FLAME.r, FLAME.g, FLAME.b, 0.14), 0.0, true))
	Fx.inst(node, Fx.torus(HEARTH_R - 0.1, HEARTH_R), Fx.mat(FLAME, 3.0, true))
	# a chama: três línguas de fogo azul-esverdeado
	for n in 3:
		var tongue := Fx.inst(node, Fx.cyl(0.02, 0.34 - n * 0.08, 1.5 - n * 0.3), Fx.mat(FLAME.lightened(n * 0.25), 4.0, true), Vector3((n - 1) * 0.22, 0.75 - n * 0.1, 0))
		tongue.set_meta("flame", n)
	hearths.append({"node": node, "owner": u, "t": HEARTH_TIME, "tick": 0.0})
	_burst(u.position, FLAME, HEARTH_R)


func _tick_hearths(delta: float) -> void:
	for h in hearths.duplicate():
		h["t"] -= delta
		h["tick"] -= delta
		var node: Node3D = h["node"]
		for c in node.get_children():
			if c.has_meta("flame"):
				c.scale.y = 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.012 + int(c.get_meta("flame")) * 2.0)
		if h["tick"] <= 0.0:
			h["tick"] = 1.0
			var owner: Unit = h["owner"]
			for o in units:
				if o.alive and o.position.distance_to(node.position) <= HEARTH_R:
					# fagulhas subindo em volta de quem está na fogueira
					_burst(o.position + Vector3(0, 0.6, 0), FLAME, 1.1)
					if o.hp < o.max_hp:
						o.hp = minf(o.max_hp, o.hp + HEARTH_HPS)
						owner.enmity += HEARTH_HPS * HEAL_ENMITY
						_popup(int(HEARTH_HPS), Color(0.5, 1.0, 0.85), 40, o.position + Vector3(0, 2.6, 0), "+")
		if h["t"] <= 0.0:
			node.queue_free()
			hearths.erase(h)


## Renascimento: uma fênix enorme atravessa o campo. Cura todos, levanta quem caiu, queima a boss
## e deixa um DoT leve nela. Se houver uma Lareira acesa, é dela que a fênix nasce.
func _rebirth(u: Unit) -> void:
	var from := u.position
	if not hearths.is_empty():
		var h: Dictionary = hearths[hearths.size() - 1]
		from = h["node"].position
		h["node"].queue_free()
		hearths.erase(h)
	var bird := Node3D.new()
	fx_root.add_child(bird)
	bird.position = from + Vector3(0, 1.5, 0)
	var fire := Fx.mat(Color(1.0, 0.55, 0.15, 0.9), 4.0, true)
	Fx.inst(bird, Fx.sphere(0.9), fire)
	for side in [-1, 1]:
		var wing := BoxMesh.new()
		wing.size = Vector3(3.6, 0.16, 1.5)
		var w := Fx.inst(bird, wing, Fx.mat(Color(FLAME.r, FLAME.g, FLAME.b, 0.85), 4.0, true), Vector3(side * 2.0, 0.3, 0.2))
		w.rotation.z = side * 0.35
	var tw := bird.create_tween()
	tw.tween_property(bird, "position", Vector3(0, 3.0, 0), 0.35)
	tw.tween_property(bird, "position", Vector3(0, 5.0, -11.5), 0.4)
	tw.tween_callback(bird.queue_free)
	hud.flash(Color(1.0, 0.6, 0.2, 0.3))
	hud.toast("RENASCIMENTO", 1.6)
	for o in units:
		if not o.alive:
			o.revive(0.5)
			o.weak_t = WEAK_TIME
			_spawn_cards(o)
			_burst(o.position, Color(1.0, 0.95, 0.6), 3.0)
			hud.toast(o.unit_name + " voltou", 2.0)
		else:
			o.hp = minf(o.max_hp, o.hp + REBIRTH_HEAL)
			_burst(o.position, FLAME, 1.8)
			_popup(int(REBIRTH_HEAL), Color(0.5, 1.0, 0.85), 56, o.position + Vector3(0, 2.6, 0), "+")
		u.enmity += REBIRTH_HEAL * HEAL_ENMITY * 0.5
	_damage_boss(u, REBIRTH_DMG, true, true)
	add_dot("brasa", "Brasa da Fênix", Color(1.0, 0.55, 0.15), REBIRTH_DOT_TIME, REBIRTH_DOT, u)


# ---------------------------------------------------------------- DoTs na boss

## Põe (ou renova) um efeito de dano por segundo na boss. Aparece embaixo da vida dela, com o tempo.
func add_dot(id: String, dot_name: String, col: Color, time: float, dps: float, owner: Unit) -> void:
	for d in boss_dots:
		if d["id"] == id:
			d["t"] = time
			d["total"] = time
			d["dps"] = dps
			d["owner"] = owner
			return
	boss_dots.append({"id": id, "name": dot_name, "col": col, "t": time, "total": time, "dps": dps, "owner": owner, "acc": 0.0})


## O DoT com esse id, ou {} se a boss não está com ele.
func get_dot(id: String) -> Dictionary:
	for d in boss_dots:
		if d["id"] == id:
			return d
	return {}


func remove_dot(id: String) -> void:
	for d in boss_dots.duplicate():
		if d["id"] == id:
			boss_dots.erase(d)


func _tick_dots(delta: float) -> void:
	for d in boss_dots.duplicate():
		d["t"] -= delta
		d["acc"] += delta
		if d["acc"] >= 1.0 and d["dps"] > 0.0:
			d["acc"] -= 1.0
			_damage_boss(d["owner"], d["dps"], false, false)
			_popup(int(d["dps"]), (d["col"] as Color).lightened(0.2), 30)
			if ended:
				return
		if d["t"] <= 0.0:
			boss_dots.erase(d)


## Malpractice paga os próprios golpes com vida. Não é golpe da boss: não conta como parry nem
## passa por mitigação ou escudo. Pode matar.
func _bleed(u: Unit, cost: float) -> void:
	if not u.alive or u.party_t > 0.0 or u.immortal_t > 0.0:
		return
	u.hp -= cost
	_popup(int(cost), BLOOD, 40, u.position + Vector3(0, 2.2, 0), "-")
	if u.hp <= 0.0:
		kill(u, "sangrou até morrer com os próprios golpes")


## Multiplicador de dano da Malpractice: cresce conforme a vida cai (1.0 com a vida cheia).
func low_hp_mult(u: Unit) -> float:
	if u.key != "nurse":
		return 1.0
	var ratio := clampf(u.hp / u.base_hp, 0.0, 1.0)
	return 1.0 + LOW_HP_BONUS * clampf((1.0 - ratio) / (1.0 - LOW_HP_FLOOR), 0.0, 1.0)


## Solo Consagrado: área sagrada no chão, onde o Paladino está. Bate na boss enquanto ela
## estiver ao alcance da área.
func _start_holy(u: Unit) -> void:
	var node := Node3D.new()
	fx_root.add_child(node)
	node.position = Vector3(u.position.x, 0.05, u.position.z)
	Fx.inst(node, Fx.disc(HOLY_R), Fx.mat(Color(GOLD.r, GOLD.g, GOLD.b, 0.16), 0.0, true))
	Fx.inst(node, Fx.torus(HOLY_R - 0.12, HOLY_R), Fx.mat(GOLD, 3.0, true))
	Fx.inst(node, Fx.torus(HOLY_R * 0.5 - 0.06, HOLY_R * 0.5), Fx.mat(GOLD, 2.0, true), Vector3(0, 0.01, 0))
	holy.append({"node": node, "owner": u, "t": HOLY_TIME, "tick": 0.0})
	_burst(u.position, GOLD, HOLY_R)


func _tick_holy(delta: float) -> void:
	for h in holy.duplicate():
		h["t"] -= delta
		h["tick"] -= delta
		var node: Node3D = h["node"]
		node.rotate_y(delta * 0.6)
		if h["tick"] <= 0.0:
			h["tick"] = HOLY_TICK
			var owner: Unit = h["owner"]
			if owner.alive and node.position.distance_to(BOSS_POINT) <= HOLY_R + 1.4:
				_burst(BOSS_POINT + Vector3(0, 0.6, 1.6), GOLD, 1.8)
				_damage_boss(owner, HOLY_DMG, true, false)
		if h["t"] <= 0.0:
			node.queue_free()
			holy.erase(h)


## Muralha da Fé: uma cruz dourada gigante sobre o grupo por WALL_SHOW segundos, com um facho
## de luz descendo em cada herói.
func _faith_cross() -> void:
	var center := Vector3.ZERO
	var n := 0
	for o in units:
		if o.alive:
			center += o.position
			n += 1
	center = center / maxf(1.0, n) + Vector3(0, 7.0, 0)
	var node := Node3D.new()
	fx_root.add_child(node)
	node.position = center
	var m := Fx.mat(Color(GOLD.r, GOLD.g, GOLD.b, 0.85), 4.0, true)
	var up := BoxMesh.new()
	up.size = Vector3(1.1, 7.0, 0.5)
	Fx.inst(node, up, m)
	var arm := BoxMesh.new()
	arm.size = Vector3(4.4, 1.1, 0.5)
	Fx.inst(node, arm, m, Vector3(0, 1.2, 0))
	var soft := Fx.mat(Color(GOLD.r, GOLD.g, GOLD.b, 0.28), 2.0, true)
	for o in units:
		if o.alive:
			Fx.inst(node, Fx.cyl(0.9, 1.2, 7.0), soft, o.position - center + Vector3(0, 3.5, 0))
	node.scale = Vector3.ONE * 0.2
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(WALL_SHOW - 0.75)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.parallel().tween_property(soft, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(node.queue_free)


## Provocar: quem usa pula pro topo da lista de enmity na hora, com folga.
func _provoke(u: Unit, by_ai: bool) -> void:
	var top := 0.0
	for o in units:
		if o != u and o.alive:
			top = maxf(top, o.enmity)
	# recuperou o aggro na mão: a party aprende a carta que faz isso sozinha
	if not by_ai and u.tank and target != null and target != u:
		_master("provoke")
	u.enmity = maxf(u.enmity, top) + PROVOKE_BONUS
	_burst(u.position, Color(1.0, 0.35, 0.6), 3.2)
	_beam(u.position, Vector3(0, 5.0, -11.5), Color(1.0, 0.35, 0.6, 0.95), 0.45)
	boss.rage()
	hud.show_biscoito()
	hud.toast("BORA BISCOITAR", 1.6)


func _add_stacks(u: Unit, n: int) -> void:
	u.stacks = mini(PARTY_NEED, u.stacks + n)


func _lifesteal(u: Unit, amount: float) -> void:
	if not u.alive or u.party_t > 0.0:
		return
	u.hp = minf(u.max_hp, u.hp + amount)
	if amount >= 1.0:
		_popup(int(amount), BLOOD.lightened(0.35), 48, u.position + Vector3(0, 2.6, 0), "+")


## Fim do Blood Taste: a vida volta ao que era antes. Se um golpe acertou durante a janela (parry
## perfeito), ela guarda metade do que ganhou e a recarga cai pra 10 s.
func _end_taste(u: Unit) -> void:
	var gained := u.base_hp * TASTE_HP - u.taste_prev
	u.taste_t = 0.0
	u.max_hp = u.base_hp
	if not u.alive:
		return
	if u.taste_hit:
		var keep := gained * TASTE_KEEP
		u.hp = minf(u.max_hp, u.taste_prev + keep)
		u.skill_cd[1] = minf(u.skill_cd[1], TASTE_CD_PARRY - TASTE_TIME)
		_burst(u.position, Color(1.0, 0.95, 0.9), 3.0)
		_popup(int(u.hp - u.taste_prev), BLOOD.lightened(0.35), 60, u.position + Vector3(0, 2.6, 0), "+")
		if u.controlled:
			hud.flash(Color(1.0, 1.0, 1.0, 0.25))
	else:
		u.hp = u.taste_prev


## Blood Taste e Blood Party correndo, por herói, a cada frame.
func _tick_blood(u: Unit, delta: float) -> void:
	if u.taste_t > 0.0:
		u.taste_t -= delta
		if u.taste_t <= 0.0:
			_end_taste(u)
	if u.party_t > 0.0:
		u.party_t -= delta
		u.party_tick -= delta
		if u.party_tick <= 0.0:
			u.party_tick = PARTY_TICK
			_burst(u.position, BLOOD, 4.4)
			if u.position.distance_to(BOSS_POINT) <= PARTY_R:
				_damage_boss(u, PARTY_DMG, true, false)
		if u.party_t <= 0.0:
			# acabou: ela fica com 1 de vida e precisa se recuperar
			u.party_t = 0.0
			u.hp = 1.0
			_burst(u.position, BLOOD.darkened(0.4), 2.0)


# ---------------------------------------------------------------- Limit Break

## Só o jogador usa, e só com a barra cheia. O efeito depende de quem você está controlando.
func use_lb() -> void:
	var u := units[ctrl]
	if lb < 1.0 or not u.alive or u.channel_t > 0.0 or prep or ended or intro_left > 0.0:
		return
	u.channel_t = LB_CAST
	u.channel_total = LB_CAST
	u.channel_slot = -1
	u.cast_ai = false
	u.face(BOSS_POINT - u.position)
	_burst(u.position, u.color, 3.0)


func _resolve_lb(u: Unit) -> void:
	lb = 0.0
	hud.flash(Color(u.color.r, u.color.g, u.color.b, 0.6))
	hud.limit_cut(u)
	_burst(u.position, u.color.lightened(0.4), 7.0)
	match u.key:
		"tank", "nurse":
			for o in units:
				if o.alive:
					o.immortal_t = LB_IMMORTAL
					_burst(o.position, Color(1.0, 0.9, 0.5), 2.2)
		"healer", "apothecary":
			for o in units:
				if not o.alive:
					o.revive(0.6)  # sem Fraqueza: é a vantagem sobre o Reviver comum
					_spawn_cards(o)
					_beam(u.position, o.position, Color(1.0, 0.95, 0.6, 0.95), 0.6)
					_burst(o.position, Color(1.0, 0.95, 0.6), 3.0)
		_:
			var dmg := boss_max * LB_DPS_CUT
			boss_hp -= dmg
			u.dmg_total += dmg
			u.dmg_bucket += dmg
			boss.hit_flash()
			_beam(u.position, Vector3(0, 5.0, -11.5), Color(1.0, 1.0, 1.0, 0.98), 0.6)
			_burst(Vector3(0, 5, -11.5), u.color.lightened(0.4), 10.0)
			_popup(int(dmg), Color(1.0, 0.95, 0.5), 110)
			if boss_hp <= 0.0:
				boss_hp = 0.0
				_end(true)


## Feixe entre dois personagens (cura, reviver): mostra de quem pra quem.
func _beam(from: Vector3, to: Vector3, col: Color, time: float) -> void:
	var a := from + Vector3(0, 1.0, 0)
	var b := to + Vector3(0, 1.0, 0)
	var length := a.distance_to(b)
	if length < 0.2:
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.22, length)
	var m := Fx.mat(Color(col.r, col.g, col.b, minf(col.a, 0.98)), 2.0, true)
	var mi := Fx.inst(fx_root, box, m, (a + b) * 0.5)
	mi.look_at(b, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


# ---------------------------------------------------------------- ataques de desvio

## Um perigo no chão: aviso (telegraph) por h.total segundos e depois o golpe.
## shape: circle (pos, r) · rect (pos, dir, half_l, half_w) · donut (seguro só dentro de r, no centro)
func _add_hazard(h: Dictionary) -> void:
	h["total"] = h["total"] / haste
	h["t"] = h["total"]
	if h["shape"] == "void":
		# aviso do desabamento: perigo em tudo que não é quadrado. O desenho é do chão (shader).
		h["node"] = Node3D.new()
		fx_root.add_child(h["node"])
		h["fill"] = h["node"]
		h["inside"] = []
		hazards.append(h)
		return
	var node := Node3D.new()
	fx_root.add_child(node)
	var soft := Fx.mat(Color(DANGER.r, DANGER.g, DANGER.b, 0.2), 0.0, true)
	var hard := Fx.mat(DANGER, 3.0, true)
	var fill_mat := Fx.mat(Color(DANGER.r, DANGER.g, DANGER.b, 0.5), 0.0, true)
	var fill: MeshInstance3D
	match h["shape"]:
		"circle":
			node.position = h["pos"] + Vector3(0, 0.03, 0)
			Fx.inst(node, Fx.disc(h["r"]), soft)
			Fx.inst(node, Fx.torus(h["r"] - 0.07, h["r"]), hard)
			fill = Fx.inst(node, Fx.disc(h["r"]), fill_mat, Vector3(0, 0.01, 0))
			fill.scale = Vector3(0.01, 1, 0.01)
		"rect":
			node.position = h["pos"] + Vector3(0, 0.03, 0)
			var dir: Vector3 = h["dir"]
			node.rotation.y = atan2(dir.x, dir.z)
			var box := BoxMesh.new()
			box.size = Vector3(h["half_w"] * 2.0, 0.02, h["half_l"] * 2.0)
			Fx.inst(node, box, soft)
			for s in [-1.0, 1.0]:
				var edge := BoxMesh.new()
				edge.size = Vector3(0.07, 0.03, h["half_l"] * 2.0)
				Fx.inst(node, edge, hard, Vector3(s * h["half_w"], 0, 0))
			# o preenchimento cresce do meio pras bordas: mesma leitura do círculo
			fill = Fx.inst(node, box, fill_mat, Vector3(0, 0.01, 0))
			fill.scale = Vector3(0.01, 1, 1)
		"donut":
			node.position = Vector3(0, 0.03, 0)
			var mid: float = (h["r"] + ARENA_R + 0.3) * 0.5
			var ring := Fx.inst(node, Fx.torus(h["r"], ARENA_R + 0.3), soft)
			ring.scale = Vector3(1, 0.02, 1)
			Fx.inst(node, Fx.torus(h["r"], h["r"] + 0.08), hard)
			fill = Fx.inst(node, Fx.torus(mid - 0.02, mid + 0.02), fill_mat, Vector3(0, 0.01, 0))
			fill.scale = Vector3(1, 0.02, 1)
			h["mid"] = mid
	h["node"] = node
	h["fill"] = fill
	# quem estava no perigo quando ele apareceu: é quem "resolve na mão" se sair a tempo
	var inside: Array = []
	for u in units:
		if u.alive and _hit_test(h, u.position, 0.0):
			inside.append(u.idx)
	h["inside"] = inside
	hazards.append(h)


func _hit_test(h: Dictionary, p: Vector3, margin: float) -> bool:
	match h["shape"]:
		"circle":
			return h["pos"].distance_to(p) < h["r"] + margin
		"rect":
			var d: Vector3 = p - h["pos"]
			var dir: Vector3 = h["dir"]
			var along := absf(d.dot(dir))
			var side := absf(d.dot(Vector3(dir.z, 0, -dir.x)))
			return along <= h["half_l"] + margin and side <= h["half_w"] + margin
		"donut":
			return Vector2(p.x, p.z).length() > h["r"] - margin
		"void":
			return not _in_square(p, -margin)
	return false


## Tem perigo em p? Com `known`, só conta os ataques pros quais a unidade tem carta.
func _danger_at(p: Vector3, u: Unit, known: bool, margin: float) -> bool:
	for h in hazards:
		# quem tem o Protocolo Final já sabe pra qual quadrado ir: não foge pro mais perto
		if h["shape"] == "void" and Knowledge.has(u.hero, "final"):
			continue
		if known and not Knowledge.has(u.hero, h["card"]):
			continue
		if not known and Knowledge.has(u.hero, h["card"]):
			continue
		if _hit_test(h, p, margin):
			return true
	return false


## Ponto seguro mais próximo, preferindo o lado do destino atual.
func _safe_point(u: Unit, goal, margin := 0.45):
	var best = null
	var best_cost := 1e9
	for ring in range(1, 14):
		var r := ring * 0.6
		for k in 16:
			var a := k * TAU / 16.0
			var p := u.position + Vector3(cos(a), 0, sin(a)) * r
			if Vector2(p.x, p.z).length() > ARENA_R - 0.2 or _danger_at(p, u, true, margin):
				continue
			var cost := r
			if goal != null:
				cost += p.distance_to(goal) * 0.15
			if cost < best_cost:
				best_cost = cost
				best = p
		if best != null:
			return best
	return null


func _tick_hazards(delta: float) -> void:
	for h in hazards.duplicate():
		h["t"] -= delta
		var f: float = clampf(1.0 - h["t"] / h["total"], 0.01, 1.0)
		match h["shape"]:
			"circle": h["fill"].scale = Vector3(f, 1, f)
			"rect": h["fill"].scale = Vector3(f, 1, 1)
			"donut":
				var half: float = (ARENA_R + 0.3 - h["r"]) * 0.5 * f
				var tm: TorusMesh = h["fill"].mesh
				tm.inner_radius = h["mid"] - half
				tm.outer_radius = h["mid"] + half
		if h["t"] > 0.0:
			continue
		hazards.erase(h)
		h["node"].queue_free()
		_hazard_boom(h)
		var player := units[ctrl]
		var player_hit := false
		for u in units:
			if h["dmg"] > 0.0 and u.alive and u.invuln <= 0.0 and _hit_test(h, u.position, 0.0):
				if u == player:
					player_hit = true
				hurt(u, h["dmg"], h["why"])
		# golpes de meia arena: passar ileso pelos dois, lendo a mão, conta pra maestria
		if h.has("cleave"):
			if player_hit:
				cleave_fail = true
			if h["cleave"] == "last" and not cleave_fail and player.alive:
				_master("final")
		# desviou na mão de um ataque que ia te pegar: a carta daquele desvio é sua
		if player.alive and not player_hit and h["inside"].has(player.idx):
			if player.key == "healer" or player.key == "maga":
				_master("cast")


func _hazard_boom(h: Dictionary) -> void:
	match h["shape"]:
		"circle": _burst(h["pos"], DANGER, h["r"])
		"rect":
			var dir: Vector3 = h["dir"]
			for k in range(-2, 3):
				_burst(h["pos"] + dir * (k * h["half_l"] * 0.4), DANGER, h["half_w"] + 0.4)
		"donut":
			for k in 10:
				var a := k * TAU / 10.0
				_burst(Vector3(cos(a), 0, sin(a)) * (h["r"] + 2.6), DANGER, 2.8)


# ---------------------------------------------------------------- círculos laranjas (juntar)

## O círculo dá um dano total fixo, dividido por igual entre quem está dentro.
## need 4: um círculo pra party toda. Menos gente dentro = fatia maior pra cada um.
## need 2: dois círculos, 2 em cada. Com mais de 2 (ou alguém nos dois), todo mundo dentro morre.
## O número de grupos de setas é o número de pessoas que o círculo pede.
func _start_stacks(total: float, need: int, exclude: Array = [], dmg := -1.0) -> void:
	stack_dmg = dmg if dmg > 0.0 else (STACK_TOTAL if need == 4 else PAIR_TOTAL)
	var pool: Array = []
	for u in _alive_shuffled():
		if not exclude.has(u):
			pool.append(u)
	if pool.is_empty():
		return
	stack_need = need
	stack_t = total
	stack_total = total
	var count := 1
	if need == 2 and pool.size() >= 4:
		count = 2
	var r := STACK_R if need == 4 else PAIR_R
	for c in count:
		var node := Node3D.new()
		fx_root.add_child(node)
		Fx.inst(node, Fx.disc(r), Fx.mat(Color(STACK_COL.r, STACK_COL.g, STACK_COL.b, 0.16), 0.0, true))
		Fx.inst(node, Fx.torus(r - 0.09, r), Fx.mat(STACK_COL, 3.0, true))
		var fill := Fx.inst(node, Fx.disc(r), Fx.mat(Color(STACK_COL.r, STACK_COL.g, STACK_COL.b, 0.3), 0.0, true), Vector3(0, 0.01, 0))
		var mats: Array = []
		var arrows: Array = []
		for j in 3:
			# sem emissão: com brilho, o fade das setas de trás não aparecia
			mats.append(Fx.mat(Color(1.0, 0.72, 0.2, 0.99), 0.0, true))
		for k in need:
			var arm := Node3D.new()
			arm.rotation.y = k * TAU / need + (PI / 4.0 if need == 4 else PI / 2.0)
			node.add_child(arm)
			var row: Array = []
			for j in 3:
				row.append(Fx.inst(arm, _arrow_mesh(), mats[j]))
			arrows.append(row)
		stacks.append({"target": pool[c], "r": r, "node": node, "fill": fill, "mats": mats, "arrows": arrows})
	_tick_stacks(0.0)


## Ponta de seta deitada no chão, com o bico em -Z (pro centro do círculo).
func _arrow_mesh() -> ImmediateMesh:
	var m := ImmediateMesh.new()
	var tip := Vector3(0, 0, -0.38)
	var left := Vector3(-0.52, 0, 0.3)
	var right := Vector3(0.52, 0, 0.3)
	var notch := Vector3(0, 0, 0.02)
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [tip, left, notch, tip, notch, right]:
		m.surface_add_vertex(v)
	m.surface_end()
	return m


func _tick_stacks(delta: float) -> void:
	if stacks.is_empty():
		return
	stack_t -= delta
	var elapsed := stack_total - stack_t
	var f: float = clampf(elapsed / stack_total, 0.01, 1.0)
	# as setas marcham pra dentro em loop; a opacidade depende só da distância, então o loop não "pula"
	var phase := fmod(elapsed * 1.5, 1.0)
	for st in stacks:
		var m: Unit = st["target"]
		st["node"].position = Vector3(m.position.x, 0.04, m.position.z)
		# com dois círculos, as setas ficam de lado em relação ao outro círculo:
		# assim nenhuma seta fica no meio dos dois parecendo apontar pro lado errado
		if stacks.size() == 2:
			var other: Unit = stacks[1]["target"] if st == stacks[0] else stacks[0]["target"]
			var to_other: Vector3 = other.position - m.position
			if to_other.length() > 0.1:
				st["node"].rotation.y = atan2(to_other.x, to_other.z)
		st["fill"].scale = Vector3(f, 1, f)
		for j in 3:
			var d := 0.5 + (j - phase) * 0.62
			var alpha := clampf(1.0 - (d - 0.5) / 1.3, 0.0, 1.0) * clampf((d + 0.12) / 0.3, 0.0, 1.0)
			st["mats"][j].albedo_color.a = alpha
			for row in st["arrows"]:
				row[j].position.z = st["r"] + 0.45 + d

	if stack_t > 0.0:
		return

	# resolve tudo de uma vez, antes de aplicar dano, pra um círculo não mudar a conta do outro
	var player := units[ctrl]
	var deaths := {}
	var hits: Array = []
	var player_ok := false
	var alive := 0
	for u in units:
		if u.alive:
			alive += 1
	for st in stacks:
		var m: Unit = st["target"]
		if not m.alive:
			continue
		var inside: Array = []
		for u in units:
			if u.alive and u.position.distance_to(m.position) <= st["r"]:
				inside.append(u)
		var fair := false
		if stack_need == 2 and inside.size() > 2:
			# dupla com gente demais (ou alguém nos dois círculos): sobrecarga, não divide
			for u in inside:
				deaths[u] = "gente demais no círculo de dupla"
		else:
			# divisão justa: o dano total é fixo, cada um dentro leva a sua parte
			var total := stack_dmg
			var share := total / maxf(1.0, inside.size())
			for u in inside:
				hits.append([u, share, "dividiu o círculo laranja com pouca gente"])
			fair = inside.size() == (alive if stack_need == 4 else 2)
			if fair and inside.has(player):
				player_ok = true
		_burst(m.position, Color(1.0, 0.9, 0.6) if fair else STACK_COL, st["r"] + 0.6)
		st["node"].queue_free()
	stacks.clear()
	for h in hits:
		if not deaths.has(h[0]):
			hurt(h[0], h[1], h[2])
	for u in deaths:
		kill(u, deaths[u])
	if player_ok and player.alive:
		_master("stack" if stack_need == 4 else "pair")
	for u in units:
		u.hold_pos = null


## Plano de dupla: cada não-marcado vai pro círculo que dá a menor caminhada total,
## os marcados se afastam um do outro, e quem sobra fica fora de todos.
func _pair_plan(u: Unit):
	var marked: Array = []
	for st in stacks:
		marked.append(st["target"])
	if _spread_on(u):
		return null  # marcado de roxo não entra em dupla
	if marked.has(u) and not spreads.is_empty():
		# com roxo junto, a dupla se forma num canto, longe dos círculos roxos
		return [CORNERS[u.idx], "→ Canto"]
	if marked.has(u):
		for o in marked:
			if o != u and o.alive and o.position.distance_to(u.position) < PAIR_R * 2.0 + 1.5:
				var away: Vector3 = u.position - o.position
				if away.length() < 0.05:
					away = Vector3(1, 0, 0).rotated(Vector3.UP, u.idx * 1.7)
				return [u.position + away.normalized() * 1.5, "Afastando"]
		return [u.position, "Esperando o par"]
	var free: Array = []
	for o in units:
		if o.alive and not marked.has(o) and not _spread_on(o):
			free.append(o)
	var mine = null
	if marked.size() == 2 and free.size() == 2:
		var straight: float = free[0].position.distance_to(marked[0].position) + free[1].position.distance_to(marked[1].position)
		var crossed: float = free[0].position.distance_to(marked[1].position) + free[1].position.distance_to(marked[0].position)
		var k := free.find(u)
		mine = marked[k] if straight <= crossed else marked[1 - k]
	else:
		var taken := {}
		for m in marked:
			var best = null
			for o in free:
				if not taken.has(o) and (best == null or o.position.distance_to(m.position) < best.position.distance_to(m.position)):
					best = o
			if best != null:
				taken[best] = m
		mine = taken.get(u)
	if mine != null:
		var side: Vector3 = u.position - mine.position
		side = side.normalized() * 0.8 if side.length() > 0.05 else Vector3(0.8, 0, 0)
		return [mine.position + side, "→ " + mine.unit_name]
	# sobrou: só garante que não está dentro de nenhum círculo
	for m in marked:
		if m.position.distance_to(u.position) < PAIR_R + 0.6:
			return [u.position + (u.position - m.position).normalized() * 1.5, "Afastando"]
	return [u.position, "Fora dos círculos"]


# ---------------------------------------------------------------- círculos roxos (espalhar)

func _spread_on(u: Unit) -> bool:
	for sp in spreads:
		if sp["target"] == u:
			return true
	return false


## n heróis ganham um círculo roxo enorme. Devolve quem foi marcado.
func _start_spreads(total: float, n: int) -> Array:
	var pool := _alive_shuffled()
	var picked: Array = []
	spread_t = total
	spread_total = total
	for c in mini(n, pool.size()):
		var node := Node3D.new()
		fx_root.add_child(node)
		Fx.inst(node, Fx.disc(SPREAD_R), Fx.mat(Color(SPREAD_COL.r, SPREAD_COL.g, SPREAD_COL.b, 0.05), 0.0, true))
		Fx.inst(node, Fx.torus(SPREAD_R - 0.12, SPREAD_R), Fx.mat(SPREAD_COL, 3.0, true))
		# marca no próprio herói: anel + setas marchando pra fora
		var mark := Fx.inst(node, Fx.torus(1.0, 1.12), Fx.mat(SPREAD_COL, 3.0, true), Vector3(0, 0.02, 0))
		var mats: Array = []
		var arrows: Array = []
		for j in 3:
			mats.append(Fx.mat(Color(SPREAD_COL.r, SPREAD_COL.g, SPREAD_COL.b, 0.99).lightened(0.25), 0.0, true))
		for k in 4:
			var arm := Node3D.new()
			arm.rotation.y = k * TAU / 4.0 + PI / 4.0
			node.add_child(arm)
			var row: Array = []
			for j in 3:
				var a := Fx.inst(arm, _arrow_mesh(), mats[j])
				a.rotation.y = PI  # bico pra fora
				row.append(a)
			arrows.append(row)
		spreads.append({"target": pool[c], "node": node, "mark": mark, "mats": mats, "arrows": arrows})
		picked.append(pool[c])
	_tick_spreads(0.0)
	return picked


func _tick_spreads(delta: float) -> void:
	if spreads.is_empty():
		return
	spread_t -= delta
	var elapsed := spread_total - spread_t
	var phase_k := fmod(elapsed * 1.5, 1.0)
	for sp in spreads:
		var m: Unit = sp["target"]
		sp["node"].position = Vector3(m.position.x, 0.05, m.position.z)
		sp["node"].visible = m.alive
		for j in 3:
			var d := (j + phase_k) * 0.62
			var alpha := clampf(d / 0.3, 0.0, 1.0) * clampf(1.0 - (d - 0.6) / 1.2, 0.0, 1.0)
			sp["mats"][j].albedo_color.a = alpha
			for row in sp["arrows"]:
				row[j].position.z = 1.4 + d
	if spread_t > 0.0:
		return

	var player := units[ctrl]
	var hits: Array = []
	var player_clean := player.alive
	for sp in spreads:
		var m: Unit = sp["target"]
		sp["node"].queue_free()
		if not m.alive:
			continue
		var clean := true
		for u in units:
			if u != m and u.alive and u.position.distance_to(m.position) <= SPREAD_R:
				hits.append([u, "ficou no círculo roxo de " + m.unit_name])
				clean = false
				if u == player:
					player_clean = false
		if m == player and not clean:
			player_clean = false
		_burst(m.position, SPREAD_COL if not clean else SPREAD_COL.lightened(0.4), 3.0)
	spreads.clear()
	for h in hits:
		hurt(h[0], SPREAD_DMG, h[1])
	if player_clean:
		_master("spread")
	if stacks.is_empty():
		for u in units:
			u.hold_pos = null


## Grade de faixas vermelhas: sobram quadrados seguros entre elas.
func _spawn_grid(total: float) -> void:
	for c in [-4.5, 0.0, 4.5]:
		for dir in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			var pos := Vector3(0, 0, c) if dir.x > 0.5 else Vector3(c, 0, 0)
			var half_l := sqrt(ARENA_R * ARENA_R - c * c)
			_add_hazard({"shape": "rect", "pos": pos, "dir": dir, "half_l": half_l, "half_w": 0.8,
				"total": total, "dmg": 26.0, "card": "dodge", "why": "ficou na grade"})


# ---------------------------------------------------------------- Esmagar (tank buster)

## Golpe pesado só no alvo 1. Não dá pra desviar: é a defesa da tank (Égide ou Blood Taste) que salva.
func _start_buster(total: float) -> void:
	var t := _aggro_target()
	if t == null:
		return
	var node := Node3D.new()
	fx_root.add_child(node)
	# anel que fecha em cima do alvo: diferente dos avisos de chão, esse te segue
	Fx.inst(node, Fx.torus(0.94, 1.06), Fx.mat(DANGER, 4.0, true))
	Fx.inst(node, Fx.torus(1.5, 1.56), Fx.mat(Color(DANGER.r, DANGER.g, DANGER.b, 0.5), 2.0, true))
	buster = {"target": t, "t": total, "total": total, "node": node}
	boss.six_seven = true


func _tick_buster(delta: float) -> void:
	if buster == null:
		return
	var t: Unit = buster["target"]
	buster["t"] -= delta
	var k: float = clampf(buster["t"] / buster["total"], 0.0, 1.0)
	var node: Node3D = buster["node"]
	node.position = Vector3(t.position.x, 0.06, t.position.z)
	node.scale = Vector3.ONE * (1.0 + k * 2.2)
	if buster["t"] > 0.0 and t.alive:
		return
	node.queue_free()
	buster = null
	boss.six_seven = false
	if not t.alive:
		return
	var mitigated := t.guard_t > 0.0 or t.taste_t > 0.0
	hud.flash(Color(1.0, 0.2, 0.35) * Color(1, 1, 1, 0.35))
	_burst(t.position, DANGER, 3.0)
	hurt(t, BUSTER_DMG, "tomou o Esmagar sem defesa" if not mitigated else "não aguentou o Esmagar")
	if mitigated and t.alive and t == units[ctrl]:
		_master("buster")


func _alive_shuffled() -> Array:
	var pool: Array = []
	for u in units:
		if u.alive:
			pool.append(u)
	pool.shuffle()
	return pool


func _spawn_circles(n: int) -> void:
	var pool := _alive_shuffled()
	for k in mini(n, pool.size()):
		var u: Unit = pool[k]
		_add_hazard({"shape": "circle", "pos": Vector3(u.position.x, 0, u.position.z), "r": CIRCLE_R,
			"total": 1.7, "dmg": 30.0, "card": "dodge", "why": "ficou no círculo"})


## Faixa que sai do boss e atravessa a arena passando por um alvo.
func _spawn_lines(n: int, half_w: float, total: float, dmg: float, why: String) -> void:
	var pool := _alive_shuffled()
	for k in mini(n, pool.size()):
		_line_at(pool[k], half_w, total + k * 0.25, dmg, why)


func _line_at(u: Unit, half_w: float, total: float, dmg: float, why: String) -> void:
	var from := Vector3(0, 0, -ARENA_R - 1.0)
	var dir := Vector3(u.position.x, 0, u.position.z) - from
	dir = dir.normalized()
	# a faixa cobre só o trecho que cruza a arena, sem sobrar pra fora do chão
	var b := from.dot(dir)
	var disc := b * b - (from.length_squared() - ARENA_R * ARENA_R)
	if disc <= 0.0:
		return
	var t1 := -b - sqrt(disc)
	var t2 := -b + sqrt(disc)
	_add_hazard({"shape": "rect", "pos": from + dir * ((t1 + t2) * 0.5), "dir": dir, "half_l": (t2 - t1) * 0.5, "half_w": half_w,
		"total": total, "dmg": dmg, "card": "dodge", "why": why})


# ---------------------------------------------------------------- grande final da MINI-CHAN

func _raidwide(ratio: float, why: String) -> void:
	hud.flash(Color(1.0, 0.2, 0.35) * Color(1, 1, 1, 0.5))
	_burst(Vector3(0, 0.2, 0), DANGER, ARENA_R)
	for u in units:
		if u.alive:
			hurt(u, u.max_hp * ratio, why)


func _in_square(p: Vector3, margin := 0.0) -> bool:
	for c in SQUARES:
		if absf(p.x - c.x) <= SQ_HALF + margin and absf(p.z - c.z) <= SQ_HALF + margin:
			return true
	return false


## warn = os quadrados aparecem marcados no chão · on = o resto da arena virou vazio.
func _set_void(warn: bool, on: bool) -> void:
	void_warn = warn
	void_on = on
	floor_mat.set_shader_parameter("void_warn", 1.0 if warn else 0.0)
	floor_mat.set_shader_parameter("void_on", 1.0 if on else 0.0)
	if on:
		hud.flash(Color(0.5, 0.3, 1.0) * Color(1, 1, 1, 0.4))


## Elo Perdido: dois heróis presos por uma corrente. Dói enquanto existir;
## pra quebrar, os dois se afastam até ela esticar demais.
func _start_link() -> void:
	_clear_link()
	var pool := _alive_shuffled()
	if pool.size() < 2:
		return
	var node := Fx.inst(fx_root, BoxMesh.new(), Fx.mat(LINK_COL, 3.0, true))
	link = {"a": pool[0], "b": pool[1], "node": node, "t": 0.0, "tick": 0.0}
	_tick_link(0.0)


func _clear_link() -> void:
	if link != null:
		link["node"].queue_free()
		link = null


func _tick_link(delta: float) -> void:
	if link == null:
		return
	var a: Unit = link["a"]
	var b: Unit = link["b"]
	if not a.alive or not b.alive:
		_clear_link()
		return
	link["t"] += delta
	link["tick"] += delta
	var pa := a.position + Vector3(0, 1.0, 0)
	var pb := b.position + Vector3(0, 1.0, 0)
	var dist := pa.distance_to(pb)
	var node: MeshInstance3D = link["node"]
	node.position = (pa + pb) * 0.5
	if dist > 0.05:
		node.look_at(pb, Vector3.UP)
	# quanto mais esticada, mais fina e clara: dá pra ver que está quase arrebentando
	var k := clampf(dist / LINK_BREAK, 0.0, 1.0)
	var thick := lerpf(0.34, 0.07, k)
	node.scale = Vector3(thick, thick, maxf(dist, 0.1))
	(node.material_override as StandardMaterial3D).albedo_color = LINK_COL.lerp(Color.WHITE, k * k)
	if dist >= LINK_BREAK or link["t"] >= LINK_MAX:
		var broke := dist >= LINK_BREAK
		_burst(pa, LINK_COL, 2.0)
		_burst(pb, LINK_COL, 2.0)
		_clear_link()
		if broke and (a.controlled or b.controlled):
			_master("link")
		return
	if link["tick"] >= LINK_TICK:
		link["tick"] = 0.0
		hurt(a, LINK_DMG, "ficou preso no Elo Perdido")
		if link != null and b.alive:
			hurt(b, LINK_DMG, "ficou preso no Elo Perdido")


## Golpes de meia arena. O aviso de verdade é a mão: a que sobe e brilha é o lado que vai apanhar.
func _tick_cleaves(delta: float) -> void:
	if cleaves.is_empty():
		if cleave_side != 0:
			cleave_side = 0
			boss.cleave_hand = 0
		return
	for c in cleaves:
		c["t"] -= delta
	var c0: Dictionary = cleaves[0]
	if c0["t"] <= CLEAVE_TELL:
		cleave_side = c0["side"]
		boss.cleave_hand = c0["side"]
	if c0["t"] <= 0.5 and not c0["shown"]:
		c0["shown"] = true
		# a marca no chão só aparece agora: quem esperou por ela quase não tem tempo
		_add_hazard({"shape": "rect", "pos": Vector3(c0["side"] * ARENA_R * 0.5, 0, 0), "dir": Vector3(0, 0, 1),
			"half_l": ARENA_R, "half_w": ARENA_R * 0.5, "total": maxf(c0["t"], 0.05) * haste, "dmg": CLEAVE_DMG, "card": "dodge",
			"why": "tomou o golpe de meia arena", "cleave": "last" if c0["last"] else "first"})
	if c0["t"] <= 0.0:
		cleaves.pop_front()
		cleave_side = 0
		boss.cleave_hand = 0


## Uma torre por herói vivo. Cada uma precisa de exatamente uma pessoa dentro quando carregar.
func _start_towers(total: float) -> void:
	_clear_towers()
	tower_t = total
	tower_total = total
	for u in units:
		if not u.alive:
			continue
		var node := Node3D.new()
		node.position = TOWER_POS[u.idx] + Vector3(0, 0.05, 0)
		fx_root.add_child(node)
		Fx.inst(node, Fx.torus(TOWER_R - 0.1, TOWER_R), Fx.mat(TOWER_COL, 3.0, true))
		Fx.inst(node, Fx.disc(TOWER_R), Fx.mat(Color(TOWER_COL.r, TOWER_COL.g, TOWER_COL.b, 0.14), 0.0, true))
		var fill := Fx.inst(node, Fx.disc(TOWER_R), Fx.mat(Color(TOWER_COL.r, TOWER_COL.g, TOWER_COL.b, 0.45), 0.0, true), Vector3(0, 0.01, 0))
		# coluna de luz: de longe dá pra ver onde ficam as torres
		var beam := Fx.inst(node, Fx.cyl(TOWER_R * 0.9, TOWER_R * 0.9, 5.0), Fx.mat(Color(TOWER_COL.r, TOWER_COL.g, TOWER_COL.b, 0.08), 0.6, true), Vector3(0, 2.5, 0))
		beam.name = "Beam"
		towers.append({"pos": TOWER_POS[u.idx], "node": node, "fill": fill})


func _clear_towers() -> void:
	for tw in towers:
		tw["node"].queue_free()
	towers.clear()


func _tick_towers(delta: float) -> void:
	if towers.is_empty():
		return
	tower_t -= delta
	var f := clampf(1.0 - tower_t / tower_total, 0.01, 1.0)
	for tw in towers:
		tw["fill"].scale = Vector3(f, 1, f)
	if tower_t > 0.0:
		return
	var player := units[ctrl]
	var empty := 0
	var crowded: Array = []
	var soakers: Array = []
	for tw in towers:
		var inside: Array = []
		for u in units:
			if u.alive and u.position.distance_to(tw["pos"]) <= TOWER_R:
				inside.append(u)
		if inside.is_empty():
			empty += 1
			_burst(tw["pos"], DANGER, 4.0)
		elif inside.size() == 1:
			soakers.append(inside[0])
			_burst(tw["pos"], TOWER_COL.lightened(0.3), 2.2)
		else:
			crowded.append_array(inside)
			_burst(tw["pos"], STACK_COL, 2.6)
	_clear_towers()
	for u in soakers:
		hurt(u, 10.0, "absorveu a torre")
	for u in crowded:
		hurt(u, 60.0, "torre com gente demais")
	# cada torre vazia explode na party inteira
	if empty > 0:
		hud.flash(Color(1.0, 0.2, 0.35) * Color(1, 1, 1, 0.5))
		for u in units:
			if u.alive:
				hurt(u, u.max_hp * 0.45 * empty, "torre vazia explodiu")
	if soakers.has(player) and player.alive:
		_master("final")


# ---------------------------------------------------------------- Contagem (golpes numerados)

## Cada herói vivo ganha um número em cima da cabeça. Depois de um tempo pra decorar,
## os golpes saem na ordem, um atrás do outro, mirados em onde o dono do número está:
## ímpar = corte em círculo · par = investida em linha, do boss até ele.
## Quem sabe que é o próximo se afasta da party antes; os outros desviam do aviso curto.
func _start_count() -> void:
	_clear_count()
	count_order = _alive_shuffled()
	count_i = 0
	count_t = 2.5 / haste
	for k in count_order.size():
		var u: Unit = count_order[k]
		var l := Fx.label(u, str(k + 1), Vector3(0, 3.5, 0), 120)
		l.outline_size = 24
		l.outline_modulate = Color(0.07, 0.08, 0.16)
		# ímpar em vermelho (círculo), par em claro (linha)
		l.modulate = DANGER.lightened(0.15) if k % 2 == 0 else Color(0.96, 0.95, 0.9)
		count_labels.append(l)


func _clear_count() -> void:
	for l in count_labels:
		if is_instance_valid(l):
			l.queue_free()
	count_labels.clear()
	count_order.clear()


func _tick_count(delta: float) -> void:
	if count_order.is_empty():
		return
	# o número da vez pulsa
	if count_i < count_labels.size() and is_instance_valid(count_labels[count_i]):
		count_labels[count_i].scale = Vector3.ONE * (1.0 + 0.18 * sin(fight_time * 14.0))
	count_t -= delta
	if count_t > 0.0:
		return
	var u: Unit = count_order[count_i]
	if u.alive:
		if count_i % 2 == 0:
			_add_hazard({"shape": "circle", "pos": Vector3(u.position.x, 0, u.position.z), "r": 3.4,
				"total": 1.0, "dmg": 45.0, "card": "dodge", "why": "ficou no corte da Contagem"})
		else:
			_line_at(u, 1.3, 1.0, 45.0, "ficou na investida da Contagem")
			_beam(Vector3(0, 5.0, -11.5), u.position, Color(1.0, 0.35, 0.4, 0.9), 0.35)
	if is_instance_valid(count_labels[count_i]):
		count_labels[count_i].queue_free()
	count_i += 1
	count_t = 1.3 / haste
	if count_i >= count_order.size():
		_clear_count()


# ---------------------------------------------------------------- dano

func _dmg_mult() -> float:
	if shield:
		return 0.25
	if vulnerable:
		return 2.0
	return 1.0


func _damage_boss(u: Unit, amount: float, show: bool, big: bool) -> void:
	if ended:
		return
	var dmg := amount * _dmg_mult() * low_hp_mult(u)
	if u.frenzy_t > 0.0:
		dmg *= FRENZY_DMG
	if u.power_t > 0.0:
		dmg *= 1.2
	if u.key == "sleepwalker":
		dmg *= 1.0 + DREAM_PER * dream_stacks
	if u.weak_t > 0.0:
		dmg *= 0.5
	if Knowledge.has(u.hero, "sharpen"):
		dmg *= 1.08
	if Knowledge.has(u.hero, "overdrive"):
		dmg *= 1.2
	if boss_hp / boss_max < 0.3 and Knowledge.has(u.hero, "executor"):
		dmg *= 1.25
	boss_hp -= dmg
	lb = minf(1.0, lb + dmg / (boss_max * LB_NEED) * (1.5 if Knowledge.has(u.hero, "spark") else 1.0))
	u.dmg_total += dmg
	u.dmg_bucket += dmg
	u.enmity += dmg * (TANK_STANCE if u.tank else 1.0)
	if show:
		boss.hit_flash()
		var col := Color(1.0, 0.9, 0.4) if big else Color.WHITE
		if shield:
			col = Color(0.5, 0.8, 1.0)
		_popup(int(round(dmg)), col, 64 if big else 46)
	if boss_hp <= 0.0:
		boss_hp = 0.0
		_end(true)


## Golpe do jogador: um risco de luz do personagem até o boss, pra o ataque "sair" de alguém.
func _attack_fx(u: Unit, big: bool) -> void:
	var from := u.position + Vector3(0, 1.1, 0)
	var to := Vector3(randf_range(-1.2, 1.2), randf_range(2.0, 4.0), -11.0)
	var m := Fx.mat(u.color.lightened(0.4), 3.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(0.28 if big else 0.18), m, from)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to, 0.09)
	tw.tween_callback(mi.queue_free)
	tw.tween_callback(_burst.bind(to, u.color.lightened(0.3), 1.6 if big else 0.9))


func _popup(value: int, col: Color, size: int, at = null, prefix := "") -> void:
	if value <= 0:
		return
	var p := Vector3(randf_range(-2.2, 2.2), randf_range(2.5, 5.0), -9.5)
	if at != null:
		p = at
	var l := Fx.label(fx_root, prefix + str(value), p, size)
	l.modulate = col
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", p.y + 1.6, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


func hurt(u: Unit, dmg: float, reason: String) -> void:
	if not u.alive:
		return
	if u.immortal_t > 0.0:
		_burst(u.position, Color(1.0, 0.9, 0.5), 1.4)
		return
	if u.parry_t > 0.0 and dmg > 0.0:
		# Golpe de Misericórdia usado como parry: o golpe da boss não entra e o corte não sai.
		# (Mecânica que mata na hora passa por kill(), não por aqui: essa o parry não salva.)
		u.parry_hit = true
		u.parry_t = 0.0
		_burst(u.position, Color(1, 1, 1), 2.6)
		if u.controlled:
			hud.toast("PARRY", 0.9)
			hud.flash(Color(1.0, 1.0, 1.0, 0.25))
		return
	if u.taste_t > 0.0 and dmg > 0.0:
		u.taste_hit = true  # golpe durante o Blood Taste = parry perfeito
	if u.guard_t > 0.0:
		dmg *= MITIGATION
	if u.wall_t > 0.0:
		dmg *= WALL_MULT
	if u.ward_t > 0.0:
		dmg *= 0.75
	if Knowledge.has(u.hero, "plate"):
		dmg *= 0.9
	if Knowledge.has(u.hero, "overdrive"):
		dmg *= 1.15
	dmg_taken += dmg
	if u.shield_hp > 0.0:
		var soak := minf(dmg, u.shield_hp)
		u.shield_hp -= soak
		dmg -= soak
		_popup(int(soak), Color(0.45, 0.9, 1.0), 56, u.position + Vector3(0, 2.6, 0), "")
		if dmg <= 0.0:
			_burst(u.position, Color(0.45, 0.9, 1.0), 1.4)
			return
	u.hp -= dmg
	hit_count[reason] = hit_count.get(reason, 0) + 1
	u.flash_hit(dmg / u.max_hp)
	_popup(int(dmg), DANGER.lightened(0.3), 72, u.position + Vector3(0, 2.6, 0), "-")
	# Poção (item): uma vez por luta, segura a queda quando a vida passa de 30%
	if u.hp > 0.0 and u.hp / u.max_hp < 0.3 and not u.potion_used and Knowledge.has(u.hero, "potion"):
		u.potion_used = true
		u.hp = minf(u.max_hp, u.hp + 50.0)
		_burst(u.position, Color(0.4, 1.0, 0.6), 1.6)
		_popup(50, Color(0.5, 1.0, 0.65), 56, u.position + Vector3(0, 3.2, 0), "+")
	if u.hp <= 0.0:
		kill(u, reason)


func kill(u: Unit, reason: String, force := false) -> void:
	if not u.alive:
		return
	# imortal (Limit Break do Tank) ignora até as mecânicas que matam na hora; só a Fúria passa
	if u.immortal_t > 0.0 and not force:
		_burst(u.position, Color(1.0, 0.9, 0.5), 1.8)
		return
	# Fênix (roxa): uma vez por luta, volta em vez de morrer. A Fúria não perdoa.
	if not force and not u.phoenix_used and Knowledge.has(u.hero, "phoenix"):
		u.phoenix_used = true
		u.hp = u.max_hp * 0.5
		_burst(u.position, Color(1.0, 0.6, 0.2), 3.0)
		_popup(int(u.hp), Color(1.0, 0.75, 0.3), 64, u.position + Vector3(0, 3.0, 0), "+")
		return
	if u.controlled and not fury:
		hud.flash(Color(1.0, 0.1, 0.2) * Color(1, 1, 1, 0.6))
	deaths += 1
	u.die()
	_sfx(SFX_DEATH, -4.0)
	log_lines.append(u.unit_name + ": " + reason)
	var any_alive := false
	for o in units:
		if o.alive:
			any_alive = true
	if not any_alive:
		if fury:
			# deixa o último biscoito aparecer antes da tela de wipe
			get_tree().create_timer(1.0).timeout.connect(_end.bind(false))
		else:
			_end(false)
	elif u.controlled:
		u.controlled = false
		for n in range(1, 4):
			var i := (u.idx + n) % 4
			if units[i].alive:
				ctrl = i
				units[i].hold_pos = null
				units[i].set_controlled(true)
				break


func _end(victory: bool) -> void:
	if ended:
		return
	ended = true
	won = victory
	var rank := -1
	var prize := {}
	if victory:
		rank = Knowledge.rank_for(_score())
		if not autoplay:
			prize = Knowledge.reward(Knowledge.boss, rank)
	hud.show_end(victory, log_lines, rank, prize)


## Nota de 0 a 100 da vitória: rapidez (40), dano tomado (40) e mortes (20).
func _score() -> float:
	# matar com 45% do tempo sobrando já vale a nota cheia de rapidez
	var speed := clampf((1.0 - fight_time / enrage) / 0.45, 0.0, 1.0) * 40.0
	var party_hp := 0.0
	for u in units:
		party_hp += u.max_hp
	# tomar o equivalente a três vezes a vida da party inteira zera a nota de dano
	var clean := clampf(1.0 - dmg_taken / (party_hp * 3.0), 0.0, 1.0) * 40.0
	var alive_pts := maxf(0.0, 20.0 - deaths * 7.0)
	return speed + clean + alive_pts


## Maestria: você resolveu a mecânica certo, na mão. Na terceira vez a carta é liberada
## e entra no baralho de quem tiver slot livre, então a IA já sai usando.
func _master(key: String) -> void:
	if autoplay or Knowledge.mastery_of(key) >= Knowledge.MASTERY_NEED:
		return
	var card: String = Knowledge.MASTERY[key]["card"]
	if Knowledge.add_mastery(key):
		for i in Knowledge.HEROES.size():
			Knowledge.equip(i, card)
		Knowledge.save()
		hud.card_unlocked(card)
	else:
		hud.mastery_tick(key)


# ---------------------------------------------------------------- boss

func _next_step() -> void:
	# o grande final entra numa virada de passo, perto do fim, e nunca no meio do Dodge Time
	if finale_state == 0 and boss_def.get("finale", false) and not DODGE_PHASES.has(phase) \
			and (fight_time >= enrage * FINALE_AT or boss_hp / boss_max <= FINALE_HP):
		finale_state = 1
		fin_i = -1
		hud.shout("BORA BISCOITAR!!!")
	var s: Dictionary = {}
	if finale_state == 1:
		fin_i += 1
		if fin_i < STEPS_FINALE.size():
			s = STEPS_FINALE[fin_i].duplicate()
		else:
			finale_state = 2
	if s.is_empty():
		step = (step + 1) % steps.size()
		s = steps[step].duplicate()
	for key in ["dur", "volley_at"]:
		if s.has(key):
			s[key] = s[key] / haste
	cur_step = s
	phase = s["t"]
	phase_t = 0.0
	phase_dur = s["dur"]
	volley_done = false
	cast_name = ""
	boss.casting = false
	match phase:
		"circles":
			_spawn_circles(s["n"])
		"stack":
			cast_name = "Comunhão" if s["need"] == 4 else "Duplas"
			boss.casting = true
			_start_stacks(s["dur"], s["need"])
		"buster":
			cast_name = "Esmagar"
			boss.casting = true
			_start_buster(s["dur"])
		"raid":
			cast_name = s.get("name", "Explosão")
			boss.casting = true
			boss.rage_t = s["dur"]
			if s.get("restore", false):
				_set_void(false, false)
		"linkcleave":
			cast_name = "Elo Perdido"
			_start_link()
			var first := 1 if randf() < 0.5 else -1
			cleave_fail = false
			cleaves = [{"side": first, "t": 2.2, "shown": false, "last": false}, {"side": -first, "t": 4.5, "shown": false, "last": true}]
		"collapse":
			cast_name = "Colapso"
			boss.casting = true
			_set_void(true, false)
			_add_hazard({"shape": "void", "pos": Vector3.ZERO, "total": s["dur"], "dmg": 0.0, "card": "dodge", "why": ""})
		"towers":
			cast_name = "Torres"
			_start_towers(s["dur"])
		"window":
			vulnerable = true
		"count":
			cast_name = "Contagem"
			boss.casting = true
			_start_count()
		"spread":
			cast_name = "Dispersão"
			boss.casting = true
			_start_spreads(s["dur"], s["n"])
		"dodgetime":
			cast_name = "Dodge Time"
			boss.casting = true
		"combo":
			cast_name = "Dodge Time"
			boss.casting = true
			var purple := _start_spreads(s["dur"], 2)
			_start_stacks(s["dur"], 2, purple, DODGE_PAIR_TOTAL)
		"grid":
			cast_name = "Dodge Time"
			boss.casting = true
			_spawn_grid(2.6)
			_start_stacks(s["dur"], 2, [], DODGE_PAIR_TOTAL)
		"blast":
			cast_name = "Explosão"
			boss.casting = true
			boss.rage_t = s["dur"]
		"line":
			cast_name = "Rajada"
			boss.casting = true
			_spawn_lines(s["n"], 1.5, 2.0, 30.0, "ficou na rajada")
		"knives":
			cast_name = "Facas"
			_spawn_lines(s["n"], 0.5, 1.0, 14.0, "levou uma faca")
		"core":
			cast_name = "Implosão"
			boss.casting = true
			_add_hazard({"shape": "circle", "pos": Vector3.ZERO, "r": 5.6, "total": s.get("total", 2.5), "dmg": 34.0,
				"card": "dodge", "why": "ficou no meio da Implosão"})
		"nova":
			cast_name = "Supernova"
			boss.casting = true
			_add_hazard({"shape": "donut", "pos": Vector3.ZERO, "r": 3.2, "total": s.get("total", 3.0), "dmg": 34.0,
				"card": "dodge", "why": "ficou na borda da Supernova"})
		"mark":
			cast_name = "Marca Elemental"
			boss.casting = true
		"zones":
			cast_name = "Sobrecarga Elemental"
			boss.casting = true
			_assign_elements()
		"cata":
			cast_name = "Cataclismo"
			boss.casting = true
			shield = true
			boss.set_shield(true)
			pair_timer = [0.0, 0.0]
			pass
		"burn":
			vulnerable = not shield


func _tick_boss(delta: float) -> void:
	phase_t += delta
	var s: Dictionary = cur_step
	if s.has("volley_at") and not volley_done and phase_t >= s["volley_at"]:
		volley_done = true
		_spawn_circles(1)
	if phase_t < phase_dur:
		return
	match phase:
		"blast":
			# explosão no fim do Dodge Time: não dá pra desviar, é cura e escudo que seguram
			_raidwide(s.get("ratio", BLAST_RATIO), "Explosão do Dodge Time")
		"raid":
			_raidwide(s["ratio"], String(s.get("name", "Explosão")))
		"collapse":
			_raidwide(s["ratio"], "Colapso")
			_set_void(false, true)
		"window":
			vulnerable = false
		"zones": _resolve_zones()
		"cata": _resolve_cataclysm()
		"burn":
			vulnerable = false
			shield = false
			boss.set_shield(false)
	if not ended:
		_next_step()


func _assign_elements() -> void:
	var els := [0, 1, 2, 3]
	els.shuffle()
	for i in 4:
		if units[i].alive:
			units[i].set_element(els[i], EL_COL[els[i]])
	var zel := [0, 1, 2, 3]
	zel.shuffle()
	for i in 4:
		var e: int = zel[i]
		var col: Color = EL_COL[e]
		var node := Node3D.new()
		node.position = ZONE_POS[i] + Vector3(0, 0.02, 0)
		fx_root.add_child(node)
		Fx.inst(node, Fx.disc(ZONE_R), Fx.mat(Color(col.r, col.g, col.b, 0.28), 0.6, true))
		Fx.inst(node, Fx.torus(ZONE_R - 0.08, ZONE_R), Fx.mat(col, 3.0, true))
		zones.append({"pos": ZONE_POS[i], "el": e, "node": node})
	zones_active = true


func _resolve_zones() -> void:
	var player := units[ctrl]
	for u in units:
		if not u.alive or u.element < 0:
			continue
		var inside = null
		for z in zones:
			if z["pos"].distance_to(u.position) <= ZONE_R:
				inside = z
		# maestria só conta na zona certa: a do elemento oposto
		if u == player and inside != null and inside["el"] == OPP[u.element]:
			_master("zone")
		if inside == null:
			kill(u, "tinha " + EL_NAME[u.element] + " e ficou fora das zonas")
		elif inside["el"] != OPP[u.element]:
			kill(u, "tinha " + EL_NAME[u.element] + " e ficou na zona de " + EL_NAME[inside["el"]])
		else:
			_burst(u.position, EL_COL[u.element], 1.4)
	for z in zones:
		z["node"].queue_free()
	zones.clear()
	zones_active = false


func _tick_pairs(delta: float) -> void:
	if phase != "cata":
		return
	for pair in 2:
		var a: Unit = null
		var b: Unit = null
		for u in units:
			if u.alive and u.element == pair * 2:
				a = u
			elif u.alive and u.element == pair * 2 + 1:
				b = u
		if a == null or b == null or a.position.distance_to(b.position) > 1.6:
			pair_timer[pair] = 0.0
			continue
		pair_timer[pair] += delta
		if pair_timer[pair] < 0.6:
			continue
		var mid := (a.position + b.position) * 0.5
		a.set_element(-1)
		b.set_element(-1)
		if a.controlled or b.controlled:
			_master("partner")
		if pair == 0:
			shield = false
			boss.set_shield(false)
			_burst(mid, Color(0.9, 0.95, 1.0), 4.0)
			_burst(Vector3(0, 5, -12), Color(0.5, 0.9, 1.0), 9.0)
		else:
			shelter_pos = mid
			_build_shelter(mid)
			_burst(mid, EL_COL[2], 3.0)


func _build_shelter(p: Vector3) -> void:
	shelter_node = Node3D.new()
	shelter_node.position = p
	fx_root.add_child(shelter_node)
	var dome := SphereMesh.new()
	dome.radius = SHELTER_R
	dome.height = SHELTER_R
	dome.is_hemisphere = true
	Fx.inst(shelter_node, dome, Fx.mat(Color(0.75, 0.62, 0.45, 0.3), 0.5))
	Fx.inst(shelter_node, Fx.torus(SHELTER_R - 0.12, SHELTER_R), Fx.mat(Color(1.0, 0.8, 0.5), 2.5, true), Vector3(0, 0.05, 0))
	shelter_node.scale = Vector3(0.1, 0.1, 0.1)
	shelter_node.create_tween().tween_property(shelter_node, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func _resolve_cataclysm() -> void:
	hud.flash(Color(1.0, 0.55, 0.9))
	var player := units[ctrl]
	for u in units:
		if not u.alive:
			continue
		if shelter_pos == null:
			kill(u, "Cataclismo sem abrigo (faltou Terra + Ar)")
		elif u.position.distance_to(shelter_pos) > SHELTER_R:
			kill(u, "Cataclismo fora do abrigo")
		elif u == player:
			_master("shelter")
	var survivors := 0
	for u in units:
		if u.alive:
			survivors += 1
			u.set_element(-1)
			u.hold_pos = null
	# A carta roxa é prêmio por já ter resolvido a mecânica inteira com a party toda viva.
	if survivors == 4 and not autoplay and Knowledge.grant("mark"):
		hud.card_unlocked("mark")
	if order == "hold":
		order = "atk"
	if shelter_node != null:
		shelter_node.queue_free()
		shelter_node = null
	shelter_pos = null


## Fim do DPS check: o boss chama os biscoitos e cada um cai em cima de alguém.
func _start_fury() -> void:
	fury = true
	_sfx(SFX_FART)
	hud.show_biscoito(1.0)
	boss.casting = true
	boss.six_seven = false
	hud.flash(Color(1.0, 0.2, 0.35) * Color(1, 1, 1, 0.45))
	var say := Fx.label(fx_root, "BORA BISCOITAR!", Vector3(0, 6.4, -9.5), 120)
	say.modulate = COOKIE_COL.lightened(0.45)
	say.outline_modulate = Color(0.16, 0.08, 0.04)
	say.outline_size = 28
	say.scale = Vector3.ONE * 0.3
	var st := say.create_tween()
	st.tween_property(say, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_interval(2.6)
	st.tween_property(say, "modulate:a", 0.0, 0.4)
	st.tween_callback(say.queue_free)

	# um biscoito mirado em cada herói vivo, um depois do outro
	var delay := 0.9
	for u in units:
		if u.alive:
			_drop_cookie(u.position, delay, 1.25, u)
			delay += 0.32
	# e uma chuva pelo resto da arena
	for n in 16:
		var a := randf() * TAU
		var r := sqrt(randf()) * ARENA_R
		_drop_cookie(Vector3(cos(a) * r, 0, sin(a) * r), randf_range(0.7, delay + 0.6), randf_range(0.7, 1.1), null)


func _drop_cookie(at: Vector3, delay: float, size: float, victim: Unit) -> void:
	var ground := Vector3(at.x, 0.0, at.z)
	# aviso no chão: fecha junto com a queda
	var warn_mat := Fx.mat(Color(1.0, 0.25, 0.3, 0.0), 1.2, true)
	var warn := Fx.inst(fx_root, Fx.disc(size * 1.25), warn_mat, ground + Vector3(0, 0.04, 0))
	var cookie := Node3D.new()
	fx_root.add_child(cookie)
	Fx.inst(cookie, Fx.cyl(size, size * 0.92, size * 0.32), Fx.mat(COOKIE_COL, 0.25))
	var chip := Fx.mat(Color(0.25, 0.13, 0.07), 0.0)
	for n in 7:
		var a := n * TAU / 7.0 + randf() * 0.5
		var r := size * randf_range(0.2, 0.75)
		for side in [1.0, -1.0]:
			Fx.inst(cookie, Fx.sphere(size * 0.13), chip, Vector3(cos(a) * r, size * 0.16 * side, sin(a + side) * r))
	var from := ground + Vector3(randf_range(-4.0, 4.0), 22.0, -11.0)
	cookie.position = from
	cookie.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	cookie.visible = false
	var fall := 0.55
	var tw := cookie.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: cookie.visible = true)
	tw.set_parallel(true)
	tw.tween_property(cookie, "position", ground + Vector3(0, size * 0.3, 0), fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(cookie, "rotation", cookie.rotation + Vector3(7.0, 2.0, 5.0), fall)
	tw.tween_property(warn_mat, "albedo_color:a", 0.5, fall)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		warn.queue_free()
		cookie.queue_free()
		_burst(ground, COOKIE_COL.lightened(0.2), size * 2.6)
		if victim != null and victim.alive:
			_popup(9999, Color(1.0, 0.3, 0.35), 90, victim.position + Vector3(0, 2.4, 0))
			victim.hp = 0.0
			kill(victim, "Fúria: o tempo acabou", true))


## Toca um som uma vez; o player se apaga sozinho quando termina.
func _sfx(stream: AudioStream, volume_db := 0.0) -> void:
	if autoplay:
		return  # os testes automáticos rodam mudos
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = &"SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _burst(p: Vector3, col: Color, radius: float) -> void:
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.6), 2.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(1.0), m, p + Vector3(0, 0.3, 0))
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.5, radius), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)
