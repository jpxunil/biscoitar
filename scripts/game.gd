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
const RANGED_RANGE := 40.0  # quem ataca de longe alcança a arena inteira (como no FFXIV): não tem limite pra mostrar
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
const ROAM_MELEE := 3.3        # boss que anda: distância de quem luta de perto ...
const ROAM_RANGED := 6.2       # ... e de quem luta de longe
const ROAM_FX_H := 0.42        # ... e a altura dos efeitos dos golpes (ela é bem mais baixa que as outras)
const MELEE_POS := [Vector3(1.3, 0, -6.2), Vector3(3.1, 0, -6.3), Vector3(-1.9, 0, -6.0), Vector3(-3.2, 0, -6.3)]
const RANGED_POS := [Vector3(1.6, 0, 1.2), Vector3(3.6, 0, 0.6), Vector3(-1.6, 0, 1.4), Vector3(-3.6, 0, 0.2)]

const UNIT_DEFS := [
	{"name": "Paladino", "range": MELEE_RANGE, "key": "tank", "color": Color(0.3, 0.5, 1.0), "hp": 160.0, "melee": true, "ai_dps": 6.0, "hit": 8.0, "tank": true},
	{"name": "Soulflame", "range": RANGED_RANGE, "key": "healer", "color": Color(0.4, 0.95, 0.55), "hp": 90.0, "melee": false, "ai_dps": 3.0, "hit": 6.0},
	{"name": "Assassina", "range": MELEE_RANGE, "key": "assassina", "color": Color(0.78, 0.38, 1.0), "hp": 100.0, "melee": true, "ai_dps": 10.0, "hit": 17.0},
	{"name": "Maga", "range": RANGED_RANGE, "key": "maga", "color": Color(1.0, 0.72, 0.25), "hp": 90.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
	# os quatro da luta vêm de Knowledge.fight_party(): qualquer combinação destes heróis
	{"name": "Malpractice", "range": MELEE_RANGE, "key": "nurse", "color": Color(0.36, 0.4, 0.95), "hp": 80.0, "melee": true, "ai_dps": 6.0, "hit": 8.0, "tank": true},
	{"name": "Soulburner", "range": RANGED_RANGE, "key": "burner", "color": Color(0.12, 0.82, 0.78), "hp": 90.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
	{"name": "Ringstar", "range": MELEE_RANGE, "key": "ringstar", "color": Color(1.0, 0.45, 0.75), "hp": 110.0, "melee": true, "ai_dps": 9.0, "hit": 14.0},
	{"name": "Apotecário", "range": RANGED_RANGE, "key": "apothecary", "color": Color(0.35, 0.8, 0.66), "hp": 90.0, "melee": false, "ai_dps": 5.0, "hit": 8.0},
	{"name": "Sleepwalker", "range": RANGED_RANGE, "key": "sleepwalker", "color": Color(0.55, 0.58, 1.0), "hp": 85.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
	{"name": "Valsa", "range": MELEE_RANGE, "key": "valsa", "color": Color(0.74, 0.62, 1.0), "hp": 95.0, "melee": true, "ai_dps": 6.0, "hit": 9.0},
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
## "big": true marca a habilidade importante do herói. Quando o JOGADOR usa uma delas, o HUD faz o
## destaque de tela (hud.skill_cut): brilho nas bordas e a arte do personagem à direita.
const SKILLS := {
	# Paladino: o mais simples do jogo. Sem recurso nem combo: bate, provoca e aperta a defesa.
	"tank": [{"name": "Golpe de Juramento", "cd": 1.5, "dmg": 30.0},
		{"name": "Baque do Escudo", "cd": 8.0, "dmg": 55.0},
		{"name": "Provocação", "cd": 15.0},
		{"name": "Solo Consagrado", "cd": 18.0},
		{"name": "Égide", "cd": 25.0},
		{"name": "Muralha da Fé", "big": true, "cd": 60.0}],
	# Malpractice (tank de sangue, "de papel"): cada golpe custa vida dela (SELF_COST). O slot 1 estoca
	# e rouba um fio de vida, o 2 é o parry, o 3 rouba vida fixa e junta acúmulos, o 4 avança e provoca,
	# o 5 é o ultimate (não tem recarga: gasta PARTY_NEED acúmulos). Quanto menos vida, mais dano.
	"nurse": [{"name": "Syringe Poke", "cd": 1.0, "dmg": 8.0},
		{"name": "Blood Taste", "cd": 20.0}, {"name": "Blood Consumed", "cd": 5.0, "dmg": 40.0},
		{"name": "Emergency Response", "cd": 8.0}, {"name": "Blood Party", "big": true, "cd": 0.0, "stacks": 20},
		{"name": "Bloodbath", "cd": 12.0}],
	# Soulflame: healer direta, sem recurso. "ai_cd" é a recarga quando quem usa é a IA.
	# Todas as habilidades dela conjuram 1,2 s (o Renascimento, 3 s): andar cancela, sem gastar a recarga.
	"healer": [{"name": "Fagulha Espiritual", "cd": 2.0, "dmg": 12.0, "cast": 1.2},
		{"name": "Toque de Brasa", "cd": 2.0, "cast": 1.2, "ai_cd": 3.5},
		{"name": "Lareira Celestial", "cd": 18.0, "cast": 1.2},
		{"name": "Manto de Cinzas", "cd": 20.0, "cast": 1.2},
		{"name": "Asa da Fênix", "cd": 30.0, "cast": 1.2},
		{"name": "Renascimento", "big": true, "cd": 60.0, "cast": 3.0}],
	# Garras Cruzadas divide a recarga com o Talho (usar uma põe a outra na mesma recarga): quase não dá
	# dano, serve pra manter o Ferimento na boss (a party toda bate mais forte).
	# Assassina: velocidade pura. O Talho (slot 1) bate MUITO mais forte do lado certo da boss:
	# três de um lado, três do outro (unit.side_need / side_left), pra sempre.
	"assassina": [{"name": "Talho Relâmpago", "cd": 1.3, "dmg": 10.0},
		{"name": "Passo Rasante", "cd": 5.0, "dmg": 35.0},
		{"name": "Garras Cruzadas", "cd": 0.6, "dmg": 2.0},
		{"name": "Dança Carmesim", "cd": 15.0, "dmg": 95.0},
		{"name": "Golpe de Misericórdia", "cd": 22.0, "dmg": 120.0},
		{"name": "Frenesi da Fera", "big": true, "cd": 60.0}],
	# Maga: atiradora. Dispara, junta balas Rainbow (passiva) e decide onde gastar. Só o Canhão Estelar
	# conjura (ela materializa a arma). A Salva Astral não tem recarga: custa SALVO_COST balas.
	# "pow" = dano de habilidade que não exige o alcance normal de ataque.
	"maga": [{"name": "Disparo Rúnico", "cd": 1.0, "dmg": 26.0},
		{"name": "Rainbow Shots", "cd": 0.3},
		{"name": "Ricochete Prismático", "cd": 8.0},
		{"name": "Tiro Perfurante", "cd": 12.0, "dmg": 95.0},
		{"name": "Salva Astral", "cd": 0.0},
		{"name": "Canhão Estelar", "big": true, "cd": 60.0, "cast": 2.0}],
	# Soulburner: marcar (Marca do Zênite) e estourar a marca (Lança Serafim) o mais tarde possível.
	"burner": [{"name": "Brasas do Firmamento", "cd": 2.0, "cast": 1.0, "dmg": 24.0},
		{"name": "Marca do Zênite", "cd": 12.0},
		{"name": "Lança Serafim", "cd": 8.0, "cast": 1.0},
		{"name": "Rasante Incandescente", "cd": 10.0},
		{"name": "Chuva de Brasas", "cd": 20.0},
		{"name": "Juízo Solar", "big": true, "cd": 60.0}],
	# Ringstar: Jab -> Direto -> Gancho, cada um fortalece o seguinte (unit.chain). Os três dividem
	# a recarga (GCD); os slots 4 e 5 são oGCD e não quebram a sequência.
	"ringstar": [{"name": "Jab Estelar", "cd": 2.0, "dmg": 22.0},
		{"name": "Direto de Campeã", "cd": 2.0, "dmg": 40.0},
		{"name": "Gancho Meteoro", "cd": 2.0, "dmg": 70.0},
		{"name": "Contagem Regressiva", "cd": 14.0},
		{"name": "SUPERSTAR!", "cd": 20.0},
		{"name": "Nocaute Final", "big": true, "cd": 60.0}],
	# Apotecário: healer com rotação ofensiva. Recurso: Vestígios (unit.vestiges, até 3), ganhos
	# renovando a Decomposição (DoT da Necropsia) com 1 s ou menos sobrando.
	"apothecary": [{"name": "Incisão", "cd": 1.0, "dmg": 16.0},
		{"name": "Necropsia", "cd": 7.0, "dmg": 60.0},
		{"name": "Sutura", "cd": 1.0, "cast": 1.5, "ai_cd": 3.5},
		{"name": "Solução Hemostática", "cd": 20.0},
		{"name": "Tanatopraxia", "big": true, "cd": 45.0},
		{"name": "Estabilização", "cd": 60.0}],
	# Sleepwalker, Modo Acordado (o Modo Dormindo é SKILLS_ASLEEP; quem escolhe a lista é kit()).
	"sleepwalker": [{"name": "Bocejo", "cd": 2.0},
		{"name": "Puxar o Lençol", "cd": 15.0},
		{"name": "Visitantes debaixo da Cama", "cd": 15.0},
		{"name": "Senhor Travesseiro", "cd": 15.0},
		{"name": "A Cama Caiu!", "cd": 15.0},
		{"name": "Sono Profundo", "cd": 3.0}],
	# Valsa: suporte que dança colada na boss. O Passo de Valsa conta um, dois, TRÊS: o terceiro é o
	# Giro, que rende Embalo (unit.embalo). O Embalo abre a saia: quem está dentro dela bate mais forte.
	# Só o Passo de Valsa exige alcance; o resto do kit sai de qualquer lugar.
	"valsa": [{"name": "Passo de Valsa", "cd": 1.2, "dmg": 16.0},
		{"name": "Passo a Dois", "cd": 8.0},
		{"name": "Pirueta", "cd": 9.0},
		{"name": "Chuva de Pétalas", "cd": 18.0},
		{"name": "Crescendo", "cd": 30.0},
		{"name": "Grande Baile", "big": true, "cd": 60.0}],
}
## Sleepwalker, Modo Dormindo: sequência obrigatória; "cost" é o Torpor gasto.
const SKILLS_ASLEEP := [
	{"name": "A Mordida dos Mil", "cd": 18.0, "cost": 5.0, "base": 100.0},
	{"name": "Senhor Travesseiro: Devorador", "cd": 0.6, "cost": 10.0, "base": 150.0},
	{"name": "O Abraço Impossível", "cd": 0.6, "cost": 15.0, "base": 200.0},
	{"name": "A Porta Errada", "cd": 0.6, "cost": 20.0, "base": 250.0},
	{"name": "A Casa que Engole", "big": true, "cd": 0.6, "cost": 50.0, "base": 600.0},
	{"name": "Acordar", "cd": 3.0},
]
## Cast curto trava o personagem no lugar; cast longo pode ser interrompido andando.
const LOCKED_CAST := 1.0
## CARTA ROTAÇÃO
## Com ela equipada, o herói na mão da IA joga o kit de verdade (_ai_rotation): cada classe tem uma
## ordem de prioridade (_rot_pick) que respeita as mecânicas dela, e cada habilidade sai de AI_REACT
## segundos depois de voltar. O dano desses golpes vale AI_ROT_MULT do que valeria na mão do jogador:
## é um aliado competente, não um segundo jogador.
const AI_REACT := Vector2(0.3, 2.0)
const AI_ROT_MULT := 0.5
## Pra LIBERAR a carta, o jogador precisa mostrar que sabe a rotação do herói, numa janela corrida de
## Knowledge.DPS_WINDOW segundos no controle dele (rot_ok):
##   1. DPS médio >= Knowledge.DPS_GOAL do herói;
##   2. o golpe básico / GCD ficou parado (pronto, ao alcance, sem estar conjurando) no máximo
##      ROT_IDLE_MAX do tempo;
##   3. cada habilidade de rotação da classe (ROT_SLOTS: as recargas de dano, sem a ultimate de 60 s,
##      as defesas e as curas) foi usada pelo menos uma vez na janela;
##   4. depois de voltarem da recarga, elas esperaram em média no máximo ROT_DELAY_MAX pra ser usadas;
##   5. nenhuma delas está parada há mais de ROT_STALE segundos agora.
const ROT_SLOTS := {"tank": [1, 3], "nurse": [2], "healer": [], "assassina": [2, 3, 4], "maga": [3], "burner": [1, 2, 4],
	"ringstar": [3, 4], "apothecary": [1], "sleepwalker": [1, 2, 3, 4], "valsa": [1, 4]}
const ROT_IDLE_MAX := 0.35
const ROT_DELAY_MAX := 3.0
const ROT_STALE := 6.0
## DPS da IA com a carta roxa Rotação (sem ela vale o ai_dps de UNIT_DEFS).
## Assassina e Maga, além disso, soltam o golpe forte de 20 s (Lâmina Final / Ruína) sempre que dá.
const ROTATION_DPS := {"tank": 10.0, "nurse": 4.0, "healer": 6.0, "assassina": 14.0, "maga": 10.0, "burner": 11.0, "ringstar": 12.0, "apothecary": 8.0, "sleepwalker": 12.0, "valsa": 9.0}
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
const MERCY_WINDOW := 1.0      # Golpe de Misericórdia: o salto em espiral até a boss; o corte sai no fim.
                               # Um golpe que chegar nesse tempo é aparado, e aí o corte não sai
const MERCY_FRENZY := 1.5      # ... em Frenesi: +50% de dano, não toma dano e o corte sai mesmo aparando
const WOUND_TIME := 12.0       # Garras Cruzadas: Ferimento na boss por esse tempo ...
const WOUND_MULT := 1.15       # ... a party toda dá +15% de dano nela
const WOUND_COL := Color(0.9, 0.1, 0.25)
const DANCE_SPIN := 0.4        # Dança Carmesim: tempo do giro
const FRENZY_TIME := 12.0      # Frenesi da Fera
## Quando o Frenesi acaba, o botão dele brilha de novo por FINISH_WINDOW: é a Última Dança, uma habilidade
## bônus (não mexe na recarga do Frenesi). Ela some e uma tempestade de cortes atravessa a boss
## (FINISH_HITS de FINISH_HIT), fechando com um X gigante (FINISH_END). Enquanto dura, ela é intocável.
const FINISH_WINDOW := 2.0
const FINISH_HITS := 14
const FINISH_HIT := 20.0
const FINISH_END := 220.0
const FINISH_TIME := 1.9
## ... e, FINISH_ECHO_T depois do X, os cortes "estouram": FINISH_ECHO de todo o dano que ela causou
## durante o Frenesi volta de uma vez (dano direto, sem multiplicadores).
const FINISH_ECHO := 0.45
const FINISH_ECHO_T := 0.6
const FINISH_WINDUP := 0.5     # antes de sumir, ela se agacha em posição de ataque por esse tempo... e VAI
const FINISH_LOCK := FINISH_WINDUP + FINISH_TIME + FINISH_ECHO_T
const MERCY_FIRST := 0.4       # Golpe de Misericórdia: a parte do dano que sai na cravada (o resto, no mergulho)
const MERCY_LAND := 0.5        # ... e o instante da cravada dentro da janela
const DANCE_FRENZY := 1.4      # Dança Carmesim em Frenesi: vira um furacão e bate +40%
## Golpe de Misericórdia é a execução: bate mais forte quanto menos vida a boss tem (até +MERCY_EXEC com
## ela no fim), e mais ainda numa boss com Ferimento, que ele renova.
const MERCY_EXEC := 0.8
const MERCY_WOUND := 1.25
const FRENZY_DMG := 1.15       # ... +15% de dano
const WOUND_GCD := 0.6         # Talho Relâmpago com a boss em Ferimento: a recarga cai de 1,3 s pra isso
const FRENZY_SHAVE := 0.3      # ... cada Talho Relâmpago tira isso da recarga da Dança Carmesim e do Golpe de Misericórdia
const FRENZY_HASTE := 0.5      # ... e Talho, Garras e Passo Rasante recarregam na metade do tempo
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
const BULLET_MAX := 8
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
const SALVO_FAIRY := 6         # Salva Astral com EXATAMENTE 6 balas: gasta as 6 e solta a Fada Astral
const FAIRY_TIME := 15.0       # ... que fica perto da boss esse tempo ...
const FAIRY_DPS := 6.0         # ... dando esse dano por segundo com a varinha (é um DoT, só que animado)
const FAIRY_HEAL := 0.05       # ... e, a cada ricochete que bate nela, cura a party nesse tanto da vida máxima
const FAIRY_AT := Vector3(2.8, 6.4, -10.4)
const FAIRY_COL := Color(1.0, 0.75, 0.95)
const CANNON_DMG := 220.0      # Canhão Estelar sozinho ...
const CANNON_PER_BULLET := 75.0  # ... e por bala guardada: bem mais que os 40 de soltá-las uma a uma
const CANNON_SUPER_BONUS := 180.0  # com EXATAMENTE BULLET_MAX balas: supercanhão arco-íris, com esse dano a mais ...
const CANNON_SUPER_TIME := 2.0   # ... disparando por esse tempo, com ela presa no lugar
const CANNON_SUPER_TICKS := 8    # ... e o dano saindo nesse número de batidas
const AIM_TIME := 2.0          # Tiro Perfurante: a boss fica marcada por esse tempo ...
const AIM_BONUS := 60.0        # ... e a Salva, o Canhão ou o Disparo fortalecido que usar a marca dá isso a mais (uma vez)
const AIM_COL := Color(0.45, 0.95, 1.0)
const RAINBOW := [Color(1.0, 0.25, 0.35), Color(1.0, 0.6, 0.2), Color(1.0, 0.88, 0.25), Color(0.35, 0.9, 0.45),
	Color(0.25, 0.85, 1.0), Color(0.4, 0.5, 1.0), Color(0.8, 0.4, 1.0)]
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
## Paleta do Soulburner: fogo celestial verde-marinho, rastros ciano, brilhos menta e núcleos brancos.
const FIRE := Color(0.1, 0.86, 0.72)
const FIRE_CYAN := Color(0.3, 0.95, 1.0)
const FIRE_MINT := Color(0.62, 1.0, 0.82)
const LANCE_PERFECT := 0.8     # Lança conjurada com a marca nesse tanto do caminho (os últimos 2 s): timing perfeito
const LANCE_GOOD := 0.4        # ... a partir daqui: bom
const LANCE_FALL := 0.35       # Lança Serafim: depois do cast, tempo da queda até o impacto (o dano sai aí)
const RAIN_EVERY := 0.11       # Chuva de Brasas: intervalo entre uma brasa e outra caindo
const SOLAR_RISE := 1.0        # Juízo Solar: ele sobe e abre as asas (preso, sem agir) ...
const SOLAR_TRAVEL := 2.0      # ... lança o sol, que leva esse tempo até a boss (o dano sai no impacto) ...
const SOLAR_FLOAT := 1.5       # ... e fica flutuando esse tempo depois do lançamento, já podendo agir
const SOLAR_HEIGHT := 2.6
## Kit da Ringstar.
const WEAK_HIT := 8.0          # Direto ou Gancho sem estar fortalecido: dano mínimo
const COUNT_TIME := 15.0       # Contagem Regressiva: duração ...
const COUNT_GCD := 1.0         # ... o GCD dos três golpes cai de 2 s pra 1 s ...
const COUNT_DMG := 1.1         # ... e +10% de dano
const COUNT_SPEED := 1.44      # ... e +44% de velocidade de movimento
const SUPERSTAR_DMG := 110.0
const SUPERSTAR_WIND := 1.0    # SUPERSTAR!: pega o microfone e aponta pra boss ...
const SUPERSTAR_FIRE := 1.0    # ... e a rajada sai ao longo desse tempo ...
const SUPERSTAR_SHOTS := 5     # ... nesse número de disparos (o dano total é SUPERSTAR_DMG)
const KNOCKOUT_DMG := 380.0
const KNOCKOUT_AIR := 0.8      # Nocaute Final: tempo do salto, no ar (passa por cima de ataque baixo) ...
const KNOCKOUT_HEIGHT := 7.5   # ... altura do salto ...
const KNOCKOUT_R := 7.0        # ... e raio da onda de choque: o dano é em quem estiver dentro dela
const STAR := Color(1.0, 0.45, 0.75)
## Kit da Valsa (dançarina de salão; suporte corpo a corpo).
const LILAC := Color(0.74, 0.62, 1.0)
const ROSE_GOLD := Color(1.0, 0.8, 0.3)
const WALTZ_GIRO := 40.0       # Passo de Valsa, terceiro tempo (o Giro): dano ...
const WALTZ_GIRO_PER := 4.0    # ... e mais isso por ponto de Embalo que ela já tinha
const EMBALO_MAX := 5          # Embalo: cada Giro dá 1, até 5. É o quanto a saia está aberta
const EMBALO_HOLD := 6.0       # sem girar por esse tempo, o Embalo começa a cair ...
const EMBALO_DROP := 2.0       # ... um ponto a cada tanto
const SKIRT_R := 3.2           # raio da saia (até onde o bônus alcança) sem Embalo ...
const SKIRT_R_PER := 0.5       # ... e a mais por ponto
const SKIRT_BONUS := 0.06      # dano a mais de quem está na saia (ela mesma não ganha) ...
const SKIRT_BONUS_PER := 0.02  # ... e a mais por ponto de Embalo
const DUET_DMG := 28.0         # Passo a Dois: o golpe dela (se estiver ao alcance) e o do Par, cada um
const DUET_HEAL := 18.0        # ... e a cura no Par
const DUET_ECHO := 8.0         # o Par acompanha cada Giro com um golpe desse dano ...
const DUET_ECHO_PER := 4.0     # ... e mais isso por ponto de Embalo
const TWIRL_TIME := 0.6        # Pirueta: tempo girando; golpe que chegar nesse tempo passa por ela
const TWIRL_DMG := 50.0
const TWIRL_BRAVO := 2         # ... desviar girando (BRAVO!) dá esse Embalo a mais ...
const TWIRL_REFUND := 0.5      # ... e a recarga da Pirueta cai pela metade
const PETAL_TIME := 6.0        # Chuva de Pétalas: quanto dura ...
const PETAL_BURST := 20.0      # ... cura na hora ...
const PETAL_HPS := 7.0         # ... e por segundo, em quem está na dança
const CRESC_TIME := 8.0        # Crescendo: duração ...
const CRESC_MULT := 2.0        # ... o bônus da saia dobra ...
const CRESC_GCD := 0.8         # ... e o Passo de Valsa recarrega nisso (o Embalo não cai enquanto dura)
const BALL_TIME := 10.0        # Grande Baile: a arena vira salão; a party toda conta como dentro da saia
const BALL_END_DMG := 260.0    # ... e o último acorde dá esse dano ...
const BALL_END_HEAL := 40.0    # ... e cura isso em todos
const AI_WALTZ_EVERY := 3.6    # Valsa na mão da IA sem a carta Rotação: um Giro a cada tanto ...
const AI_WALTZ_MAX := 3        # ... e o Embalo dela não passa disso
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
## Ele é lento de propósito: TODA habilidade tem conjuração (SW_CAST; SW_CAST_NEAR com o buff Perto
## do Sonho, que vem de manter o DoT). Por isso o dano por golpe é alto (SW_SCALE).
const SW_SCALE := 0.62
const SW_CAST := 1.25          # conjuração de todas as habilidades dele, parado ...
const SW_CAST_NEAR := 0.75     # ... e com Perto do Sonho ativo
## Torpor é difícil de juntar acordado: a sequência sozinha rende pouco, e quase metade vem de
## acertar as janelas. Ciclo perfeito (4 da sequência + Bocejos) dá uns 50 líquidos; a sequência
## inteira do sonho custa 100. Ou seja: dois ciclos bem feitos por visita completa ao sonho.
const SW_AWAKE := [  # dano-base, Torpor gerado, stacks de Vulnerabilidade com a interação certa / sem ela
	{"base": 50.0, "torpor": 3.0, "stacks": 0, "weak": 0},
	{"base": 60.0, "torpor": 5.0, "stacks": 2, "weak": 2},
	{"base": 120.0, "torpor": 7.0, "stacks": 3, "weak": 1},
	{"base": 140.0, "torpor": 9.0, "stacks": 2, "weak": 1},
	{"base": 200.0, "torpor": 12.0, "stacks": 1, "weak": 0},
]
const SW_WINDOW := 1.0         # depois que uma da sequência sai, tempo pra COMEÇAR a conjurar a seguinte
const SW_PERFECT_TORPOR := 6.0 # Torpor extra por interação acertada
const SW_STEP_GAP := 0.3       # dormindo: respiro entre uma habilidade da sequência e a próxima
## Punição ao acordar, em segundos sem atacar nem usar habilidade (andar pode):
const SW_LOCK_NONE := 2.0      # acordou sem ter usado nada no sonho
const SW_LOCK_BITE := 1.0      # usou só A Mordida dos Mil (visita curta pra renovar o DoT)
const SW_LOCK_BROKEN := 3.0    # começou a sequência e não fechou com A Casa que Engole
const SW_BITE_WAKE := 15.0     # acordar depois de usar só a Mordida custa só isso de Torpor (o resto fica)
const SW_ECHO_TORPOR := 4.0    # Torpor por Fresta acertada com o Bocejo
const SW_FULL_HOLD := 3.0      # ao chegar em 100 de Torpor, esse tempo sem perder nada
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
## Renascimento usado com uma Lareira acesa: a fênix nasce dela e a Lareira fica FORTE em vez de sumir.
const HEARTH_STRONG_TIME := 14.0   # volta a durar isso
const HEARTH_STRONG_R := 7.0       # alcança mais longe
const HEARTH_STRONG_HPS := 12.0    # e cura mais
## Renascimento, depois do cast: a fênix nasce (REBIRTH_BIRTH), grita (REBIRTH_CRY) e só então atravessa
## o campo devagar (REBIRTH_FLY) até a boss, largando fogo pelo caminho (REBIRTH_PATCH segundos no chão).
## A cura e o reviver saem no nascimento; o dano e o DoT, quando ela chega na boss.
const REBIRTH_BIRTH := 0.9
const REBIRTH_CRY := 0.6
const REBIRTH_FLY := 1.8
const REBIRTH_PATCH := 5.0
const PHOENIX_HEAL := 110.0    # Asa da Fênix
const REBIRTH_HEAL := 70.0     # Renascimento: cura em todos ...
const REBIRTH_DMG := 90.0      # ... dano médio na boss ...
const REBIRTH_DOT := 6.0       # ... e um DoT leve por segundo ...
const REBIRTH_DOT_TIME := 12.0 # ... durante esse tempo
## Velocidade de andar por classe, como fração da velocidade-base (unit.speed). Assassina e Malpractice
## são as ágeis (base cheia); o resto anda 40% mais devagar; Sleepwalker e Apotecário, 65% mais devagar.
## Vale só pra quem o jogador controla (ver move_speed). Dash, avanços e empurrões não mudam.
const MOVE_MULT := {"assassina": 1.0, "nurse": 1.0, "sleepwalker": 0.35, "apothecary": 0.35, "valsa": 0.85}
const MOVE_DEFAULT := 0.6
const HASTE_MULT := 1.6        # pressa da Nuvem Conservante do Apotecário: +60% de velocidade ...
const HASTE_TIME := 8.0        # ... na party toda, por esse tempo
const REVIVE_HP := 0.5         # Asa da Fênix num aliado caído (Soulflame): volta com metade da vida
const REANIMATE_HP := 0.4      # Estabilização no Paciente caído (Apotecário): volta com 40% ...
const REANIMATE_COST := 3      # ... e gasta os 3 Vestígios
## Em que slot fica o golpe forte que a IA com a carta Rotação solta, e que a carta Golpe Lapidado melhora.
const BIG_SLOT := {"assassina": 4, "maga": 3}
## Em que slot cada tank guarda a defesa e a provocação (as cartas Guarda e Biscoiteiro usam isso).
const DEF_SLOT := {"tank": 4, "nurse": 1}
const PROVOKE_SLOT := {"tank": 2, "nurse": 3}
## Kit da Malpractice. Ela é "de papel": pouca vida e cada golpe custa sangue (SELF_COST).
## Quem erra o parry ou segura mal as recargas morre do próprio dano; quem joga bem vive no fio
## e bate mais forte por isso (LOW_HP_BONUS).
const SELF_COST := {"Syringe Poke": 4.0, "Blood Consumed": 8.0, "Emergency Response": 6.0}
const LOW_HP_BONUS := 0.75     # +75% de dano com a vida em LOW_HP_FLOOR ou menos; some com a vida cheia
const GAUGE_STEAL := 0.04      # gauge de sangue cheio (PARTY_NEED acúmulos): cada golpe devolve 4% da vida máxima
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
const RUSH_STACKS := 1         # Emergency Response junta 1 de Sangue
const PARTY_NEED := 20         # Blood Party: acúmulos gastos
const PARTY_TIME := 10.0       # Blood Party: quanto dura. Ela começa com 1 de vida e NÃO morre enquanto dura ...
const PARTY_DMG_MULT := 2.0    # ... dano das habilidades dobrado ...
const PARTY_CD := 0.5          # ... recargas pela metade ...
const PARTY_STEAL := 0.25      # ... rouba esse tanto do dano que causa (é a única cura que entra) ...
## ... e se a vida não estiver CHEIA quando o tempo acabar, ela morre.
const EXTRACT_TIME := 1.0      # Extração (o slot do parry durante o Blood Party): tempo com a seringa na boss ...
const EXTRACT_HEAL := 0.4      # ... recupera esse tanto da vida máxima ...
const EXTRACT_DMG := 60.0      # ... e dá esse dano
const EXTRACT_CD := 4.0
## Bloodbath (slot 6): ergue a seringa e chove sangue em volta dela, cobrindo a party.
const BATH_COST := 10          # Sangue gasto (o primeiro de cada Blood Party sai de graça) ...
const BATH_R := 6.0            # ... raio da chuva (o dobro no Blood Party) ...
const BATH_MULT := 0.8         # ... quem foi coberto toma 20% menos dano ...
const BATH_TIME := 10.0        # ... por esse tempo
const BATH_WINDOW := 2.0       # depois dela, tempo pra escolher a habilidade que sai fortalecida ...
const BATH_CHARGES_ULT := 3    # ... uma só; no Blood Party, as três próximas
const BATH_SLOTS := [0, 1, 2]  # quais podem: Syringe Poke, Blood Taste / Extração e Blood Consumed
const PURE_TIME := 10.0        # Bloodbath no Blood Party: DoT Pure Blood na boss (não alimenta o roubo de vida)
const PURE_DPS := 14.0
const POKE_RUSH_TIME := 3.0    # Syringe Poke fortalecido: por esse tempo ...
const POKE_RUSH_CD := 0.55     # ... a recarga dele cai pra quase metade de novo
const TASTE_BIG := 2.0         # Blood Taste fortalecido (fora do Blood Party): janela do parry em dobro
const EXTRACT_BIG_TIME := 2.5  # Extração fortalecida: carrega esse tempo na boss ...
const EXTRACT_BIG_DMG := 260.0 # ... e a explosão dá esse dano ...
const EXTRACT_BIG_HEAL := 0.7  # ... recuperando esse tanto da vida máxima
const CONSUMED_BIG_HEAL := 0.2 # Blood Consumed fortalecido: cura 20% da vida máxima ...
const CONSUMED_REGEN := 4.0    # ... regenera isso por segundo nela ...
const SHARE_REGEN := 4.0       # ... e a party toda regenera isso por segundo (Compartilhamento de Sangue) ...
const SHARE_TIME := 5.0        # ... durante esse tempo
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
## TROVÃO-KUN (mini boss, "roam"): fica no meio da arena e anda. É uma luta de PARTY: cada passo do
## ciclo dá trabalho pra um papel diferente, e nenhum castiga quem está só fazendo o próprio serviço.
##   leap   — marca um círculo vermelho em quem NÃO está com o aggro e salta ali. Quem está no círculo
##            sai (Desvio); a queda solta uma onda de choque fraca em todo mundo (cura).
##   chase  — anda atrás de quem está no topo do aggro, sem dano de contato: o tank o leva pra onde
##            quiser e quem luta de perto continua batendo.
##   buster — Esmagar no tank (defesa do tank, Escudo do curandeiro).
##   orbs   — "olho da tempestade": as faíscas nascem num anel em volta dele (ORB_START) e vão pra fora
##            em ondas. Perto dele é seguro, então quem luta de perto não para de bater; quem luta de
##            longe entra no olho ou desvia pelos buracos. Caem círculos vermelhos em dois heróis.
##   raid   — Trovoada: dano em todos, sem desvio. É o momento do curandeiro.
##   fan    — ventilador de raios rentes ao chão (PULE), com um círculo vermelho em CADA herói de
##            tempos em tempos: todo mundo se mexe, ninguém fica parado girando.
##   stack  — Comunhão: a party junta no círculo laranja pra dividir o dano. Fecha o ciclo reagrupando.
const STEPS_STORM := [
	{"t": "idle", "dur": 2.5},
	{"t": "leap", "dur": 1.8},
	{"t": "chase", "dur": 3.0},
	{"t": "buster", "dur": 3.0},
	{"t": "idle", "dur": 1.2},
	{"t": "orbs", "dur": 7.0},
	{"t": "raid", "name": "Trovoada", "ratio": 0.22, "dur": 3.0},
	{"t": "idle", "dur": 1.5},
	{"t": "fan", "dur": 12.0},
	{"t": "stack", "need": 4, "dur": 6.0},
	{"t": "idle", "dur": 2.0},
]
const JUMP_AIR := 0.55         # o pulo: tempo no ar ...
const JUMP_CD := 0.8           # ... recarga (do começo de um pulo ao próximo) ...
const JUMP_H := 1.7            # ... e altura
const LEAP_R := 3.2
const LEAP_DMG := 38.0
const LEAP_WAVE := 0.08        # onda de choque da queda: essa fração da vida de cada um
const CHASE_SPEED := 1.7
## Faíscas (bullet hell): ondas de ORB_COUNT bolinhas em roda, com ORB_GAPS buracos pra passar;
## cada onda sai um pouco girada em relação à anterior. Andam em linha reta e não seguem ninguém.
const ORB_COUNT := 12
const ORB_START := 5.4         # as faíscas nascem a essa distância dele: dentro disso é o olho da tempestade
const ORB_GAPS := 3
const ORB_WAVE := 0.95         # intervalo entre ondas
const ORB_SPEED := 4.2
const ORB_DMG := 8.0
const ORB_R := 0.4
const ORB_RED_AT := [2.2, 4.6] # nesses instantes da fase também caem os círculos vermelhos de sempre
const FAN_WARN := 1.6          # o ventilador aparece fino e parado por esse tempo antes de girar
const FAN_W := 0.45            # meia largura de cada raio
const FAN_DMG := 10.0
const FAN_INNER := 0.9         # colado no boss os raios ainda não pegam
const FAN_DROP := 4.0          # de quanto em quanto tempo cai um círculo vermelho em cada herói
const LEARN_EYE := 4.0         # passou a fase das faíscas sem tomar nenhuma: aprende o olho da tempestade
## [raios, velocidade em rad/s] conforme a vida do boss: acima de 66%, acima de 33%, e o resto.
const FAN_STAGES := [[3, 0.75], [4, 0.95], [5, 1.15]]
## Sem a carta de um ataque, a chance de o herói perceber (com conhecimento zero) e o atraso dele.
const AWARE_MIN := 0.3
const AWARE_LATE := 1.0
const LEARN_DODGED := 2.0      # estava dentro de um ataque e saiu a tempo, sem a carta: aprende
## Aprendizado do ventilador (Knowledge.learn, mecânica "fan"): quanto cada experiência ensina.
const LEARN_HIT := 1.0         # tomou o raio: aprende um pouco, de tanto apanhar
const LEARN_OWN := 3.0         # pulou e passou sozinho: repete o que deu certo
const LEARN_HAND := 6.0        # o jogador pulou e passou controlando este herói
const LEARN_WATCH := 1.5       # viu o jogador passar
## MEL-CHAN (boss "bee", que também anda): a abelha idol. Luta de DESVIO: pouco pra decorar, muito
## pra executar. Regra única: cada golpe dela que pega dá +1 coração (em cima da cabeça do herói); no
## 4º ele fica encantado, ela se cura e fica mais forte pra sempre. São três atos, pela vida dela
## (66% e 33%), cada um aberto por um Finale que limpa a arena e os corações. Os golpes saem de um
## saco embaralhado, sempre com uma folga depois (é a hora de bater).
##   wave   — Onda de Mel: barra baixa que atravessa a arena. PULE.
##   ring   — Batida do Palco: ela cai e solta ondas de choque em anel. PULE.
##   sting  — Rajada de Ferrões: leques mirados em quem o jogador controla (5 com um no meio, depois
##            4 com um vão no meio, alternando).
##   spiral — Chuva de Pólen: braços de bolinhas girando (do 2º ato em diante).
##   dive   — Mergulho: faixa vermelha e ela atravessa a arena.
##   slash  — Corte Ferroado: faixa larga em quem está no topo do aggro (depois pra trás e pros lados).
##   corações teleguiados entram por cima dos golpes do 2º ato em diante.
const STEPS_BEE := [{"t": "bee_idle", "dur": 2.5}]
const BEE_POOL := [
	["wave", "sting", "ring", "slash", "dive"],
	["wave", "sting", "ring", "slash", "dive", "spiral"],
	["wave", "sting", "ring", "slash", "dive", "spiral"],
]
## Duração de cada golpe em cada ato, e a folga depois dele.
const BEE_DUR := {
	"wave": [3.2, 3.6, 5.6], "ring": [2.8, 3.9, 4.6], "sting": [3.8, 4.6, 5.2],
	"slash": [2.0, 3.0, 4.0], "dive": [2.2, 3.5, 4.7], "spiral": [5.0, 5.5, 6.5],
}
const BEE_REST := [2.4, 1.9, 1.4]
const BEE_ACT_AT := [0.66, 0.33]
const BEE_HEARTS := 4          # no 4º coração o herói fica encantado
const BEE_CHARM := 3.0         # ... por esse tempo, parado e intocável
const BEE_IFRAMES := 0.75      # depois de tomar um golpe dela: um instante sem tomar outro
const BEE_HEAL := 0.015        # cada encantado cura isso da vida dela ...
const BEE_POWER_UP := 0.1      # ... e soma isso no dano dela, pra sempre
const BEE_POWER_MAX := 2.0
const BEE_AI_CHARM := 0.3      # quanto do ganho dela vale quando o encantado é da IA
const BEE_COL := Color(1.0, 0.45, 0.72)
const BEE_HONEY := Color(1.0, 0.78, 0.2)
const BEE_WAVE_W := 0.5
const BEE_WAVE_WARN := 1.0
const BEE_WAVE_SPEED := [7.0, 8.0, 9.0]
const BEE_RING_W := 0.45
const BEE_RING_SPEED := [5.5, 6.5, 7.5]
const BEE_SHOT_R := 0.36
const BEE_SHOT_SPEED := [7.5, 8.5, 9.5]
const BEE_SPIRAL_SPEED := 4.6
const BEE_HOMING_SPEED := 2.9
const BEE_HOMING_LIFE := 7.0
const BEE_CHASE := 2.2
const BEE_AI_SOFT := 0.6      # dano dos golpes dela em quem a IA controla
## HELL TIME: uma vez por luta ela volta pro meio do palco e fica uns 50 s soltando combinações
## em cima da batida da música (tools/hell_time_music.py gera o arquivo; os tempos são os mesmos).
const HELL_MUSIC := "res://assets/music/hell_time.wav"
const HELL_BEAT := 0.4        # 150 BPM
const HELL_PRE := 3.2         # dois compassos de subida antes do primeiro golpe
const HELL_BARS := 32
const HELL_AT_HP := 0.5       # começa quando a vida dela passa disso ...
const HELL_AT_TIME := 70.0    # ... ou a luta passa desse tempo, o que vier primeiro
const HELL_RING := 7.5
const HELL_WAVE := 9.0
const BEE_AI_SOFT_HELL := 0.4 # no HELL TIME a IA apanha ainda mais leve
const BEE_DMG := {"wave": 14.0, "ring": 14.0, "shot": 9.0, "dive": 30.0, "slash": 44.0, "homing": 6.0}
## Mesma ordem de Knowledge.BOSS_INFO.
const BOSSES := [
	{"name": "BISCOITO-KUN", "hp": 2600.0, "enrage": 100.0, "steps": STEPS_COOKIE, "look": "cookie", "hair": Color(0.86, 0.6, 0.3), "scale": 0.8},
	{"name": "MINI-CHAN", "hp": 7000.0, "enrage": 120.0, "steps": STEPS_DODGE, "finale": true, "hair": Color(0.25, 0.8, 0.9), "scale": 0.95},
	{"name": "PROTÓTIPO-CHAN", "hp": 10400.0, "enrage": 150.0, "steps": STEPS_ELEMENT, "elements": true, "hair": Color(1.0, 0.38, 0.66), "scale": 1.2},
	# haste: tudo dela (passos, avisos, casts) corre esse tanto mais rápido
	{"name": "FUSÃO-CHAN", "hp": 11500.0, "enrage": 165.0, "steps": STEPS_FUSION, "elements": true, "haste": 1.2, "hair": Color(0.75, 0.45, 1.0), "scale": 1.3},
	{"name": "TROVÃO-KUN", "hp": 3600.0, "enrage": 130.0, "steps": STEPS_STORM, "look": "storm", "roam": true, "arena": 13.5, "hair": Color(0.4, 0.8, 1.0), "scale": 1.0},
	{"name": "MEL-CHAN", "hp": 6200.0, "enrage": 215.0, "steps": STEPS_BEE, "look": "bee", "roam": true, "bee": true, "stage": true, "arena": 10.0, "hair": Color(1.0, 0.8, 0.25), "scale": 1.0},
]

## Treino livre (Knowledge.practice): um boneco no lugar da boss. Não ataca, não tem mecânica,
## não tem Fúria e não morre: quando a vida zera, ela enche de novo (DUMMY_HP por volta).
const DUMMY_HP := 20000.0
const DUMMY := {"name": "DUMMY DE TREINO", "hp": DUMMY_HP, "enrage": 1.0e9, "steps": [{"t": "idle", "dur": 60.0}],
	"look": "dummy", "hair": Color(0.9, 0.75, 0.4), "scale": 0.9}

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
## Onde a boss está pra tudo que mira nela (alcance, golpes, efeitos). Nas bosses de sempre é o ponto
## fixo no fundo da arena (BOSS_POINT). Numa boss que anda (boss_def "roam") ele muda durante a luta.
var boss_pos := BOSS_POINT
var roam := false
## Raio da arena desta luta (boss_def "arena"; o normal é ARENA_R).
var arena_r := ARENA_R
## Boss em foco (clique nela): mostra no chão até onde o herói que você controla alcança.
## Aprendizado das cartas: nesta luta, quem morreu (died[hero]) e quem tomou a mecânica de uma carta
## (card_fail[hero][id]). Na vitória, a carta de aprendizado equipada só rende se a luta foi limpa.
var died := {}
var card_fail := {}
## As mecânicas que de fato apareceram nesta luta (id da carta -> true). Carta de uma mecânica que
## não apareceu não ganha aprendizado: não dá pra provar o que não foi pedido.
var fight_mechs := {}
## Cartas que valem em qualquer luta (não dependem de uma mecânica da boss).
const ALWAYS_LEARN := ["dps", "instinct", "provoke"]
## Que cartas cada passo da boss põe à prova.
const PHASE_CARDS := {"spread": ["spread"], "buster": ["mitigate"], "linkcleave": ["link"], "mark": ["zone", "mark"],
	"zones": ["zone", "mark"], "cata": ["partner", "shelter", "mark"], "collapse": ["final"], "towers": ["final"]}
var boss_focus := false
var range_ring: MeshInstance3D
var range_ring_r := -1.0
## Estado do TROVÃO-KUN.
var storm_target: Unit = null
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO
var orbs: Array = []       # {"node", "dir": Vector3}
var orb_wave_t := 0.0
var orb_spin := 0.0
var orb_reds := 0
var eye_ring: MeshInstance3D   # o limite do olho da tempestade, no chão
var orb_hit := {}              # quem tomou faísca nesta fase (hero -> true)
var fan_rig: Node3D
var fan_beams: Array = []  # MeshInstance3D, um por raio
var fan_mat: StandardMaterial3D
var fan_angle := 0.0
var fan_speed := 0.0       # rad/s com sinal (o sentido)
var fan_on := false
var fan_drop_t := 0.0
var fan_flip_done := false
## Estado da MEL-CHAN.
var bee := false
var bee_act := 1
var bee_n := 0             # passos desde o começo do ato (ímpar = folga, par = golpe)
var bee_bag: Array = []
var bee_first := true
var bee_last := ""
var bee_power := 1.0       # multiplicador de dano dela (cresce a cada encantado)
var bee_charms := 0
var bee_hearts := [0, 0, 0, 0]
var bee_pip_nodes := {}    # idx do herói -> os corações em cima da cabeça
var bee_events: Array = [] # [instante dentro do passo, Callable], em ordem
var bee_tips := {}
var bee_focus: Unit = null
var bee_waves: Array = []
var bee_rings: Array = []
var bee_shots: Array = []
var bee_homing: Array = []
var bee_lift := 0.0
var bee_lift_tw: Tween
var bee_face := 0.0
var bee_aim_node: MeshInstance3D
var bee_aim_t := 0.0
var bee_spin := 0.0
var bee_spin_dir := 1.0
var bee_spin_flip := true
var bee_spiral_t := 0.0
var bee_hell := false      # HELL TIME rolando
var bee_hell_done := false
var bee_hell_dir := 0.0    # sentido do pólen no HELL TIME (0 = desligado)
var bee_hell_next := 0.0
var hell_player: AudioStreamPlayer
var hell_fire: Node3D
var hell_lights: Array = []
var hell_glow := 0.0       # 0..1: quanto o fogo está aceso
var hell_tw: Tween
var stage_env: Environment
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
var zenith_node: Node3D  # halo da Marca do Zênite em cima da boss (Soulburner)
var zenith_mats: Array = []
var rain_t := 0.0        # Chuva de Brasas caindo (só o visual; o dano é o DoT "chuva")
var rain_tick := 0.0
var rain_node: Node3D
var fairy_t := 0.0   # Fada Astral da Maga em campo
var fairy_node: Node3D
var fairy_owner: Unit
var fairy_shot := 0.0
var plain_hit := false  # o dano em curso não alimenta roubo de vida (DoT Pure Blood)
var aim_t := 0.0  # marca do Tiro Perfurante na boss (Maga)
var aim_node: Node3D
var dream_stacks := 0  # Vulnerabilidade Onírica (Sleepwalker)
var dream_t := 0.0
var echoes: Array = []  # Frestas dos Ecos do Pesadelo: {"wait", "open", "hit", "warned"}
var echo_mark: MeshInstance3D
var _tones := {}
## Valsa: a voluta no chão sob quem recebe o bônus (uma por herói), o fio dourado de cada Valsa até o
## Par dela (idx -> {"root", "beads", "rose"}) e o salão do Grande Baile.
var valsa_marks: Array = []
var valsa_threads := {}
var ball_node: Node3D
var ball_mat: ShaderMaterial
var ball_lamp: Node3D
var ball_spots: Array = []
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
## Acompanhamento da rotação de quem o jogador controla (ver ROT_SLOTS): por segundo, quanto o GCD
## ficou parado; por habilidade, há quanto tempo está pronta, e os atrasos dos últimos usos.
var rot_idle: Array[float] = []
var rot_idle_acc := 0.0
var rot_wait := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var rot_used := {}    # slot -> segundos desde o último uso
var rot_delays: Array[float] = []
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

var cam: Camera3D
var cam_home := Vector3.ZERO
var shake_t := 0.0   # tremor de câmera (impactos grandes)
var shake_amp := 0.0

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
		if a.begins_with("--know="):
			# só pra teste: todo mundo já entra sabendo esse tanto (0..100) do ventilador de raios
			for h in Knowledge.HEROES.size():
				Knowledge.know[h] = {"fan": float(a.trim_prefix("--know="))}
		if a.begins_with("--party="):
			# só pra teste: os quatro heróis da luta (índices de HEROES), sem tocar no save
			var picks: Array = []
			for p in a.trim_prefix("--party=").split(","):
				picks.append(int(p))
			if picks.size() == 4:
				Knowledge.party = picks
				Knowledge.start_hero = picks[0]
		if a.begins_with("--boss="):
			Knowledge.boss = clampi(int(a.trim_prefix("--boss=")), 0, BOSSES.size() - 1)
	if args.has("--practice"):
		Knowledge.practice = true
	boss_def = DUMMY if Knowledge.practice else BOSSES[Knowledge.boss]
	roam = boss_def.get("roam", false)
	bee = boss_def.get("bee", false)
	arena_r = float(boss_def.get("arena", ARENA_R))
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
		if args.has("--rot"):
			for u in units:
				Knowledge.dps_known[u.key] = true
				Knowledge.equip(u.hero, "dps")
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
	# brilho: tudo que emite luz (golpes, explosões, auras) estoura em volta, na cor do próprio efeito
	env.glow_enabled = true
	env.glow_intensity = 1.25
	env.glow_strength = 1.15
	env.glow_bloom = 0.3
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
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

	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	# arena maior: a câmera recua e sobe na mesma proporção, olhando mais pro chão (a boss de lá é baixa)
	var wide := arena_r / ARENA_R - 1.0
	cam.look_at_from_position(Vector3(0, 12.0 + wide * 11.0, 23.0 + wide * 14.0), Vector3(0, 5.0 - minf(wide, 1.0) * 4.0, -3.0 + wide * 2.0))
	cam_home = cam.position

	floor_mat = ShaderMaterial.new()
	var stage: bool = boss_def.get("stage", false)
	floor_mat.shader = preload("res://shaders/stage.gdshader") if stage else preload("res://shaders/floor.gdshader")
	floor_mat.set_shader_parameter("arena_r", arena_r + 0.35)
	floor_mat.set_shader_parameter("melee_center", Vector2(boss_pos.x, boss_pos.z))
	floor_mat.set_shader_parameter("melee_r", MELEE_RANGE)
	Fx.inst(self, Fx.disc(arena_r + (2.4 if stage else 0.7), 0.5), floor_mat, Vector3(0, -0.25, 0))

	if stage:
		_build_stage(env, rim)
	# colunas de luz no fundo, só pra dar profundidade (o palco tem o cenário dele)
	for i in (0 if stage else 9):
		var a := lerpf(-1.25, 1.25, i / 8.0)
		var p := Vector3(sin(a) * 26.0, 7.0, -cos(a) * 26.0 - 2.0)
		var col := Color(0.55, 0.25, 1.0) if i % 2 == 0 else Color(0.25, 0.5, 1.0)
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 22.0 + (i % 3) * 5.0, 0.35)
		Fx.inst(self, b, Fx.mat(col, 1.6, true), p)

	boss = preload("res://scripts/boss.gd").new()
	boss.hair_color = boss_def["hair"]
	boss.look = boss_def.get("look", "girl")
	boss_pos = Vector3.ZERO if roam else BOSS_POINT
	boss.position = boss_pos if roam else Vector3(0, 0, -13.3)
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


## Palco da MEL-CHAN: o chão de favo é do shader (stage.gdshader). Aqui entram o aro listrado em
## volta, a arquibancada em arco com a plateia de biscoitinhos e bastões de luz, os painéis do fundo
## e os holofotes. A frente fica aberta: é por onde a câmera olha.
func _build_stage(env: Environment, rim: OmniLight3D) -> void:
	stage_env = env
	_build_hell_fire()
	env.background_color = Color(0.09, 0.03, 0.12)
	env.ambient_light_color = Color(0.75, 0.62, 0.78)
	env.ambient_light_energy = 0.62
	env.fog_light_color = Color(0.2, 0.07, 0.2)
	env.fog_density = 0.0012
	rim.light_color = Color(1.0, 0.75, 0.4)
	var edge := arena_r + 2.6
	# aro listrado
	var seg := 44
	for n in seg:
		var a := n * TAU / seg
		var box := BoxMesh.new()
		box.size = Vector3(TAU * edge / seg * 1.03, 0.55, 0.55)
		var col := Color(0.8, 0.6, 0.15) if n % 2 == 0 else Color(0.14, 0.45, 0.58)
		var piece := Fx.inst(self, box, Fx.mat(col), Vector3(cos(a), 0, sin(a)) * edge + Vector3(0, -0.05, 0))
		piece.rotation.y = PI / 2.0 - a
	# arquibancada: três degraus em arco no fundo, cada bloco com três fãs
	var cookie := Fx.mat(Color(0.86, 0.6, 0.3))
	var chip := Fx.mat(Color(0.25, 0.13, 0.07))
	var sticks := [Fx.mat(Color(1.0, 0.45, 0.72), 0.7), Fx.mat(Color(1.0, 0.85, 0.3), 0.7), Fx.mat(Color(0.4, 0.9, 1.0), 0.7)]
	var blocks := 13
	for row in 3:
		var rad := arena_r + 5.4 + row * 2.5
		var top := 0.7 + row * 1.35
		# os fãs de cada degrau balançam em dois grupos, fora de fase
		var crowds: Array = []
		for g in 2:
			var crowd := Node3D.new()
			add_child(crowd)
			crowds.append(crowd)
			var tw := crowd.create_tween().set_loops()
			tw.tween_interval(0.21 * g + 0.07 * row)
			tw.tween_property(crowd, "position:y", 0.3, 0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(crowd, "position:y", 0.0, 0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.42 - 0.21 * g - 0.07 * row + 0.21)
		for n in blocks:
			var t := lerpf(-1.5, 1.5, n / float(blocks - 1))
			var a := -PI / 2.0 + t
			var out := Vector3(cos(a), 0, sin(a))
			var arc := 3.0 * rad / blocks
			var box := BoxMesh.new()
			box.size = Vector3(arc * 0.96, top + 1.0, 2.4)
			var col := Color(0.07, 0.3, 0.35) if (n + row) % 2 == 0 else Color(0.2, 0.11, 0.38)
			var block := Fx.inst(self, box, Fx.mat(col), out * rad + Vector3(0, (top - 1.0) * 0.5, 0))
			block.rotation.y = PI / 2.0 - a
			# faixa clara na beirada do degrau
			var lip := BoxMesh.new()
			lip.size = Vector3(arc * 0.96, 0.12, 0.3)
			var lip_node := Fx.inst(self, lip, Fx.mat(Color(0.7, 0.6, 0.55)), out * (rad - 1.1) + Vector3(0, top + 0.02, 0))
			lip_node.rotation.y = PI / 2.0 - a
			var side := Vector3(-out.z, 0, out.x)
			for f in 3:
				var crowd: Node3D = crowds[(n + f) % 2]
				var at := out * (rad - 0.2 + (f % 2) * 0.5) + side * ((f - 1) * arc * 0.3) + Vector3(0, top + 0.42, 0)
				var fan := Fx.inst(crowd, Fx.sphere(0.44), cookie, at)
				fan.scale = Vector3(1.0, 0.92, 0.7)
				fan.rotation.y = PI / 2.0 - a
				Fx.inst(fan, Fx.sphere(0.09), chip, Vector3(-0.15, 0.1, -0.42))
				Fx.inst(fan, Fx.sphere(0.09), chip, Vector3(0.15, 0.1, -0.42))
				var stick := Fx.inst(crowd, Fx.capsule(0.07, 0.7), sticks[(n + f + row) % 3], at + side * 0.5 + Vector3(0, 0.5, 0))
				stick.rotation.z = 0.35 if f % 2 == 0 else -0.35
	# painéis do fundo, em xadrez, e holofotes
	var walls := [Color(0.2, 0.07, 0.17), Color(0.24, 0.17, 0.05), Color(0.11, 0.07, 0.22), Color(0.05, 0.15, 0.2)]
	for n in 11:
		var a := -PI / 2.0 + lerpf(-1.35, 1.35, n / 10.0)
		var out := Vector3(cos(a), 0, sin(a))
		for lvl in 3:
			var box := BoxMesh.new()
			box.size = Vector3(6.3, 7.0, 0.5)
			var panel := Fx.inst(self, box, Fx.mat(walls[(n + lvl) % 4], 0.0, true), out * (arena_r + 17.0) + Vector3(0, 6.5 + lvl * 7.0, 0))
			panel.rotation.y = PI / 2.0 - a
	for n in 4:
		var a := -PI / 2.0 + lerpf(-1.0, 1.0, n / 3.0)
		var col := Color(1.0, 0.5, 0.8, 0.025) if n % 2 == 0 else Color(1.0, 0.9, 0.4, 0.025)
		var beam := Fx.inst(self, Fx.cyl(0.2, 1.6, 30.0), Fx.mat(col, 0.0, true), Vector3(cos(a), 0, sin(a)) * (arena_r + 9.0) + Vector3(0, 14.0, 0))
		beam.rotation.z = lerpf(0.35, -0.35, n / 3.0)
		beam.rotation.x = 0.3


func _build_units() -> void:
	for i in 4:
		var u := Unit.new()
		add_child(u)
		u.setup(i, UNIT_DEFS[Knowledge.hero_at(i)])
		u.hero = Knowledge.hero_at(i)
		u.position = _atk_pos(u) + Vector3(0, 0, 0.6 if u.melee else 0.9)
		u.face(boss_pos - u.position)
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
	# clique num boneco da party: foca; dois cliques: assume o controle dele
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := unit_at(event.position)
		if hit >= 0:
			click_unit(hit, event.double_click)
			get_viewport().set_input_as_handled()
			return
		if boss_at(event.position):
			# clique na boss: foca nela e mostra no chão o alcance de quem você controla
			boss_focus = not boss_focus
			get_viewport().set_input_as_handled()
			return
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
		"jump": jump(units[ctrl])
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
			elif id.begins_with("skill_") and n >= 0:
				# a tecla é da POSIÇÃO na barra; a habilidade que está lá vem da ordem escolhida na tela SKILLS.
				# O ataque básico vale enquanto segura, e quem lê é o _process.
				var me := units[ctrl]
				var s := Knowledge.skill_at(me.hero, n, kit(me).size())
				if s > 0:
					use_skill(me, s)


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
## A run foi abandonada: o que tinha sido ganho nela (cartas, maestria) é descartado.
func leave_fight(screen: String) -> void:
	Knowledge.abort_run()
	if not Knowledge.practice:
		Knowledge.attempts += 1
	Knowledge.screen = screen
	_reload()


## TENTAR NOVAMENTE do pause: recomeça a mesma luta do zero, com a mesma party, os mesmos baralhos
## e o mesmo herói no controle, sem passar pelos menus. Vale como abandonar a run: nada do que
## foi ganho nesta tentativa fica.
func retry_fight() -> void:
	Knowledge.abort_run()
	if not Knowledge.practice:
		Knowledge.attempts += 1
	Knowledge.screen = "cards"
	Knowledge.autostart = true
	_reload()


func start_fight() -> void:
	Knowledge.begin_run()
	prep = false
	hud.set_prep(false)
	intro_left = hud.play_intro()
	_fight_setup()


## Efeitos de carta que valem "no começo da luta".
func _fight_setup() -> void:
	for u in units:
		_spawn_cards(u)
		# equipamentos de atributo (tela de gear)
		var gs := Knowledge.gear_stats(u.hero)
		u.max_hp += float(gs["hp"])
		u.base_hp = u.max_hp
		u.hp = u.max_hp
		u.atk_range *= float(gs["range"])
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
	if roam:
		# boss que anda: cada um tem o seu lugar numa roda em volta dela (de perto ou de longe)
		var a := PI * 0.5 + (u.idx - 1.5) * 0.9
		var p := boss_pos + Vector3(cos(a), 0, sin(a)) * (ROAM_MELEE if u.melee else ROAM_RANGED)
		var flat := Vector2(p.x, p.z).limit_length(arena_r - 0.7)
		return Vector3(flat.x, 0, flat.y)
	return MELEE_POS[u.idx] if u.melee else RANGED_POS[u.idx]


## Um ponto de efeito pensado pra boss do fundo, levado pra onde a boss está agora. Nas bosses de
## sempre não muda nada; numa boss que anda (pequena, no meio da arena) o efeito vai junto e encolhe.
func _bp(v: Vector3) -> Vector3:
	if not roam:
		return v
	var o := v - BOSS_POINT
	return boss_pos + Vector3(o.x * 0.45, o.y * ROAM_FX_H, o.z * 0.2)


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
	Knowledge.practice = false
	Knowledge.boss = i
	Knowledge.attempts = 1
	Knowledge.screen = "cards"
	Knowledge.save()
	get_tree().reload_current_scene()


## Clique num card: escolhe aquele personagem como alvo das suas habilidades de suporte.
## Treino livre: recarrega a cena com o dummy no lugar da boss, já na tela de cartas.
func select_practice() -> void:
	Knowledge.practice = true
	Knowledge.attempts = 1
	Knowledge.screen = "cards"
	Knowledge.save()
	get_tree().reload_current_scene()


func select_target(i: int) -> void:
	sel = -1 if sel == i else i
	for u in units:
		u.chosen = u.idx == sel


## Põe o foco no herói `i` (alvo das curas, escudos e do reviver). Diferente de select_target, não
## desliga se ele já era o foco.
func focus_unit(i: int) -> void:
	sel = i
	for u in units:
		u.chosen = u.idx == sel


## Clique no card ou no boneco 3D: um clique foca; dois cliques trocam o controle pra ele.
## (morto não dá pra controlar: os dois cliques só focam, que é o que o reviver precisa)
func click_unit(i: int, twice: bool) -> void:
	focus_unit(i)
	if twice and i != ctrl and units[i].alive:
		set_ctrl(i)


## Qual boneco da party está embaixo desse ponto da tela (-1 = nenhum). Mede na tela, em volta do
## meio do corpo; com dois sobrepostos, vale o mais perto do clique.
## O clique caiu em cima da boss?
func boss_at(screen: Vector2) -> bool:
	var at := boss_pos + Vector3(0, 1.8 if roam else 6.0, 0)
	if cam.is_position_behind(at):
		return false
	return cam.unproject_position(at).distance_to(screen) < (95.0 if roam else 210.0)


## Boss em foco: um marcador de alvo embaixo dela, e (na boss que anda) o arco do alcance máximo do
## herói que você controla aparece no chão, centrado nela. Dentro do arco você bate; fora, não.
func _tick_range_ring() -> void:
	var me := units[ctrl]
	var on := boss_focus and me.alive and not prep and not ended
	if range_ring != null:
		range_ring.visible = on
	if not on:
		return
	if range_ring == null or not is_equal_approx(range_ring_r, me.atk_range):
		if range_ring != null:
			range_ring.queue_free()
		range_ring_r = me.atk_range
		# marcador de alvo embaixo da boss; o arco do alcance em si é desenhado pelo chão (shader)
		var mark := 2.0 if roam else 3.9
		range_ring = Fx.inst(self, Fx.torus(mark, mark + 0.12), Fx.mat(Color(1.0, 0.3, 0.4, 0.9), 0.0, true))
	range_ring.position = Vector3(boss_pos.x, 0.05, boss.position.z if not roam else boss_pos.z)
	range_ring.rotate_y(0.02)


func unit_at(screen: Vector2) -> int:
	var best := -1
	var best_d := 52.0
	for u in units:
		var at := u.position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(at):
			continue
		var d := cam.unproject_position(at).distance_to(screen)
		if d < best_d:
			best_d = d
			best = u.idx
	return best


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


## O pulo: um instante no ar, passando por cima de ataques rentes ao chão (o ventilador de raios).
## Não é invulnerabilidade: qualquer outro golpe acerta normalmente. Dá pra pular andando e conjurando.
func jump(u: Unit) -> bool:
	if not u.alive or u.asleep or u.hop_t > 0.0 or u.hop_cd > 0.0 or u.air_t > 0.0 or u.lock_t > 0.0:
		return false
	u.hop_t = JUMP_AIR
	u.hop_cd = JUMP_CD
	u.hop(JUMP_AIR, JUMP_H)
	return true


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
	if shake_t > 0.0:
		shake_t -= delta
		var sk := shake_amp * clampf(shake_t / 0.35, 0.0, 1.0)
		cam.position = cam_home + Vector3(randf_range(-sk, sk), randf_range(-sk, sk), 0.0)
		if shake_t <= 0.0:
			cam.position = cam_home
	_tick_boss(delta)
	if roam:
		_tick_storm(delta)
	if bee:
		_tick_bee(delta)
	_tick_range_ring()
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
	_tick_aim(delta)
	_tick_fairy(delta)
	_tick_zenith(delta)
	_tick_rain(delta)
	_tick_valsa_view(delta)
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
		if u.frenzy_t > 0.0:
			u.frenzy_t -= delta
			if u.frenzy_t <= 0.0:
				u.frenzy_t = 0.0
				if u.key == "assassina" and u.alive:
					# o Frenesi acabou: abre a janela da Última Dança
					u.finisher_t = FINISH_WINDOW
					_burst(u.position, Color(1.0, 0.3, 0.7), 3.0)
					if u.controlled:
						hud.toast("ÚLTIMA DANÇA!", 1.4)
		u.finisher_t = maxf(0.0, u.finisher_t - delta)
		u.count_t = maxf(0.0, u.count_t - delta)
		if u.key == "valsa":
			_tick_valsa(u, delta)
			if ended:
				return
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
				_mercy_hit(u, 2)
		if u.regen_t > 0.0:
			u.regen_t -= delta
			u.hp = minf(u.max_hp, u.hp + AEGIS_REGEN * delta)
		_tick_blood(u, delta)
		if ended:
			return
		u.lock_t = maxf(0.0, u.lock_t - delta)
		u.bath_t = maxf(0.0, u.bath_t - delta)
		u.poke_rush_t = maxf(0.0, u.poke_rush_t - delta)
		if u.bath_window > 0.0:
			u.bath_window -= delta
			if u.bath_window <= 0.0:
				u.bath_charges = 0  # passou o tempo de escolher
		u.haste_t = maxf(0.0, u.haste_t - delta)
		if u.salvo_t > 0.0:
			u.salvo_t -= delta
			if u.shield_hp <= 0.0 or u.shield_t <= 0.0:
				u.salvo_t = 0.0  # o escudo da Salva acabou ou foi quebrado
		if u.air_t > 0.0:
			u.air_t -= delta
			if u.air_t <= 0.0:
				_knockout_land(u)
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
		u.hop_t = maxf(0.0, u.hop_t - delta)
		u.hop_cd = maxf(0.0, u.hop_cd - delta)
		u.fan_safe_t = maxf(0.0, u.fan_safe_t - delta)
		u.fan_cross_t = maxf(0.0, u.fan_cross_t - delta)
		var before := u.position
		if u.controlled and not autoplay:
			if u.air_t <= 0.0 and u.lock_t <= 0.0:
				_tick_player(u, delta)
		else:
			if u.air_t <= 0.0 and u.lock_t <= 0.0:
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
	# o arco acompanha a boss (numa boss que anda, ele anda junto)
	floor_mat.set_shader_parameter("melee_center", Vector2(boss_pos.x, boss_pos.z))
	# o arco do alcance não fica na tela o tempo todo: só com a boss em foco (clique nela), e só pra quem
	# luta de perto. Quem ataca de longe alcança tudo, então não tem o que mostrar.
	floor_mat.set_shader_parameter("melee_on", 1.0 if me.alive and me.melee and boss_focus else 0.0)
	floor_mat.set_shader_parameter("melee_in", 1.0 if _in_range(me) else 0.0)
	_tick_side_mark()


func _print_report() -> void:
	print("--- REPORT ---")
	for line in log_lines:
		print("morte: ", line)
	print("acertos: ", hit_count)
	print("boss=", boss_def["name"], " ended=", ended, " won=", won, " boss_hp=", int(boss_hp), "/", int(boss_max), " phase=", phase, " t=", int(fight_time))
	for u in units:
		print(u.unit_name, " alive=", u.alive, " hp=", int(u.hp), " dps=", int(u.dmg_total / maxf(fight_time, 1.0)), " casts=", u.get_meta("ai_casts", 0), " fail=", u.get_meta("ai_fail", 0))
	for l in log_lines:
		print("LOG: ", l)


func _clamp_to_arena(u: Unit) -> void:
	var flat := Vector2(u.position.x, u.position.z)
	if flat.length() > arena_r:
		flat = flat.normalized() * arena_r
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
	if autoplay or Knowledge.practice or not u.alive or Knowledge.dps_known.has(u.key):
		return
	if rot_unit != u.idx:
		_rot_reset(u)
	rot_buckets.append(u.dmg_bucket)
	rot_idle.append(minf(1.0, rot_idle_acc))
	rot_idle_acc = 0.0
	if rot_buckets.size() > Knowledge.DPS_WINDOW:
		rot_buckets.pop_front()
		rot_idle.pop_front()
	for s in rot_used.keys():
		rot_used[s] += 1.0
	if rot_ok(u):
		Knowledge.dps_known[u.key] = true
		Knowledge.mark_new("dps", u.hero)  # entra na coleção dele como NOVA; equipar é com o jogador
		Knowledge.save()
		hud.card_unlocked("dps")


func _rot_reset(u: Unit) -> void:
	rot_unit = u.idx
	rot_buckets.clear()
	rot_idle.clear()
	rot_idle_acc = 0.0
	rot_wait = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	rot_used = {}
	rot_delays.clear()
	for s in u.skill_cd.size():
		u.set_meta("rot_cd%d" % s, u.skill_cd[s])


## A cada frame, pro herói no controle: mede o GCD parado e o atraso de cada habilidade de rotação.
func _rot_track(u: Unit, delta: float) -> void:
	if autoplay or Knowledge.practice or not u.alive or Knowledge.dps_known.has(u.key):
		return
	if rot_unit != u.idx:
		_rot_reset(u)
	var free: bool = u.channel_t <= 0.0 and u.lock_t <= 0.0 and u.air_t <= 0.0 and u.silence_t <= 0.0 and not u.asleep
	if free and u.skill_cd[0] <= 0.0 and _in_range(u):
		rot_idle_acc += delta
	for s in ROT_SLOTS[u.key]:
		var before: float = u.get_meta("rot_cd%d" % s, 0.0)
		var now: float = u.skill_cd[s]
		if now > 0.0 and before <= 0.0:
			# acabou de ser usada: guarda quanto ela esperou pronta
			rot_delays.append(rot_wait[s])
			if rot_delays.size() > 12:
				rot_delays.pop_front()
			rot_wait[s] = 0.0
			rot_used[s] = 0.0
		elif now <= 0.0 and free:
			rot_wait[s] += delta
		u.set_meta("rot_cd%d" % s, now)


## Os cinco critérios da carta Rotação (lista em cima de ROT_SLOTS). Devolve também o motivo que falta
## em rot_missing, pra teste e depuração.
var rot_missing := ""

func rot_ok(u: Unit) -> bool:
	var window: int = Knowledge.DPS_WINDOW
	if rot_buckets.size() < window:
		rot_missing = "janela"
		return false
	var sum := 0.0
	for b in rot_buckets:
		sum += b
	if sum / window < float(Knowledge.DPS_GOAL[u.key]):
		rot_missing = "dps"
		return false
	var idle := 0.0
	for v in rot_idle:
		idle += v
	if idle / window > ROT_IDLE_MAX:
		rot_missing = "gcd parado"
		return false
	for s in ROT_SLOTS[u.key]:
		if not rot_used.has(s) or float(rot_used[s]) > window:
			rot_missing = "habilidade %d não usada" % (s + 1)
			return false
		if rot_wait[s] > ROT_STALE:
			rot_missing = "habilidade %d esperando" % (s + 1)
			return false
	if not rot_delays.is_empty():
		var late := 0.0
		for d in rot_delays:
			late += d
		if late / rot_delays.size() > ROT_DELAY_MAX:
			rot_missing = "atraso médio"
			return false
	rot_missing = ""
	return true


# ---- IA com a carta Rotação

## A IA joga o kit do herói: escolhe a próxima habilidade pela prioridade da classe e usa. Devolve true
## se usou alguma coisa neste frame.
func _ai_rotation(u: Unit, delta: float) -> bool:
	for s in u.skill_cd.size():
		if u.skill_cd[s] > 0.0:
			u.ai_ready[s] = -1.0
		elif u.ai_ready[s] < 0.0:
			# voltou agora: ela leva um instante pra apertar (o básico e os passos de combo são na hora)
			u.ai_ready[s] = 0.1 if _rot_prompt(u, s) else randf_range(AI_REACT.x, AI_REACT.y)
		else:
			u.ai_ready[s] = maxf(0.0, u.ai_ready[s] - delta)
	var slot := _rot_pick(u)
	if slot < 0:
		return false
	if use_skill(u, slot, true):
		u.set_meta("ai_casts", int(u.get_meta("ai_casts", 0)) + 1)
		return true
	u.set_meta("ai_fail", int(u.get_meta("ai_fail", 0)) + 1)
	return false


func _rot_prompt(u: Unit, s: int) -> bool:
	if s == 0:
		return true
	return (u.key == "ringstar" and s <= 2) or (u.key == "sleepwalker" and s <= 4) or (u.key == "assassina" and s == 2)


func _rot_ready(u: Unit, s: int) -> bool:
	return u.skill_cd[s] <= 0.0 and u.ai_ready[s] == 0.0


## A prioridade de cada classe, respeitando a mecânica dela. -1 = nada pra usar agora.
func _rot_pick(u: Unit) -> int:
	match u.key:
		"tank":
			for s in [3, 1, 0]:
				if _rot_ready(u, s):
					return s
		"nurse":
			# versão segura: sem a Ultimate e sem pagar vida
			for s in [2, 0]:
				if _rot_ready(u, s):
					return s
		"healer":
			if _rot_ready(u, 0):
				return 0
		"assassina":
			if _rot_ready(u, 5):
				return 5
			var wound := get_dot("ferida")
			if _rot_ready(u, 2) and (wound.is_empty() or wound["t"] < 2.0):
				return 2  # mantém o Ferimento
			for s in [4, 3, 0]:
				if _rot_ready(u, s):
					return s
		"maga":
			var n := u.bullets.size()
			if n >= BULLET_MAX and _rot_ready(u, 5):
				return 5  # pente cheio: supercanhão
			if _rot_ready(u, 3):
				return 3  # marca a boss
			if aim_t > 0.0 and n >= SALVO_COST and n < BULLET_MAX and u.skill_cd[5] > 10.0:
				return 4  # estoura a marca com a Salva
			if u.pierce_next and _rot_ready(u, 0):
				return 0
			if n == SALVO_FAIRY and fairy_t <= 0.0 and u.skill_cd[5] > 16.0:
				return 4  # seis balas e o canhão longe: fada
			if fairy_t > 0.0 and _rot_ready(u, 2):
				return 2
			if n >= 1 and u.skill_cd[5] > 8.0 * (BULLET_MAX - n) and _rot_ready(u, 1):
				return 1  # não vai dar tempo de encher o pente: gasta
			if _rot_ready(u, 0):
				return 0
		"burner":
			var mark := get_dot("zenite")
			if mark.is_empty():
				if _rot_ready(u, 1):
					return 1
			else:
				if _rot_ready(u, 5):
					return 5  # o sol com a boss marcada
				if 1.0 - mark["t"] / mark["total"] >= LANCE_PERFECT - 0.1 and u.skill_cd[2] <= 0.0:
					return 2  # a lança no fim da marca
			if _rot_ready(u, 4):
				return 4
			if _rot_ready(u, 0):
				return 0
		"ringstar":
			for s in [3, 4, 5]:
				if _rot_ready(u, s):
					return s
			if _rot_ready(u, u.chain):
				return u.chain  # Jab, Direto, Gancho, na ordem
		"valsa":
			# o baile e o Crescendo quando voltam; pétalas só com alguém machucado; o resto, no compasso
			for s in [5, 4]:
				if _rot_ready(u, s):
					return s
			if _rot_ready(u, 3):
				for o in units:
					if o.alive and _in_dance(u, o) and o.hp / o.max_hp < 0.7:
						return 3
			for s in [1, 2, 0]:
				if _rot_ready(u, s):
					return s
		"apothecary":
			var rot := get_dot("decomp")
			if (rot.is_empty() or rot["t"] <= VESTIGE_WINDOW) and u.skill_cd[1] <= 0.0:
				return 1  # renova a Decomposição na janela do Vestígio
			if _rot_ready(u, 0):
				return 0
		"sleepwalker":
			# versão segura: só o Modo Acordado (dormindo ele ficaria parado no meio das mecânicas)
			if u.window_t > 0.0 and u.window_slot >= 1 and u.skill_cd[u.window_slot] <= 0.0:
				return u.window_slot
			if u.window_t <= 0.0 and _rot_ready(u, 1):
				return 1
			if _rot_ready(u, 0):
				return 0
	return -1


# ---------------------------------------------------------------- jogador

func _tick_player(u: Unit, delta: float) -> void:
	var moving := _input_dir() != Vector3.ZERO or u.dash_t > 0.0
	_rot_track(u, delta)
	if u.asleep:
		moving = false  # dormindo ele não sai do lugar: apertar direção não cancela a conjuração
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
			u.position += d * move_speed(u) * delta
			u.face(d)

	# J é o ataque básico: uma habilidade com 1 s de recarga (segurar repete)
	var want_attack := Input.is_action_pressed("skill_%d" % (Knowledge.pos_of(u.hero, 0, kit(u).size()) + 1))
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
	if u.has_meta("extracting"):
		# Extração Total: a barra só acompanha; quem resolve é o timer dela, e ela não anda
		u.channel_t = maxf(0.01, u.channel_t - delta)
		return true
	if moving:
		# andar ou esquivar interrompe qualquer cast, sem gastar a recarga
		u.cancel_ratio = 1.0 - u.channel_t / u.channel_total
		u.cancel_t = 0.7
		if u.channel_slot >= 0:
			u.skill_cd[u.channel_slot] = 0.0
		u.channel_t = 0.0
		_cannon_drop(u)
		_lance_drop(u)
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
	return u.position.distance_to(boss_pos) <= u.atk_range


# ---------------------------------------------------------------- IA da party

func _tick_ai(u: Unit, delta: float) -> void:
	if roam:
		_fan_ai(u, delta)
	if bee:
		_bee_ai(u, delta)
	# conjurando (a Cura da IA também tem cast): fica parado até soltar
	var i := u.idx
	var caster := u.key == "healer" or u.key == "maga"
	var careful := not caster or Knowledge.has(u.hero, "safe_cast")
	# Cautela: larga o cast (sem gastar a recarga) se um vermelho aparecer embaixo
	if u.channel_t > 0.0 and u.channel_slot >= 0:
		# com a carta Rotação, qualquer conjuração de ataque é largada se uma mecânica chamar pra outro lugar
		var must_move := false
		if Knowledge.has(u.hero, "dps") and not (u.key == "healer" and u.channel_slot != 0):
			var call = _card_plan(u)
			must_move = not stacks.is_empty() or (call != null and call[0] != null and u.position.distance_to(call[0]) > 0.3)
		if must_move or (careful and _danger_at(u.position, u, true, 0.1)):
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
	if roam:
		var storm = _storm_goal(u)
		if storm != null:
			goal = storm[0]
			text = storm[1]
			kind = 1
	if bee:
		var honey = _bee_goal(u)
		if honey != null:
			goal = honey[0]
			text = honey[1]
			kind = 1
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
			u.position += to / dist * minf(move_speed(u) * delta, dist)
			u.face(to)
		elif _in_range(u):
			u.face(boss_pos - u.position)

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
	# carta roxa Rotação: a IA joga o kit do herói de verdade, parada no lugar de ataque e fora de perigo
	if Knowledge.has(u.hero, "dps"):
		if _in_range(u) and not in_danger and stacks.is_empty() and (goal == null or u.position.distance_to(goal) < 0.3):
			if _ai_rotation(u, delta) and u.channel_t > 0.0:
				u.set_action("Conjurando", 1)
				return
			text = "Rotação"
		elif text == "Atacando":
			text = "Indo atacar"
		u.set_action(text, kind)
		return

	# Sem a carta: auto-ataque conservador, bem mais fraco que o jogador no controle.
	if _in_range(u):
		var rate: float = u.ai_dps
		_damage_boss(u, rate * delta, false, false)
		if u.key == "valsa":
			_ai_waltz(u, delta)
		if u.key == "nurse":
			# as estocadas da IA também roubam um fio de vida
			u.hp = minf(u.max_hp, u.hp + boss_hp * POKE_STEAL * delta)
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
	if target == null or Knowledge.practice:
		return  # o dummy não bate em ninguém
	if phase == "dodgetime":
		return  # conjurando o Dodge Time: ela não bate
	auto_t += delta
	if auto_t < AUTO_EVERY:
		return
	auto_t = 0.0
	var victim := target
	var from := _bp(Vector3(randf_range(-2.5, 2.5), 6.0, -11.5))
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
	# Assassina com a janela da Última Dança aberta: o botão do Frenesi vira a habilidade bônus (sem recarga)
	if u.key == "assassina" and slot == 5 and u.finisher_t > 0.0 and u.alive and u.lock_t <= 0.0 and intro_left <= 0.0:
		_last_dance(u)
		return true
	# Acordar (Sleepwalker dormindo, slot 6) é o único botão que interrompe uma conjuração em curso
	var wake_now: bool = u.key == "sleepwalker" and u.asleep and slot == 5
	if not u.alive or slot >= list.size() or list[slot] == null or u.skill_cd[slot] > 0.0 or (u.channel_t > 0.0 and not wake_now) or intro_left > 0.0:
		return false
	var sk: Dictionary = list[slot]
	if u.silence_t > 0.0 or u.air_t > 0.0 or u.lock_t > 0.0:
		return false  # punido por acordar mal, no meio do salto, ou segurando o supercanhão
	if sk["name"] == "Rainbow Shots" and u.bullets.is_empty():
		u.set_action("Sem balas", 2)
		return false  # sem Rainbow Shot guardada, a habilidade não sai (nem gasta o intervalo)
	if sk["name"] == "Salva Astral" and u.bullets.size() < SALVO_COST:
		u.set_action("Precisa de %d balas" % SALVO_COST, 2)
		return false
	var cast_time: float = sk.get("cast", 0.0)
	if u.key == "sleepwalker":
		if not _sw_can(u, slot):
			return false
		cast_time = sw_cast(u, slot)
	# segurar o ataque básico andando não fica começando e cancelando cast a cada frame
	if slot == 0 and cast_time > 0.0 and not by_ai and not u.asleep and _input_dir() != Vector3.ZERO:
		return false
	u.cast_target = null
	# (o Golpe de Misericórdia na mão do jogador é um salto até a boss: sai de qualquer distância)
	var leap: bool = sk["name"] == "Golpe de Misericórdia" and not by_ai
	if sk.has("dmg") and not _in_range(u) and not leap:
		u.set_action("Longe demais", 2)
		return false
	match sk["name"]:
		"Blood Taste":
			if u.party_t > 0.0:
				# durante o Blood Party este slot é a Extração: precisa encostar na boss
				if not _in_range(u):
					u.set_action("Longe demais", 2)
					return false
			elif u.taste_t > 0.0:
				return false
		"Blood Party":
			if u.stacks < PARTY_NEED or u.party_t > 0.0 or u.taste_t > 0.0:
				return false
		"Bloodbath":
			# de graça só o primeiro de cada Blood Party; fora isso, custa Sangue
			if not (u.party_t > 0.0 and u.bath_free) and u.stacks < BATH_COST:
				u.set_action("Precisa de %d de Sangue" % BATH_COST, 2)
				return false
		"Toque de Brasa", "Asa da Fênix", "Sutura", "Estabilização":
			var ht := _heal_target()
			# na sua mão, o alvo escolhido no card tem prioridade
			if not by_ai and sel >= 0 and units[sel].alive and units[sel].hp < units[sel].max_hp:
				ht = units[sel]
			# REVIVER
			# Soulflame, simples: com alguém caído, a Asa da Fênix vai nele (o escolhido no card primeiro).
			if sk["name"] == "Asa da Fênix" and _fallen() != null:
				ht = _fallen(-1 if by_ai else sel)
			# Apotecário, em etapas: 1) Sutura no aliado caído ESCOLHIDO no card prepara o corpo (ele
			# vira o Paciente); 2) Estabilização com os 3 Vestígios reanima o Paciente caído.
			if sk["name"] == "Sutura" and not by_ai and sel >= 0 and not units[sel].alive:
				ht = units[sel]
			if sk["name"] == "Estabilização" and u.patient != null and not u.patient.alive and u.patient_t > 0.0:
				if u.vestiges < REANIMATE_COST:
					u.set_action("Reanimar pede %d Vestígios" % REANIMATE_COST, 2)
					return false
				ht = u.patient
			if forced != null:
				ht = forced
			if ht == null:
				return false
			u.cast_target = ht
		"Passo a Dois":
			# o Par: o escolhido no card; sem escolha, o Par de agora; sem Par, quem mais bate
			var pt := _duet_pick(u, by_ai)
			if forced != null and forced != u:
				pt = forced
			if pt == null:
				u.set_action("Sem par", 2)
				return false
			u.cast_target = pt
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

	if cast_time > 0.0:
		var cast: float = cast_time
		if u.key == "sleepwalker":
			# a janela da sequência vale pra quem COMEÇA a conjurar dentro dela
			u.cast_perfect = u.window_slot == slot and u.window_t > 0.0
		# Golpe Lapidado: a Maga conjura o golpe forte mais rápido
		if u.key == "maga" and slot == BIG_SLOT["maga"] and Knowledge.has(u.hero, "burst"):
			cast -= 0.7
		u.channel_t = cast
		u.channel_total = cast
		u.channel_slot = slot
		if sk["name"] == "Canhão Estelar":
			_cannon_charge(u, cast)
		if sk["name"] == "Lança Serafim":
			_lance_charge(u, cast)
		u.cast_ai = by_ai
		if u.cast_target != null:
			# liga quem conjura a quem vai receber enquanto o cast corre
			u.face(u.cast_target.position - u.position)
			_beam(u.position, u.cast_target.position, Color(0.4, 1.0, 0.6, 0.7), cast + 0.15)
		elif sk.has("dmg") or u.key == "sleepwalker":
			u.face(boss_pos - u.position)
		# cast curto já gasta a recarga ao começar; cast longo só gasta se sair
		# (as conjurações do Sleepwalker sempre podem ser interrompidas andando, sem gastar nada)
		if sk.has("cast") and sk["cast"] < LOCKED_CAST:
			u.skill_cd[slot] = sk["cd"] * (1.15 if by_ai else 1.0)
		return true
	_resolve_skill(u, slot, by_ai)
	return true


func _resolve_skill(u: Unit, slot: int, by_ai: bool) -> void:
	var sk: Dictionary = kit(u)[slot]
	if u.key == "assassina":
		# as adagas batem no ritmo de cada golpe
		match slot:
			0: u.dagger_anim("cut")
			1: u.dagger_anim("thrust")
			2: u.dagger_anim("claws")
			3: u.dagger_anim("spin", DANCE_SPIN)
			4: u.dagger_anim("raise", MERCY_WINDOW if not by_ai else 0.25)
	if u.key == "ringstar":
		# as luvas acompanham cada habilidade (o SUPERSTAR! e o Nocaute animam por conta própria)
		u.face(boss_pos - u.position)
		match slot:
			0: u.glove_anim("jab")
			1: u.glove_anim("straight")
			2: u.glove_anim("hook")
			3: u.glove_anim("guard")
			5: u.glove_anim("raise", KNOCKOUT_AIR)
	if u.key == "valsa" and slot != 1:
		u.face(boss_pos - u.position)  # no Passo a Dois ela se vira pro Par
	if sk.get("big", false) and u.controlled and not by_ai:
		hud.skill_cut(u, sk["name"])  # habilidade importante, na mão do jogador: destaque de tela
	if u.key == "sleepwalker":
		_sleep_skill(u, slot)
		return
	if not (sk.has("cast") and sk["cast"] < LOCKED_CAST):
		u.skill_cd[slot] = sk.get("ai_cd", sk["cd"] * 1.15) if by_ai else sk["cd"]
	if u.key == "burner" and slot == 0:
		# Brasas: os 2 s de recarga contam desde o começo do cast (1 s conjurando + 1 s livre)
		u.skill_cd[slot] = maxf(0.0, u.skill_cd[slot] - float(sk["cast"]))
	if u.key == "assassina" and slot == 0 and not get_dot("ferida").is_empty():
		u.skill_cd[slot] = WOUND_GCD  # boss ferida: o Talho sai bem mais rápido
	if u.key == "assassina" and slot <= 2 and u.frenzy_t > 0.0:
		u.skill_cd[slot] *= FRENZY_HASTE  # Frenesi: Talho, Passo Rasante e Garras na metade da recarga
	elif slot == 0 and u.frenzy_t > 0.0:
		u.skill_cd[slot] *= FRENZY_HASTE
	if u.key == "assassina" and (slot == 0 or slot == 2):
		# Talho e Garras dividem a recarga
		u.skill_cd[2 - slot] = maxf(u.skill_cd[2 - slot], u.skill_cd[slot])
	if u.key == "ringstar" and slot <= 2:
		# os três golpes dividem a recarga; com a Contagem Regressiva ela cai pela metade
		var gcd: float = COUNT_GCD if u.count_t > 0.0 else sk["cd"]
		for n in 3:
			u.skill_cd[n] = gcd
	if u.key == "valsa" and slot == 0 and u.crescendo_t > 0.0:
		u.skill_cd[0] = CRESC_GCD  # Crescendo: o compasso acelera
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
		"Bloodbath":
			_bloodbath(u)
		"Blood Taste":
			if u.party_t > 0.0:
				_extract(u, _bath_use(u, slot))
				return
			var long_parry := _bath_use(u, slot)
			_parry_guard(u)
			# a vida vai a TASTE_HP por meio segundo; quando acaba, volta ao que era (ver _end_taste)
			u.taste_prev = u.hp
			u.max_hp = u.base_hp * TASTE_HP
			u.hp = u.max_hp
			u.taste_t = TASTE_TIME * (TASTE_BIG if long_parry else 1.0)
			u.taste_hit = false
			_burst(u.position, BLOOD, 2.4)
		"Emergency Response":
			# avança até encostar na boss (no máximo RUSH_DIST) e puxa ela pra si
			var to_boss := boss_pos - u.position
			to_boss.y = 0.0
			var go := clampf(to_boss.length() - (MELEE_RANGE - 1.0), 0.0, RUSH_DIST)
			u.face(to_boss)
			u.dash_fx()
			var rush_to := u.position + to_boss.normalized() * go
			# rastro vermelho do avanço
			for k in 3:
				_beam(u.position + Vector3(0, k * 0.4 - 0.4, 0), rush_to + Vector3(0, k * 0.4 - 0.4, 0), Color(BLOOD.r * 1.6, BLOOD.g, BLOOD.b, 0.9 - k * 0.25), 0.4 + k * 0.12)
			u.syringe_stab(1.4, 0.12)
			var tw := u.create_tween()
			tw.tween_property(u, "position", rush_to, 0.12)
			tw.tween_callback(func():
				_clamp_to_arena(u)
				# impacto físico na chegada: onda de energia no chão
				_impact_ring(u.position + Vector3(0, 0.4, 0), BLOOD.lightened(0.2), 3.6)
				_burst(u.position, Color(1, 1, 1), 1.8)
				shake_t = 0.18
				shake_amp = 0.22
				if u.alive and _in_range(u):
					u.punch()
					_damage_boss(u, RUSH_DMG, true, false))
			_taunt_mark()
			_add_stacks(u, RUSH_STACKS)
			_provoke(u, by_ai)
		"Blood Party":
			# gasta o gauge, joga o escudo fora e se injeta: fica com 1 de vida, não morre enquanto dura,
			# bate o dobro com recargas pela metade e vive do sangue que rouba. Regras em _tick_blood.
			u.stacks -= PARTY_NEED
			u.hp = 1.0
			u.party_hp = 1.0
			u.shield_hp = 0.0
			u.taste_t = 0.0
			u.max_hp = u.base_hp
			u.party_t = PARTY_TIME
			u.party_tick = 0.0
			for n in u.skill_cd.size():
				u.skill_cd[n] *= PARTY_CD
			# o Blood Party libera UM Bloodbath de graça, pronto na hora (o botão brilha pra avisar)
			u.bath_free = true
			u.skill_cd[5] = 0.0
			u.blood_party_start()
			hud.flash(BLOOD, 0.4)
			_burst(u.position, Color(1, 1, 1), 3.0)
			_burst(u.position, BLOOD, 6.5)
			for k in 3:
				_impact_ring(u.position + Vector3(0, 0.5 + k * 0.5, 0), BLOOD.lightened(k * 0.15), 3.0 + k * 1.4)
			shake_t = 0.35
			shake_amp = 0.4
			hud.toast("BLOOD PARTY: RECUPERE A VIDA TODA", 2.0)
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
			add_dot("zenite", "Marca do Zênite", FIRE, ZENITH_TIME, ZENITH_DPS, u)
			_zenith_halo()
			_burst(_bp(Vector3(0, 7.5, -12.5)), Color(1.0, 0.9, 0.45), 3.0)
		"Lança Serafim":
			_lance(u)
		"Rasante Incandescente":
			_swoop(u)
		"Chuva de Brasas":
			add_dot("chuva", "Chuva de Brasas", FIRE, RAIN_TIME, RAIN_DPS, u)
			_rain_start()
			for n in 8:
				_burst(_bp(Vector3(randf_range(-3.0, 3.0), randf_range(1.0, 5.0), -11.5)), FIRE, 1.0)
		"Juízo Solar":
			_solar(u)
		"Contagem Regressiva":
			_countdown(u)
		"SUPERSTAR!":
			_superstar(u)
		"Nocaute Final":
			_knockout_jump(u)
		"Passo a Dois":
			_duet(u)
		"Pirueta":
			_twirl(u)
		"Chuva de Pétalas":
			_petal_rain(u)
		"Crescendo":
			_crescendo(u)
		"Grande Baile":
			_grand_ball(u)
		"Passo Rasante":
			_dash_cut(u, sk["dmg"])
		"Garras Cruzadas":
			# três cortes seguidos, cada um com a silhueta dela num lugar
			for n in CLAW_HITS:
				get_tree().create_timer(n * CLAW_GAP, false).timeout.connect(_claw.bind(u, n, sk["dmg"]))
			if _in_range(u):
				_wound(u)
		"Dança Carmesim":
			_crimson_dance(u, sk["dmg"])
		"Golpe de Misericórdia":
			u.face(boss_pos - u.position)
			if by_ai:
				_mercy_hit(u)
			else:
				_mercy_leap(u)
		"Frenesi da Fera":
			u.frenzy_t = FRENZY_TIME
			u.frenzy_dmg = 0.0
			u.skill_cd[0] = 0.0
			_burst(u.position, Color(0.75, 0.2, 1.0), 4.0)
			hud.toast("FRENESI DA FERA", 1.4)
		"Bora Biscoitar":
			_provoke(u, by_ai)
		"Toque de Brasa", "Asa da Fênix", "Sutura", "Estabilização":
			var ht: Unit = u.cast_target
			if ht != null and not ht.alive:
				# o alvo está caído: é o caminho do reviver de cada healer
				if sk["name"] == "Asa da Fênix":
					_beam(u.position, ht.position, Color(1.0, 0.75, 0.3, 0.95), 0.4)
					_raise(ht, REVIVE_HP, FLAME)
					return
				if sk["name"] == "Sutura":
					# prepara o corpo: ele vira o Paciente. Falta a Estabilização com os 3 Vestígios.
					u.patient = ht
					u.patient_t = PATIENT_TIME
					_beam(u.position, ht.position, Color(CHEM.r, CHEM.g, CHEM.b, 0.95), 0.4)
					_impact_ring(ht.position + Vector3(0, 0.3, 0), CHEM, 2.0)
					if u.controlled:
						hud.toast("CORPO PREPARADO: Estabilização com %d Vestígios reanima" % REANIMATE_COST, 2.2)
					return
				if sk["name"] == "Estabilização" and u.patient == ht and u.vestiges >= REANIMATE_COST:
					u.vestiges -= REANIMATE_COST
					u.patient_t = PATIENT_TIME
					_beam(u.position, ht.position, Color(CHEM.r, CHEM.g, CHEM.b, 0.95), 0.4)
					_raise(ht, REANIMATE_HP, CHEM)
					if u.controlled:
						hud.toast("REANIMAÇÃO", 1.4)
					return
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
			u.face(boss_pos - u.position)
			u.punch()
			if u.key == "maga":
				_maga_basic_fx(u, slot)
			elif u.key == "burner":
				_ember_fx(u)
			elif u.key == "valsa":
				pass  # quem anima e desenha o passo é o _waltz_hit, logo abaixo
			else:
				_attack_fx(u, big)
			if sk.has("cast") and sk["cast"] >= LOCKED_CAST and slot != 0:
				_burst(_bp(Vector3(0, 4, -11.5)), u.color.lightened(0.3), 6.0)
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
					amount += _use_aim(u)  # com a boss marcada pelo Tiro Perfurante: estoura a marca
					big = true
					_beam(u.position, _bp(Vector3(0, 2.0, -13.0)), Color(1, 1, 1, 0.9), 0.25)
				if u.dash_next:
					u.dash_next = false
					_knock_back(u, 3.0)
			if u.key == "ringstar":
				amount = _combo_hit(u, slot, amount)
				big = amount > 30.0
			if u.key == "valsa":
				amount = _waltz_hit(u, amount)
				big = amount > 30.0
			if sk["name"] == "Talho Relâmpago":
				big = false
				if u.frenzy_t > 0.0:
					_afterimage(u, Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.5, 0.5)), Color(0.75, 0.2, 1.0))
					# em Frenesi, cada Talho adianta a Dança Carmesim e o Golpe de Misericórdia
					for s in [3, 4]:
						u.skill_cd[s] = maxf(0.0, u.skill_cd[s] - FRENZY_SHAVE)
				# do lado certo da boss: gasta um dos três golpes fortalecidos; acabou, troca de lado
				# (a IA com a carta Rotação conta como posicionada do lado certo)
				if (not by_ai and _side_of(u) == u.side_need) or (by_ai and Knowledge.has(u.hero, "dps")):
					amount *= SIDE_MULT
					big = true
					u.side_left -= 1
					if u.side_left <= 0:
						u.side_need = -u.side_need
						u.side_left = SIDE_HITS
						_burst(_side_pos(u.side_need), SIDE_COL, 2.4)
			if sk["name"] == "Tiro Perfurante":
				_aim_mark(u)
			if sk["name"] == "Baque do Escudo":
				# golpe de escudo: mais pesado na tela. (Interromper fica pra quando existir cast interrompível.)
				_burst(boss_pos + Vector3(0, 1.2, 2.0), Color(1.0, 0.95, 0.8), 2.6)
				boss.hit_flash()
			if sk["name"] == "Syringe Poke":
				# o roubo é em cima da vida ATUAL da boss: vai rendendo menos conforme a luta anda
				var steal := boss_hp * POKE_STEAL
				amount += steal
				_lifesteal(u, steal)
				_poke_fx(u)
				if _bath_use(u, slot):
					# fortalecido pelo Bloodbath: estocadas em rajada por alguns segundos
					u.poke_rush_t = POKE_RUSH_TIME
					_burst(u.position + Vector3(0, 1.0, 0), BLOOD, 2.6)
					if u.controlled:
						hud.toast("ESTOCADAS EM RAJADA", 1.0)
				if u.poke_rush_t > 0.0:
					u.skill_cd[slot] *= POKE_RUSH_CD
			elif sk["name"] == "Blood Consumed":
				amount += CONSUMED_STEAL
				_lifesteal(u, CONSUMED_STEAL)
				_add_stacks(u, CONSUMED_STACKS)
				_consumed_fx(u)
				if _bath_use(u, slot):
					_consumed_big(u)
			_damage_boss(u, amount, true, big)
	if u.key == "nurse" and u.party_t > 0.0:
		u.skill_cd[slot] *= PARTY_CD  # Blood Party: recargas pela metade
	# Malpractice: o golpe saiu, o sangue foi. Só na mão do jogador: a IA joga uma versão segura dela.
	if not by_ai and SELF_COST.has(sk["name"]):
		_bleed(u, SELF_COST[sk["name"]])


# ---------------------------------------------------------------- Assassina

## De que lado da boss o herói está: 1 = direita (x positivo), -1 = esquerda, 0 = no meio.
func _side_of(u: Unit) -> int:
	if roam:
		return u.side_need  # boss que anda: não existe "lado" dela; o Talho vale sempre
	if u.position.x - boss_pos.x > SIDE_MIN:
		return 1
	if u.position.x - boss_pos.x < -SIDE_MIN:
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
	if flat.length() > arena_r:
		flat = flat.normalized() * arena_r
		to = Vector3(flat.x, 0, flat.y)
	u.face(to - from)
	u.dash_fx()
	u.invuln = maxf(u.invuln, 0.2)
	_beam(from, to, SIDE_COL, 0.5)
	_afterimage(u, Vector3.ZERO, SIDE_COL)
	var tw := u.create_tween()
	tw.tween_property(u, "position", to, 0.1)
	tw.tween_callback(func():
		u.face(boss_pos - u.position)
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


## Dano direto, sem nenhum multiplicador (o estouro da Última Dança).
func _raw_hit(u: Unit, dmg: float, size := 84) -> void:
	if ended or dmg <= 0.0:
		return
	boss_hp -= dmg
	u.dmg_total += dmg
	u.dmg_bucket += dmg
	u.enmity += dmg
	boss.hit_flash()
	_popup(int(round(dmg)), Color(1.0, 0.45, 1.0), size)
	if boss_hp <= 0.0:
		if Knowledge.practice:
			boss_hp = boss_max
			hud.toast("O dummy se recompôs", 1.6)
			return
		boss_hp = 0.0
		_end(true)


## Os golpes do Golpe de Misericórdia. `part`: 0 = o corte inteiro de uma vez (IA); 1 = a cravada com as
## duas adagas no chão (MERCY_FIRST do dano); 2 = o mergulho que fecha (o resto).
func _mercy_hit(u: Unit, part := 0) -> void:
	var strong := u.mercy_frenzy
	if part != 1:
		u.mercy_frenzy = false
		u.visual.rotation.z = 0.0
		u.visual.rotation.x = 0.0
		u.visual.position.y = 0.0
	if not u.alive or not _in_range(u):
		u.remove_meta("mercy_amt")
		return
	var base: float = SKILLS["assassina"][BIG_SLOT["assassina"]]["dmg"]
	var missing := 1.0 - clampf(boss_hp / boss_max, 0.0, 1.0)
	var wounded := not get_dot("ferida").is_empty()
	var amount := base
	if part == 2 and u.has_meta("mercy_amt"):
		# o total já foi calculado na cravada
		amount = u.get_meta("mercy_amt")
		missing = u.get_meta("mercy_missing", missing)
		wounded = u.get_meta("mercy_wounded", wounded)
	else:
		if Knowledge.has(u.hero, "burst"):
			amount *= 1.3
		if strong:
			amount *= MERCY_FRENZY
		# execução: quanto menos vida a boss tem, mais forte; com Ferimento, mais ainda (e o Ferimento é renovado)
		amount *= 1.0 + MERCY_EXEC * missing
		if wounded:
			amount *= MERCY_WOUND
			_wound(u)
	var total := amount
	if part == 1:
		u.set_meta("mercy_amt", amount)
		u.set_meta("mercy_missing", missing)
		u.set_meta("mercy_wounded", wounded)
		_mercy_slam(u, strong)
		_damage_boss(u, amount * MERCY_FIRST, true, false)
		return
	if part == 2 and u.has_meta("mercy_amt"):
		u.remove_meta("mercy_amt")
		amount *= 1.0 - MERCY_FIRST
	u.punch()
	_attack_fx(u, true)
	var at := boss_pos + Vector3(0, 1.6, 1.6)
	var col := Color(0.75, 0.2, 1.0) if strong else Color(1.0, 0.95, 0.9)
	_burst(at, Color(1, 1, 1), 3.0)
	_burst(at, col, 4.2 if strong else 3.0)
	# o corte: duas lâminas de luz cruzadas no ponto do golpe
	for k in 2:
		var slash := BoxMesh.new()
		slash.size = Vector3(0.16, 5.2 if strong else 3.8, 0.08)
		var sm := Fx.mat(Color(col.r * 2.2, col.g * 2.2, col.b * 2.2, 0.95), 0.0, true)
		var mi := Fx.inst(fx_root, slash, sm, at + Vector3(0, 1.0, 0.2))
		mi.rotation.z = (0.75 if k == 0 else -0.75)
		mi.scale = Vector3(1.0, 0.1, 1.0)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.08)
		tw.tween_property(sm, "albedo_color:a", 0.0, 0.3).set_delay(0.08)
		tw.chain().tween_callback(mi.queue_free)
	_impact_ring(at, col, 4.5 if strong else 3.2)
	# o chão racha embaixo dela e uma coluna de luz sobe do golpe
	_impact_ring(u.position + Vector3(0, 0.2, 0), col, 3.4)
	var pc := Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.8)
	var pm := Fx.mat(pc, 0.0, true)
	var pillar := Fx.inst(fx_root, Fx.cyl(0.9, 1.2, 14.0), pm, at + Vector3(0, 5.0, 0))
	var tpl := pillar.create_tween().set_parallel(true)
	tpl.tween_property(pillar, "scale", Vector3(0.05, 1.1, 0.05), 0.45).set_ease(Tween.EASE_IN)
	tpl.tween_property(pm, "albedo_color:a", 0.0, 0.45)
	tpl.chain().tween_callback(pillar.queue_free)
	for n in 10:
		var a := n * TAU / 10.0
		var sp := Fx.inst(fx_root, Fx.sphere(0.12), Fx.mat(Color(col.r * 1.6, col.g * 1.6, col.b * 1.6), 0.0, true), at)
		var ts := sp.create_tween().set_parallel(true)
		ts.tween_property(sp, "position", at + Vector3(cos(a), sin(a), 0.2) * randf_range(2.0, 4.0), 0.4).set_ease(Tween.EASE_OUT)
		ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.4)
		ts.chain().tween_callback(sp.queue_free)
	if u.controlled:
		# brilho nas bordas da tela: mais forte quanto mais o golpe executou
		hud.edge_glow(col, 0.5 + missing * 0.5 + (0.3 if strong else 0.0))
		if missing >= 0.5 or wounded:
			hud.toast("EXECUÇÃO  +%d%%" % roundi((total / base - 1.0) * 100.0), 1.0)
	if strong:
		_impact_ring(at, Color(1, 1, 1), 6.5)
		hud.flash(Color(0.75, 0.2, 1.0), 0.2)
		shake_t = 0.35
		shake_amp = 0.45
	else:
		hud.flash(Color(1, 1, 1), 0.12)
		shake_t = 0.25
		shake_amp = 0.32
	boss.hit_flash()
	_damage_boss(u, amount, true, true)


## A cravada: ela chega puxada pela adaga e enterra as duas no chão, na frente da boss.
func _mercy_slam(u: Unit, strong: bool) -> void:
	var col := Color(0.75, 0.2, 1.0) if strong else Color(1.0, 0.95, 0.9)
	var at := u.position + Vector3(0, 0.15, 0)
	u.punch()
	_attack_fx(u, false)
	_burst(at, Color(1, 1, 1), 2.2)
	_burst(at, col, 3.0)
	_impact_ring(at, col, 3.0)
	_impact_ring(at, Color(1, 1, 1), 1.8)
	# rachaduras: riscos de luz que abrem do ponto da cravada
	for n in 7:
		var a := n * TAU / 7.0 + randf() * 0.4
		var crack := BoxMesh.new()
		crack.size = Vector3(0.1, 0.04, randf_range(1.6, 3.0))
		var cm := Fx.mat(Color(col.r * 2.4, col.g * 2.4, col.b * 2.4, 0.95), 0.0, true)
		var mi := Fx.inst(fx_root, crack, cm, at + Vector3(cos(a), 0, sin(a)) * crack.size.z * 0.5)
		mi.rotation.y = PI / 2.0 - a
		var tw := mi.create_tween()
		tw.tween_property(cm, "albedo_color:a", 0.0, 0.45).set_delay(0.08)
		tw.tween_callback(mi.queue_free)
	hud.flash(col, 0.1)
	shake_t = 0.18
	shake_amp = 0.3


## Golpe de Misericórdia na mão do jogador (MERCY_WINDOW no total):
##   1. ela arremessa uma adaga, que crava no chão na frente da boss;
##   2. se puxa por ela num rasante e enterra as duas adagas no chão (a cravada, em MERCY_LAND);
##   3. sobe num pulo seco e mergulha: o corte que fecha, no fim da janela.
## Durante tudo ela está presa na animação. Se um golpe chegar nesse tempo, ela o apara e o resto NÃO
## sai. Em Frenesi da Fera: não toma dano, os dois golpes saem de qualquer jeito, batem mais forte, e ela
## faz o caminho todo girando com as adagas abertas, como uma serra.
func _mercy_leap(u: Unit) -> void:
	var strong := u.frenzy_t > 0.0
	u.mercy_frenzy = strong
	u.remove_meta("mercy_amt")
	u.parry_t = MERCY_WINDOW
	u.parry_hit = false
	u.lock_t = MERCY_WINDOW
	var from := u.position
	var to_boss := boss_pos - from
	to_boss.y = 0.0
	var dist := maxf(0.0, to_boss.length() - (MELEE_RANGE - 1.2))
	var fwd := to_boss.normalized()
	var to := from + fwd * dist
	var col := Color(0.75, 0.2, 1.0) if strong else u.color.lightened(0.3)
	var hot := Color(col.r * 2.4, col.g * 2.4, col.b * 2.4)
	var t_throw := 0.16
	var t_pull := MERCY_LAND - t_throw - 0.02
	var t_up := (MERCY_WINDOW - MERCY_LAND) * 0.58
	var t_down := MERCY_WINDOW - MERCY_LAND - t_up
	u.face(fwd)
	_burst(from, col, 2.0)
	if u.controlled:
		hud.edge_glow(col, 0.45)
		if strong:
			hud.toast("MISERICÓRDIA EM FRENESI", 1.0)
	# 1. a adaga arremessada, com o fio de luz que a liga à mão dela
	u.dagger_anim("thrust", 0.2)
	var knife := Node3D.new()
	fx_root.add_child(knife)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.12, 0.12, 0.95)
	Fx.inst(knife, blade, Fx.mat(Color(2.6, 2.6, 2.8), 0.0, true), Vector3.ZERO)
	Fx.inst(knife, Fx.sphere(0.2), Fx.mat(hot, 0.0, true), Vector3(0, 0, 0.5))
	var hand := from + Vector3(0, 1.1, 0)
	var stuck := to + fwd * 0.9 + Vector3(0, 0.25, 0)
	knife.position = hand
	knife.look_at(stuck + Vector3(0, -0.6, 0), Vector3.UP)
	var wire := BoxMesh.new()
	wire.size = Vector3(0.05, 0.05, 1.0)
	var wm := Fx.mat(Color(hot.r, hot.g, hot.b, 0.9), 0.0, true)
	var line := Fx.inst(fx_root, wire, wm, hand)
	var stretch := func():
		if not is_instance_valid(line) or not is_instance_valid(knife) or not is_instance_valid(u):
			return
		var a: Vector3 = u.position + Vector3(0, 1.1 + u.visual.position.y, 0)
		var b: Vector3 = knife.position
		var len := a.distance_to(b)
		line.visible = len > 0.3
		if line.visible:
			line.position = (a + b) * 0.5
			line.look_at(b, Vector3.UP)
			line.scale = Vector3(1, 1, len)
	var tk := knife.create_tween()
	tk.tween_method(func(t: float):
		knife.position = hand.lerp(stuck, t)
		stretch.call(), 0.0, 1.0, t_throw).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tk.tween_callback(func():
		_burst(stuck, col, 1.4)
		_impact_ring(stuck, col, 1.2))
	# em Frenesi: a serra, um disco de lâminas que gira com ela a animação inteira
	var saw: Node3D = null
	if strong:
		saw = Node3D.new()
		u.visual.add_child(saw)
		saw.position = Vector3(0, 1.0, 0)
		for k in 4:
			var tooth := BoxMesh.new()
			tooth.size = Vector3(0.1, 3.4, 0.34)
			var tm := Fx.inst(saw, tooth, Fx.mat(Color(2.6, 1.2, 3.0, 0.9), 0.0, true), Vector3.ZERO)
			tm.rotation.x = k * PI / 4.0
		var rim := Fx.inst(saw, Fx.torus(1.55, 1.75), Fx.mat(Color(2.0, 0.5, 2.6, 0.75), 0.0, true), Vector3.ZERO)
		rim.rotation.z = PI / 2.0
		u.dagger_anim("spin", MERCY_WINDOW)
	# 2 e 3. o corpo: rasante puxado pela adaga, cravada, pulo seco e mergulho
	var tw := u.create_tween()
	tw.tween_interval(t_throw)
	tw.tween_method(func(t: float):
		u.position = from.lerp(to, t)
		u.visual.position.y = sin(t * PI) * 0.9
		u.visual.rotation.x = t * TAU * 3.0 if strong else -0.55 * sin(t * PI)
		stretch.call(), 0.0, 1.0, t_pull).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		u.position = to
		u.visual.position.y = 0.0
		if not strong:
			u.visual.rotation.x = 0.0
		if is_instance_valid(knife):
			knife.queue_free()
		if is_instance_valid(line):
			line.queue_free()
		# a cravada só sai se ninguém a acertou no caminho (em Frenesi, sai sempre)
		if u.alive and u.lock_t > 0.0 and (strong or not u.parry_hit):
			_mercy_hit(u, 1)
			if not strong:
				u.dagger_anim("raise", t_up + t_down))
	tw.tween_interval(0.02)
	tw.tween_method(func(t: float):
		u.visual.position.y = t * 4.4
		if strong:
			u.visual.rotation.x = TAU * 3.0 + t * TAU * 2.0, 0.0, 1.0, t_up).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float):
		u.visual.position.y = (1.0 - t) * 4.4
		if strong:
			u.visual.rotation.x = TAU * 5.0 + t * TAU * 3.0, 0.0, 1.0, t_down).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		u.visual.position.y = 0.0
		u.visual.rotation.x = 0.0
		u.visual.rotation.z = 0.0
		if saw != null and is_instance_valid(saw):
			saw.queue_free()
		u.face(boss_pos - u.position))
	# rastro: silhuetas pelo caminho; em Frenesi, mais delas e anéis de corte
	var ghosts := 12 if strong else 6
	for n in ghosts:
		get_tree().create_timer(MERCY_WINDOW * (n + 1) / (ghosts + 1.0), false).timeout.connect(func():
			if is_instance_valid(u) and u.alive and u.lock_t > 0.0:
				_afterimage(u, Vector3(0, u.visual.position.y, 0), col)
				if strong:
					_impact_ring(u.position + Vector3(0, 1.0 + u.visual.position.y, 0), col, 1.8))


## Última Dança: a habilidade bônus do fim do Frenesi. Ela some num borrão; uma tempestade de cortes
## atravessa a boss vindo de todos os lados, cada um com a silhueta dela; então ela reaparece no alto e
## fecha com um X gigante que racha a arena. Durante tudo isso ela é intocável.
func _last_dance(u: Unit) -> void:
	u.finisher_t = 0.0
	u.lock_t = FINISH_LOCK
	u.invuln = maxf(u.invuln, FINISH_LOCK)
	u.channel_t = 0.0
	var echo := u.frenzy_dmg * FINISH_ECHO
	u.frenzy_dmg = 0.0
	if u.controlled:
		hud.skill_cut(u, "Última Dança")
		hud.toast("ÚLTIMA DANÇA", 1.6)
		hud.flash(Color(0.45, 0.05, 0.7), 0.5)
		hud.edge_glow(Color(0.8, 0.25, 1.0), 1.0)
	var purple := Color(0.8, 0.25, 1.0)
	var pink := Color(1.0, 0.3, 0.7)
	var green := SIDE_COL
	var center := _bp(Vector3(0, 4.2, -11.2))
	var home := boss_pos + Vector3(0, 0, MELEE_RANGE - 1.2)
	# o preparo: ela se agacha em posição de ataque, as adagas cruzadas, a energia juntando nos pés
	u.face(boss_pos - u.position)
	u.dagger_anim("both", FINISH_WINDUP)
	var crouch := u.visual.create_tween()
	crouch.tween_property(u.visual, "scale", Vector3(1.2, 0.62, 1.2), FINISH_WINDUP * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	crouch.parallel().tween_property(u.visual, "rotation:x", -0.35, FINISH_WINDUP * 0.7)
	crouch.tween_property(u.visual, "scale", Vector3(0.8, 1.35, 0.8), 0.06)
	for k in 4:
		get_tree().create_timer(k * FINISH_WINDUP / 4.0, false).timeout.connect(func():
			if not is_instance_valid(u) or not u.alive:
				return
			# anéis que fecham em cima dela
			var gm := Fx.mat(Color(purple.r * 2.2, purple.g * 2.2, purple.b * 2.2, 0.0), 0.0, true)
			var gather := Fx.inst(fx_root, Fx.torus(0.9, 1.0), gm, u.position + Vector3(0, 0.25, 0))
			gather.scale = Vector3.ONE * (4.2 - k * 0.5)
			var tg := gather.create_tween().set_parallel(true)
			tg.tween_property(gather, "scale", Vector3.ONE * 0.3, FINISH_WINDUP / 3.0).set_ease(Tween.EASE_IN)
			tg.tween_property(gm, "albedo_color:a", 0.9, FINISH_WINDUP / 3.0)
			tg.chain().tween_callback(gather.queue_free))
	await get_tree().create_timer(FINISH_WINDUP, false).timeout
	if not is_instance_valid(u):
		return
	u.visual.scale = Vector3.ONE
	u.visual.rotation.x = 0.0
	if ended or not u.alive:
		return
	# ... e VAI
	_burst(u.position, purple, 3.2)
	_burst(u.position, Color(1, 1, 1), 2.0)
	_impact_ring(u.position + Vector3(0, 0.2, 0), purple, 4.5)
	_beam(u.position + Vector3(0, 1.0, 0), center, Color(1, 1, 1, 0.9), 0.18)
	_afterimage(u, Vector3.ZERO, purple)
	shake_t = 0.2
	shake_amp = 0.35
	u.visual.visible = false
	u.position = home
	# a tempestade de cortes
	var storm := FINISH_TIME * 0.62
	for n in FINISH_HITS:
		get_tree().create_timer(0.12 + storm * n / FINISH_HITS, false).timeout.connect(func():
			if ended or not is_instance_valid(u) or not u.alive:
				return
			var col: Color = [purple, pink, green, Color(1, 1, 1)][n % 4]
			# cortes quase deitados, que atravessam a arena de lado a lado
			var a := randf_range(-0.42, 0.42) + (PI if n % 2 == 1 else 0.0)
			var dir := Vector3(cos(a), sin(a), 0)
			# o risco do corte atravessando a boss
			var slash := BoxMesh.new()
			slash.size = Vector3(0.24, 30.0 + randf() * 10.0, 0.08)
			var sm := Fx.mat(Color(col.r * 3.4, col.g * 3.4, col.b * 3.4, 0.95), 0.0, true)
			var mi := Fx.inst(fx_root, slash, sm, center + Vector3(randf_range(-1.2, 1.2), randf_range(-2.6, 2.6), 0.6))
			mi.rotation.z = a + PI / 2.0
			mi.scale = Vector3(1.0, 0.05, 1.0)
			var tw := mi.create_tween().set_parallel(true)
			tw.tween_property(mi, "scale", Vector3.ONE, 0.05)
			tw.tween_property(sm, "albedo_color:a", 0.0, 0.28).set_delay(0.05)
			tw.chain().tween_callback(mi.queue_free)
			# o miolo branco do corte, que fica um instante a mais
			var core := BoxMesh.new()
			core.size = Vector3(0.06, slash.size.y, 0.1)
			var core_m := Fx.mat(Color(4.0, 4.0, 4.0, 1.0), 0.0, true)
			var ci := Fx.inst(fx_root, core, core_m, mi.position + Vector3(0, 0, 0.05))
			ci.rotation.z = mi.rotation.z
			var tc := ci.create_tween()
			tc.tween_property(core_m, "albedo_color:a", 0.0, 0.5).set_delay(0.12)
			tc.tween_callback(ci.queue_free)
			_burst(mi.position, col, 2.2)
			# a tela vai ficando branca a cada corte, até estourar no fim
			hud.flash(Color(1, 1, 1), 0.1 + 0.5 * (n + 1.0) / FINISH_HITS)
			# a silhueta dela passando
			var ghost := Fx.inst(fx_root, Fx.capsule(0.38, 1.3), Fx.mat(Color(col.r, col.g, col.b, 0.7), 0.0, true), mi.position + dir * 13.0)
			var tg := ghost.create_tween().set_parallel(true)
			tg.tween_property(ghost, "position", mi.position - dir * 13.0, 0.1)
			tg.tween_property(ghost, "scale", Vector3.ONE * 0.3, 0.2)
			tg.chain().tween_callback(ghost.queue_free)
			_impact_ring(center + dir * randf_range(-1.5, 1.5), col, 1.6)
			shake_t = 0.12
			shake_amp = 0.22
			boss.hit_flash()
			_damage_boss(u, FINISH_HIT, true, false))
	# ela reaparece no alto, com as adagas erguidas
	get_tree().create_timer(0.12 + storm + 0.08, false).timeout.connect(func():
		if not is_instance_valid(u) or not u.alive:
			return
		u.visual.visible = true
		u.face(boss_pos - u.position)
		u.visual.position.y = 6.5
		u.dagger_anim("raise", FINISH_TIME - storm - 0.4)
		_burst(u.position + Vector3(0, 6.5, 0), Color(1, 1, 1), 2.6)
		u.visual.create_tween().tween_property(u.visual, "position:y", 0.0, FINISH_TIME - storm - 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN))
	# o X gigante
	get_tree().create_timer(FINISH_TIME - 0.08, false).timeout.connect(func():
		if is_instance_valid(u):
			u.visual.visible = true
			u.visual.position.y = 0.0
		if ended or not is_instance_valid(u) or not u.alive:
			return
		for k in 2:
			for layer in 2:
				var big := BoxMesh.new()
				big.size = Vector3(0.9 - layer * 0.5, 17.0, 0.1)
				var lc: Color = [purple, Color(1, 1, 1)][layer]
				var bm := Fx.mat(Color(lc.r * 2.4, lc.g * 2.4, lc.b * 2.4, 0.95), 0.0, true)
				var mi := Fx.inst(fx_root, big, bm, center + Vector3(0, 0, 0.8 + layer * 0.05))
				mi.rotation.z = 0.78 if k == 0 else -0.78
				mi.scale = Vector3(1.0, 0.05, 1.0)
				var tw := mi.create_tween().set_parallel(true)
				tw.tween_property(mi, "scale", Vector3.ONE, 0.07)
				tw.tween_property(bm, "albedo_color:a", 0.0, 0.6).set_delay(0.15)
				tw.chain().tween_callback(mi.queue_free)
		_burst(center, Color(1, 1, 1), 10.0)
		_burst(center, purple, 14.0)
		for k in 6:
			_impact_ring(center, [Color(1, 1, 1), purple, pink, green][k % 4], 4.0 + k * 2.4)
		_impact_ring(u.position + Vector3(0, 0.2, 0), purple, 7.0)
		var pm := Fx.mat(Color(purple.r * 2.0, purple.g * 2.0, purple.b * 2.0, 0.85), 0.0, true)
		var pillar := Fx.inst(fx_root, Fx.cyl(2.0, 2.6, 22.0), pm, center + Vector3(0, 6.0, 0))
		var tp := pillar.create_tween().set_parallel(true)
		tp.tween_property(pillar, "scale", Vector3(0.05, 1.1, 0.05), 0.7).set_ease(Tween.EASE_IN)
		tp.tween_property(pm, "albedo_color:a", 0.0, 0.7)
		tp.chain().tween_callback(pillar.queue_free)
		for n in 30:
			var a := n * TAU / 30.0
			var sp := Fx.inst(fx_root, Fx.sphere(0.18), Fx.mat([purple, pink, green][n % 3], 0.0, true), center)
			var ts := sp.create_tween().set_parallel(true)
			ts.tween_property(sp, "position", center + Vector3(cos(a), sin(a) * 0.8, 0.3) * randf_range(4.0, 10.0), 0.8).set_ease(Tween.EASE_OUT)
			ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.8)
			ts.chain().tween_callback(sp.queue_free)
		hud.flash(Color(1, 1, 1), 0.75)
		if u.controlled:
			hud.edge_glow(purple, 1.0)
		shake_t = 0.6
		shake_amp = 0.8
		boss.hit_flash()
		_wound(u)
		_damage_boss(u, FINISH_END, true, true)
		# ela pousa de costas pra boss, adagas baixas: o corte já foi dado, falta ele "chegar"
		u.face(u.position - boss_pos)
		u.dagger_anim("both", 0.3)
		# as duas linhas finas do X ficam riscadas no ar até o estouro
		for k in 2:
			var scar := BoxMesh.new()
			scar.size = Vector3(0.07, 19.0, 0.06)
			var scm := Fx.mat(Color(4.0, 4.0, 4.0, 1.0), 0.0, true)
			var si := Fx.inst(fx_root, scar, scm, center + Vector3(0, 0, 0.9))
			si.rotation.z = 0.78 if k == 0 else -0.78
			var tsc := si.create_tween()
			tsc.tween_interval(FINISH_ECHO_T)
			tsc.tween_property(si, "scale", Vector3(14.0, 1.0, 1.0), 0.08)
			tsc.parallel().tween_property(scm, "albedo_color", Color(purple.r * 3.0, purple.g * 3.0, purple.b * 3.0, 0.0), 0.3)
			tsc.tween_callback(si.queue_free))
	# o estouro: os cortes chegam todos de uma vez, e o dano do Frenesi volta
	get_tree().create_timer(FINISH_TIME + FINISH_ECHO_T - 0.05, false).timeout.connect(func():
		if is_instance_valid(u):
			u.visual.visible = true
			u.visual.position.y = 0.0
		if ended or not is_instance_valid(u) or not u.alive:
			return
		# explosões em cadeia ao longo dos dois riscos do X
		for k in 2:
			var dir := Vector3(-sin(0.78), cos(0.78), 0) if k == 0 else Vector3(sin(0.78), cos(0.78), 0)
			for n in 9:
				var p := center + dir * (n - 4) * 2.0 + Vector3(0, 0, 0.9)
				get_tree().create_timer(n * 0.018, false).timeout.connect(func():
					_burst(p, [Color(1, 1, 1), purple, pink][n % 3], 3.4)
					_impact_ring(p, purple, 2.4))
		_burst(center, Color(1, 1, 1), 16.0)
		_burst(center, pink, 20.0)
		for k in 8:
			_impact_ring(center, [Color(1, 1, 1), purple, pink, green][k % 4], 5.0 + k * 3.0)
		_impact_ring(boss_pos + Vector3(0, 0.2, 0), purple, 12.0)
		# a boss "abre" em quatro: quatro lascas de luz voando do centro
		for k in 4:
			var a := PI / 4.0 + k * PI / 2.0 + PI / 4.0
			var shard_m := Fx.mat(Color(purple.r * 2.6, purple.g * 2.6, purple.b * 2.6, 0.85), 0.0, true)
			var shard := Fx.inst(fx_root, Fx.cyl(0.0, 2.2, 5.0), shard_m, center)
			shard.rotation.z = a - PI / 2.0
			var tsh := shard.create_tween().set_parallel(true)
			tsh.tween_property(shard, "position", center + Vector3(cos(a), sin(a), 0) * 7.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
			tsh.tween_property(shard_m, "albedo_color:a", 0.0, 0.5)
			tsh.chain().tween_callback(shard.queue_free)
		for n in 44:
			var a := randf() * TAU
			var sp := Fx.inst(fx_root, Fx.sphere(0.2), Fx.mat([Color(3, 3, 3), purple, pink, green][n % 4], 0.0, true), center)
			var ts := sp.create_tween().set_parallel(true)
			ts.tween_property(sp, "position", center + Vector3(cos(a), sin(a) * 0.8, 0.3) * randf_range(5.0, 14.0), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
			ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.9)
			ts.chain().tween_callback(sp.queue_free)
		hud.flash(Color(1, 1, 1), 1.0)
		if u.controlled:
			hud.edge_glow(pink, 1.0)
			hud.toast("CORTE FINAL  +%d" % roundi(echo), 1.6)
		shake_t = 0.9
		shake_amp = 1.1
		boss.hit_flash()
		u.face(boss_pos - u.position)
		_raw_hit(u, echo))


## Garras Cruzadas: abre o Ferimento na boss. Enquanto dura, a party inteira dá mais dano nela.
func _wound(u: Unit) -> void:
	add_dot("ferida", "Ferimento", WOUND_COL, WOUND_TIME, 0.0, u)
	var at := boss_pos + Vector3(0, 2.2, 1.8)
	for k in 3:
		# três rasgos vermelhos
		var cut := BoxMesh.new()
		cut.size = Vector3(0.12, 2.6, 0.06)
		var cm := Fx.mat(Color(2.0, 0.25, 0.5, 0.95), 0.0, true)
		var mi := Fx.inst(fx_root, cut, cm, at + Vector3((k - 1) * 0.6, 0, 0))
		mi.rotation.z = -0.5
		var tw := mi.create_tween()
		tw.tween_interval(k * 0.06)
		tw.tween_property(cm, "albedo_color:a", 0.0, 0.5)
		tw.tween_callback(mi.queue_free)
	if u.controlled:
		hud.toast("FERIMENTO: +%d%% DE DANO DA PARTY" % roundi((WOUND_MULT - 1.0) * 100.0), 1.0)


## O furacão da Dança Carmesim em Frenesi: uma coluna de anéis de corte que sobe girando e abre no alto.
func _hurricane(u: Unit, col: Color) -> void:
	var time := 0.9
	var root := Node3D.new()
	fx_root.add_child(root)
	root.position = u.position
	for k in 9:
		var h := 0.3 + k * 0.85
		var rad := 1.3 + k * 0.42
		var c: Color = [col, Color(1.0, 0.3, 0.7), Color(1, 1, 1)][k % 3]
		var rm := Fx.mat(Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.55), 0.0, true)
		var ring := Fx.inst(root, Fx.torus(rad * 0.93, rad), rm, Vector3(0, h * 0.2, 0))
		ring.scale = Vector3.ONE * 0.2
		ring.rotation.x = randf_range(-0.14, 0.14)
		var tr := ring.create_tween().set_parallel(true)
		tr.tween_property(ring, "scale", Vector3.ONE, 0.22).set_delay(k * 0.035).set_ease(Tween.EASE_OUT)
		tr.tween_property(ring, "position:y", h, 0.3).set_delay(k * 0.035).set_ease(Tween.EASE_OUT)
		tr.tween_property(rm, "albedo_color:a", 0.0, 0.35).set_delay(time - 0.35)
		# lâminas presas no anel, pra dar pra ver o giro
		for s in 3:
			var a := s * TAU / 3.0 + k
			var blade := BoxMesh.new()
			blade.size = Vector3(0.9, 0.06, 0.2)
			var bi := Fx.inst(ring, blade, Fx.mat(Color(1.6, 1.6, 1.8, 0.9), 0.0, true), Vector3(cos(a), 0, sin(a)) * rad)
			bi.rotation.y = -a + PI / 2.0
	var tw := root.create_tween()
	tw.tween_property(root, "rotation:y", -TAU * 4.0, time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(root.queue_free)
	for n in 8:
		get_tree().create_timer(n * time / 8.0, false).timeout.connect(func():
			if is_instance_valid(u) and u.alive:
				if n % 3 == 0:
					_impact_ring(u.position + Vector3(0, 0.2, 0), col, 3.0 + n * 0.4)
				_afterimage(u, Vector3(cos(n * 2.4), 0, sin(n * 2.4)) * 2.0, col))
	if u.controlled:
		hud.edge_glow(col, 0.7)
	shake_t = 0.4
	shake_amp = 0.35


## Dança Carmesim: ela gira de verdade, com as duas facas abertas, cortando tudo em volta.
func _crimson_dance(u: Unit, dmg: float) -> void:
	var col := WOUND_COL
	var strong := u.frenzy_t > 0.0
	if strong:
		# em Frenesi: um furacão roxo, e bate mais forte
		dmg *= DANCE_FRENZY
		col = Color(0.75, 0.2, 1.0)
		_hurricane(u, col)
	# o corpo gira duas voltas
	var start := u.visual.rotation.y
	var tw := u.visual.create_tween()
	tw.tween_property(u.visual, "rotation:y", start + TAU * 2.0, DANCE_SPIN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(u.visual, "scale", Vector3(1.2, 0.9, 1.2), DANCE_SPIN * 0.5)
	tw.tween_property(u.visual, "scale", Vector3.ONE, 0.1)
	tw.tween_callback(func(): u.visual.rotation.y = start)
	# as duas facas: lâminas que giram em volta dela, deixando um disco de corte
	var rig := Node3D.new()
	u.add_child(rig)
	rig.position = Vector3(0, 1.0, 0)
	for s in [-1.0, 1.0]:
		var blade := BoxMesh.new()
		blade.size = Vector3(1.9, 0.08, 0.32)
		Fx.inst(rig, blade, Fx.mat(Color(2.4, 2.4, 2.6), 0.0, true), Vector3(s * 1.5, s * 0.25, 0))
		var trail := BoxMesh.new()
		trail.size = Vector3(2.4, 0.04, 0.9)
		Fx.inst(rig, trail, Fx.mat(Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.6), 0.0, true), Vector3(s * 1.5, s * 0.25, s * 0.5))
	var tr := rig.create_tween()
	tr.tween_property(rig, "rotation:y", -TAU * 2.5, DANCE_SPIN)
	tr.parallel().tween_property(rig, "scale", Vector3.ONE * 1.35, DANCE_SPIN)
	tr.tween_callback(rig.queue_free)
	# anéis de corte no chão e silhuetas em volta
	for k in 3:
		var ring_m := Fx.mat(Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.9), 0.0, true)
		var ring := Fx.inst(fx_root, Fx.torus(0.85, 1.0), ring_m, u.position + Vector3(0, 0.6 + k * 0.5, 0))
		ring.scale = Vector3.ONE * 0.4
		var tg := ring.create_tween().set_parallel(true)
		tg.tween_property(ring, "scale", Vector3.ONE * (3.4 + k * 0.5), DANCE_SPIN).set_delay(k * 0.07).set_ease(Tween.EASE_OUT)
		tg.tween_property(ring_m, "albedo_color:a", 0.0, DANCE_SPIN).set_delay(k * 0.07 + 0.1)
		tg.chain().tween_callback(ring.queue_free)
	for n in 6:
		var a := n * TAU / 6.0
		get_tree().create_timer(n * DANCE_SPIN / 6.0, false).timeout.connect(func():
			if is_instance_valid(u) and u.alive:
				_afterimage(u, Vector3(cos(a), 0, sin(a)) * 1.5, col))
	_burst(u.position, col, 3.8)
	shake_t = 0.2
	shake_amp = 0.2
	if _in_range(u):
		_damage_boss(u, dmg, true, true)


## Marca no chão do lado em que o Talho está valendo, com os golpes que faltam. Só pra quem
## está jogando de Assassina.
func _tick_side_mark() -> void:
	var me := units[ctrl]
	var on: bool = me.key == "assassina" and me.alive and not prep and not ended and not roam
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
	var away := u.position - boss_pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
	var to := u.position + away * dist
	var flat := Vector2(to.x, to.z)
	if flat.length() > arena_r:
		flat = flat.normalized() * arena_r
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


## Bala saindo da pistola até a boss: uma cabeça brilhante esticada na direção do tiro, um rastro
## que apaga e um anel de impacto na cor da munição. `size` 1 = bala comum.
func _shot_fx(u: Unit, col: Color, big: bool, size := 1.0) -> void:
	if big:
		size = maxf(size, 1.7)
	u.kick(size)
	var from := u.position + Vector3(0, 1.25, 0)
	var to := _bp(Vector3(randf_range(-0.8, 0.8), randf_range(2.5, 4.0), -11.0))
	# clarão na boca da arma
	var muzzle_m := Fx.mat(Color(col.r, col.g, col.b, 0.9).lightened(0.4), 8.0, true)
	var muzzle := Fx.inst(fx_root, Fx.sphere(0.3 * size), muzzle_m, from)
	var tm := muzzle.create_tween().set_parallel(true)
	tm.tween_property(muzzle, "scale", Vector3.ONE * 0.2, 0.12)
	tm.tween_property(muzzle_m, "albedo_color:a", 0.0, 0.12)
	tm.chain().tween_callback(muzzle.queue_free)
	# a bala: cápsula esticada, virada pro alvo
	var head := Fx.inst(fx_root, Fx.capsule(0.13 * size, 0.9 * size), Fx.mat(col.lightened(0.25), 7.0, true), from)
	head.look_at(to, Vector3.UP)
	head.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := head.create_tween()
	tw.tween_property(head, "position", to, 0.09)
	tw.tween_callback(head.queue_free)
	tw.tween_callback(_impact_ring.bind(to, col, 1.4 * size))
	tw.tween_callback(_burst.bind(to, col, 1.3 * size))
	_beam(u.position + Vector3(0, 0.25, 0), to - Vector3(0, 1.0, 0), Color(col.r, col.g, col.b, 0.75), 0.22)


## Anel que abre de frente pra arena no ponto do impacto.
func _impact_ring(at: Vector3, col: Color, radius: float) -> void:
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.95).lightened(0.3), 6.0, true)
	var ring := Fx.inst(fx_root, Fx.torus(0.8, 1.0), m, at)
	ring.rotation.x = PI / 2.0
	ring.scale = Vector3.ONE * 0.2
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * radius, 0.26).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.26)
	tw.chain().tween_callback(ring.queue_free)


## Disparo Rúnico (munição arcana pequena e limpa) e Tiro Perfurante (lança pesada que atravessa a boss).
func _maga_basic_fx(u: Unit, slot: int) -> void:
	if slot == 0:
		_shot_fx(u, Color(1.0, 0.78, 0.4), false, 0.8)
		return
	u.kick(2.2)
	var from := u.position + Vector3(0, 1.25, 0)
	var hit := _bp(Vector3(0, 3.2, -11.0))
	var through := from + (hit - from).normalized() * (from.distance_to(hit) + 9.0)
	var lance_m := Fx.mat(Color(0.8, 0.98, 1.0), 9.0, true)
	var lance := Fx.inst(fx_root, Fx.capsule(0.2, 3.4), lance_m, from)
	lance.look_at(through, Vector3.UP)
	lance.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := lance.create_tween()
	tw.tween_property(lance, "position", through, 0.16)
	tw.tween_callback(lance.queue_free)
	# rastro grosso em linha reta, que atravessa
	var a := from - Vector3(0, 1.0, 0)
	var bb := through - Vector3(0, 1.0, 0)
	for k in 2:
		_beam(a + Vector3(0, k * 0.05, 0), bb, Color(0.6, 0.95, 1.0, 0.95 - k * 0.3), 0.3 + k * 0.2)
	get_tree().create_timer(0.07, false).timeout.connect(func():
		_impact_ring(hit, AIM_COL, 3.2)
		_impact_ring(hit + Vector3(0, 0, -1.5), Color(1, 1, 1), 2.2)
		_burst(hit, AIM_COL, 2.6)
		boss.hit_flash())


# ---- marca do Tiro Perfurante

## O Tiro Perfurante marca a boss por AIM_TIME: uma mira arcana fecha em cima dela. Salva Astral,
## Canhão Estelar ou Disparo Rúnico fortalecido usados nesse tempo estouram a marca (_use_aim).
func _aim_mark(u: Unit) -> void:
	aim_t = AIM_TIME
	add_dot("mira", "Marca Perfurante", AIM_COL, AIM_TIME, 0.0, u)
	if aim_node != null and is_instance_valid(aim_node):
		aim_node.queue_free()
	aim_node = Node3D.new()
	aim_node.position = _bp(Vector3(0, 5.2, -11.0))
	fx_root.add_child(aim_node)
	for spec in [[2.3, 2.5], [1.5, 1.62]]:
		var ring := Fx.inst(aim_node, Fx.torus(spec[0], spec[1]), Fx.mat(AIM_COL, 6.0, true))
		ring.rotation.x = PI / 2.0
	for n in 4:
		# os quatro traços da mira
		var tick := BoxMesh.new()
		tick.size = Vector3(0.14, 1.1, 0.08)
		var t := Fx.inst(aim_node, tick, Fx.mat(Color(1, 1, 1), 7.0, true), Vector3(0, 2.4, 0).rotated(Vector3(0, 0, 1), n * PI / 2.0))
		t.rotation.z = n * PI / 2.0
	Fx.inst(aim_node, Fx.sphere(0.2), Fx.mat(Color(1, 1, 1), 8.0, true))
	# entra grande e fecha na boss
	aim_node.scale = Vector3.ONE * 2.4
	aim_node.create_tween().tween_property(aim_node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if u.controlled:
		hud.toast("MARCADA", 0.7)


func _tick_aim(delta: float) -> void:
	if aim_t <= 0.0:
		return
	aim_t -= delta
	if aim_node != null and is_instance_valid(aim_node):
		aim_node.rotation.z += delta * 2.4
		# nos últimos instantes a mira pisca: a marca está acabando
		aim_node.visible = aim_t > 0.5 or fmod(aim_t, 0.16) > 0.08
	if aim_t <= 0.0:
		_aim_clear()


func _aim_clear() -> void:
	aim_t = 0.0
	remove_dot("mira")
	if aim_node != null and is_instance_valid(aim_node):
		aim_node.queue_free()
	aim_node = null


## Estoura a marca, se ela existe: devolve o dano a mais (0 sem marca). Vale uma vez por marca.
func _use_aim(u: Unit) -> float:
	if aim_t <= 0.0:
		return 0.0
	var at := _bp(Vector3(0, 5.2, -11.0))
	_aim_clear()
	# ruptura arcana: a mira se parte em estilhaços e um clarão
	_impact_ring(at, Color(1, 1, 1), 5.0)
	_impact_ring(at, AIM_COL, 3.4)
	_burst(at, AIM_COL, 4.2)
	for n in 8:
		var a := n * TAU / 8.0
		var shard := BoxMesh.new()
		shard.size = Vector3(0.12, 0.9, 0.12)
		var mi := Fx.inst(fx_root, shard, Fx.mat(Color(1, 1, 1), 8.0, true), at)
		mi.rotation.z = a
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", at + Vector3(-sin(a), cos(a), 0) * 3.4, 0.28).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.28)
		tw.chain().tween_callback(mi.queue_free)
	boss.hit_flash()
	_popup(int(AIM_BONUS), AIM_COL, 54, at + Vector3(0, 1.8, 0), "RUPTURA +")
	if u.controlled:
		hud.toast("RUPTURA ARCANA", 0.8)
	return AIM_BONUS


## Rainbow Shots: gasta a próxima bala. Com exatamente 3 guardadas, gasta as 3 num tiro só.
func _rainbow(u: Unit) -> void:
	if u.bullets.is_empty():
		u.set_action("Sem balas", 2)
		return
	u.face(boss_pos - u.position)
	if u.bullets.size() == 3:
		# tiro triplo: as três cores saem juntas, num disparo pesado
		for n in 3:
			_shot_fx(u, BULLETS[u.bullets[n]]["col"], true, 1.5)
		u.bullets.clear()
		_damage_boss(u, BULLET_TRIPLE, true, true)
		_knock_back(u, BULLET_KNOCK)
		hud.toast("TIRO TRIPLO", 0.9)
		return
	var kind: int = u.bullets.pop_front()
	var col: Color = BULLETS[kind]["col"]
	_shot_fx(u, col, false, 1.15)
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


## Ricochete Prismático. Normal: um tiro que bate na boss e ricocheteia uma vez nela mesma (não volta).
## Com o escudo da Salva Astral de pé (unit.salvo_t) e perto da boss: a bala fica indo e voltando
## entre a boss e a Maga, batendo numa e curando a outra. Sem esse escudo, nunca volta nela.
func _ricochet(u: Unit) -> void:
	u.face(boss_pos - u.position)
	u.kick(1.2)
	if fairy_t > 0.0:
		# com a Fada Astral em campo, a bala fica ricocheteando entre a boss e ela, de qualquer distância
		_rico_leg(u.position + Vector3(0, 1.25, 0), _bp(Vector3(0, 3.0, -11.5)))
		u.ricochet_t = RICO_TIME
		u.ricochet_tick = 0.16
		u.ricochet_out = true
		u.set_meta("rico_fairy", true)
		if u.controlled:
			hud.toast("RICOCHETE NA FADA", 0.9)
		return
	u.set_meta("rico_fairy", false)
	if u.salvo_t <= 0.0 or u.position.distance_to(boss_pos) > MELEE_RANGE:
		var hit := _bp(Vector3(randf_range(-0.6, 0.6), 2.6, -11.0))
		_rico_leg(u.position + Vector3(0, 1.25, 0), hit)
		get_tree().create_timer(0.16, false).timeout.connect(_rico_leg.bind(hit, hit + Vector3(2.4, 2.2, 0.5)))
		_damage_boss(u, RICO_DMG * 2.5, true, false)
		return
	u.ricochet_t = RICO_TIME
	u.ricochet_tick = 0.0
	u.ricochet_out = true
	if u.controlled:
		hud.toast("RICOCHETE NO ESCUDO", 0.9)


## Um trecho do ricochete: prisma brilhante viajando de `from` a `to`, com rastro e faísca na batida.
func _rico_leg(from: Vector3, to: Vector3) -> void:
	var col: Color = RAINBOW[randi() % RAINBOW.size()].lightened(0.35)
	var prism := Fx.inst(fx_root, Fx.sphere(0.22), Fx.mat(Color(1, 1, 1), 8.0, true), from)
	prism.scale = Vector3(0.8, 0.8, 1.6)
	var tw := prism.create_tween()
	tw.tween_property(prism, "position", to, 0.15)
	tw.tween_callback(prism.queue_free)
	tw.tween_callback(_impact_ring.bind(to, col, 1.5))
	tw.tween_callback(_burst.bind(to, col, 1.1))
	_beam(from - Vector3(0, 1.0, 0), to - Vector3(0, 1.0, 0), Color(col.r, col.g, col.b, 0.9), 0.3)


func _tick_ricochet(u: Unit, delta: float) -> void:
	if u.ricochet_t <= 0.0:
		return
	u.ricochet_t -= delta
	u.ricochet_tick -= delta
	if u.ricochet_tick > 0.0:
		return
	u.ricochet_tick = RICO_STEP
	var boss_at := _bp(Vector3(0, 3.0, -11.5))
	if u.get_meta("rico_fairy", false):
		if fairy_t <= 0.0:
			u.ricochet_t = 0.0  # a fada foi embora: acabou o vai e volta
			return
		if u.ricochet_out:
			_rico_leg(_bp(FAIRY_AT), boss_at)
			_damage_boss(u, RICO_DMG, true, false)
		else:
			_rico_leg(boss_at, _bp(FAIRY_AT))
			_fairy_heal()
		u.ricochet_out = not u.ricochet_out
		return
	if u.position.distance_to(boss_pos) > MELEE_RANGE or u.salvo_t <= 0.0:
		u.ricochet_t = 0.0  # saiu de perto, ou o escudo da Salva caiu: a bala se perde
		return
	var me := u.position + Vector3(0, 1.2, 0)
	if u.ricochet_out:
		_rico_leg(me, boss_at)
		_damage_boss(u, RICO_DMG, true, false)
	else:
		_rico_leg(boss_at, me)
		var room := u.max_hp - u.hp
		u.hp = minf(u.max_hp, u.hp + RICO_HEAL)
		if room < RICO_HEAL:
			# o que passou da vida cheia vira escudo
			u.shield_hp += RICO_HEAL - maxf(room, 0.0)
			u.shield_t = maxf(u.shield_t, SHIELD_TIME)
	u.ricochet_out = not u.ricochet_out


## Salva Astral: consome SALVO_COST balas Rainbow numa rajada e ergue um escudo nela. Não tem recarga:
## a restrição é ter as balas.
func _salvo(u: Unit) -> void:
	if u.bullets.size() < SALVO_COST:
		u.set_action("Precisa de %d balas" % SALVO_COST, 2)
		return
	u.face(boss_pos - u.position)
	# com EXATAMENTE 6 balas (o botão brilha): gasta as seis e solta a Fada Astral
	var fairy := u.bullets.size() == SALVO_FAIRY
	var cost := SALVO_FAIRY if fairy else SALVO_COST
	for n in cost:
		var col: Color = BULLETS[u.bullets.pop_front()]["col"]
		get_tree().create_timer(n * 0.11, false).timeout.connect(func():
			if is_instance_valid(u) and u.alive:
				_shot_fx(u, col, false, 1.25))
	_damage_boss(u, SALVO_DMG * cost + _use_aim(u), true, true)
	if fairy:
		_fairy_spawn(u)
	u.shield_hp = maxf(u.shield_hp, SALVO_SHIELD)
	u.shield_t = SHIELD_TIME
	u.salvo_t = SHIELD_TIME
	# o escudo aparecendo: uma bolha que fecha em volta dela
	var bub_m := Fx.mat(Color(0.45, 0.9, 1.0, 0.45), 4.0, true)
	var bub := Fx.inst(u, Fx.sphere(1.0), bub_m, Vector3(0, 1.0, 0))
	bub.scale = Vector3.ONE * 2.6
	var tb := bub.create_tween().set_parallel(true)
	tb.tween_property(bub, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tb.tween_property(bub_m, "albedo_color:a", 0.0, 0.7).set_delay(0.25)
	tb.chain().tween_callback(bub.queue_free)
	if u.controlled:
		hud.toast(("FADA ASTRAL  ·  −%d BALAS" if fairy else "SALVA ASTRAL  ·  −%d BALAS") % cost, 1.2)


# ---- Fada Astral

## A fada sai voando da Maga até perto da boss e fica lá FAIRY_TIME segundos. Ela atira com uma
## varinha pequena: é o DoT "fada" (FAIRY_DPS), só que animado. Enquanto ela está em campo, o Ricochete
## Prismático passa a quicar entre a boss e ela, e cada bala que ela recebe vira cura na party (_fairy_heal).
func _fairy_spawn(u: Unit) -> void:
	_fairy_clear()
	fairy_t = FAIRY_TIME
	fairy_owner = u
	fairy_shot = 0.6
	add_dot("fada", "Fada Astral", FAIRY_COL, FAIRY_TIME, FAIRY_DPS, u)
	fairy_node = Node3D.new()
	fx_root.add_child(fairy_node)
	fairy_node.position = u.position + Vector3(0, 1.6, 0)
	Fx.inst(fairy_node, Fx.sphere(0.26), Fx.mat(Color(1, 1, 1), 7.0, true))
	Fx.inst(fairy_node, Fx.sphere(0.42), Fx.mat(Color(FAIRY_COL.r, FAIRY_COL.g, FAIRY_COL.b, 0.45), 4.0, true))
	for s in [-1.0, 1.0]:
		# asinhas: batem em _tick_fairy
		var wing := BoxMesh.new()
		wing.size = Vector3(0.62, 0.36, 0.03)
		var pivot := Node3D.new()
		pivot.name = "WingL" if s < 0.0 else "WingR"
		fairy_node.add_child(pivot)
		Fx.inst(pivot, wing, Fx.mat(Color(0.7, 0.95, 1.0, 0.75), 4.0, true), Vector3(s * 0.38, 0.14, 0.05))
	# varinha com uma estrela na ponta
	var wand := Node3D.new()
	wand.name = "Wand"
	wand.position = Vector3(-0.3, -0.05, -0.15)
	wand.rotation.z = 0.6
	fairy_node.add_child(wand)
	Fx.inst(wand, Fx.cyl(0.025, 0.025, 0.5), Fx.mat(Color(1.0, 0.95, 0.6), 3.0, true), Vector3(0, 0.25, 0))
	Fx.inst(wand, Fx.sphere(0.09), Fx.mat(Color(1.0, 0.9, 0.35), 8.0, true), Vector3(0, 0.52, 0))
	fairy_node.create_tween().tween_property(fairy_node, "position", _bp(FAIRY_AT), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(u.position + Vector3(0, 1.6, 0), FAIRY_COL, 2.4)


func _tick_fairy(delta: float) -> void:
	if fairy_t <= 0.0:
		return
	fairy_t -= delta
	if fairy_t <= 0.0 or get_dot("fada").is_empty():
		_fairy_clear()
		return
	if fairy_node == null or not is_instance_valid(fairy_node):
		return
	var t := Time.get_ticks_msec() * 0.001
	# paira num oito pequeno e bate as asas
	fairy_node.position = fairy_node.position.lerp(_bp(FAIRY_AT) + Vector3(sin(t * 1.7) * 0.5, sin(t * 3.1) * 0.3, 0), delta * 6.0)
	fairy_node.get_node("WingL").rotation.y = sin(t * 26.0) * 0.7
	fairy_node.get_node("WingR").rotation.y = -sin(t * 26.0) * 0.7
	# nos últimos 2 s ela pisca: está indo embora
	fairy_node.visible = fairy_t > 2.0 or fmod(fairy_t, 0.2) > 0.08
	fairy_shot -= delta
	if fairy_shot <= 0.0:
		fairy_shot = 1.0
		# o tiro da varinha (só o desenho: o dano é o DoT)
		var from: Vector3 = fairy_node.position + Vector3(-0.5, 0.3, -0.1)
		var to := _bp(Vector3(randf_range(-0.8, 0.8), randf_range(4.5, 7.5), -11.4))
		var bolt := Fx.inst(fx_root, Fx.sphere(0.11), Fx.mat(Color(1.0, 0.9, 0.5), 8.0, true), from)
		var tw := bolt.create_tween()
		tw.tween_property(bolt, "position", to, 0.16)
		tw.tween_callback(bolt.queue_free)
		tw.tween_callback(_impact_ring.bind(to, FAIRY_COL, 0.8))
		var wand: Node3D = fairy_node.get_node("Wand")
		wand.rotation.z = 1.3
		wand.create_tween().tween_property(wand, "rotation:z", 0.6, 0.25)


func _fairy_clear() -> void:
	fairy_t = 0.0
	remove_dot("fada")
	if fairy_node != null and is_instance_valid(fairy_node):
		_burst(fairy_node.position, FAIRY_COL, 1.6)
		fairy_node.queue_free()
	fairy_node = null
	fairy_owner = null


## A fada foi atingida por uma bala do Ricochete: ela entrega a cura pra party toda, em área.
## FAIRY_HEAL da vida máxima de cada um; o que passar da vida cheia vira escudo.
func _fairy_heal() -> void:
	_burst(_bp(FAIRY_AT), Color(0.6, 1.0, 0.75), 2.6)
	_impact_ring(_bp(FAIRY_AT), Color(0.6, 1.0, 0.75), 2.2)
	for o in units:
		if not o.alive:
			continue
		var amount := o.max_hp * FAIRY_HEAL
		var room := maxf(0.0, o.max_hp - o.hp)
		o.hp = minf(o.max_hp, o.hp + amount)
		if room < amount:
			o.shield_hp += amount - room
			o.shield_t = maxf(o.shield_t, SHIELD_TIME)
		_beam(_bp(FAIRY_AT) - Vector3(0, 1.0, 0), o.position, Color(0.6, 1.0, 0.75, 0.6), 0.3)
		_popup(int(round(amount)), Color(0.5, 1.0, 0.65), 34, o.position + Vector3(0, 2.6, 0), "+")


# ---- Canhão Estelar

## Preparo (a conjuração): a Maga materializa o canhão. O cano cresce, três anéis de energia acendem
## um por um e a carga na boca do cano incha. Com as BULLET_MAX balas, elas orbitam a boca.
## O conjunto fica guardado em meta "cannon" até o disparo (ou até ela andar e cancelar).
func _cannon_charge(u: Unit, time: float) -> void:
	_cannon_drop(u)
	u.cannon_bonus = _use_aim(u)  # a marca do Tiro Perfurante é usada já no começo do preparo
	u.face(boss_pos - u.position)
	var rig := Node3D.new()
	u.add_child(rig)
	rig.position = Vector3(0, 1.7, 0)
	rig.look_at(_bp(Vector3(0, 4.0, -11.5)), Vector3.UP)
	u.set_meta("cannon", rig)
	var super_shot := u.bullets.size() == BULLET_MAX
	var metal := Fx.mat(Color(0.85, 0.88, 1.0, 0.92), 1.2)
	var barrel := Fx.inst(rig, Fx.cyl(0.62, 0.48, 3.4), metal, Vector3(0, 0, -1.9))
	barrel.rotation.x = PI / 2.0
	barrel.scale = Vector3(0.05, 0.05, 0.05)
	barrel.create_tween().tween_property(barrel, "scale", Vector3.ONE * (1.25 if super_shot else 1.0), time * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for n in 3:
		var col: Color = RAINBOW[(n * 2) % RAINBOW.size()] if super_shot else u.color.lightened(0.3)
		var ring := Fx.inst(rig, Fx.torus(0.78, 0.95), Fx.mat(col, 6.0, true), Vector3(0, 0, -0.9 - n * 1.1))
		ring.rotation.x = PI / 2.0
		ring.scale = Vector3.ZERO
		var tr := ring.create_tween()
		tr.tween_interval(time * (0.25 + n * 0.18))
		tr.tween_property(ring, "scale", Vector3.ONE * (1.3 if super_shot else 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var charge_m := Fx.mat(Color(1.0, 0.95, 0.7, 0.9), 9.0, true)
	var charge := Fx.inst(rig, Fx.sphere(0.5), charge_m, Vector3(0, 0, -3.8))
	charge.scale = Vector3.ONE * 0.1
	charge.create_tween().tween_property(charge, "scale", Vector3.ONE * (2.4 if super_shot else 1.5), time).set_ease(Tween.EASE_IN)
	if super_shot:
		# as oito balas orbitando a boca do canhão
		var orbit := Node3D.new()
		orbit.position = Vector3(0, 0, -3.8)
		rig.add_child(orbit)
		for n in u.bullets.size():
			var a := n * TAU / u.bullets.size()
			Fx.inst(orbit, Fx.sphere(0.2), Fx.mat(BULLETS[u.bullets[n]]["col"], 7.0, true), Vector3(cos(a), sin(a), 0) * 1.5)
		orbit.create_tween().tween_property(orbit, "rotation:z", TAU * 2.0, time).set_ease(Tween.EASE_IN)
		orbit.create_tween().tween_property(orbit, "scale", Vector3.ONE * 0.35, time).set_ease(Tween.EASE_IN)
		if u.controlled:
			hud.toast("SUPERCANHÃO: %d BALAS" % BULLET_MAX, 1.6)
	elif u.controlled:
		hud.toast("CARREGANDO O CANHÃO", 1.2)
	# postura de disparo: ela firma os pés
	u.visual.scale = Vector3(1.12, 0.9, 1.12)


## Some com o canhão em preparo (ela andou e cancelou).
func _cannon_drop(u: Unit) -> void:
	if u.has_meta("cannon"):
		var rig = u.get_meta("cannon")
		if is_instance_valid(rig):
			rig.queue_free()
		u.remove_meta("cannon")
		u.visual.scale = Vector3.ONE
		u.cannon_bonus = 0.0


## O disparo. Gasta TODAS as balas guardadas; cada uma vale bem mais aqui do que solta.
## Com exatamente BULLET_MAX balas vira o supercanhão arco-íris (_cannon_super).
func _cannon(u: Unit) -> void:
	u.face(boss_pos - u.position)
	var loaded := u.bullets.size()
	u.bullets.clear()
	var amount := CANNON_DMG + CANNON_PER_BULLET * loaded + u.cannon_bonus
	u.cannon_bonus = 0.0
	var rig: Node3D = u.get_meta("cannon") if u.has_meta("cannon") else null
	if rig != null and not is_instance_valid(rig):
		rig = null
	if u.has_meta("cannon"):
		u.remove_meta("cannon")
	u.visual.scale = Vector3.ONE
	if loaded == BULLET_MAX:
		_cannon_super(u, amount + CANNON_SUPER_BONUS, rig)
		return
	var from := u.position + Vector3(0, 1.7, 0)
	var hit := _bp(Vector3(0, 4.0, -11.5))
	# feixe grosso, branco com a cor dela em volta
	_cannon_beam(from, hit, [Color(1, 1, 1), u.color.lightened(0.3)], 0.55, 0.45)
	_impact_ring(hit, u.color.lightened(0.4), 6.0 + loaded * 0.5)
	_impact_ring(hit, Color(1, 1, 1), 4.0)
	_burst(hit, u.color.lightened(0.4), 6.0 + loaded)
	hud.flash(Color(1.0, 0.9, 0.6), 0.28)
	shake_t = 0.35
	shake_amp = 0.35
	hud.toast("CANHÃO ESTELAR" + (" ×%d" % loaded if loaded > 0 else ""), 1.6)
	_damage_boss(u, amount, true, true)
	_knock_back(u, 2.0)
	if rig != null:
		# recuo do cano e some
		var tw := rig.create_tween()
		tw.tween_property(rig, "position:z", rig.position.z + 0.9, 0.08)
		tw.tween_property(rig, "scale", Vector3.ONE * 0.05, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(rig.queue_free)


## Feixe do canhão: cilindros concêntricos do ponto de saída até o alvo, que afinam e apagam.
func _cannon_beam(from: Vector3, to: Vector3, cols: Array, radius: float, time: float) -> void:
	var length := from.distance_to(to)
	for k in cols.size():
		var c: Color = cols[k]
		var m := Fx.mat(Color(c.r, c.g, c.b, 0.95 - k * 0.3), 9.0 - k * 3.0, true)
		var beam := Fx.inst(fx_root, Fx.cyl(radius * (1.0 + k * 0.7), radius * (1.0 + k * 0.7), length), m, (from + to) * 0.5)
		beam.look_at(to, Vector3.UP)
		beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		var tw := beam.create_tween().set_parallel(true)
		tw.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), time).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "albedo_color:a", 0.0, time)
		tw.chain().tween_callback(beam.queue_free)


## Supercanhão arco-íris (Canhão Estelar com as BULLET_MAX balas). Ela fica presa no lugar por
## CANNON_SUPER_TIME, segurando o disparo: sete feixes coloridos girando em volta de um miolo branco,
## anéis de choque correndo pelo feixe (o ar "rasgando"), estilhaços de luz, e o dano saindo em
## CANNON_SUPER_TICKS batidas. Fecha com uma explosão e um recuo forte.
func _cannon_super(u: Unit, total: float, rig: Node3D) -> void:
	u.lock_t = CANNON_SUPER_TIME
	u.invuln = maxf(u.invuln, 0.0)
	var from := u.position + Vector3(0, 1.7, 0)
	var hit := _bp(Vector3(0, 4.0, -11.5))
	var length := from.distance_to(hit)
	hud.toast("SUPERCANHÃO ARCO-ÍRIS", 2.0)
	hud.flash(Color(1, 1, 1), 0.35)
	shake_t = CANNON_SUPER_TIME
	shake_amp = 0.3
	var beam := Node3D.new()
	fx_root.add_child(beam)
	beam.position = from
	beam.look_at(hit, Vector3.UP)
	# miolo branco
	var core_m := Fx.mat(Color(1, 1, 1, 0.98), 12.0, true)
	var core := Fx.inst(beam, Fx.cyl(0.55, 0.55, length), core_m, Vector3(0, 0, -length * 0.5))
	core.rotation.x = PI / 2.0
	# sete feixes do arco-íris em volta, girando
	var spin := Node3D.new()
	beam.add_child(spin)
	for n in RAINBOW.size():
		var a := n * TAU / RAINBOW.size()
		var strand := Fx.inst(spin, Fx.cyl(0.34, 0.34, length), Fx.mat(RAINBOW[n], 8.0, true), Vector3(cos(a) * 0.95, sin(a) * 0.95, -length * 0.5))
		strand.rotation.x = PI / 2.0
	spin.create_tween().tween_property(spin, "rotation:z", TAU * 3.0, CANNON_SUPER_TIME)
	# bainha escura em volta: o espaço "rasgado" pelo disparo
	var tear := Fx.inst(beam, Fx.cyl(1.9, 1.9, length), Fx.mat(Color(0.12, 0.0, 0.25, 0.45), 0.0, true), Vector3(0, 0, -length * 0.5))
	tear.rotation.x = PI / 2.0
	# o feixe abre, pulsa e fecha
	beam.scale = Vector3(0.1, 0.1, 1.0)
	var tb := beam.create_tween()
	tb.tween_property(beam, "scale", Vector3(1.25, 1.25, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for n in 6:
		tb.tween_property(beam, "scale", Vector3(0.95, 0.95, 1.0), CANNON_SUPER_TIME * 0.07)
		tb.tween_property(beam, "scale", Vector3(1.2, 1.2, 1.0), CANNON_SUPER_TIME * 0.07)
	tb.tween_property(beam, "scale", Vector3(0.02, 0.02, 1.0), 0.18).set_ease(Tween.EASE_IN)
	tb.tween_callback(beam.queue_free)
	# batidas de dano, cada uma com um anel de choque correndo pelo feixe e estilhaços no alvo
	for n in CANNON_SUPER_TICKS:
		var at := 0.1 + (CANNON_SUPER_TIME - 0.3) * n / maxf(1.0, CANNON_SUPER_TICKS - 1.0)
		get_tree().create_timer(at, false).timeout.connect(_cannon_super_tick.bind(u, total / CANNON_SUPER_TICKS, n, from, hit))
	get_tree().create_timer(CANNON_SUPER_TIME, false).timeout.connect(func():
		if ended:
			return
		# fecho: explosão arco-íris e o recuo que ela vinha segurando
		for n in RAINBOW.size():
			_impact_ring(hit, RAINBOW[n], 4.0 + n * 1.3)
		_burst(hit, Color(1, 1, 1), 12.0)
		hud.flash(Color(1, 1, 1), 0.4)
		shake_t = 0.5
		shake_amp = 0.6
		if is_instance_valid(u) and u.alive:
			_knock_back(u, 4.5))
	if rig != null:
		# o canhão treme enquanto dispara e some no fim
		var tw := rig.create_tween()
		for n in 16:
			tw.tween_property(rig, "position:y", 1.7 + (0.08 if n % 2 == 0 else -0.08), CANNON_SUPER_TIME / 16.0)
		tw.tween_property(rig, "scale", Vector3.ONE * 0.05, 0.25)
		tw.tween_callback(rig.queue_free)


func _cannon_super_tick(u: Unit, amount: float, n: int, from: Vector3, hit: Vector3) -> void:
	if ended or not is_instance_valid(u) or not u.alive:
		return
	_damage_boss(u, amount, true, true)
	u.kick(1.6)
	var col: Color = RAINBOW[n % RAINBOW.size()]
	# anel de choque que nasce na boca do canhão e corre até a boss, crescendo
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.95).lightened(0.2), 7.0, true)
	var ring := Fx.inst(fx_root, Fx.torus(0.85, 1.0), m, from)
	ring.look_at(hit, Vector3.UP)
	ring.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	ring.scale = Vector3.ONE * 1.4
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "position", hit, 0.3)
	tw.tween_property(ring, "scale", Vector3.ONE * 4.2, 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3).set_delay(0.12)
	tw.chain().tween_callback(ring.queue_free)
	_impact_ring(hit, col, 5.0)
	_burst(hit + Vector3(randf_range(-2.5, 2.5), randf_range(-1.5, 2.5), 0), col, 3.4)
	# estilhaços de luz saindo do feixe
	for k in 3:
		var along := from.lerp(hit, randf_range(0.15, 0.9))
		var out := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0).normalized() * randf_range(1.6, 3.2)
		var sp := Fx.inst(fx_root, Fx.sphere(0.14), Fx.mat(RAINBOW[(n + k) % RAINBOW.size()], 8.0, true), along)
		var ts := sp.create_tween().set_parallel(true)
		ts.tween_property(sp, "position", along + out, 0.35).set_ease(Tween.EASE_OUT)
		ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.35)
		ts.chain().tween_callback(sp.queue_free)


# ---------------------------------------------------------------- Soulburner

## Lança Serafim: quase nada sem a marca. Com ela, o dano cresce conforme a marca envelhece
## (médio no começo, alto perto do fim) e a marca é consumida.
func lance_damage() -> float:
	var mark := get_dot("zenite")
	if mark.is_empty():
		return LANCE_BARE
	var aged := clampf(1.0 - mark["t"] / mark["total"], 0.0, 1.0)
	return lerpf(LANCE_MIN, LANCE_MAX, aged)


# ---- Brasas do Firmamento

## Ataque básico: uma brasa celestial pequena (estrela comprimida), rastro ciano e um flash branco na batida.
func _ember_fx(u: Unit) -> void:
	var from := u.position + Vector3(0, 1.3, 0)
	var to := _bp(Vector3(randf_range(-1.0, 1.0), randf_range(2.4, 4.2), -11.0))
	var star := Node3D.new()
	fx_root.add_child(star)
	star.position = from
	Fx.inst(star, Fx.sphere(0.16), Fx.mat(Color(1, 1, 1), 9.0, true))
	for k in 3:
		# três lâminas cruzadas: o brilho de estrela
		var spike := BoxMesh.new()
		spike.size = Vector3(0.07, 0.62, 0.07)
		var s := Fx.inst(star, spike, Fx.mat(FIRE, 7.0, true))
		s.rotation = Vector3(k * PI / 3.0, 0, k * PI / 3.0)
	var tw := star.create_tween()
	tw.tween_property(star, "position", to, 0.1)
	tw.parallel().tween_property(star, "rotation:z", TAU, 0.1)
	tw.tween_callback(star.queue_free)
	tw.tween_callback(func():
		# flash branco curto no impacto
		var m := Fx.mat(Color(1, 1, 1, 0.95), 10.0, true)
		var fl := Fx.inst(fx_root, Fx.sphere(0.5), m, to)
		var tf := fl.create_tween().set_parallel(true)
		tf.tween_property(fl, "scale", Vector3.ONE * 1.8, 0.12)
		tf.tween_property(m, "albedo_color:a", 0.0, 0.12)
		tf.chain().tween_callback(fl.queue_free)
		_impact_ring(to, FIRE_CYAN, 1.1))
	_beam(u.position + Vector3(0, 0.3, 0), to - Vector3(0, 1.0, 0), Color(FIRE_CYAN.r, FIRE_CYAN.g, FIRE_CYAN.b, 0.8), 0.25)
	# partículas ciano soltas pelo caminho
	for k in 3:
		var at := from.lerp(to, 0.25 + k * 0.25)
		var pm := Fx.mat(FIRE_CYAN, 6.0, true)
		var p := Fx.inst(fx_root, Fx.sphere(0.07), pm, at)
		var tp := p.create_tween().set_parallel(true)
		tp.tween_property(p, "position", at + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.7), 0), 0.35)
		tp.tween_property(p, "scale", Vector3.ONE * 0.1, 0.35)
		tp.chain().tween_callback(p.queue_free)


# ---- Marca do Zênite

## O julgamento em cima da boss: um halo verde-marinho, um círculo mágico e símbolos girando em volta.
## _tick_zenith deixa tudo mais luminoso conforme a marca envelhece: dá pra ver quando está no fim,
## que é a hora da Lança Serafim.
func _zenith_halo() -> void:
	_zenith_clear()
	zenith_node = Node3D.new()
	# na altura da cabeça da boss e um pouco à frente: acima disso a barra de vida dela esconde
	zenith_node.position = _bp(Vector3(0, 10.4, -11.6))
	zenith_node.rotation.x = 0.4
	fx_root.add_child(zenith_node)
	zenith_mats = []
	var halo_m := Fx.mat(FIRE, 3.0, true)
	Fx.inst(zenith_node, Fx.torus(1.9, 2.2), halo_m)
	zenith_mats.append(halo_m)
	var circle_m := Fx.mat(Color(FIRE_CYAN.r, FIRE_CYAN.g, FIRE_CYAN.b, 0.6), 2.0, true)
	Fx.inst(zenith_node, Fx.torus(2.9, 2.98), circle_m)
	Fx.inst(zenith_node, Fx.torus(1.2, 1.26), circle_m)
	zenith_mats.append(circle_m)
	var sym_m := Fx.mat(FIRE_MINT, 3.0, true)
	for n in 6:
		# símbolos: pequenas cruzes de luz em volta do halo
		var a := n * TAU / 6.0
		var holder := Node3D.new()
		holder.position = Vector3(cos(a), 0, sin(a)) * 2.6
		holder.rotation.y = -a
		zenith_node.add_child(holder)
		for size in [Vector3(0.1, 0.02, 0.5), Vector3(0.34, 0.02, 0.1)]:
			var bm := BoxMesh.new()
			bm.size = size
			Fx.inst(holder, bm, sym_m)
	zenith_mats.append(sym_m)
	var core := Fx.inst(zenith_node, Fx.sphere(0.4), Fx.mat(Color(2.2, 2.2, 2.2, 0.9), 0.0, true))
	core.name = "Core"
	core.visible = false
	zenith_node.scale = Vector3.ONE * 0.2
	zenith_node.create_tween().tween_property(zenith_node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(_bp(Vector3(0, 10.4, -11.6)), FIRE, 3.0)


func _tick_zenith(delta: float) -> void:
	if zenith_node == null:
		return
	var mark := get_dot("zenite")
	if mark.is_empty():
		_zenith_clear()
		return
	var aged: float = clampf(1.0 - mark["t"] / mark["total"], 0.0, 1.0)
	zenith_node.rotation.y += delta * (0.8 + aged * 2.4)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for k in zenith_mats.size():
		var m: StandardMaterial3D = zenith_mats[k]
		# do começo (apagado, escuro) ao fim (quase branco, estourando no brilho e pulsando).
		# Esses materiais não têm sombra, então emissão não conta: o brilho vem da própria cor,
		# que passa de 1 (HDR) e estoura no bloom.
		var base: Color = [FIRE, FIRE_CYAN, FIRE_MINT][k]
		var c := base.darkened(0.45).lerp(base, minf(aged * 2.0, 1.0)).lerp(Color(1, 1, 1), maxf(0.0, aged - 0.4) * 1.1)
		var power := 0.8 + aged * aged * 2.6 + (pulse * 1.3 if aged >= LANCE_PERFECT else 0.0)
		m.albedo_color = Color(c.r * power, c.g * power, c.b * power, 0.55 + aged * 0.45)
	zenith_node.scale = Vector3.ONE * (0.85 + aged * 0.5)
	# miolo de luz que só aparece no fim: a hora da Lança
	var core: MeshInstance3D = zenith_node.get_node("Core")
	core.visible = aged >= LANCE_PERFECT
	core.scale = Vector3.ONE * (0.6 + pulse * 0.5)


func _zenith_clear() -> void:
	if zenith_node != null and is_instance_valid(zenith_node):
		zenith_node.queue_free()
	zenith_node = null
	zenith_mats = []


# ---- Lança Serafim

## Modelo da lança celestial: ponta branca luminosa, haste verde-marinho e duas asinhas. Aponta pra baixo.
func _lance_model() -> Node3D:
	var lance := Node3D.new()
	var shaft := Fx.inst(lance, Fx.cyl(0.16, 0.16, 6.5), Fx.mat(FIRE, 5.0, true), Vector3(0, 1.6, 0))
	shaft.name = "Shaft"
	Fx.inst(lance, Fx.cyl(0.55, 0.0, 2.6), Fx.mat(Color(1, 1, 1), 10.0, true), Vector3(0, -2.9, 0))
	Fx.inst(lance, Fx.torus(0.34, 0.5), Fx.mat(FIRE_MINT, 6.0, true), Vector3(0, -1.5, 0))
	for s in [-1.0, 1.0]:
		for k in 2:
			var wing := BoxMesh.new()
			wing.size = Vector3(1.5 - k * 0.5, 0.3, 0.06)
			var w := Fx.inst(lance, wing, Fx.mat(FIRE_MINT.lerp(Color(1, 1, 1), 0.3), 6.0, true), Vector3(s * (0.85 - k * 0.2), -0.6 + k * 0.5, 0))
			w.rotation.z = s * (0.55 + k * 0.2)
	return lance


## O preparo (1 s de cast): ele ergue a mão, um círculo mágico abre em cima da boss e a lança vai se
## formando no céu, cada vez mais luminosa. O dano é calculado AQUI, no começo: quem conjura com a marca
## no fim não perde o bônus se ela expirar durante a animação.
func _lance_charge(u: Unit, time: float) -> void:
	_lance_drop(u)
	u.lance_amount = lance_damage()
	u.lance_marked = not get_dot("zenite").is_empty()
	# grau do timing: 0 sem marca ou cedo demais · 1 bom · 2 perfeito (marca nos últimos instantes)
	var grade := 0
	if u.lance_marked:
		var mk := get_dot("zenite")
		var aged: float = 1.0 - mk["t"] / mk["total"]
		grade = 2 if aged >= LANCE_PERFECT else (1 if aged >= LANCE_GOOD else 0)
	u.set_meta("lance_grade", grade)
	u.face(boss_pos - u.position)
	u.visual.scale = Vector3(0.92, 1.12, 0.92)  # braço pra cima
	var rig := Node3D.new()
	fx_root.add_child(rig)
	rig.position = _bp(Vector3(0, 0, -12.0))
	u.set_meta("lance", rig)
	var circle := Node3D.new()
	circle.position = Vector3(0, 12.2, 0)
	circle.rotation.x = 0.35
	rig.add_child(circle)
	Fx.inst(circle, Fx.torus(2.6, 2.75), Fx.mat(FIRE_CYAN, 5.0, true))
	Fx.inst(circle, Fx.torus(1.5, 1.58), Fx.mat(FIRE_MINT, 5.0, true))
	circle.scale = Vector3.ONE * 0.1
	circle.create_tween().tween_property(circle, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	circle.create_tween().tween_property(circle, "rotation:y", TAU, time)
	var lance := _lance_model()
	lance.name = "Lance"
	lance.position = Vector3(0, 11.0, 1.4)
	lance.scale = Vector3(0.1, 0.1, 0.1)
	rig.add_child(lance)
	var big: float = [1.0, 1.25, 1.6][grade] if u.lance_marked else 0.8
	lance.create_tween().tween_property(lance, "scale", Vector3.ONE * big, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# o retorno do timing, na própria lança: quanto melhor, mais fogo celestial enrolado nela
	if grade > 0:
		var flames := Node3D.new()
		flames.position = lance.position + Vector3(0, 0.6, 0)
		rig.add_child(flames)
		var count := 5 if grade == 1 else 12
		for n in count:
			var a := n * TAU / count
			var col: Color = [FIRE, FIRE_CYAN, FIRE_MINT, Color(1, 1, 1)][n % (3 if grade == 1 else 4)]
			var tongue := Fx.inst(flames, Fx.capsule(0.16, 1.5 + (n % 3) * 0.5), Fx.mat(Color(col.r * 2.2, col.g * 2.2, col.b * 2.2, 0.9), 0.0, true),
				Vector3(cos(a) * 1.3, -2.5 + (n % 4) * 1.5, sin(a) * 1.3))
			tongue.rotation.z = cos(a) * 0.35
			tongue.rotation.x = sin(a) * 0.35
		flames.scale = Vector3(0.1, 0.1, 0.1)
		flames.create_tween().tween_property(flames, "scale", Vector3.ONE * (1.0 if grade == 1 else 1.35), time * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		flames.create_tween().tween_property(flames, "rotation:y", TAU * (1.5 if grade == 1 else 3.0), time + LANCE_FALL)
		lance.set_meta("flames", flames)
	if grade == 2:
		# perfeito: anéis de luz descendo pela lança e um clarão no céu
		for n in 3:
			var ring := Fx.inst(rig, Fx.torus(1.5, 1.7), Fx.mat(Color(2.5, 2.5, 2.5, 0.9), 0.0, true), lance.position + Vector3(0, 5.0, 0))
			ring.scale = Vector3.ONE * 0.2
			var tr := ring.create_tween()
			tr.tween_interval(n * time * 0.28)
			tr.tween_property(ring, "scale", Vector3.ONE * 1.6, 0.2)
			tr.parallel().tween_property(ring, "position:y", lance.position.y - 3.0, time * 0.5)
			tr.tween_callback(ring.queue_free)
		_burst(_bp(Vector3(0, 11.0, -10.6)), Color(1, 1, 1), 4.0)
		if u.controlled:
			hud.toast("LANÇA PERFEITA!", 1.2)
			hud.flash(FIRE_MINT, 0.12)
	elif grade == 1 and u.controlled:
		hud.toast("BOA LANÇA", 0.9)
	# fagulhas subindo da mão dele até o céu
	_beam(u.position + Vector3(0, 1.2, 0), _bp(Vector3(0, 10.0, -10.6)), Color(FIRE_CYAN.r, FIRE_CYAN.g, FIRE_CYAN.b, 0.5), time)


func _lance_drop(u: Unit) -> void:
	if u.has_meta("lance"):
		var rig = u.get_meta("lance")
		if is_instance_valid(rig):
			rig.queue_free()
		u.remove_meta("lance")
		u.visual.scale = Vector3.ONE


## O cast terminou: a lança despenca (LANCE_FALL) e o dano sai no impacto, com o valor travado no começo.
## A marca é consumida.
func _lance(u: Unit) -> void:
	var amount := u.lance_amount
	var marked := u.lance_marked
	if not u.has_meta("lance"):
		# sem preparo (IA, teste): vale o estado de agora
		amount = lance_damage()
		marked = not get_dot("zenite").is_empty()
		_lance_charge(u, 0.01)
	remove_dot("zenite")
	var rig: Node3D = u.get_meta("lance")
	u.remove_meta("lance")
	u.visual.scale = Vector3.ONE
	var lance: Node3D = rig.get_node("Lance")
	var tw := lance.create_tween()
	tw.tween_property(lance, "position:y", 4.4, LANCE_FALL).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	if lance.has_meta("flames"):
		var flames: Node3D = lance.get_meta("flames")
		tw.parallel().tween_property(flames, "position:y", 5.0, LANCE_FALL).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	var grade: int = u.get_meta("lance_grade", 0)
	tw.tween_callback(_lance_hit.bind(u, amount, marked, grade))
	tw.tween_property(lance, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(rig.queue_free)


func _lance_hit(u: Unit, amount: float, marked: bool, grade := 0) -> void:
	if ended:
		return
	var at := _bp(Vector3(0, 3.4, -11.5))
	if grade == 2:
		# perfeito: coluna de fogo celestial no ponto do impacto, mais ondas e o aviso em cima do dano
		for k in 2:
			var pc: Color = [FIRE, Color(1, 1, 1)][k]
			var pm := Fx.mat(Color(pc.r * 2.4, pc.g * 2.4, pc.b * 2.4, 0.85), 0.0, true)
			var pillar := Fx.inst(fx_root, Fx.cyl(1.6 - k * 0.9, 1.9 - k * 1.0, 16.0), pm, at + Vector3(0, 5.0, 0))
			var tp := pillar.create_tween().set_parallel(true)
			tp.tween_property(pillar, "scale", Vector3(0.05, 1.15, 0.05), 0.55).set_ease(Tween.EASE_IN)
			tp.tween_property(pm, "albedo_color:a", 0.0, 0.55)
			tp.chain().tween_callback(pillar.queue_free)
		for k in 4:
			_impact_ring(at, [Color(1, 1, 1), FIRE_MINT, FIRE, FIRE_CYAN][k], 6.0 + k * 2.0)
		hud.toast("PERFEITO!", 0.9)
	elif grade == 1:
		_impact_ring(at, FIRE_MINT, 5.5)
	if marked:
		# explosão branca com fogo verde-marinho em volta
		_burst(at, Color(1, 1, 1), 6.0)
		_burst(at, FIRE, 4.6)
		for k in 3:
			_impact_ring(at, [Color(1, 1, 1), FIRE, FIRE_CYAN][k], 3.0 + k * 1.6)
		hud.flash(FIRE_MINT, 0.18)
		shake_t = 0.25
		shake_amp = 0.25 + 0.25 * clampf((amount - LANCE_MIN) / (LANCE_MAX - LANCE_MIN), 0.0, 1.0)
	else:
		_burst(at, Color(0.6, 0.7, 0.7), 1.6)
	boss.hit_flash()
	if is_instance_valid(u):
		_damage_boss(u, amount, true, amount > 60.0)


# ---- Rasante Incandescente

## Abre as asas, corta o campo num dash fluido (na direção que está andando, ou pra trás) e fecha.
## Fogo celestial no rastro, uma explosão luminosa na saída e outra na chegada, penas soltando no caminho.
func _swoop(u: Unit) -> void:
	var d := _input_dir() if u.controlled else Vector3.ZERO
	if d == Vector3.ZERO:
		d = (u.position - boss_pos).normalized()
		d.y = 0.0
	var from := u.position
	var to := from + d.normalized() * SWOOP_DIST
	var flat := Vector2(to.x, to.z)
	if flat.length() > arena_r:
		flat = flat.normalized() * arena_r
		to = Vector3(flat.x, 0, flat.y)
	u.wings_open(true, 0.08)
	u.dash_fx()
	u.invuln = maxf(u.invuln, 0.35)
	for k in 3:
		_beam(from + Vector3(0, k * 0.35 - 0.3, 0), to + Vector3(0, k * 0.35 - 0.3, 0), [FIRE, FIRE_CYAN, FIRE_MINT][k], 0.5 + k * 0.15)
	_burst(from, Color(1, 1, 1), 2.0)
	_burst(from, FIRE, 3.2)
	var tw := u.create_tween()
	tw.tween_property(u, "position", to, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		_burst(to, Color(1, 1, 1), 1.8)
		_burst(to, FIRE_CYAN, 2.8)
		u.wings_open(false, 0.3))
	# penas de luz que se soltam das asas
	for k in 7:
		var at := from.lerp(to, k / 6.0) + Vector3(randf_range(-0.6, 0.6), 1.2, randf_range(-0.6, 0.6))
		var feather := BoxMesh.new()
		feather.size = Vector3(0.3, 0.05, 0.1)
		var fm := Fx.mat(FIRE_MINT, 6.0, true)
		var p := Fx.inst(fx_root, feather, fm, at)
		p.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var tp := p.create_tween().set_parallel(true)
		tp.tween_property(p, "position", at + Vector3(0, -0.9, 0), 0.6).set_delay(k * 0.02)
		tp.tween_property(p, "rotation:z", TAU, 0.6)
		tp.tween_property(p, "scale", Vector3.ONE * 0.1, 0.6)
		tp.chain().tween_callback(p.queue_free)
	_damage_boss(u, SWOOP_DMG, true, false)


# ---- Chuva de Brasas

## Um círculo mágico abre no céu em cima da boss e brasas verdes caem pelos 15 s do DoT, cada uma num
## ponto diferente da área, com uma pequena explosão no chão (_tick_rain). Só visual: o dano é o DoT.
func _rain_start() -> void:
	rain_t = RAIN_TIME
	rain_tick = 0.0
	if rain_node != null and is_instance_valid(rain_node):
		rain_node.queue_free()
	rain_node = Node3D.new()
	rain_node.position = _bp(Vector3(0, 10.6, -10.5))
	rain_node.rotation.x = 0.3
	fx_root.add_child(rain_node)
	Fx.inst(rain_node, Fx.torus(4.6, 4.8), Fx.mat(FIRE, 5.0, true))
	Fx.inst(rain_node, Fx.torus(3.2, 3.3), Fx.mat(FIRE_CYAN, 4.0, true))
	Fx.inst(rain_node, Fx.disc(4.6, 0.02), Fx.mat(Color(FIRE.r, FIRE.g, FIRE.b, 0.18), 2.0, true))
	for n in 8:
		var a := n * TAU / 8.0
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.03, 1.2)
		var ray := Fx.inst(rain_node, bm, Fx.mat(FIRE_MINT, 4.0, true), Vector3(cos(a), 0, sin(a)) * 3.9)
		ray.rotation.y = -a + PI / 2.0
	rain_node.scale = Vector3.ONE * 0.1
	rain_node.create_tween().tween_property(rain_node, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tick_rain(delta: float) -> void:
	if rain_t <= 0.0:
		return
	rain_t -= delta
	if rain_node != null and is_instance_valid(rain_node):
		rain_node.rotation.y += delta * 0.6
	if rain_t <= 0.0 or get_dot("chuva").is_empty():
		rain_t = 0.0
		if rain_node != null and is_instance_valid(rain_node):
			var gone := rain_node
			rain_node = null
			var tw := gone.create_tween()
			tw.tween_property(gone, "scale", Vector3.ONE * 0.05, 0.3)
			tw.tween_callback(gone.queue_free)
		return
	rain_tick -= delta
	while rain_tick <= 0.0:
		rain_tick += RAIN_EVERY * randf_range(0.6, 1.5)
		# cada brasa cai num ponto sorteado da área, com tamanho e velocidade próprios
		var a := randf() * TAU
		var r := sqrt(randf()) * 4.4
		var ground := Vector3(cos(a) * r, 0.1, -10.5 + sin(a) * r)
		var col: Color = [FIRE, FIRE_CYAN, FIRE_MINT][randi() % 3]
		var ember := Fx.inst(fx_root, Fx.capsule(0.09, 0.55 + randf() * 0.4), Fx.mat(col, 7.0, true), ground + Vector3(randf_range(-0.6, 0.6), 10.4, 0))
		var tw := ember.create_tween()
		tw.tween_property(ember, "position", ground, randf_range(0.32, 0.5)).set_ease(Tween.EASE_IN)
		tw.tween_callback(ember.queue_free)
		tw.tween_callback(_burst.bind(ground, col, randf_range(0.7, 1.2)))


# ---- Juízo Solar

## Sequência: ele sobe e abre as asas (SOLAR_RISE, preso), lança um sol celestial que leva SOLAR_TRAVEL
## até a boss, e fica flutuando SOLAR_FLOAT depois do lançamento, já podendo andar e usar o resto do kit.
## O dano sai no impacto. Com a boss marcada NA HORA EM QUE ELE USA: mais dano e o DoT (a marca fica).
func _solar(u: Unit) -> void:
	var marked := not get_dot("zenite").is_empty()
	u.lock_t = SOLAR_RISE
	u.face(boss_pos - u.position)
	u.wings_open(true, 0.35)
	if u.controlled:
		hud.toast("JUÍZO SOLAR", 1.6)
	var up := u.visual.create_tween()
	up.tween_property(u.visual, "position:y", SOLAR_HEIGHT, SOLAR_RISE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_interval(SOLAR_FLOAT)
	up.tween_property(u.visual, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	up.tween_callback(u.wings_open.bind(false, 0.3))
	_burst(u.position, FIRE, 3.0)
	# o sol: uma estrela pequena. Núcleo branco, camadas de fogo verde-marinho e anéis orbitando.
	var sun := Node3D.new()
	fx_root.add_child(sun)
	sun.position = u.position + Vector3(0, SOLAR_HEIGHT + 5.2, 0.5)
	Fx.inst(sun, Fx.sphere(0.8), Fx.mat(Color(1, 1, 1), 12.0, true))
	Fx.inst(sun, Fx.sphere(1.15), Fx.mat(Color(FIRE_MINT.r, FIRE_MINT.g, FIRE_MINT.b, 0.55), 6.0, true))
	Fx.inst(sun, Fx.sphere(1.55), Fx.mat(Color(FIRE.r, FIRE.g, FIRE.b, 0.3), 4.0, true))
	var rings: Array = []
	for k in 3:
		var ring := Fx.inst(sun, Fx.torus(1.9 + k * 0.25, 2.0 + k * 0.25), Fx.mat([FIRE_CYAN, FIRE, FIRE_MINT][k], 6.0, true))
		ring.rotation = Vector3(0.6 + k * 0.9, 0, k * 1.1)
		rings.append(ring)
		ring.create_tween().set_loops().tween_property(ring, "rotation:y", TAU, 1.1 + k * 0.4).as_relative()
	sun.scale = Vector3.ONE * 0.1
	var hit := _bp(Vector3(0, 5.0, -11.5))
	var ts := sun.create_tween()
	ts.tween_property(sun, "scale", Vector3.ONE * 1.3, SOLAR_RISE).set_ease(Tween.EASE_OUT)
	ts.tween_property(sun, "position", hit, SOLAR_TRAVEL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ts.parallel().tween_property(sun, "scale", Vector3.ONE * 2.6, SOLAR_TRAVEL)
	ts.tween_callback(_solar_hit.bind(u, marked, hit))
	ts.tween_callback(sun.queue_free)


func _solar_hit(u: Unit, marked: bool, hit: Vector3) -> void:
	if ended:
		return
	# grande explosão celestial: clarão branco, fogo verde-marinho, ondas de choque e partículas
	_burst(hit, Color(1, 1, 1), 13.0)
	_burst(hit, FIRE, 10.0)
	for k in 5:
		_impact_ring(hit, [Color(1, 1, 1), FIRE, FIRE_CYAN, FIRE_MINT, FIRE][k], 4.0 + k * 2.2)
	for n in 18:
		var a := n * TAU / 18.0
		var pm := Fx.mat([FIRE, FIRE_CYAN, FIRE_MINT][n % 3], 8.0, true)
		var p := Fx.inst(fx_root, Fx.sphere(0.2), pm, hit)
		var tp := p.create_tween().set_parallel(true)
		tp.tween_property(p, "position", hit + Vector3(cos(a), sin(a) * 0.7, 0.3) * randf_range(5.0, 9.0), 0.7).set_ease(Tween.EASE_OUT)
		tp.tween_property(p, "scale", Vector3.ONE * 0.1, 0.7)
		tp.chain().tween_callback(p.queue_free)
	hud.flash(FIRE_MINT, 0.35)
	shake_t = 0.55
	shake_amp = 0.55
	boss.hit_flash()
	if not is_instance_valid(u):
		return
	_damage_boss(u, SOLAR_MARKED if marked else SOLAR_DMG, true, true)
	if marked:
		add_dot("solar", "Queimadura Solar", FIRE_MINT, SOLAR_DOT_TIME, SOLAR_DOT, u)


# ---------------------------------------------------------------- Ringstar

## Qual slot da Ringstar está fortalecido agora (-1 = nenhum). É o que faz o botão brilhar na barra.
func glow_slot(u: Unit) -> int:
	if u.key == "ringstar" and u.chain > 0:
		return u.chain
	if u.key == "maga" and u.pierce_next:
		return 0
	if u.key == "valsa" and u.waltz_step == 2:
		return 0  # o próximo Passo de Valsa é o Giro
	if u.key == "burner":
		# a marca está nos últimos instantes: é a hora da Lança Serafim
		var mk := get_dot("zenite")
		if not mk.is_empty() and 1.0 - mk["t"] / mk["total"] >= LANCE_PERFECT:
			return 2
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
			_burst(boss_pos + Vector3(0, 1.6, 1.8), STAR, 3.4)
	else:
		amount = WEAK_HIT  # fora de ordem: dano mínimo e a sequência se perde
		u.chain = 0
	if u.count_t > 0.0:
		amount *= COUNT_DMG
	return amount


## Contagem Regressiva: avança até a boss e abre uma arena de luz em volta dela mesma.
func _countdown(u: Unit) -> void:
	var to_boss := boss_pos - u.position
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


## SUPERSTAR!: ela pega o microfone e aponta pra boss (SUPERSTAR_WIND), e só então a rajada sai, em
## SUPERSTAR_SHOTS disparos ao longo de SUPERSTAR_FIRE. É oGCD: ela continua andando e batendo
## enquanto isso, e a sequência Jab/Direto/Gancho não quebra. Se ela cair no meio, a rajada para.
func _superstar(u: Unit) -> void:
	u.face(boss_pos - u.position)
	u.glove_anim("mic", SUPERSTAR_WIND)
	if u.controlled:
		hud.toast("SUPERSTAR!", 1.0)
	# microfone na mão direita, com um brilho que cresce durante o preparo
	var mic := Node3D.new()
	u.gloves[1].add_child(mic)
	Fx.inst(mic, Fx.cyl(0.05, 0.05, 0.34), Fx.mat(Color(0.2, 0.2, 0.3)), Vector3(0, 0.3, 0))
	Fx.inst(mic, Fx.sphere(0.13), Fx.mat(Color(1.0, 0.9, 0.35), 4.0, true), Vector3(0, 0.52, 0))
	var glow_m := Fx.mat(Color(STAR.r, STAR.g, STAR.b, 0.5), 5.0, true)
	var glow := Fx.inst(mic, Fx.sphere(0.2), glow_m, Vector3(0, 0.52, 0))
	glow.create_tween().tween_property(glow, "scale", Vector3.ONE * 3.2, SUPERSTAR_WIND)
	_burst(u.position + Vector3(0, 1.6, 0), Color(1.0, 0.9, 0.35), 1.6)
	for n in SUPERSTAR_SHOTS:
		var at := SUPERSTAR_WIND + SUPERSTAR_FIRE * n / maxf(1.0, SUPERSTAR_SHOTS - 1.0)
		get_tree().create_timer(at, false).timeout.connect(_superstar_shot.bind(u, n))
	get_tree().create_timer(SUPERSTAR_WIND, false).timeout.connect(func():
		if is_instance_valid(u) and u.alive:
			u.glove_anim("volley", SUPERSTAR_FIRE))
	get_tree().create_timer(SUPERSTAR_WIND + SUPERSTAR_FIRE + 0.1, false).timeout.connect(func():
		if is_instance_valid(mic):
			mic.queue_free())


func _superstar_shot(u: Unit, n: int) -> void:
	if ended or not is_instance_valid(u) or not u.alive:
		return
	# estrela gigante saindo dela até a boss
	var from := u.position + Vector3(0, 1.8, 0)
	var to := _bp(Vector3(randf_range(-2.2, 2.2), randf_range(2.5, 6.0), -11.0))
	var m := Fx.mat([STAR, Color(1.0, 0.9, 0.35), Color(0.45, 0.8, 1.0)][n % 3].lightened(0.2), 8.0, true)
	var star := Fx.inst(fx_root, Fx.sphere(0.55), m, from)
	var tw := star.create_tween()
	tw.tween_property(star, "position", to, 0.14)
	tw.parallel().tween_property(star, "scale", Vector3.ONE * 1.6, 0.14)
	tw.tween_callback(star.queue_free)
	tw.tween_callback(_burst.bind(to, STAR.lightened(0.2), 3.6))
	_damage_boss(u, SUPERSTAR_DMG / SUPERSTAR_SHOTS, true, n == SUPERSTAR_SHOTS - 1)


## Nocaute Final: salta alto na direção da boss, fica suspensa e despenca. O dano é na aterrissagem
## (_knockout_land), em área. Enquanto air_t > 0 ela está no ar: não age e passa por cima de
## ataque baixo (hazard com "low": true).
func _knockout_jump(u: Unit) -> void:
	var to_boss := boss_pos - u.position
	to_boss.y = 0.0
	var go := maxf(0.0, to_boss.length() - (MELEE_RANGE - 1.0))
	u.face(to_boss)
	u.air_t = KNOCKOUT_AIR
	u.channel_t = 0.0
	if u.controlled:
		hud.toast("NOCAUTE FINAL", 1.4)
	_burst(u.position, STAR, 3.0)
	# o corpo vai até o ponto de queda enquanto o boneco sobe, paira e desce
	var land := u.position + to_boss.normalized() * go if go > 0.1 else u.position
	u.create_tween().tween_property(u, "position", land, KNOCKOUT_AIR * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var tw := u.visual.create_tween()
	tw.tween_property(u.visual, "position:y", KNOCKOUT_HEIGHT, KNOCKOUT_AIR * 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(u.visual, "scale", Vector3(0.8, 1.35, 0.8), KNOCKOUT_AIR * 0.36)
	# suspensa: a luva cresce e brilha em cima dela
	tw.tween_property(u.visual, "position:y", KNOCKOUT_HEIGHT + 0.5, KNOCKOUT_AIR * 0.44)
	tw.parallel().tween_property(u.visual, "scale", Vector3(1.25, 1.25, 1.25), KNOCKOUT_AIR * 0.44)
	tw.tween_property(u.visual, "position:y", 0.0, KNOCKOUT_AIR * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	var glove_m := Fx.mat(Color(STAR.r, STAR.g, STAR.b, 0.85), 8.0, true)
	var glove := Fx.inst(u, Fx.sphere(0.5), glove_m, Vector3(0, 2.6, 0))
	var tg := glove.create_tween()
	tg.tween_property(glove, "position:y", KNOCKOUT_HEIGHT + 3.0, KNOCKOUT_AIR * 0.36).set_ease(Tween.EASE_OUT)
	tg.parallel().tween_property(glove, "scale", Vector3.ONE * 4.2, KNOCKOUT_AIR * 0.8)
	tg.tween_property(glove, "position:y", 1.0, KNOCKOUT_AIR * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tg.tween_callback(glove.queue_free)
	# marca no chão de onde a onda de choque vai pegar
	var mark_m := Fx.mat(Color(STAR.r, STAR.g, STAR.b, 0.22), 2.5, true)
	var mark := Fx.inst(fx_root, Fx.torus(KNOCKOUT_R - 0.22, KNOCKOUT_R), mark_m, land + Vector3(0, 0.06, 0))
	mark.create_tween().tween_callback(mark.queue_free).set_delay(KNOCKOUT_AIR)


## A aterrissagem: explosão de luz, onda de choque no chão (do tamanho exato do dano), coluna de
## luz, estrelas voando e tremor. Dano em área em volta de onde ela caiu.
func _knockout_land(u: Unit) -> void:
	u.air_t = 0.0
	u.visual.position.y = 0.0
	u.visual.scale = Vector3.ONE
	u.punch()
	var at := u.position
	var hot := STAR.lightened(0.45)
	# clarão no ponto de impacto
	var flash_m := Fx.mat(Color(1.0, 0.95, 1.0, 0.9), 5.0, true)
	var fl := Fx.inst(fx_root, Fx.sphere(1.0), flash_m, at + Vector3(0, 0.6, 0))
	fl.scale = Vector3.ONE * 0.6
	var tf := fl.create_tween().set_parallel(true)
	tf.tween_property(fl, "scale", Vector3(KNOCKOUT_R * 0.75, KNOCKOUT_R * 0.5, KNOCKOUT_R * 0.75), 0.3).set_ease(Tween.EASE_OUT)
	tf.tween_property(flash_m, "albedo_color:a", 0.0, 0.34)
	tf.chain().tween_callback(fl.queue_free)
	# chão aceso por um instante, na área exata do dano
	var disc_m := Fx.mat(Color(hot.r, hot.g, hot.b, 0.45), 1.6, true)
	var disc := Fx.inst(fx_root, Fx.disc(KNOCKOUT_R, 0.03), disc_m, at + Vector3(0, 0.05, 0))
	var td := disc.create_tween()
	td.tween_property(disc_m, "albedo_color:a", 0.0, 0.55)
	td.tween_callback(disc.queue_free)
	# onda de choque: três anéis saindo até a borda da área
	for n in 3:
		var ring_m := Fx.mat(Color(hot.r, hot.g, hot.b, 0.95), 6.0 - n * 1.5, true)
		var ring := Fx.inst(fx_root, Fx.torus(0.78, 1.0), ring_m, at + Vector3(0, 0.12 + n * 0.04, 0))
		ring.scale = Vector3(0.3, 1.0 + (2 - n) * 1.2, 0.3)
		var tr := ring.create_tween().set_parallel(true)
		tr.tween_property(ring, "scale", Vector3(KNOCKOUT_R, 0.5, KNOCKOUT_R), 0.42 + n * 0.1).set_delay(n * 0.07).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tr.tween_property(ring_m, "albedo_color:a", 0.0, 0.42 + n * 0.1).set_delay(n * 0.07 + 0.12)
		tr.chain().tween_callback(ring.queue_free)
	# coluna de luz
	var col_m := Fx.mat(Color(1.0, 0.9, 1.0, 0.8), 4.0, true)
	var pillar := Fx.inst(fx_root, Fx.cyl(1.6, 1.6, 26.0), col_m, at + Vector3(0, 13.0, 0))
	var tp := pillar.create_tween().set_parallel(true)
	tp.tween_property(pillar, "scale", Vector3(0.05, 1.0, 0.05), 0.5).set_ease(Tween.EASE_IN)
	tp.tween_property(col_m, "albedo_color:a", 0.0, 0.5)
	tp.chain().tween_callback(pillar.queue_free)
	# estrelas voando pra fora, em arco
	for n in 16:
		var a := n * TAU / 16.0 + randf_range(-0.15, 0.15)
		var dir := Vector3(cos(a), 0, sin(a))
		var star_m := Fx.mat([STAR, Color(1.0, 0.9, 0.35), Color(0.45, 0.8, 1.0)][n % 3], 8.0, true)
		var star := Fx.inst(fx_root, Fx.sphere(0.22 + randf() * 0.14), star_m, at + Vector3(0, 0.5, 0))
		var far := at + dir * randf_range(KNOCKOUT_R * 0.7, KNOCKOUT_R * 1.15)
		var ts := star.create_tween().set_parallel(true)
		ts.tween_property(star, "position:x", far.x, 0.6).set_ease(Tween.EASE_OUT)
		ts.tween_property(star, "position:z", far.z, 0.6).set_ease(Tween.EASE_OUT)
		ts.tween_property(star, "position:y", randf_range(2.5, 5.5), 0.3).set_ease(Tween.EASE_OUT)
		ts.tween_property(star, "scale", Vector3.ONE * 0.1, 0.6)
		ts.chain().tween_callback(star.queue_free)
	hud.flash(STAR.lightened(0.3), 0.22)
	shake_t = 0.45
	shake_amp = 0.55
	# dano: a boss leva se o ponto de ataque dela está dentro da onda
	if at.distance_to(boss_pos) <= KNOCKOUT_R:
		_damage_boss(u, KNOCKOUT_DMG, true, true)
		_burst(_bp(Vector3(0, 4.5, -11.5)), hot, 8.0)


# ---------------------------------------------------------------- Valsa

## Raio da saia: até onde o bônus dela alcança. Cresce com o Embalo.
func skirt_r(v: Unit) -> float:
	return SKIRT_R + SKIRT_R_PER * v.embalo


## `o` está na dança de `v`? Ela mesma, o Par, quem está dentro da saia; no Grande Baile, a party toda.
func _in_dance(v: Unit, o: Unit) -> bool:
	if not v.alive or not o.alive:
		return false
	if o == v or o == v.partner or v.ball_t > 0.0:
		return true
	return Vector2(o.position.x - v.position.x, o.position.z - v.position.z).length() <= skirt_r(v)


## Quanto de dano a mais `o` está dando por causa de uma Valsa (0.16 = +16%). Ela não fortalece a si mesma.
func valsa_bonus(o: Unit) -> float:
	var best := 0.0
	for v in units:
		if v.key != "valsa" or v == o or not _in_dance(v, o):
			continue
		var b: float = SKIRT_BONUS + SKIRT_BONUS_PER * v.embalo
		if v.crescendo_t > 0.0:
			b *= CRESC_MULT
		best = maxf(best, b)
	return best


## Voluta dourada (a espiral da arte dela): abre girando e some. De pé, virada pra câmera, ou deitada no chão.
func _swirl(at: Vector3, col: Color, size: float, time := 0.5, lying := false) -> void:
	var m := Fx.flat(Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.95))
	var mi := Fx.inst(fx_root, Fx.spiral_mesh(), m, at)
	if lying:
		mi.rotation.x = -PI / 2.0
	mi.rotation.z = randf() * TAU
	mi.scale = Vector3.ONE * size * 0.25
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation:z", mi.rotation.z - TAU * 1.2, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time * 0.45).set_delay(time * 0.55)
	tw.chain().tween_callback(mi.queue_free)


func _petal_mat(gold: float) -> StandardMaterial3D:
	var col: Color = ROSE_GOLD if randf() < gold else [LILAC.lightened(0.25), Color(1, 1, 1), LILAC][randi() % 3]
	return Fx.flat(Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 0.95))


## Pétalas: `n` saem de `at` em arco até `spread` de distância, girando, e somem. `gold` = fração dourada.
func _petals(at: Vector3, n: int, spread: float, up := 1.6, time := 0.8, gold := 0.4) -> void:
	for k in n:
		var m := _petal_mat(gold)
		var mi := Fx.inst(fx_root, Fx.petal_mesh(), m, at)
		var a := randf() * TAU
		var far := at + Vector3(cos(a), 0, sin(a)) * randf_range(spread * 0.35, spread)
		var t := time * randf_range(0.75, 1.15)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		mi.scale = Vector3.ONE * randf_range(0.9, 1.7)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position:x", far.x, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position:z", far.z, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position:y", at.y + up * randf_range(0.5, 1.0), t * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position:y", maxf(0.06, at.y - 0.9), t * 0.6).set_delay(t * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), 0), t)
		tw.tween_property(m, "albedo_color:a", 0.0, t * 0.3).set_delay(t * 0.7)
		tw.chain().tween_callback(mi.queue_free)


## Uma pétala caindo devagar do alto, balançando, em algum ponto do círculo.
func _petal_fall(center: Vector3, radius: float, gold := 0.35) -> void:
	var a := randf() * TAU
	var d := sqrt(randf()) * radius
	var p := Vector3(center.x + cos(a) * d, randf_range(3.4, 5.0), center.z + sin(a) * d)
	var m := _petal_mat(gold)
	var mi := Fx.inst(fx_root, Fx.petal_mesh(), m, p)
	mi.scale = Vector3.ONE * randf_range(1.0, 1.8)
	var t := randf_range(1.0, 1.5)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "position:y", 0.07, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "position:x", p.x + randf_range(-0.7, 0.7), t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mi, "rotation", Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), randf_range(-3.0, 3.0)), t)
	tw.chain().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)


## Anel no chão que abre de r0 até r1 e some (a barra da saia passando).
func _ring_floor(at: Vector3, col: Color, r0: float, r1: float, time := 0.4) -> void:
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.9), 4.0, true)
	var ring := Fx.inst(fx_root, Fx.torus(0.93, 1.0), m, Vector3(at.x, 0.09, at.z))
	ring.scale = Vector3(r0, 0.6, r0)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(r1, 0.4, r1), time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	tw.chain().tween_callback(ring.queue_free)


## Nota de caixinha de música: o compasso da Valsa se ouve. `semis` = semitons acima do Dó.
func _chime(semis: int, volume_db := -9.0) -> void:
	if autoplay:
		return
	var key := "chime_%d" % semis
	if not _tones.has(key):
		var freq := 523.25 * pow(2.0, semis / 12.0)
		var rate := 22050
		var count := int(rate * 0.55)
		var data := PackedByteArray()
		data.resize(count * 2)
		for i in count:
			var t := float(i) / rate
			var env := exp(-t * 7.5) * minf(1.0, t * 500.0)
			var v := sin(TAU * freq * t) + 0.32 * sin(TAU * freq * 2.0 * t) + 0.1 * sin(TAU * freq * 3.0 * t) + 0.12 * sin(TAU * freq * 4.2 * t) * exp(-t * 22.0)
			data.encode_s16(i * 2, int(clampf(v * env * 0.55, -1.0, 1.0) * 26000.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.data = data
		_tones[key] = wav
	_sfx(_tones[key], volume_db)


## Várias notas em sequência (arpejo), uma a cada `gap` segundos.
func _chimes(notes: Array, gap := 0.08, volume_db := -9.0) -> void:
	if autoplay:
		return
	for n in notes.size():
		var note: int = notes[n]
		if n == 0:
			_chime(note, volume_db)
		else:
			get_tree().create_timer(n * gap, false).timeout.connect(_chime.bind(note, volume_db))


## "1", "2", "3!" em cima dela: o compasso, pra quem está jogando de Valsa.
func _count_pop(u: Unit, step: int) -> void:
	var giro := step == 2
	var txt: String = ["1", "2", "3!"][step]
	var dx: float = [-0.75, 0.75, 0.0][step]
	var l := Fx.label(fx_root, txt, u.position + Vector3(dx, 2.6, 0.0), 78 if giro else 46)
	l.modulate = ROSE_GOLD if giro else LILAC.lightened(0.45)
	l.outline_size = 14
	l.outline_modulate = Color(0.07, 0.08, 0.16)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + (1.1 if giro else 0.7), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## O golpe dela "sai": uma fita dourada da mão até a boss.
func _ribbon(u: Unit, to: Vector3, big := false) -> void:
	var m := Fx.mat(Color(1.0, 0.86, 0.45), 7.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(0.3 if big else 0.18), m, u.position + Vector3(0, 1.3, 0))
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to, 0.09)
	tw.tween_callback(mi.queue_free)
	_beam(u.position + Vector3(0, 0.3, 0), to - Vector3(0, 1.0, 0), Color(1.0, 0.82, 0.4, 0.8 if big else 0.55), 0.22 if big else 0.14)


## Onde o golpe dela acerta a boss.
func _waltz_at() -> Vector3:
	return _bp(Vector3(randf_range(-1.0, 1.0), randf_range(2.2, 3.8), -11.0))


## Ganha Embalo: a rosa nasce na órbita dela e a saia abre mais um pouco.
func _embalo_add(u: Unit, n: int) -> void:
	var was := u.embalo
	u.embalo = mini(EMBALO_MAX, u.embalo + n)
	u.embalo_t = EMBALO_HOLD
	for k in range(was, u.embalo):
		u.rose_pop(k)
	if u.embalo == EMBALO_MAX and was < EMBALO_MAX:
		_swirl(u.position + Vector3(0, 2.8, 0), ROSE_GOLD, 1.5, 0.7)
		_ring_floor(u.position, ROSE_GOLD, 1.0, skirt_r(u), 0.6)
		if u.controlled:
			hud.toast("SAIA ABERTA: EMBALO MÁXIMO", 1.2)


## Passo de Valsa: o compasso de três tempos. Os dois primeiros são passos; o terceiro é o Giro.
## Devolve o dano do golpe.
func _waltz_hit(u: Unit, full: float) -> float:
	var step := u.waltz_step
	u.waltz_step = (step + 1) % 3
	if u.controlled:
		_count_pop(u, step)
	var hit := _waltz_at()
	if step == 2:
		return _giro(u, hit)
	_chime(0 if step == 0 else 4)
	u.waltz_anim("step")
	_ribbon(u, hit)
	_swirl(hit, ROSE_GOLD, 0.9, 0.4)
	_petals(hit, 4, 1.2, 0.8, 0.6, 0.6)
	_petals(u.position + Vector3(0, 0.5, 0), 3, 1.3, 0.7, 0.6, 0.15)
	return full


## O Giro: ela dá a volta inteira, a saia abre até a borda do bônus, o Embalo sobe e o Par acompanha.
func _giro(u: Unit, hit: Vector3) -> float:
	var amount: float = WALTZ_GIRO + WALTZ_GIRO_PER * u.embalo
	_chimes([7, 12], 0.06)
	u.waltz_anim("giro", 0.36)
	var r := skirt_r(u)
	_ring_floor(u.position, LILAC.lightened(0.3), 0.6, r, 0.45)
	_ring_floor(u.position, ROSE_GOLD, 0.4, r * 0.7, 0.36)
	_petals(u.position + Vector3(0, 0.7, 0), 12, r * 0.8, 1.6, 0.9)
	_ribbon(u, hit, true)
	_swirl(hit, ROSE_GOLD, 2.0, 0.55)
	_swirl(hit + Vector3(0.5, 0.4, 0.1), Color(1, 1, 1), 1.1, 0.45)
	_petals(hit, 10, 2.4, 1.2, 0.8, 0.7)
	_burst(hit, ROSE_GOLD, 2.2)
	shake_t = maxf(shake_t, 0.12)
	shake_amp = maxf(shake_amp, 0.12)
	_embalo_add(u, 1)
	_duet_echo(u)
	return amount


## O Par acompanha o Giro (no Grande Baile, a party inteira acompanha).
func _duet_echo(u: Unit) -> void:
	var amount: float = DUET_ECHO + DUET_ECHO_PER * u.embalo
	for o in units:
		if o != u and o.alive and (o == u.partner or u.ball_t > 0.0):
			_duet_strike(u, o, amount, false)


## Uma voluta sai dela, chega no aliado, e ele acerta a boss junto. O dano é DELE (aparece no DPS dele).
func _duet_strike(u: Unit, o: Unit, amount: float, big: bool) -> void:
	var orb := Fx.inst(fx_root, Fx.spiral_mesh(), Fx.flat(Color(1.5, 1.2, 0.45, 0.95)), u.position + Vector3(0, 1.4, 0))
	orb.scale = Vector3.ONE * 0.45
	var tw := orb.create_tween()
	tw.tween_property(orb, "position", o.position + Vector3(0, 1.4, 0), 0.12)
	tw.parallel().tween_property(orb, "rotation:z", -TAU, 0.12)
	tw.tween_callback(orb.queue_free)
	tw.tween_callback(func():
		if ended or not is_instance_valid(o) or not o.alive:
			return
		o.punch()
		_swirl(o.position + Vector3(0, 2.3, 0), ROSE_GOLD, 1.1 if big else 0.7, 0.4)
		var hit := _bp(Vector3(randf_range(-1.4, 1.4), randf_range(2.0, 4.2), -11.0))
		var shot := Fx.inst(fx_root, Fx.sphere(0.36 if big else 0.26), Fx.mat(o.color.lightened(0.45), 7.0, true), o.position + Vector3(0, 1.2, 0))
		var ts := shot.create_tween()
		ts.tween_property(shot, "position", hit, 0.1)
		ts.tween_callback(shot.queue_free)
		ts.tween_callback(func():
			_swirl(hit, o.color.lightened(0.5), 1.9 if big else 1.3, 0.45)
			_petals(hit, 5, 1.6, 0.9, 0.7, 0.8))
		_damage_boss(o, amount, true, big))


## Quem é o Par: o escolhido no card; sem escolha, o Par de agora; sem Par, quem o jogador controla
## ou, entre os outros, quem mais está batendo.
func _duet_pick(u: Unit, by_ai: bool) -> Unit:
	if not by_ai and sel >= 0 and units[sel].alive and units[sel] != u:
		return units[sel]
	if u.partner != null and u.partner.alive:
		return u.partner
	var best: Unit = null
	for o in units:
		if o == u or not o.alive:
			continue
		if best == null or (o.controlled and not best.controlled) or (o.controlled == best.controlled and o.dps > best.dps):
			best = o
	return best


## Cura quem está na dança dela (dentro da saia, o Par, ela mesma).
func _dance_heal(u: Unit, amount: float, size := 40) -> void:
	for o in units:
		if not _in_dance(u, o) or o.hp >= o.max_hp:
			continue
		o.hp = minf(o.max_hp, o.hp + amount)
		u.enmity += amount * HEAL_ENMITY
		_popup(int(amount), Color(0.75, 1.0, 0.7), size, o.position + Vector3(0, 2.6, 0), "+")


## Passo a Dois: ela estende a mão pro Par. Os dois acertam a boss juntos, ele é curado, vira o Par
## (o fio dourado) e o compasso dela pula direto pro Giro.
func _duet(u: Unit) -> void:
	var o: Unit = u.cast_target
	if o == null or not o.alive or o == u:
		o = _duet_pick(u, true)
	if o == null:
		u.skill_cd[1] = 0.0
		return
	var fresh := u.partner != o
	u.partner = o
	u.face(o.position - u.position)
	u.waltz_anim("offer")
	get_tree().create_timer(0.34, false).timeout.connect(func():
		if is_instance_valid(u) and u.alive:
			u.face(boss_pos - u.position))
	_chimes([4, 9, 12], 0.07)
	# o fio acende de ponta a ponta
	_beam(u.position + Vector3(0, 0.25, 0), o.position + Vector3(0, 0.25, 0), Color(1.0, 0.85, 0.4, 0.9), 0.35)
	_swirl(o.position + Vector3(0, 0.1, 0), ROSE_GOLD, 1.5, 0.6, true)
	_swirl(u.position + Vector3(0, 0.1, 0), ROSE_GOLD, 1.5, 0.6, true)
	_petals(o.position + Vector3(0, 1.0, 0), 8, 1.5)
	if o.hp < o.max_hp:
		o.hp = minf(o.max_hp, o.hp + DUET_HEAL)
		u.enmity += DUET_HEAL * HEAL_ENMITY
		_popup(int(DUET_HEAL), Color(0.75, 1.0, 0.7), 52, o.position + Vector3(0, 2.6, 0), "+")
	if _in_range(u):
		var hit := _waltz_at()
		_ribbon(u, hit, true)
		_swirl(hit, ROSE_GOLD, 1.6, 0.5)
		_damage_boss(u, DUET_DMG, true, true)
	_duet_strike(u, o, DUET_DMG, true)
	u.waltz_step = 2  # o próximo Passo de Valsa já é o Giro (o botão brilha)
	if fresh and u.controlled:
		hud.toast("PAR DE DANÇA: %s" % o.unit_name.to_upper(), 1.2)


## Pirueta: três voltas na ponta do pé. Enquanto gira (TWIRL_TIME), golpe nenhum pega nela (ver hurt:
## é o BRAVO!). Dá dano se estiver ao alcance, rende Embalo e o Par acompanha, como num Giro.
func _twirl(u: Unit) -> void:
	u.twirl_t = TWIRL_TIME
	u.twirl_hit = false
	u.waltz_anim("pirueta", TWIRL_TIME)
	_chimes([7, 9, 12, 16], 0.09)
	var r := skirt_r(u)
	var cols := [LILAC.lightened(0.3), ROSE_GOLD, Color(1, 1, 1)]
	for k in 3:
		get_tree().create_timer(k * 0.16, false).timeout.connect(func():
			if is_instance_valid(u) and u.alive:
				_ring_floor(u.position, cols[k], 0.5, r * (0.6 + k * 0.2), 0.42)
				_swirl(u.position + Vector3(0, 0.5 + k * 0.9, 0), cols[(k + 1) % 3], 1.5 - k * 0.25, 0.5, true)
				_petals(u.position + Vector3(0, 0.8 + k * 0.4, 0), 7, r * 0.8, 2.0, 0.9))
	if _in_range(u):
		var hit := _waltz_at()
		_ribbon(u, hit, true)
		_swirl(hit, ROSE_GOLD, 2.3, 0.6)
		_swirl(hit, LILAC.lightened(0.4), 1.4, 0.5)
		_petals(hit, 12, 2.6, 1.3, 0.8, 0.7)
		_damage_boss(u, TWIRL_DMG, true, true)
	_embalo_add(u, 1)
	_duet_echo(u)


## BRAVO!: um golpe chegou no meio da Pirueta e passou direto. A plateia joga rosas, o Embalo sobe e
## a recarga da Pirueta cai. Vale uma vez por Pirueta (os outros golpes do mesmo giro só são desviados).
func _bravo(u: Unit) -> void:
	_petals(u.position + Vector3(0, 1.2, 0), 8, 1.6)
	_swirl(u.position + Vector3(0, 1.3, 0), Color(1, 1, 1), 1.3, 0.35)
	if u.twirl_hit:
		return
	u.twirl_hit = true
	_embalo_add(u, TWIRL_BRAVO)
	u.skill_cd[2] *= TWIRL_REFUND
	_rose_rain(u.position)
	_chimes([12, 16, 19], 0.06)
	if u.controlled:
		hud.toast("BRAVO!", 0.9)
		hud.flash(ROSE_GOLD, 0.25)


## Rosas jogadas da plateia: caem em volta dela e ficam um instante no chão.
func _rose_rain(at: Vector3) -> void:
	for k in 7:
		var a := randf() * TAU
		var land := Vector3(at.x + cos(a) * randf_range(0.8, 2.4), 0.08, at.z + sin(a) * randf_range(0.8, 2.4))
		var rose := Fx.rose(fx_root, 0.17)
		rose.position = land + Vector3(randf_range(-3.0, 3.0), 6.0, 5.0)
		var t := randf_range(0.35, 0.6)
		var tw := rose.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(rose, "position", land, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(rose, "rotation", Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), 0), t)
		tw.tween_property(rose, "rotation", Vector3.ZERO, 0.08)
		tw.tween_interval(0.7)
		tw.tween_property(rose, "scale", Vector3.ONE * 0.01, 0.2)
		tw.tween_callback(rose.queue_free)


## Chuva de Pétalas: ela joga o buquê pro alto, ele estoura e as pétalas caem dentro da saia por
## PETAL_TIME, curando quem está na dança (a cura por segundo sai em _tick_valsa).
func _petal_rain(u: Unit) -> void:
	u.petal_t = PETAL_TIME
	u.petal_tick = 1.0
	u.waltz_anim("toss")
	_chimes([0, 4, 7, 12], 0.07)
	var top := u.position + Vector3(0, 4.6, 0)
	var bouquet := Fx.rose(fx_root, 0.3)
	bouquet.position = u.position + Vector3(0, 2.2, 0)
	var r := skirt_r(u)
	var tw := bouquet.create_tween()
	tw.tween_property(bouquet, "position", top, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bouquet, "rotation", Vector3(5.0, 3.0, 0), 0.3)
	tw.tween_callback(bouquet.queue_free)
	tw.tween_callback(func():
		_burst(top, ROSE_GOLD, 2.6)
		_swirl(top, ROSE_GOLD, 1.9, 0.6)
		_petals(top, 28, r, 1.0, 1.4))
	_dance_heal(u, PETAL_BURST, 52)


## Crescendo: a música sobe. Por CRESC_TIME o bônus da saia dobra, o compasso acelera e o Embalo não cai.
func _crescendo(u: Unit) -> void:
	u.crescendo_t = CRESC_TIME
	u.embalo_t = EMBALO_HOLD
	u.skill_cd[0] = minf(u.skill_cd[0], 0.2)
	u.waltz_anim("crescendo")
	_chimes([0, 4, 7, 12, 16, 19], 0.06)
	var r := skirt_r(u)
	_ring_floor(u.position, ROSE_GOLD, 0.5, r, 0.6)
	_ring_floor(u.position, Color(1, 1, 1), 0.3, r * 0.8, 0.5)
	for k in 4:
		get_tree().create_timer(0.1 + k * 0.09, false).timeout.connect(func():
			if is_instance_valid(u) and u.alive:
				_swirl(u.position + Vector3(0, 0.6 + k * 0.85, 0), ROSE_GOLD if k % 2 == 0 else Color(1, 1, 1), 2.1 - k * 0.3, 0.6, true))
	_petals(u.position + Vector3(0, 1.0, 0), 18, r, 2.4, 1.1, 0.8)
	for o in units:
		if o != u and _in_dance(u, o):
			_swirl(o.position + Vector3(0, 2.2, 0), ROSE_GOLD, 1.0, 0.6)
			_ring_floor(o.position, ROSE_GOLD, 0.3, 1.3, 0.5)
	if u.controlled:
		hud.toast("CRESCENDO: BÔNUS DA SAIA EM DOBRO", 1.4)
		hud.edge_glow(ROSE_GOLD, 0.8, 0.8)


## Grande Baile: a arena vira salão por BALL_TIME. A party inteira conta como dentro da saia, o Embalo
## fica no máximo, todo mundo acompanha os Giros dela, e o baile fecha com o último acorde (_ball_finale).
func _grand_ball(u: Unit) -> void:
	u.ball_t = BALL_TIME
	_embalo_add(u, EMBALO_MAX)
	u.waltz_anim("ball", 1.2)
	_ball_build()
	_chimes([0, 7, 4, 7, 12, 16, 12, 19], 0.11)
	hud.toast("GRANDE BAILE", 1.6)
	hud.flash(LILAC.lightened(0.3), 0.3)
	_ring_floor(u.position, ROSE_GOLD, 0.5, arena_r, 0.9)
	_ring_floor(u.position, LILAC.lightened(0.3), 0.3, arena_r * 0.8, 0.7)
	_petals(u.position + Vector3(0, 1.2, 0), 30, 5.0, 3.0, 1.3, 0.6)
	for o in units:
		if o.alive:
			_swirl(o.position + Vector3(0, 0.1, 0), ROSE_GOLD, 1.7, 0.8, true)
			_swirl(o.position + Vector3(0, 2.4, 0), Color(1, 1, 1), 0.9, 0.6)
	shake_t = maxf(shake_t, 0.25)
	shake_amp = maxf(shake_amp, 0.2)


## O salão: a roseta da saia do tamanho da arena, o lustre descendo do alto e um foco de luz por herói.
func _ball_build() -> void:
	if ball_node != null and is_instance_valid(ball_node):
		ball_node.queue_free()
	ball_node = Node3D.new()
	fx_root.add_child(ball_node)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/valsa_aura.gdshader")
	mat.set_shader_parameter("lobes", 16.0)
	mat.set_shader_parameter("energy", 1.0)
	mat.set_shader_parameter("gold", 0.35)
	mat.set_shader_parameter("alpha", 0.0)
	ball_mat = mat
	var floor_mi := Fx.inst(ball_node, plane, mat, Vector3(0, 0.03, 0))
	floor_mi.scale = Vector3(arena_r / 0.93, 1.0, arena_r / 0.93)
	floor_mi.create_tween().tween_method(func(a: float): mat.set_shader_parameter("alpha", a), 0.0, 0.8, 0.5)
	ball_lamp = Node3D.new()
	ball_lamp.position = Vector3(0, 19.0, -2.0)
	ball_node.add_child(ball_lamp)
	var gold_m := Fx.mat(ROSE_GOLD, 3.0, true)
	Fx.inst(ball_lamp, Fx.torus(2.2, 2.45), gold_m)
	Fx.inst(ball_lamp, Fx.torus(1.0, 1.18), gold_m, Vector3(0, 0.8, 0))
	Fx.inst(ball_lamp, Fx.cyl(0.07, 0.07, 6.0), gold_m, Vector3(0, 3.8, 0))
	Fx.inst(ball_lamp, Fx.sphere(0.5), Fx.mat(Color(1.0, 0.95, 0.75), 6.0, true), Vector3(0, -0.5, 0))
	var candle_m := Fx.mat(Color(1.0, 0.95, 0.7), 8.0, true)
	var drop_m := Fx.mat(Color(0.85, 0.75, 1.0), 5.0, true)
	for k in 10:
		var a := k * TAU / 10.0
		Fx.inst(ball_lamp, Fx.sphere(0.2), candle_m, Vector3(cos(a) * 2.32, 0.3, sin(a) * 2.32))
		var drop := Fx.inst(ball_lamp, Fx.sphere(0.11), drop_m, Vector3(cos(a) * 2.32, -0.5, sin(a) * 2.32))
		drop.scale.y = 1.8
	ball_lamp.create_tween().tween_property(ball_lamp, "position:y", 10.5, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ball_spots.clear()
	for o in units:
		var cone := Fx.inst(ball_node, Fx.cyl(0.12, 1.25, 9.0), Fx.mat(Color(1.0, 0.92, 0.6, 0.1), 2.0, true), o.position + Vector3(0, 4.5, 0))
		cone.visible = o.alive
		ball_spots.append(cone)


func _ball_clear() -> void:
	var node := ball_node
	var mat := ball_mat
	ball_node = null
	ball_spots.clear()
	if node == null or not is_instance_valid(node):
		return
	var tw := node.create_tween()
	tw.tween_method(func(a: float): mat.set_shader_parameter("alpha", a), 0.8, 0.0, 0.5)
	tw.parallel().tween_property(node, "scale", Vector3(1.0, 0.01, 1.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## O último acorde: ela faz a reverência, a luz de todo mundo corre pra boss e uma rosa enorme desabrocha nela.
func _ball_finale(u: Unit) -> void:
	u.waltz_anim("bow", 0.5)
	_chimes([12, 16, 19, 24], 0.05)
	var hit := _bp(Vector3(0, 3.6, -11.0))
	for o in units:
		if o.alive:
			_beam(o.position + Vector3(0, 0.4, 0), hit - Vector3(0, 1.0, 0), Color(1.0, 0.86, 0.45, 0.85), 0.5)
			_ring_floor(o.position, ROSE_GOLD, 0.3, 1.6, 0.5)
	var bloom := Fx.rose(fx_root, 0.3)
	bloom.position = hit
	bloom.rotation.x = PI / 2.0
	var tb := bloom.create_tween()
	tb.tween_property(bloom, "scale", Vector3.ONE * 2.6, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tb.parallel().tween_property(bloom, "rotation:z", TAU * 0.5, 0.7)
	tb.tween_interval(0.25)
	tb.tween_property(bloom, "scale", Vector3.ONE * 0.01, 0.2)
	tb.tween_callback(bloom.queue_free)
	_swirl(hit, ROSE_GOLD, 5.0, 0.9)
	_swirl(hit, Color(1, 1, 1), 3.0, 0.7)
	_petals(hit, 44, 5.5, 2.6, 1.4, 0.7)
	_burst(hit, ROSE_GOLD, 7.0)
	hud.flash(ROSE_GOLD, 0.3)
	hud.toast("ÚLTIMO ACORDE", 1.2)
	shake_t = 0.4
	shake_amp = 0.45
	for o in units:
		if o.alive and o.hp < o.max_hp:
			o.hp = minf(o.max_hp, o.hp + BALL_END_HEAL)
			_popup(int(BALL_END_HEAL), Color(0.75, 1.0, 0.7), 56, o.position + Vector3(0, 2.6, 0), "+")
	_ball_clear()
	_damage_boss(u, BALL_END_DMG, true, true)


## Valsa, a cada frame (só viva): os tempos do kit, a chuva de pétalas e o Embalo, que cai se ela para de girar.
func _tick_valsa(u: Unit, delta: float) -> void:
	u.twirl_t = maxf(0.0, u.twirl_t - delta)
	if u.partner != null and not u.partner.alive:
		u.partner = null  # o fio se desfaz; o Passo a Dois escolhe outro
	if u.crescendo_t > 0.0:
		u.crescendo_t = maxf(0.0, u.crescendo_t - delta)
		if randf() < delta * 7.0:
			var a := randf() * TAU
			var d := randf() * skirt_r(u)
			_swirl(u.position + Vector3(cos(a) * d, randf_range(0.3, 2.6), sin(a) * d), ROSE_GOLD, randf_range(0.35, 0.7), 0.5)
	if u.petal_t > 0.0:
		u.petal_t = maxf(0.0, u.petal_t - delta)
		if randf() < delta * 16.0:
			_petal_fall(u.position, skirt_r(u))
		u.petal_tick -= delta
		if u.petal_tick <= 0.0:
			u.petal_tick += 1.0
			_dance_heal(u, PETAL_HPS, 34)
	if u.ball_t > 0.0:
		u.ball_t -= delta
		u.embalo = EMBALO_MAX
		u.embalo_t = EMBALO_HOLD
		if randf() < delta * 14.0:
			_petal_fall(Vector3.ZERO, arena_r, 0.5)
		if u.ball_t <= 0.0:
			u.ball_t = 0.0
			_ball_finale(u)
			return
	elif u.embalo > 0 and u.crescendo_t <= 0.0:
		u.embalo_t -= delta
		if u.embalo_t <= 0.0:
			u.embalo -= 1
			u.embalo_t = EMBALO_DROP


## Valsa na mão da IA sem a carta Rotação: dança sozinha enquanto bate. A cada AI_WALTZ_EVERY ela gira,
## junta Embalo (até AI_WALTZ_MAX) e o Par (quem o jogador controla, de preferência) acompanha.
func _ai_waltz(u: Unit, delta: float) -> void:
	if u.partner == null:
		u.partner = _duet_pick(u, true)
	u.ai_waltz += delta
	if u.ai_waltz < AI_WALTZ_EVERY:
		return
	u.ai_waltz = 0.0
	u.face(boss_pos - u.position)
	u.waltz_anim("giro", 0.36)
	var r := skirt_r(u)
	_ring_floor(u.position, LILAC.lightened(0.3), 0.6, r, 0.45)
	_petals(u.position + Vector3(0, 0.7, 0), 8, r * 0.8, 1.6, 0.9)
	_swirl(_waltz_at(), ROSE_GOLD, 1.4, 0.5)
	if u.embalo < AI_WALTZ_MAX:
		_embalo_add(u, 1)
	else:
		u.embalo_t = EMBALO_HOLD
	_duet_echo(u)


## O que se vê da Valsa no mundo, a cada frame: a roseta da saia no chão (o alcance do bônus), o fio
## dourado até o Par, a voluta girando sob quem está recebendo o bônus e o salão do Grande Baile.
func _tick_valsa_view(delta: float) -> void:
	var any := false
	var any_ball := false
	for v in units:
		if v.key != "valsa":
			continue
		any = true
		var on: bool = v.alive
		v.aura.visible = on
		if on:
			var r := skirt_r(v) / 0.93
			v.aura.scale = v.aura.scale.lerp(Vector3(r, 1.0, r), minf(1.0, delta * 8.0))
			v.aura_spin += delta * (0.3 + 0.28 * v.embalo + v.skirt_kick * 6.0 + (1.6 if v.crescendo_t > 0.0 else 0.0))
			v.aura_mat.set_shader_parameter("spin", v.aura_spin)
			v.aura_mat.set_shader_parameter("energy", float(v.embalo) / EMBALO_MAX)
			v.aura_mat.set_shader_parameter("gold", 1.0 if v.crescendo_t > 0.0 else 0.0)
			v.aura_mat.set_shader_parameter("alpha", 1.0 if v.controlled else 0.75)
			any_ball = any_ball or v.ball_t > 0.0
		_thread_view(v, on and v.partner != null and v.partner.alive)
	if not any:
		return
	if valsa_marks.size() < units.size() or not is_instance_valid(valsa_marks[0]):
		valsa_marks.clear()
		for i in units.size():
			var made := Fx.inst(fx_root, Fx.spiral_mesh(), Fx.flat(Color(1.5, 1.2, 0.45, 0.85)))
			made.rotation.x = -PI / 2.0
			made.visible = false
			valsa_marks.append(made)
	for i in units.size():
		var o := units[i]
		var mk: MeshInstance3D = valsa_marks[i]
		var b := valsa_bonus(o)
		mk.visible = b > 0.0
		if mk.visible:
			mk.position = Vector3(o.position.x, 0.07, o.position.z)
			mk.rotation.z -= delta * (2.5 + b * 20.0)
			mk.scale = Vector3.ONE * (0.8 + b * 2.2)
	if ball_node != null and is_instance_valid(ball_node):
		if any_ball:
			ball_mat.set_shader_parameter("spin", Time.get_ticks_msec() * 0.00035)
			ball_lamp.rotation.y += delta * 0.6
			for i in mini(ball_spots.size(), units.size()):
				var cone: MeshInstance3D = ball_spots[i]
				cone.visible = units[i].alive
				cone.position = units[i].position + Vector3(0, 4.5, 0)
		else:
			_ball_clear()


## O fio do Par: contas douradas correndo em espiral dela até ele, e uma rosa girando em cima dele.
func _thread_view(v: Unit, on: bool) -> void:
	var th: Dictionary = valsa_threads.get(v.idx, {})
	if th.is_empty() or not is_instance_valid(th["root"]):
		if not on:
			return
		var made := Node3D.new()
		fx_root.add_child(made)
		var made_beads: Array = []
		var bead_m := Fx.mat(Color(1.0, 0.84, 0.4), 6.0, true)
		for k in 14:
			made_beads.append(Fx.inst(made, Fx.sphere(0.07), bead_m))
		th = {"root": made, "beads": made_beads, "rose": Fx.rose(made, 0.2)}
		valsa_threads[v.idx] = th
	var root: Node3D = th["root"]
	root.visible = on
	if not on:
		return
	var t := Time.get_ticks_msec() * 0.001
	var a := v.position + Vector3(0, 1.25, 0)
	var along := v.partner.position - v.position
	var side := Vector3.RIGHT
	if along.length() > 0.05:
		side = Vector3(-along.z, 0, along.x).normalized()
	var beads: Array = th["beads"]
	for k in beads.size():
		var f := fmod(float(k) / beads.size() + t * 0.35, 1.0)
		var wind := f * TAU * 2.5 - t * 5.0
		var bead: MeshInstance3D = beads[k]
		bead.position = a + along * f + Vector3(0, sin(f * PI) * 0.9 + sin(wind) * 0.2, 0) + side * cos(wind) * 0.2
		bead.scale = Vector3.ONE * (0.6 + sin(f * PI) * 0.9)
	var rose: Node3D = th["rose"]
	rose.position = v.partner.position + Vector3(0, 2.75 + sin(t * 3.0) * 0.08, 0)
	rose.rotation = Vector3(0.5, t * 2.0, 0)


# ---------------------------------------------------------------- Apotecário

## Buffs ativos do herói, pro HUD mostrar ao lado do card dele: [{"icon": Texture2D, "t": segundos}].
## O ícone é o da habilidade que deu o buff (SkillInfo.icon). Só entra o que tem tempo correndo.
func buffs_of(u: Unit) -> Array:
	var out: Array = []
	if not u.alive:
		return out
	var list := [
		[u.guard_t if u.key == "tank" else 0.0, "tank", 4, false],        # Égide
		[u.wall_t, "tank", 5, false],                                       # Muralha da Fé (a party toda)
		[u.taste_t, "nurse", 1, false],                                     # Blood Taste
		[u.party_t, "nurse", 4, false],                                     # Blood Party
		[u.bath_t, "nurse", 5, false],                                      # Bloodbath (mitigação na party)
		[u.mend_t if u.mend_rate == SHARE_REGEN else 0.0, "nurse", 2, false],  # Compartilhamento de Sangue
		[u.frenzy_t, "assassina", 5, false],                                # Frenesi da Fera
		[maxf(u.power_t, u.ward_t), "maga", 1, false],                      # bala Rainbow (dano / guarda)
		[u.count_t, "ringstar", 3, false],                                  # Contagem Regressiva
		[u.petal_t, "valsa", 3, false],                                     # Chuva de Pétalas
		[u.crescendo_t, "valsa", 4, false],                                 # Crescendo
		[u.ball_t, "valsa", 5, false],                                      # Grande Baile
		[u.shield_t if u.shield_hp > 0.0 and u.shield_t < 60.0 else 0.0, "healer", 3, false],  # escudo
		[maxf(u.mend_t, u.haste_t), "apothecary", 4, false],                # regeneração e pressa da Tanatopraxia
		[u.near_t, "sleepwalker", 0, true],                                 # Perto do Sonho
		[dream_t if (u.key == "sleepwalker" and dream_stacks > 0) else 0.0, "sleepwalker", 1, false],  # Vulnerabilidade Onírica
		[u.immortal_t if u.party_t <= 0.0 else 0.0, "tank", 2, false],      # imortal (Limit Break do Tank)
	]
	for b in list:
		if float(b[0]) > 0.0:
			out.append({"icon": SkillInfo.icon(b[1], b[2], b[3]), "t": float(b[0])})
	# Valsa: o Crescendo e o Grande Baile aparecem também em quem está na dança dela
	for v in units:
		if v.key == "valsa" and v != u and _in_dance(v, u):
			if v.crescendo_t > 0.0:
				out.append({"icon": SkillInfo.icon("valsa", 4), "t": v.crescendo_t})
			if v.ball_t > 0.0:
				out.append({"icon": SkillInfo.icon("valsa", 5), "t": v.ball_t})
	# Paciente do Apotecário: aparece em quem está sendo cuidado
	for o in units:
		if o.key == "apothecary" and o.alive and o.patient == u and o.patient_t > 0.0:
			out.append({"icon": SkillInfo.icon("apothecary", 2), "t": o.patient_t})
	return out


## Velocidade de andar do herói agora: base x a da classe x a pressa, se tiver.
func move_speed(u: Unit) -> float:
	var haste := HASTE_MULT if u.haste_t > 0.0 else 1.0
	if Knowledge.has(u.hero, "boots"):
		haste *= 1.12  # Botas Leves
	if u.count_t > 0.0:
		haste *= COUNT_SPEED  # Contagem Regressiva da Ringstar
	# A lentidão de classe é pra quem o JOGADOR controla (é o peso do personagem na mão). A IA anda na
	# velocidade-base: os tempos das mecânicas foram medidos com ela, e mais devagar a party morre nelas.
	if not u.controlled:
		return u.speed * haste
	return u.speed * float(MOVE_MULT.get(u.key, MOVE_DEFAULT)) * haste


## Primeiro aliado caído (ou null). `pick`: o escolhido no card tem prioridade, se estiver caído.
func _fallen(pick := -1) -> Unit:
	if pick >= 0 and not units[pick].alive:
		return units[pick]
	for o in units:
		if not o.alive:
			return o
	return null


## Levanta um aliado caído (reviver de habilidade): vida, Fraqueza, cartas de início e o aviso.
func _raise(o: Unit, hp_ratio: float, col: Color) -> void:
	o.revive(hp_ratio)
	o.weak_t = WEAK_TIME
	_spawn_cards(o)
	_burst(o.position, Color(1, 1, 1), 2.4)
	_burst(o.position, col, 3.4)
	_impact_ring(o.position + Vector3(0, 0.3, 0), col, 3.0)
	hud.toast(o.unit_name + " voltou", 2.0)


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
	u.face(boss_pos - u.position)
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
			_beam(u.position, _bp(Vector3(0, 3.0, -11.5)), Color(0.75, 0.3, 0.9, 0.95), 0.4)
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
		_burst(_bp(Vector3(0, 3, -11.5)), Color(0.6, 0.85, 0.2), 7.0)
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
		o.haste_t = HASTE_TIME  # a nuvem deixa todo mundo mais leve
		o.mend_t = CLOUD_TIME
		o.mend_rate = CLOUD_REGEN * boost
		u.enmity += each * HEAL_ENMITY * 0.5
		_burst(o.position, CHEM, 1.6)
		_popup(int(each), Color(0.5, 1.0, 0.85), 52, o.position + Vector3(0, 2.6, 0), "+")


# ---------------------------------------------------------------- Sleepwalker

## Recarga de uma habilidade do Sleepwalker, já com o -1 s do Perto do Sonho.
func _sw_cd(u: Unit, base: float) -> float:
	return maxf(0.3, base - (1.0 if u.near_t > 0.0 else 0.0))


## Conjuração da habilidade do slot, agora. Só Acordar é na hora (é o botão de emergência, e já
## cobra a punição de acordar mal).
func sw_cast(u: Unit, slot: int) -> float:
	if slot == 5 and u.asleep:
		return 0.0
	return SW_CAST_NEAR if u.near_t > 0.0 else SW_CAST


## Dá pra começar a conjurar a habilidade do slot? (tudo que faria ela falhar é checado ANTES do
## cast, pra ele nunca terminar à toa)
func _sw_can(u: Unit, slot: int) -> bool:
	if slot == 5:
		return true
	if u.asleep:
		if slot != u.dream_step or u.wake_t > 0.0:
			u.set_action("Fora de ordem", 2)
			return false
		return slot == 0 or u.torpor >= float(SKILLS_ASLEEP[slot]["cost"])
	if not _in_range(u):
		u.set_action("Longe demais", 2)
		return false
	return true


func _dream_add(n: int) -> void:
	if n <= 0:
		return
	dream_stacks = mini(DREAM_MAX, dream_stacks + n)
	dream_t = DREAM_TIME


func _sw_hit(u: Unit, base: float, big: bool) -> void:
	u.face(boss_pos - u.position)
	_attack_fx(u, big)
	_damage_boss(u, base * SW_SCALE, true, big)


## Soma Torpor. Ao encher (100), ele segura cheio por SW_FULL_HOLD segundos antes de voltar a cair:
## dá tempo de decidir e conjurar o Sono Profundo com a barra inteira.
func _torpor_add(u: Unit, n: float) -> void:
	var was := u.torpor
	u.torpor = minf(100.0, u.torpor + n)
	if u.torpor >= 100.0 and was < 100.0:
		u.torpor_hold = SW_FULL_HOLD


## Todas as habilidades do Sleepwalker passam por aqui (acordado e dormindo).
func _sleep_skill(u: Unit, slot: int) -> void:
	if slot == 5:
		_sw_toggle(u)
		return
	if u.asleep:
		_sw_dream(u, slot)
		return
	var def: Dictionary = SW_AWAKE[slot]
	# a recarga conta desde o começo da conjuração, como um GCD: o cast cabe dentro dela
	u.skill_cd[slot] = maxf(0.25, _sw_cd(u, SKILLS["sleepwalker"][slot]["cd"]) - u.channel_total)
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
				gain += SW_ECHO_TORPOR
				_burst(_bp(Vector3(0, 3.5, -11.5)), Color(1, 1, 1), 3.4)
				if u.controlled:
					hud.toast("FRESTA!", 0.6)
				break
		_torpor_add(u, gain)
		_sw_hit(u, amount, amount > 60.0)
		return
	# sequência Lençol (1) -> Visitantes (2) -> Travesseiro (3) -> Cama (4): cada uma abre 1 s pra próxima
	var perfect: bool = slot == 1 or u.cast_perfect
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
		# fora da sequência (ou fora da janela): a corrente quebra aqui, como na Ringstar
		u.crumbs = false
		u.pillow_full = false
		if u.controlled:
			hud.toast("FORA DA SEQUÊNCIA", 0.8)
	elif slot > 1 and u.controlled:
		hud.toast("PERFEITO", 0.5)
	_dream_add(stacks)
	_torpor_add(u, gain)
	# A sequência só existe a partir do Puxar o Lençol: a janela da próxima abre apenas depois de
	# um passo acertado. Usar Visitantes, Travesseiro ou Cama soltos não acende nada adiante.
	var chain_on: bool = perfect and slot < 4
	u.window_slot = slot + 1 if chain_on else -1
	u.window_t = SW_WINDOW if chain_on else 0.0
	_sw_hit(u, amount, true)


## Sono Profundo / Acordar.
func _sw_toggle(u: Unit) -> void:
	u.skill_cd[5] = 3.0
	if u.asleep:
		_sw_wake(u, true)
		return
	u.asleep = true
	u.dream_step = 0
	u.cast_perfect = false
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
## `clean`: fechou a sequência com A Casa que Engole, então não tem punição. Qualquer outro jeito
## de acordar deixa ele um tempo sem agir (silence_t), conforme até onde foi no sonho.
func _sw_wake(u: Unit, lose: bool, clean := false) -> void:
	var steps := u.dream_step  # até onde ele foi no sonho
	var lock := 0.0
	if not clean:
		lock = SW_LOCK_NONE if u.dream_step == 0 else (SW_LOCK_BITE if u.dream_step == 1 else SW_LOCK_BROKEN)
	u.silence_t = lock
	u.channel_t = 0.0
	if u.controlled and lock > 0.0:
		var why := "ACORDOU À TOA" if u.dream_step == 0 else ("VISITA CURTA" if u.dream_step == 1 else "ROTAÇÃO QUEBRADA")
		hud.toast("%s: %d s sem agir" % [why, int(lock)], 1.4)
	u.bite_cd = u.skill_cd[0]
	u.asleep = false
	u.dream_step = 0
	u.wake_t = 0.0
	if lose:
		# visita curta (só a Mordida, pra renovar o DoT) custa SW_BITE_WAKE; largar o sonho de
		# qualquer outro jeito custa o Torpor todo
		u.torpor = maxf(0.0, u.torpor - SW_BITE_WAKE) if steps == 1 else 0.0
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
		_sw_wake(u, false, true)
		return
	u.dream_step = slot + 1
	for n in range(1, 5):
		u.skill_cd[n] = SW_STEP_GAP
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
	if u.silence_t > 0.0:
		u.silence_t = maxf(0.0, u.silence_t - delta)
		u.set_action("Sonolento  %.1f" % u.silence_t, 2)
	if not u.asleep:
		if u.torpor_hold > 0.0:
			u.torpor_hold -= delta
		else:
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
	var node := _hearth_node(Vector3(u.position.x, 0.05, u.position.z), false)
	hearths.append({"node": node, "owner": u, "t": HEARTH_TIME, "tick": 0.0, "strong": false, "r": HEARTH_R, "hps": HEARTH_HPS})
	_burst(u.position, FLAME, HEARTH_R)


## O desenho da fogueira. Forte (depois do Renascimento): área maior, anel duplo, o dobro de línguas
## de fogo, mais altas e com miolo branco.
func _hearth_node(at: Vector3, strong: bool) -> Node3D:
	var node := Node3D.new()
	fx_root.add_child(node)
	node.position = at
	var r := HEARTH_STRONG_R if strong else HEARTH_R
	Fx.inst(node, Fx.disc(r), Fx.mat(Color(FLAME.r, FLAME.g, FLAME.b, 0.22 if strong else 0.14), 0.0, true))
	Fx.inst(node, Fx.torus(r - 0.1, r), Fx.mat(Color(FLAME.r * 0.9, FLAME.g * 0.9, FLAME.b * 0.9) if strong else FLAME.darkened(0.5), 3.0, true))
	if strong:
		Fx.inst(node, Fx.torus(r * 0.6 - 0.08, r * 0.6), Fx.mat(Color(1.0, 1.0, 0.8), 0.0, true), Vector3(0, 0.01, 0))
	# a chama: línguas de fogo azul-esverdeado
	var count := 7 if strong else 3
	for n in count:
		var a := n * TAU / count
		var off := Vector3(cos(a), 0, sin(a)) * (0.5 if strong else 0.0) + Vector3((n - 1) * 0.22 if not strong else 0.0, 0, 0)
		var tall := (2.6 - (n % 3) * 0.4) if strong else (1.5 - n * 0.3)
		# (o brilho do fogo dela foi cortado pela metade: estava estourando na tela)
		var col := FLAME.lightened((n % 3) * 0.25).darkened(0.5)
		if strong:
			col = FLAME.lightened((n % 3) * 0.25).darkened(0.05)
		var tongue := Fx.inst(node, Fx.cyl(0.02, (0.5 if strong else 0.34) - (n % 3) * 0.08, tall), Fx.mat(col, 4.0, true), off + Vector3(0, tall * 0.5, 0))
		tongue.set_meta("flame", n)
	if strong:
		Fx.inst(node, Fx.sphere(0.5), Fx.mat(Color(1.2, 1.2, 1.0), 0.0, true), Vector3(0, 0.6, 0))
	return node


## Renascimento passou pela Lareira: ela fica forte (mais cura, mais alcance, dura de novo) e o fogo cresce.
func _hearth_empower(h: Dictionary) -> void:
	var at: Vector3 = h["node"].position
	h["node"].queue_free()
	h["node"] = _hearth_node(at, true)
	h["strong"] = true
	h["t"] = HEARTH_STRONG_TIME
	h["r"] = HEARTH_STRONG_R
	h["hps"] = HEARTH_STRONG_HPS
	_burst(at, Color(1, 1, 1), 4.0)
	_burst(at, FLAME, HEARTH_STRONG_R)
	_impact_ring(at + Vector3(0, 0.3, 0), FLAME, HEARTH_STRONG_R)
	hud.toast("LAREIRA FORTALECIDA", 1.4)


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
			var hps: float = h["hps"]
			if h["strong"]:
				# fogo forte: fagulhas subindo por toda a área
				for k in 6:
					var a := randf() * TAU
					var p: Vector3 = node.position + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, float(h["r"]))
					var em := Fx.mat(FLAME, 0.0, true)
					var spark := Fx.inst(fx_root, Fx.sphere(0.09), em, p + Vector3(0, 0.2, 0))
					var ts := spark.create_tween().set_parallel(true)
					ts.tween_property(spark, "position:y", randf_range(2.0, 3.6), 0.9)
					ts.tween_property(spark, "scale", Vector3.ONE * 0.1, 0.9)
					ts.chain().tween_callback(spark.queue_free)
			for o in units:
				if o.alive and o.position.distance_to(node.position) <= float(h["r"]):
					# fagulhas subindo em volta de quem está na fogueira
					_burst(o.position + Vector3(0, 0.6, 0), FLAME, 1.6 if h["strong"] else 1.1)
					if o.hp < o.max_hp:
						o.hp = minf(o.max_hp, o.hp + hps)
						owner.enmity += hps * HEAL_ENMITY
						_popup(int(hps), Color(0.5, 1.0, 0.85), 40, o.position + Vector3(0, 2.6, 0), "+")
		if h["t"] <= 0.0:
			node.queue_free()
			hearths.erase(h)


## Renascimento: uma fênix enorme atravessa o campo. Cura todos, levanta quem caiu, queima a boss
## e deixa um DoT leve nela. Se houver uma Lareira acesa, é dela que a fênix nasce, e a Lareira
## fica fortalecida (_hearth_empower).
func _rebirth(u: Unit) -> void:
	var from := u.position
	if not hearths.is_empty():
		# a fênix nasce da Lareira, e a Lareira fica mais forte em vez de sumir
		var h: Dictionary = hearths[hearths.size() - 1]
		from = h["node"].position
		_hearth_empower(h)
	hud.toast("RENASCIMENTO", 1.6)
	# cura e reviver saem já no nascimento
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
	_phoenix(u, from)


## A fênix do Renascimento. Nasce do fogo abrindo as asas, sobe, solta um grito (ondas de luz, tremor,
## as chamas do campo respondem) e só então atravessa a arena devagar até a boss, batendo as asas e
## largando fogo pelo caminho. O dano e o DoT saem quando ela chega.
func _phoenix(u: Unit, from: Vector3) -> void:
	var gold := Color(1.0, 0.7, 0.25)
	var bird := Node3D.new()
	fx_root.add_child(bird)
	bird.position = from + Vector3(0, 0.6, 0)
	# corpo, cabeça com crista, bico e cauda
	Fx.inst(bird, Fx.sphere(0.9), Fx.mat(Color(gold.r * 1.3, gold.g * 1.3, gold.b * 1.3, 0.95), 0.0, true)).scale = Vector3(0.9, 0.9, 1.5)
	Fx.inst(bird, Fx.sphere(0.5), Fx.mat(Color(1.4, 1.3, 1.0), 0.0, true), Vector3(0, 0.55, -1.2))
	Fx.inst(bird, Fx.cyl(0.0, 0.16, 0.6), Fx.mat(Color(1.2, 0.9, 0.3), 0.0, true), Vector3(0, 0.5, -1.75)).rotation.x = -PI / 2.0
	for n in 3:
		var crest := Fx.inst(bird, Fx.cyl(0.0, 0.1, 0.8), Fx.mat(Color(FLAME.r * 1.2, FLAME.g * 1.2, FLAME.b * 1.2), 0.0, true), Vector3((n - 1) * 0.2, 1.1, -1.0))
		crest.rotation.x = 0.5
		crest.rotation.z = (n - 1) * -0.4
	for n in 5:
		var tail := BoxMesh.new()
		tail.size = Vector3(0.3, 0.06, 3.2 - absf(n - 2) * 0.5)
		var tm := Fx.inst(bird, tail, Fx.mat(Color(FLAME.r, FLAME.g, FLAME.b, 0.85).lerp(gold, 0.3 * (n % 2)), 0.0, true), Vector3((n - 2) * 0.32, -0.1, 2.4))
		tm.rotation.y = (n - 2) * -0.14
	# asas: cada uma um leque de penas de fogo, num pivô que bate
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.6, 0.3, 0)
		bird.add_child(pivot)
		for k in 5:
			var feather := BoxMesh.new()
			feather.size = Vector3(3.4 - k * 0.45, 0.07, 0.9)
			var col := gold.lerp(FLAME, k / 4.0)
			var fm := Fx.inst(pivot, feather, Fx.mat(Color(col.r * 1.1, col.g * 1.1, col.b * 1.1, 0.9), 0.0, true), Vector3(side * (1.7 - k * 0.2), 0, 0.2 + k * 0.55))
			fm.rotation.y = side * -k * 0.16
		pivot.rotation.z = side * -1.3  # nasce com as asas fechadas pra cima
		wings.append(pivot)
	bird.scale = Vector3.ONE * 0.15
	# 1. nascimento: sai do fogo, cresce e abre as asas
	_burst(from, Color(1, 1, 1), 3.0)
	_burst(from, gold, 5.0)
	for k in 3:
		_impact_ring(from + Vector3(0, 0.3, 0), [gold, FLAME, Color(1, 1, 1)][k], 2.5 + k * 1.5)
	var pillar_m := Fx.mat(Color(gold.r, gold.g, gold.b, 0.6), 0.0, true)
	var pillar := Fx.inst(fx_root, Fx.cyl(1.2, 1.8, 12.0), pillar_m, from + Vector3(0, 6.0, 0))
	var tp := pillar.create_tween().set_parallel(true)
	tp.tween_property(pillar, "scale", Vector3(0.05, 1.0, 0.05), REBIRTH_BIRTH).set_ease(Tween.EASE_IN)
	tp.tween_property(pillar_m, "albedo_color:a", 0.0, REBIRTH_BIRTH)
	tp.chain().tween_callback(pillar.queue_free)
	var hover := from + Vector3(0, 4.6, 0)
	var tw := bird.create_tween()
	tw.tween_property(bird, "position", hover, REBIRTH_BIRTH).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bird, "scale", Vector3.ONE * 1.5, REBIRTH_BIRTH).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in wings.size():
		var s := -1.0 if k == 0 else 1.0
		tw.parallel().tween_property(wings[k], "rotation:z", s * 0.25, REBIRTH_BIRTH).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bird.look_at_from_position(bird.position, _bp(Vector3(0, 5.0, -11.5)), Vector3.UP)
	# 2. o grito
	tw.tween_callback(_phoenix_cry.bind(hover, gold))
	tw.tween_property(bird, "scale", Vector3.ONE * 1.85, REBIRTH_CRY * 0.35)
	tw.tween_property(bird, "scale", Vector3.ONE * 1.6, REBIRTH_CRY * 0.65)
	# 3. o voo lento até a boss
	var hit := _bp(Vector3(0, 5.2, -11.5))
	tw.tween_property(bird, "position", hit, REBIRTH_FLY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_phoenix_hit.bind(u, hit, gold))
	tw.tween_property(bird, "scale", Vector3.ONE * 0.1, 0.25)
	tw.tween_callback(bird.queue_free)
	# batidas de asa durante o grito e o voo
	var flap := bird.create_tween().set_loops(8)
	flap.tween_interval(REBIRTH_BIRTH / 8.0)
	for k in wings.size():
		var s := -1.0 if k == 0 else 1.0
		flap.parallel().tween_property(wings[k], "rotation:z", s * -0.45, 0.22).set_delay(REBIRTH_BIRTH / 8.0)
	for k in wings.size():
		var s := -1.0 if k == 0 else 1.0
		flap.tween_property(wings[k], "rotation:z", s * 0.4, 0.2)
	# fogo que fica no chão pelo caminho
	var patches := 6
	for n in patches:
		var t := float(n + 1) / (patches + 1.0)
		var ground := Vector3(from.x, 0, from.z).lerp(_bp(Vector3(0, 0, -9.5)), t) + Vector3(randf_range(-1.4, 1.4), 0, randf_range(-0.8, 0.8))
		get_tree().create_timer(REBIRTH_BIRTH + REBIRTH_CRY + REBIRTH_FLY * t, false).timeout.connect(_fire_patch.bind(ground, gold))
		# e penas de fogo caindo dela
		get_tree().create_timer(REBIRTH_BIRTH + REBIRTH_CRY + REBIRTH_FLY * t - 0.1, false).timeout.connect(func():
			if not is_instance_valid(bird):
				return
			for k in 3:
				var fb := BoxMesh.new()
				fb.size = Vector3(0.5, 0.04, 0.16)
				var fm := Fx.mat(Color(gold.r, gold.g, gold.b, 0.95), 0.0, true)
				var feather := Fx.inst(fx_root, fb, fm, bird.position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-0.6, 0.6)))
				var tf := feather.create_tween().set_parallel(true)
				tf.tween_property(feather, "position:y", 0.2, 0.9).set_ease(Tween.EASE_IN)
				tf.tween_property(feather, "rotation", Vector3(TAU, TAU * 0.5, TAU), 0.9)
				tf.tween_property(fm, "albedo_color:a", 0.0, 0.9)
				tf.chain().tween_callback(feather.queue_free))


## O grito da fênix: som, ondas de luz saindo dela, clarão, tremor, e as chamas nos aliados respondendo.
func _phoenix_cry(at: Vector3, gold: Color) -> void:
	_sfx(_tone(1568.0, 0.45, false), -5.0)
	_sfx(_tone(2093.0, 0.35, false), -9.0)
	for k in 5:
		var m := Fx.mat(Color([gold, FLAME, Color(1, 1, 1)][k % 3].r, [gold, FLAME, Color(1, 1, 1)][k % 3].g, [gold, FLAME, Color(1, 1, 1)][k % 3].b, 0.9), 0.0, true)
		var ring := Fx.inst(fx_root, Fx.torus(0.9, 1.0), m, at)
		ring.rotation.x = PI / 2.0
		ring.scale = Vector3.ONE * 0.5
		var tr := ring.create_tween().set_parallel(true)
		tr.tween_property(ring, "scale", Vector3.ONE * (9.0 + k * 3.0), 0.7).set_delay(k * 0.08).set_ease(Tween.EASE_OUT)
		tr.tween_property(m, "albedo_color:a", 0.0, 0.7).set_delay(k * 0.08)
		tr.chain().tween_callback(ring.queue_free)
	_impact_ring(Vector3(at.x, 0.3, at.z), gold, 12.0)
	_burst(at, Color(1, 1, 1), 5.0)
	hud.flash(Color(1.0, 0.75, 0.3), 0.26)
	hud.toast("O GRITO DA FÊNIX", 1.2)
	shake_t = REBIRTH_CRY
	shake_amp = 0.4
	for o in units:
		if o.alive:
			_impact_ring(o.position + Vector3(0, 0.3, 0), FLAME, 1.8)
			_beam(at - Vector3(0, 1.0, 0), o.position, Color(gold.r, gold.g, gold.b, 0.5), 0.5)


## Um foco de fogo que a fênix deixa no chão: fica aceso REBIRTH_PATCH segundos e apaga devagar.
func _fire_patch(at: Vector3, gold: Color) -> void:
	var node := Node3D.new()
	fx_root.add_child(node)
	node.position = at
	var mats: Array = []
	var ground_m := Fx.mat(Color(gold.r, gold.g * 0.8, gold.b * 0.5, 0.4), 0.0, true)
	Fx.inst(node, Fx.disc(1.3, 0.03), ground_m, Vector3(0, 0.05, 0))
	mats.append(ground_m)
	for n in 5:
		var a := n * TAU / 5.0
		var tall := 1.0 + (n % 3) * 0.5
		var col := gold.lerp(FLAME, (n % 2) * 0.6)
		var m := Fx.mat(Color(col.r, col.g, col.b, 0.9), 0.0, true)
		var tongue := Fx.inst(node, Fx.cyl(0.02, 0.26, tall), m, Vector3(cos(a) * 0.5, tall * 0.5, sin(a) * 0.5))
		tongue.create_tween().set_loops().tween_property(tongue, "scale:y", 1.3, 0.25 + n * 0.05).set_trans(Tween.TRANS_SINE)
		mats.append(m)
	_burst(at, gold, 1.8)
	node.scale = Vector3(0.2, 0.2, 0.2)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(REBIRTH_PATCH - 1.25)
	tw.tween_property(node, "scale", Vector3(1.0, 0.05, 1.0), 1.0)
	for m in mats:
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(node.queue_free)


## A fênix chega na boss: a explosão, o dano e a Brasa da Fênix (o DoT).
func _phoenix_hit(u: Unit, hit: Vector3, gold: Color) -> void:
	if ended:
		return
	_burst(hit, Color(1, 1, 1), 9.0)
	_burst(hit, gold, 12.0)
	for k in 5:
		_impact_ring(hit, [Color(1, 1, 1), gold, FLAME][k % 3], 4.0 + k * 2.0)
	for n in 20:
		var a := n * TAU / 20.0
		var sp := Fx.inst(fx_root, Fx.sphere(0.18), Fx.mat([gold, FLAME][n % 2], 0.0, true), hit)
		var ts := sp.create_tween().set_parallel(true)
		ts.tween_property(sp, "position", hit + Vector3(cos(a), sin(a) * 0.8, 0.3) * randf_range(4.0, 8.0), 0.7).set_ease(Tween.EASE_OUT)
		ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.7)
		ts.chain().tween_callback(sp.queue_free)
	hud.flash(Color(1.0, 0.6, 0.2), 0.3)
	shake_t = 0.5
	shake_amp = 0.5
	boss.hit_flash()
	if not is_instance_valid(u):
		return
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
			plain_hit = d.get("plain", false)
			_damage_boss(d["owner"], d["dps"], false, false)
			plain_hit = false
			_popup(int(d["dps"]), (d["col"] as Color).lightened(0.2), 30)
			if ended:
				return
		if d["t"] <= 0.0:
			boss_dots.erase(d)


## Malpractice paga os próprios golpes com vida. Não é golpe da boss: não conta como parry (o Blood
## Taste só apara o que vem do inimigo, por hurt()) nem passa por mitigação ou escudo. Pode matar.
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
			if owner.alive and node.position.distance_to(boss_pos) <= HOLY_R + 1.4:
				_burst(boss_pos + Vector3(0, 0.6, 1.6), GOLD, 1.8)
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
	_beam(u.position, _bp(Vector3(0, 5.0, -11.5)), Color(1.0, 0.35, 0.6, 0.95), 0.45)
	boss.rage()
	# confirmação de que a boss foi provocada: uma etiqueta pequena ao lado dela
	hud.provoke_tag(cam.unproject_position(_bp(Vector3(4.6, 8.4, -12.0))))


func _add_stacks(u: Unit, n: int) -> void:
	u.stacks = mini(PARTY_NEED, u.stacks + n)


func _lifesteal(u: Unit, amount: float) -> void:
	if not u.alive or u.party_t > 0.0:
		return
	u.hp = minf(u.max_hp, u.hp + amount)
	if amount >= 1.0:
		_popup(int(amount), BLOOD.lightened(0.35), 48, u.position + Vector3(0, 2.6, 0), "+")


## Cura da própria Malpractice durante o Blood Party (roubo de vida e Extração): a única que entra.
func _party_heal(u: Unit, amount: float) -> void:
	if not u.alive or amount <= 0.0:
		return
	var was := u.hp
	u.hp = minf(u.max_hp, u.hp + amount)
	u.party_hp = u.hp
	if u.hp - was >= 1.0:
		_popup(int(u.hp - was), BLOOD.lightened(0.35), 44, u.position + Vector3(0, 2.6, 0), "+")
		_blood_return(u, 2)


## Gotas de sangue voltando da boss até ela (toda cura que vem de sangue roubado), com uma cruzinha
## médica subindo em cima dela.
func _blood_return(u: Unit, count: int) -> void:
	var from := boss_pos + Vector3(0, 2.2, 1.6)
	for n in count:
		var drop := Fx.inst(fx_root, Fx.sphere(0.11), Fx.mat(Color(1.8, 0.12, 0.25), 0.0, true), from + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.8), 0))
		var tw := drop.create_tween()
		tw.tween_interval(n * 0.05)
		tw.tween_property(drop, "position", u.position + Vector3(0, 1.2, 0), 0.24).set_ease(Tween.EASE_IN)
		tw.tween_callback(drop.queue_free)
	var cross := Node3D.new()
	fx_root.add_child(cross)
	cross.position = u.position + Vector3(randf_range(-0.4, 0.4), 2.0, 0.3)
	var cm := Fx.mat(Color(1.6, 0.25, 0.35, 0.95), 0.0, true)
	for size in [Vector3(0.1, 0.34, 0.04), Vector3(0.34, 0.1, 0.04)]:
		var bar := BoxMesh.new()
		bar.size = size
		Fx.inst(cross, bar, cm)
	var tc := cross.create_tween().set_parallel(true)
	tc.tween_property(cross, "position:y", cross.position.y + 1.0, 0.6)
	tc.tween_property(cm, "albedo_color:a", 0.0, 0.6)
	tc.chain().tween_callback(cross.queue_free)


## Syringe Poke: estocada rápida, uma perfuração pequena e um fio de sangue puxado da boss pra seringa.
func _poke_fx(u: Unit) -> void:
	u.syringe_stab(1.1)
	var at := boss_pos + Vector3(randf_range(-0.6, 0.6), 2.0, 1.7)
	_impact_ring(at, BLOOD.lightened(0.2), 0.9)
	_beam(at - Vector3(0, 1.0, 0), u.position + Vector3(0.4, 0.0, 0), Color(BLOOD.r * 1.8, BLOOD.g, BLOOD.b, 0.9), 0.28)
	u.set_fill(0.55, 0.08)
	u.create_tween().tween_callback(u.set_fill.bind(0.35, 0.3)).set_delay(0.2)
	_blood_return(u, 1)


## Blood Consumed: a seringa entra na boss e o reservatório enche de sangue; no fim, uma explosão de
## gotas e o vermelho correndo pelo corpo dela (a vida recuperada).
func _consumed_fx(u: Unit) -> void:
	u.syringe_stab(1.5, 0.35)
	u.set_fill(1.0, 0.35)
	var at := boss_pos + Vector3(0, 2.2, 1.7)
	for n in 8:
		# o sangue sendo sugado: gotas correndo da boss pra seringa
		var drop := Fx.inst(fx_root, Fx.sphere(0.1), Fx.mat(Color(1.8, 0.12, 0.25), 0.0, true), at + Vector3(randf_range(-1.2, 1.2), randf_range(-0.8, 1.2), 0))
		var tw := drop.create_tween()
		tw.tween_interval(n * 0.04)
		tw.tween_property(drop, "position", u.position + Vector3(0.4, 1.1, -0.6), 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(drop.queue_free)
	_beam(at - Vector3(0, 1.0, 0), u.position + Vector3(0.4, 0.0, 0), Color(BLOOD.r * 1.8, BLOOD.g, BLOOD.b, 0.95), 0.45)
	get_tree().create_timer(0.4, false).timeout.connect(func():
		if not is_instance_valid(u) or not u.alive:
			return
		_burst(at, BLOOD, 3.2)
		_impact_ring(at, BLOOD.lightened(0.2), 2.6)
		for n in 10:
			var a := n * TAU / 10.0
			var sp := Fx.inst(fx_root, Fx.sphere(0.09), Fx.mat(Color(1.8, 0.12, 0.25), 0.0, true), at)
			var ts := sp.create_tween().set_parallel(true)
			ts.tween_property(sp, "position", at + Vector3(cos(a), sin(a), 0.2) * randf_range(1.2, 2.4), 0.35).set_ease(Tween.EASE_OUT)
			ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.35)
			ts.chain().tween_callback(sp.queue_free)
		# o vermelho percorre o corpo: a vida voltando
		u.body_mat.emission = BLOOD
		u.body_mat.emission_energy_multiplier = 4.0
		u.create_tween().tween_property(u.body_mat, "emission_energy_multiplier", 0.25, 0.5)
		u.create_tween().tween_callback(func(): u.body_mat.emission = u.color).set_delay(0.5)
		u.set_fill(0.35, 0.4)
		_blood_return(u, 3))


## Blood Taste (parry): uma proteção vermelha com cruzes médicas em volta dela pela janela do parry.
func _parry_guard(u: Unit) -> void:
	var dome_m := Fx.mat(Color(BLOOD.r * 1.5, BLOOD.g, BLOOD.b, 0.3), 0.0, true)
	var dome := Fx.inst(u, Fx.sphere(1.35), dome_m, Vector3(0, 1.0, 0))
	dome.scale = Vector3.ONE * 0.4
	var cm := Fx.mat(Color(2.2, 2.2, 2.2, 0.95), 0.0, true)
	for n in 4:
		var a := n * TAU / 4.0 + 0.4
		var cross := Node3D.new()
		cross.position = Vector3(cos(a) * 1.3, 0.2, sin(a) * 1.3)
		cross.rotation.y = -a + PI / 2.0
		dome.add_child(cross)
		for size in [Vector3(0.12, 0.42, 0.04), Vector3(0.42, 0.12, 0.04)]:
			var bar := BoxMesh.new()
			bar.size = size
			Fx.inst(cross, bar, cm)
	var tw := dome.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dome, "rotation:y", 1.6, TASTE_TIME)
	tw.tween_interval(maxf(0.0, TASTE_TIME - 0.2))
	tw.tween_property(dome_m, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(dome.queue_free)
	if u.med_shield != null:
		# o escudo vem pra frente
		u.med_shield.position = Unit.SHIELD_HOME + Vector3(0.45, 0.1, -0.35)
		u.med_shield.create_tween().tween_property(u.med_shield, "position", Unit.SHIELD_HOME, 0.3).set_delay(TASTE_TIME)


## Indicador de provocação em cima da boss (Emergency Response): uma seta vermelha apontando pra baixo.
func _taunt_mark() -> void:
	var node := Node3D.new()
	fx_root.add_child(node)
	node.position = _bp(Vector3(0, 9.6, -10.8))
	var m := Fx.mat(Color(2.0, 0.2, 0.35, 0.95), 0.0, true)
	Fx.inst(node, Fx.cyl(0.0, 0.7, 1.1), m, Vector3(0, -0.2, 0)).rotation.x = PI
	Fx.inst(node, Fx.cyl(0.24, 0.24, 0.9), m, Vector3(0, 0.75, 0))
	Fx.inst(node, Fx.torus(0.95, 1.1), m, Vector3(0, -1.0, 0))
	var tw := node.create_tween()
	for n in 4:
		tw.tween_property(node, "position:y", 9.0, 0.16)
		tw.tween_property(node, "position:y", 9.6, 0.16)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(node.queue_free)


# ---- Bloodbath

## Bloodbath: ela ergue a seringa e o sangue sobe numa fonte e chove em volta, cobrindo quem está na
## área (BATH_R; o dobro no Blood Party): 20% menos dano por BATH_TIME. Depois dela, as habilidades que
## podem ser fortalecidas (BATH_SLOTS) brilham vermelho por BATH_WINDOW: a próxima sai mais forte.
## No Blood Party: sai de graça, vale pras três próximas e deixa o DoT Pure Blood na boss.
func _bloodbath(u: Unit) -> void:
	var ult := u.party_t > 0.0
	if ult and u.bath_free:
		u.bath_free = false  # o Bloodbath grátis do Blood Party: um só
	else:
		u.stacks -= BATH_COST
	var r := BATH_R * (2.0 if ult else 1.0)
	u.bath_window = BATH_WINDOW
	u.bath_charges = BATH_CHARGES_ULT if ult else 1
	u.syringe_raise(0.9)
	var at := u.position
	for o in units:
		if o.alive and o.position.distance_to(at) <= r:
			o.bath_t = BATH_TIME
			# o sangue escorre em cada um que foi coberto
			_impact_ring(o.position + Vector3(0, 0.25, 0), BLOOD.lightened(0.2), 1.6)
			_burst(o.position + Vector3(0, 1.4, 0), BLOOD, 1.4)
	if ult:
		add_dot("pure", "Pure Blood", Color(1.0, 0.45, 0.6), PURE_TIME, PURE_DPS, u)
		get_dot("pure")["plain"] = true
	# a fonte: um jato vermelho subindo da agulha
	var jet_m := Fx.mat(Color(BLOOD.r * 2.2, BLOOD.g * 1.5, BLOOD.b * 1.5, 0.95), 0.0, true)
	var jet := Fx.inst(fx_root, Fx.cyl(0.5, 0.12, 9.0), jet_m, at + Vector3(0.4, 7.2, 0))
	jet.scale = Vector3(1.0, 0.05, 1.0)
	var tj := jet.create_tween()
	tj.tween_property(jet, "scale", Vector3.ONE, 0.16).set_ease(Tween.EASE_OUT)
	tj.tween_interval(0.35)
	tj.tween_property(jet_m, "albedo_color:a", 0.0, 0.4)
	tj.tween_callback(jet.queue_free)
	# a nuvem no alto e o chão coberto, do tamanho exato da área
	var cloud_m := Fx.mat(Color(BLOOD.r * 1.6, BLOOD.g, BLOOD.b, 0.5), 0.0, true)
	var cloud := Fx.inst(fx_root, Fx.disc(r, 0.5), cloud_m, at + Vector3(0, 11.0, 0))
	cloud.scale = Vector3(0.1, 1.0, 0.1)
	var tc := cloud.create_tween()
	tc.tween_property(cloud, "scale", Vector3.ONE, 0.3).set_delay(0.12).set_ease(Tween.EASE_OUT)
	tc.tween_interval(0.7)
	tc.tween_property(cloud_m, "albedo_color:a", 0.0, 0.5)
	tc.tween_callback(cloud.queue_free)
	var pool_m := Fx.mat(Color(BLOOD.r * 1.4, BLOOD.g, BLOOD.b, 0.42), 0.0, true)
	var pool := Fx.inst(fx_root, Fx.disc(r, 0.03), pool_m, at + Vector3(0, 0.06, 0))
	pool.scale = Vector3(0.1, 1.0, 0.1)
	var tp := pool.create_tween()
	tp.tween_property(pool, "scale", Vector3.ONE, 0.5).set_delay(0.3).set_ease(Tween.EASE_OUT)
	tp.tween_property(pool_m, "albedo_color:a", 0.0, 1.6)
	tp.tween_callback(pool.queue_free)
	_impact_ring(at + Vector3(0, 0.3, 0), BLOOD.lightened(0.2), r)
	# a chuva: gotas grossas caindo por toda a área durante um segundo
	var drops := 46 if ult else 26
	for n in drops:
		var a := randf() * TAU
		var d := sqrt(randf()) * r
		var ground := at + Vector3(cos(a) * d, 0.1, sin(a) * d)
		var drop := Fx.inst(fx_root, Fx.capsule(0.1, 0.7), Fx.mat(Color(BLOOD.r * 2.0, BLOOD.g * 1.4, BLOOD.b * 1.4), 0.0, true), ground + Vector3(0, 11.0, 0))
		drop.visible = false
		var td := drop.create_tween()
		td.tween_interval(0.3 + randf() * 0.9)
		td.tween_callback(func(): drop.visible = true)
		td.tween_property(drop, "position", ground, 0.3).set_ease(Tween.EASE_IN)
		td.tween_callback(drop.queue_free)
		td.tween_callback(_burst.bind(ground, BLOOD, 0.8))
	hud.flash(BLOOD, 0.2)
	shake_t = 0.25
	shake_amp = 0.25
	if u.controlled:
		hud.toast("BLOODBATH: ESCOLHA A HABILIDADE FORTALECIDA" + ("  (x%d)" % BATH_CHARGES_ULT if ult else ""), 1.8)


## A habilidade do slot vai sair fortalecida pelo Bloodbath? Se sim, gasta uma carga (e, sobrando carga,
## abre de novo o tempo de escolha).
func _bath_use(u: Unit, slot: int) -> bool:
	if u.bath_window <= 0.0 or u.bath_charges <= 0 or not BATH_SLOTS.has(slot):
		return false
	u.bath_charges -= 1
	u.bath_window = BATH_WINDOW if u.bath_charges > 0 else 0.0
	return true


## Blood Consumed fortalecido: cura grande, regeneração nela e o Compartilhamento de Sangue na party toda.
func _consumed_big(u: Unit) -> void:
	var heal := u.max_hp * CONSUMED_BIG_HEAL
	if u.party_t > 0.0:
		_party_heal(u, heal)
	else:
		u.hp = minf(u.max_hp, u.hp + heal)
		_popup(int(heal), BLOOD.lightened(0.35), 58, u.position + Vector3(0, 2.8, 0), "+")
	u.mend_t = SHARE_TIME
	u.mend_rate = CONSUMED_REGEN
	for o in units:
		if not o.alive or o == u:
			continue
		o.mend_t = SHARE_TIME
		o.mend_rate = SHARE_REGEN
		# o sangue passa dela pra cada aliado
		_beam(u.position, o.position, Color(BLOOD.r * 1.8, BLOOD.g, BLOOD.b, 0.9), 0.5)
		_impact_ring(o.position + Vector3(0, 0.3, 0), BLOOD.lightened(0.3), 1.6)
		_burst(o.position + Vector3(0, 1.0, 0), BLOOD.lightened(0.2), 1.3)
	_burst(u.position + Vector3(0, 1.0, 0), Color(1, 1, 1), 2.2)
	_blood_return(u, 6)
	if u.controlled:
		hud.toast("COMPARTILHAMENTO DE SANGUE", 1.4)


## Extração fortalecida pelo Bloodbath (no Blood Party): ela carrega a seringa na boss por EXTRACT_BIG_TIME.
## O sangue vem cada vez mais grosso, uma esfera cresce na ponta da agulha, e quando ela solta a
## explosão é enorme: muito dano e quase a vida inteira de volta.
func _extract_big(u: Unit) -> void:
	u.skill_cd[1] = EXTRACT_CD
	u.lock_t = EXTRACT_BIG_TIME
	u.channel_t = EXTRACT_BIG_TIME  # barra de conjuração no HUD (o disparo é pelo timer abaixo)
	u.channel_total = EXTRACT_BIG_TIME
	u.channel_slot = 1
	u.set_meta("extracting", true)
	u.face(boss_pos - u.position)
	u.syringe_stab(1.5, EXTRACT_BIG_TIME - 0.1)
	u.set_fill(0.05, 0.0)
	u.set_fill(1.0, EXTRACT_BIG_TIME)
	var at := boss_pos + Vector3(0, 2.4, 1.7)
	if u.controlled:
		hud.toast("EXTRAÇÃO TOTAL", 1.6)
	# a esfera de sangue crescendo na boss
	var orb_m := Fx.mat(Color(BLOOD.r * 2.6, BLOOD.g * 1.6, BLOOD.b * 1.6, 0.85), 0.0, true)
	var orb := Fx.inst(fx_root, Fx.sphere(1.0), orb_m, at)
	orb.scale = Vector3.ONE * 0.2
	orb.create_tween().tween_property(orb, "scale", Vector3.ONE * 2.6, EXTRACT_BIG_TIME).set_ease(Tween.EASE_IN)
	var steps := 24
	for n in steps:
		get_tree().create_timer(EXTRACT_BIG_TIME * n / steps, false).timeout.connect(func():
			if not is_instance_valid(u) or not u.alive:
				return
			var k := float(n) / steps
			_beam(at - Vector3(0, 1.0, 0), u.position + Vector3(0.4, 0.0, 0), Color(BLOOD.r * (1.5 + k * 2.5), BLOOD.g, BLOOD.b, 0.95), 0.14)
			for j in 3:
				var drop := Fx.inst(fx_root, Fx.sphere(0.1 + k * 0.12), Fx.mat(Color(1.8 + k * 2.0, 0.12, 0.25), 0.0, true), at + Vector3(randf_range(-2.4, 2.4), randf_range(-1.4, 3.0), 0))
				var tw := drop.create_tween()
				tw.tween_property(drop, "position", at, 0.16).set_ease(Tween.EASE_IN)
				tw.tween_callback(drop.queue_free)
			if n % 4 == 0:
				_impact_ring(at, BLOOD.lightened(k * 0.4), 1.5 + k * 3.0)
			shake_t = 0.12
			shake_amp = 0.08 + k * 0.2
			for m in u.syringe_mats:
				(m as StandardMaterial3D).albedo_color = Color(3.2 + k * 6.0, 0.2 + k * 0.6, 0.4 + k * 0.6))
	get_tree().create_timer(EXTRACT_BIG_TIME, false).timeout.connect(func():
		if is_instance_valid(orb):
			orb.queue_free()
		if ended or not is_instance_valid(u) or not u.alive:
			return
		u.channel_t = 0.0
		u.remove_meta("extracting")
		# a explosão: clarão, coluna de sangue, ondas e uma chuva de gotas pra todo lado
		_burst(at, Color(1, 1, 1), 9.0)
		_burst(at, BLOOD, 13.0)
		for k in 6:
			_impact_ring(at, [Color(1, 1, 1), BLOOD, BLOOD.lightened(0.3)][k % 3], 4.0 + k * 2.2)
		var col_m := Fx.mat(Color(BLOOD.r * 2.4, BLOOD.g * 1.5, BLOOD.b * 1.5, 0.9), 0.0, true)
		var pillar := Fx.inst(fx_root, Fx.cyl(2.2, 2.8, 20.0), col_m, at + Vector3(0, 7.0, 0))
		var tp := pillar.create_tween().set_parallel(true)
		tp.tween_property(pillar, "scale", Vector3(0.05, 1.1, 0.05), 0.7).set_ease(Tween.EASE_IN)
		tp.tween_property(col_m, "albedo_color:a", 0.0, 0.7)
		tp.chain().tween_callback(pillar.queue_free)
		for n in 28:
			var a := n * TAU / 28.0
			var sp := Fx.inst(fx_root, Fx.sphere(0.2), Fx.mat(Color(2.2, 0.15, 0.3), 0.0, true), at)
			var ts := sp.create_tween().set_parallel(true)
			ts.tween_property(sp, "position", at + Vector3(cos(a), sin(a) * 0.8, 0.3) * randf_range(4.0, 9.0), 0.7).set_ease(Tween.EASE_OUT)
			ts.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.7)
			ts.chain().tween_callback(sp.queue_free)
		hud.flash(BLOOD, 0.45)
		shake_t = 0.6
		shake_amp = 0.7
		boss.hit_flash()
		_damage_boss(u, EXTRACT_BIG_DMG / (PARTY_DMG_MULT if u.party_t > 0.0 else 1.0), true, true)
		if u.party_t > 0.0:
			_party_heal(u, u.max_hp * EXTRACT_BIG_HEAL)
		else:
			u.hp = minf(u.max_hp, u.hp + u.max_hp * EXTRACT_BIG_HEAL)
		_blood_return(u, 10)
		for m in u.syringe_mats:
			(m as StandardMaterial3D).albedo_color = Color(3.2, 0.2, 0.4) if u.party_t > 0.0 else Color(1.5, 0.08, 0.2)
		u.set_fill(0.4, 0.4))


## Extração (o slot do parry durante o Blood Party): ela crava a seringa na boss e fica EXTRACT_TIME
## sugando. A seringa enche e brilha cada vez mais; no fim, explosão de sangue e uma cura grande.
func _extract(u: Unit, big := false) -> void:
	if big:
		_extract_big(u)
		return
	u.skill_cd[1] = EXTRACT_CD
	u.lock_t = EXTRACT_TIME
	u.face(boss_pos - u.position)
	u.syringe_stab(1.5, EXTRACT_TIME - 0.1)
	u.set_fill(0.05, 0.0)
	u.set_fill(1.0, EXTRACT_TIME)
	var at := boss_pos + Vector3(0, 2.2, 1.7)
	if u.controlled:
		hud.toast("EXTRAÇÃO", 1.0)
	var steps := 10
	for n in steps:
		get_tree().create_timer(EXTRACT_TIME * n / steps, false).timeout.connect(func():
			if not is_instance_valid(u) or not u.alive:
				return
			# fluxo de sangue da boss pra seringa, cada vez mais forte
			_beam(at - Vector3(0, 1.0, 0), u.position + Vector3(0.4, 0.0, 0), Color(BLOOD.r * (1.5 + n * 0.25), BLOOD.g, BLOOD.b, 0.9), 0.16)
			for k in 2:
				var drop := Fx.inst(fx_root, Fx.sphere(0.1 + n * 0.008), Fx.mat(Color(1.8 + n * 0.15, 0.12, 0.25), 0.0, true), at + Vector3(randf_range(-1.4, 1.4), randf_range(-1.0, 1.6), 0))
				var tw := drop.create_tween()
				tw.tween_property(drop, "position", u.position + Vector3(0.4, 1.1, -0.6), 0.14).set_ease(Tween.EASE_IN)
				tw.tween_callback(drop.queue_free)
			for m in u.syringe_mats:
				(m as StandardMaterial3D).albedo_color = Color(3.2 + n * 0.5, 0.2 + n * 0.05, 0.4 + n * 0.05))
	get_tree().create_timer(EXTRACT_TIME, false).timeout.connect(func():
		if ended or not is_instance_valid(u) or not u.alive:
			return
		_burst(at, Color(1, 1, 1), 3.0)
		_burst(at, BLOOD, 5.5)
		for k in 3:
			_impact_ring(at, BLOOD.lightened(k * 0.15), 3.0 + k * 1.5)
		hud.flash(BLOOD, 0.22)
		shake_t = 0.3
		shake_amp = 0.35
		boss.hit_flash()
		_damage_boss(u, EXTRACT_DMG / PARTY_DMG_MULT, true, true)
		if u.party_t > 0.0:
			_party_heal(u, u.max_hp * EXTRACT_HEAL)
		else:
			u.hp = minf(u.max_hp, u.hp + u.max_hp * EXTRACT_HEAL)
		_blood_return(u, 6)
		for m in u.syringe_mats:
			(m as StandardMaterial3D).albedo_color = Color(3.2, 0.2, 0.4) if u.party_t > 0.0 else Color(1.5, 0.08, 0.2)
		u.set_fill(0.4, 0.4))


## Fim do Blood Taste: a vida volta ao que era antes. Se um golpe acertou durante a janela (parry
## perfeito), ela guarda metade do que ganhou e a recarga cai pra 10 s.
func _end_taste(u: Unit) -> void:
	var gained := u.base_hp * TASTE_HP - u.taste_prev
	u.taste_t = 0.0
	u.max_hp = u.base_hp
	if not u.alive:
		return
	if u.taste_hit:
		# o Sangue só entra aqui: parry que não aparou nada não rende nada
		_add_stacks(u, TASTE_STACKS)
		var keep := gained * TASTE_KEEP
		u.hp = minf(u.max_hp, u.taste_prev + keep)
		u.skill_cd[1] = minf(u.skill_cd[1], TASTE_CD_PARRY - TASTE_TIME)
		_burst(u.position, Color(1.0, 0.95, 0.9), 3.0)
		# parry bem-sucedido: explosão de sangue e energia, bem visível
		_burst(u.position + Vector3(0, 1.0, 0), BLOOD, 4.6)
		for k in 3:
			_impact_ring(u.position + Vector3(0, 0.4 + k * 0.5, 0), [Color(1, 1, 1), BLOOD, BLOOD.lightened(0.3)][k], 2.6 + k * 1.2)
		shake_t = 0.25
		shake_amp = 0.3
		_blood_return(u, 4)
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
	if u.blood_orbit != null:
		# as gotas de sangue giram em volta dela; mais rápido no Blood Party e com a vida baixa
		u.blood_orbit.rotation.y += delta * (5.0 if u.party_t > 0.0 else (2.6 if u.hp / u.base_hp < 0.35 else 1.2))
		u.blood_orbit.scale = Vector3.ONE * (1.6 if u.party_t > 0.0 else 1.0)
	if u.key == "nurse" and u.alive and u.party_t <= 0.0 and u.hp / u.base_hp <= 0.3:
		# vida baixa: pulso de sangue no chão, no ritmo de um coração
		u.party_tick -= delta
		if u.party_tick <= 0.0:
			u.party_tick = 0.8
			_impact_ring(u.position + Vector3(0, 0.15, 0), BLOOD, 1.5)
	if u.party_t > 0.0:
		u.party_t -= delta
		# cura e escudo de fora não entram: a vida que vale é a que ela mesma roubou
		if u.hp > u.party_hp:
			u.hp = u.party_hp
		u.party_hp = u.hp
		u.shield_hp = 0.0
		u.party_tick -= delta
		if u.party_tick <= 0.0:
			# aura de energia sanguínea, mais rápida conforme o tempo acaba (a urgência)
			u.party_tick = lerpf(0.25, 0.8, clampf(u.party_t / PARTY_TIME, 0.0, 1.0))
			_impact_ring(u.position + Vector3(0, 0.3, 0), BLOOD.lightened(0.2) if u.hp < u.max_hp else Color(1, 1, 1), 2.2)
		if u.party_t <= 0.0:
			u.party_t = 0.0
			u.bath_free = false  # não usou: perdeu
			u.blood_party_end()
			if u.hp >= u.max_hp - 0.5:
				# conseguiu: sai com a vida cheia
				u.hp = u.max_hp
				_burst(u.position, Color(1, 1, 1), 3.0)
				if u.controlled:
					hud.toast("SOBREVIVEU AO BLOOD PARTY", 1.6)
			else:
				_burst(u.position, BLOOD.darkened(0.3), 5.0)
				kill(u, "não recuperou a vida toda no Blood Party")


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
	u.face(boss_pos - u.position)
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
			_beam(u.position, _bp(Vector3(0, 5.0, -11.5)), Color(1.0, 1.0, 1.0, 0.98), 0.6)
			_burst(_bp(Vector3(0, 5, -11.5)), u.color.lightened(0.4), 10.0)
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
	fight_mechs[h["card"]] = true
	fight_mechs["safe_cast"] = true
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
			var mid: float = (h["r"] + arena_r + 0.3) * 0.5
			var ring := Fx.inst(node, Fx.torus(h["r"], arena_r + 0.3), soft)
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
## Este herói percebeu este ataque? Com a carta (ou a passiva) dele, sempre e na hora. Sem ela, ele
## não fica mais parado feito zumbi: TENTA, com o que sabe (Knowledge.knowledge da carta daquele
## ataque). O conhecimento dá a chance de ele perceber e o atraso até reagir; no começo percebe pouco
## e tarde, e apanha tentando. Cada ataque é decidido uma vez por herói.
## No tutorial (sandbox) vale a regra antiga: sem carta, não sabe e pronto, que é o que a aula mostra.
func _aware(u: Unit, h: Dictionary) -> bool:
	if Knowledge.has(u.hero, h["card"]):
		return true
	if Knowledge.sandbox:
		return false
	if not h.has("aware"):
		h["aware"] = {}
	if not h["aware"].has(u.idx):
		var k := Knowledge.knowledge(u.hero, h["card"]) / 100.0
		# [percebeu?, quanto demora pra reagir]
		h["aware"][u.idx] = [randf() < lerpf(AWARE_MIN, 0.96, k), lerpf(AWARE_LATE, 0.15, k)]
	var seen: Array = h["aware"][u.idx]
	return seen[0] and float(h["total"]) - float(h["t"]) >= float(seen[1])


func _danger_at(p: Vector3, u: Unit, known: bool, margin: float) -> bool:
	for h in hazards:
		# quem tem o Protocolo Final já sabe pra qual quadrado ir: não foge pro mais perto
		if h["shape"] == "void" and Knowledge.has(u.hero, "final"):
			continue
		if known and not _aware(u, h):
			continue
		if not known and _aware(u, h):
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
			if Vector2(p.x, p.z).length() > arena_r - 0.2 or _danger_at(p, u, true, margin):
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
				var half: float = (arena_r + 0.3 - h["r"]) * 0.5 * f
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
			# "low": ataque rente ao chão. Quem está no ar (unit.air_t, salto do Nocaute Final) passa
			# por cima; qualquer outro ataque acerta normalmente: o salto não é invulnerabilidade.
			if h.get("low", false) and u.airborne():
				continue
			if h["dmg"] > 0.0 and u.alive and u.invuln <= 0.0 and _hit_test(h, u.position, 0.0):
				if not card_fail.has(u.hero):
					card_fail[u.hero] = {}
				card_fail[u.hero][h["card"]] = true
				if not Knowledge.has(u.hero, h["card"]) and not autoplay:
					Knowledge.learn(u.hero, h["card"], LEARN_HIT)
				if u == player:
					player_hit = true
				hurt(u, h["dmg"], h["why"])
				if h.get("bee", false):
					_bee_heart(u)
		# o jogador estava dentro e saiu na mão: conta pra revelar essa mecânica no painel do boss
		if h["dmg"] > 0.0 and not autoplay and player.alive and h["inside"].has(player.idx) and not _hit_test(h, player.position, 0.0):
			Knowledge.solve(h["card"])
		# quem estava dentro quando o ataque apareceu e saiu a tempo, sem ter a carta: aprendeu um pouco
		if h["dmg"] > 0.0 and not autoplay:
			for u in units:
				if u.alive and h["inside"].has(u.idx) and not Knowledge.has(u.hero, h["card"]) and not _hit_test(h, u.position, 0.0):
					Knowledge.learn(u.hero, h["card"], LEARN_HAND if (u == player) else LEARN_DODGED)
					if u == player:
						for o in units:
							if o != u and o.alive and not Knowledge.has(o.hero, h["card"]):
								Knowledge.learn(o.hero, h["card"], LEARN_WATCH)
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
			var half_l := sqrt(arena_r * arena_r - c * c)
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
	var from := Vector3(0, 0, -arena_r - 1.0)
	var dir := Vector3(u.position.x, 0, u.position.z) - from
	dir = dir.normalized()
	# a faixa cobre só o trecho que cruza a arena, sem sobrar pra fora do chão
	var b := from.dot(dir)
	var disc := b * b - (from.length_squared() - arena_r * arena_r)
	if disc <= 0.0:
		return
	var t1 := -b - sqrt(disc)
	var t2 := -b + sqrt(disc)
	_add_hazard({"shape": "rect", "pos": from + dir * ((t1 + t2) * 0.5), "dir": dir, "half_l": (t2 - t1) * 0.5, "half_w": half_w,
		"total": total, "dmg": dmg, "card": "dodge", "why": why})


# ---------------------------------------------------------------- grande final da MINI-CHAN

func _raidwide(ratio: float, why: String) -> void:
	hud.flash(Color(1.0, 0.2, 0.35) * Color(1, 1, 1, 0.5))
	_burst(Vector3(0, 0.2, 0), DANGER, arena_r)
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
		_add_hazard({"shape": "rect", "pos": Vector3(c0["side"] * arena_r * 0.5, 0, 0), "dir": Vector3(0, 0, 1),
			"half_l": arena_r, "half_w": arena_r * 0.5, "total": maxf(c0["t"], 0.05) * haste, "dmg": CLEAVE_DMG, "card": "dodge",
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
			_beam(_bp(Vector3(0, 5.0, -11.5)), u.position, Color(1.0, 0.35, 0.4, 0.9), 0.35)
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
	if show and Knowledge.has(u.hero, "dice") and randf() < 0.25:
		dmg *= 1.5  # Dado Viciado: acerto crítico
		big = true
	if Knowledge.has(u.hero, "overdrive"):
		dmg *= 1.2
	if boss_hp / boss_max < 0.3 and Knowledge.has(u.hero, "executor"):
		dmg *= 1.25
	if not get_dot("ferida").is_empty():
		dmg *= WOUND_MULT  # Ferimento das Garras Cruzadas: vale pra party toda
	dmg *= 1.0 + valsa_bonus(u)  # dentro da saia da Valsa (ou sendo o Par dela)
	if not u.controlled and Knowledge.has(u.hero, "dps"):
		dmg *= AI_ROT_MULT  # IA com a carta Rotação: joga o kit inteiro, com parte do dano do jogador
	if u.key == "nurse" and u.party_t > 0.0:
		# Blood Party: bate o dobro e rouba vida em cima do dano causado (menos o DoT Pure Blood)
		dmg *= PARTY_DMG_MULT
		if not plain_hit:
			_party_heal(u, dmg * PARTY_STEAL)
	# Malpractice com o gauge de sangue cheio: cada golpe direto devolve um pedaço da vida máxima
	if u.key == "nurse" and show and u.stacks >= PARTY_NEED:
		_lifesteal(u, u.base_hp * GAUGE_STEAL)
	boss_hp -= dmg
	lb = minf(1.0, lb + dmg / (boss_max * LB_NEED) * (1.5 if Knowledge.has(u.hero, "spark") else 1.0))
	u.dmg_total += dmg
	u.dmg_bucket += dmg
	if u.key == "assassina" and u.frenzy_t > 0.0:
		u.frenzy_dmg += dmg
	u.enmity += dmg * (TANK_STANCE if u.tank else 1.0)
	if show:
		boss.hit_flash()
		var col := Color(1.0, 0.9, 0.4) if big else Color.WHITE
		if shield:
			col = Color(0.5, 0.8, 1.0)
		_popup(int(round(dmg)), col, 64 if big else 46)
	if boss_hp <= 0.0:
		if Knowledge.practice:
			# o dummy não morre: a vida enche de novo e o treino continua
			boss_hp = boss_max
			hud.toast("O dummy se recompôs", 1.6)
			return
		boss_hp = 0.0
		_end(true)


## Golpe do jogador: um risco de luz do personagem até o boss, pra o ataque "sair" de alguém.
func _attack_fx(u: Unit, big: bool) -> void:
	var from := u.position + Vector3(0, 1.1, 0)
	var to := _bp(Vector3(randf_range(-1.2, 1.2), randf_range(2.0, 4.0), -11.0))
	var m := Fx.mat(u.color.lightened(0.4), 7.0 if big else 5.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(0.34 if big else 0.2), m, from)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to, 0.09)
	tw.tween_callback(mi.queue_free)
	tw.tween_callback(_burst.bind(to, u.color.lightened(0.3), 1.6 if big else 0.9))


func _popup(value: int, col: Color, size: int, at = null, prefix := "") -> void:
	if value <= 0:
		return
	var p := _bp(Vector3(randf_range(-2.2, 2.2), randf_range(2.5, 5.0), -9.5))
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
	if u.twirl_t > 0.0 and dmg > 0.0:
		# Pirueta: o golpe passa por ela enquanto gira. (Mecânica que mata na hora passa por kill().)
		_bravo(u)
		return
	if u.parry_t > 0.0 and dmg > 0.0 and u.mercy_frenzy:
		# Misericórdia em Frenesi: o golpe não entra e ela nem perde o corte
		_burst(u.position + Vector3(0, 1.0, 0), Color(0.75, 0.2, 1.0), 2.4)
		if u.controlled:
			hud.toast("INTOCÁVEL", 0.7)
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
	if u.bath_t > 0.0:
		dmg *= BATH_MULT  # coberto pelo Bloodbath
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
	if u.party_t > 0.0:
		# Blood Party: o golpe entra, mas ela não morre enquanto dura
		u.hp = maxf(1.0, u.hp)
		u.party_hp = u.hp
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
	# Blood Party: não morre enquanto dura (só a Fúria passa)
	if u.party_t > 0.0 and not force:
		_burst(u.position, BLOOD, 2.0)
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
	died[u.hero] = true
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
	if bee:
		_bee_hell_stop()
	won = victory
	var rank := -1
	var prize := {}
	if victory and not Knowledge.practice:
		rank = Knowledge.rank_for(_score())
		if not autoplay:
			prize = Knowledge.reward(Knowledge.boss, rank)
			_learn_cards()
	# a run terminou (vitória ou wipe): o que foi ganho nela passa a valer e é gravado no save
	prize["cards"] = [] if Knowledge.practice else Knowledge.run_cards()
	Knowledge.commit_run()
	hud.show_end(victory, log_lines, rank, prize)


## Vitória: cada carta de aprendizado no baralho de quem lutou ganha progresso, se o herói provou que
## aprendeu: não morreu nesta luta e não tomou a mecânica daquela carta.
func _learn_cards() -> void:
	for u in units:
		if died.has(u.hero):
			continue
		for kind in Knowledge.KINDS:
			for id in Knowledge.deck(u.hero)[kind].duplicate():
				if id == "" or Knowledge.role(id) != "learn":
					continue
				if not fight_mechs.has(id) and not ALWAYS_LEARN.has(id):
					continue  # a mecânica dessa carta nem apareceu nesta luta
				if card_fail.has(u.hero) and card_fail[u.hero].has(id):
					continue
				Knowledge.add_progress(u.hero, id, Knowledge.LEARN_WIN)


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


## Maestria: você resolveu a mecânica certo, na mão. Na terceira vez a carta é liberada.
## Ela fica na coleção, com o selo NOVO, até o jogador equipar em quem quiser.
func _master(key: String) -> void:
	if autoplay or Knowledge.practice or Knowledge.mastery_of(key) >= Knowledge.MASTERY_NEED:
		return
	var card: String = Knowledge.MASTERY[key]["card"]
	if Knowledge.add_mastery(key):
		# a carta entra na coleção marcada como NOVA pra quem a conquistou. Ela NÃO é equipada:
		# quem decide usar é o jogador, na tela de cartas.
		Knowledge.mark_new(card, units[ctrl].hero)
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
		if bee:
			s = _bee_next()
	for key in ["dur", "volley_at"]:
		if s.has(key):
			s[key] = s[key] / haste
	if roam:
		_storm_end_phase()
	if bee:
		_bee_end_phase()
	cur_step = s
	phase = s["t"]
	for id in PHASE_CARDS.get(phase, []):
		fight_mechs[id] = true
	if phase == "stack":
		fight_mechs["stack" if int(s.get("need", 4)) == 4 else "pair"] = true
	if finale_state == 1:
		fight_mechs["final"] = true
	phase_t = 0.0
	phase_dur = s["dur"]
	volley_done = false
	cast_name = ""
	boss.casting = false
	if bee:
		_bee_start(s)
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
		"leap": _storm_leap(s["dur"])
		"chase": _storm_chase()
		"orbs": _storm_orbs()
		"fan": _storm_fan()
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
		"leap":
			# a queda: onda de choque fraca em todo mundo
			_impact_ring(boss_pos + Vector3(0, 0.2, 0), Color(0.6, 0.95, 1.0), arena_r)
			_raidwide(LEAP_WAVE, "onda de choque do salto")
		"zones": _resolve_zones()
		"cata": _resolve_cataclysm()
		"burn":
			vulnerable = false
			shield = false
			boss.set_shield(false)
	if not ended:
		_next_step()


# ---------------------------------------------------------------- TROVÃO-KUN (boss que anda)

func _storm_pick() -> Unit:
	var pool := _alive_shuffled()
	return pool[0] if not pool.is_empty() else null


## Salto: marca o chão onde o alvo está e cai ali. O círculo é um ataque vermelho comum (carta Desvio).
func _storm_leap(dur: float) -> void:
	cast_name = "Salto Trovejante"
	boss.casting = true
	# o salto vai em quem NÃO está com a atenção dele: o tank não é o único que tem o que fazer
	var top := _aggro_target()
	storm_target = null
	for u in _alive_shuffled():
		if u != top:
			storm_target = u
			break
	if storm_target == null:
		storm_target = top
	leap_from = boss_pos
	leap_to = boss_pos
	if storm_target != null:
		var flat := Vector2(storm_target.position.x, storm_target.position.z).limit_length(arena_r - 1.6)
		leap_to = Vector3(flat.x, 0, flat.y)
	_add_hazard({"shape": "circle", "pos": leap_to, "r": LEAP_R, "total": dur, "dmg": LEAP_DMG, "card": "dodge", "why": "ficou embaixo do salto"})


## Perseguição: anda devagar atrás de quem está no topo do aggro (como qualquer boss atrás do tanque).
func _storm_chase() -> void:
	cast_name = ""
	storm_target = _aggro_target()
	if storm_target == null or not storm_target.alive:
		storm_target = _storm_pick()


## Faíscas: ondas de bolinhas de raio em roda, em linha reta. É pra desviar passando pelos buracos.
func _storm_orbs() -> void:
	cast_name = "Enxame de Faíscas"
	boss.casting = true
	orb_wave_t = 0.9
	orb_spin = randf() * TAU
	orb_reds = 0
	orb_hit = {}
	if eye_ring == null:
		eye_ring = Fx.inst(fx_root, Fx.torus(ORB_START - 0.1, ORB_START), Fx.mat(Color(0.5, 1.0, 1.6, 0.9), 0.0, true))
	eye_ring.visible = true
	eye_ring.position = Vector3(boss_pos.x, 0.06, boss_pos.z)
	for u in units:
		u.remove_meta("eye_plan")


func _orb_wave() -> void:
	orb_spin += 0.37
	var gap_every := maxi(1, ORB_COUNT / ORB_GAPS)
	for n in ORB_COUNT:
		if n % gap_every == 0:
			continue  # buraco
		var a := orb_spin + n * TAU / ORB_COUNT
		var dir := Vector3(cos(a), 0, sin(a))
		var node := Fx.inst(fx_root, Fx.sphere(0.3), Fx.mat(Color(0.6, 1.15, 1.7), 0.0, true), boss_pos + dir * ORB_START + Vector3(0, 0.7, 0))
		Fx.inst(node, Fx.torus(0.4, 0.5), Fx.mat(Color(DANGER.r * 1.4, DANGER.g, DANGER.b, 0.9), 0.0, true))
		orbs.append({"node": node, "dir": dir})


## Ventilador: os raios aparecem finos e parados (aviso), depois engrossam e giram.
func _storm_fan() -> void:
	cast_name = "Ventilador de Raios"
	boss.casting = true
	var ratio := boss_hp / boss_max
	var stage: Array = FAN_STAGES[0] if ratio > 0.66 else (FAN_STAGES[1] if ratio > 0.33 else FAN_STAGES[2])
	var count: int = stage[0]
	fan_speed = float(stage[1]) * (1.0 if randf() < 0.5 else -1.0)
	fan_angle = randf() * TAU
	fan_on = false
	fan_drop_t = FAN_WARN + FAN_DROP * 0.6
	fan_flip_done = ratio > 0.5  # abaixo de metade da vida, o giro inverte no meio
	fan_rig = Node3D.new()
	fan_rig.position = boss_pos + Vector3(0, 0.22, 0)
	fx_root.add_child(fan_rig)
	fan_mat = Fx.mat(Color(0.5, 1.0, 1.6, 0.3), 0.0, true)
	fan_beams.clear()
	for n in count:
		var box := BoxMesh.new()
		box.size = Vector3(arena_r * 2.2, 0.16, 1.0)
		var beam := Fx.inst(fan_rig, box, fan_mat)
		beam.scale = Vector3(1, 1, 0.12)
		fan_beams.append(beam)
	_fan_place()
	hud.toast("PULE OS RAIOS!", 1.6)


func _fan_dir(n: int) -> Vector3:
	var a := fan_angle + n * TAU / fan_beams.size()
	return Vector3(cos(a), 0, sin(a))


func _fan_place() -> void:
	for n in fan_beams.size():
		var dir := _fan_dir(n)
		var beam: MeshInstance3D = fan_beams[n]
		beam.position = dir * (arena_r * 1.1 + FAN_INNER * 0.5)
		beam.rotation.y = -atan2(dir.z, dir.x)


## Quanto falta (em segundos) pro próximo raio passar por este herói. INF se não vem nenhum.
func fan_eta(u: Unit) -> float:
	if fan_beams.is_empty() or absf(fan_speed) < 0.01:
		return INF
	var rel := u.position - boss_pos
	if Vector2(rel.x, rel.z).length() < FAN_INNER:
		return INF
	var ua := atan2(rel.z, rel.x)
	var best := INF
	for n in fan_beams.size():
		var ba := fan_angle + n * TAU / fan_beams.size()
		var gap := fposmod((ua - ba) * signf(fan_speed), TAU)
		best = minf(best, gap / absf(fan_speed))
	# durante o aviso, conta também o tempo que falta pra ele começar a girar
	return best + (maxf(0.0, FAN_WARN - phase_t) if not fan_on else 0.0)


func _storm_end_phase() -> void:
	boss.position = boss_pos
	if eye_ring != null and eye_ring.visible:
		eye_ring.visible = false
		# fim das faíscas: quem passou sem tomar nenhuma aprendeu o olho da tempestade
		if not autoplay:
			var me := units[ctrl]
			for u in units:
				if u.alive and not orb_hit.has(u.hero):
					Knowledge.learn(u.hero, "eye", LEARN_HAND if u == me else LEARN_EYE)
					if u == me:
						Knowledge.solve("eye")
	if fan_rig != null and is_instance_valid(fan_rig):
		fan_rig.queue_free()
	fan_rig = null
	fan_beams.clear()
	fan_on = false
	for u in units:
		u.ai_fan_decided = false
		u.ai_hop_at = -1.0
		u.ai_run = false


func _tick_storm(delta: float) -> void:
	match phase:
		"leap":
			# agacha no começo, depois o arco até o ponto marcado; chega junto com o círculo
			var k := clampf(phase_t / phase_dur, 0.0, 1.0)
			var fly := clampf((k - 0.45) / 0.55, 0.0, 1.0)
			boss_pos = leap_from.lerp(leap_to, fly * fly * (3.0 - 2.0 * fly))
			boss.position = boss_pos + Vector3(0, sin(fly * PI) * 4.5, 0)
			boss.scale = Vector3.ONE * float(boss_def["scale"]) * (1.0 - 0.18 * sin(clampf(k / 0.45, 0.0, 1.0) * PI))
			if k >= 1.0:
				shake_t = 0.4
				shake_amp = 0.5
		"chase":
			var top := _aggro_target()
			if top != null and top.alive:
				storm_target = top
			if storm_target != null and storm_target.alive:
				var to := storm_target.position - boss_pos
				to.y = 0.0
				# para no limite do corpo a corpo: não precisa subir em cima de ninguém
				if to.length() > ROAM_MELEE - 0.6:
					boss_pos += to.normalized() * CHASE_SPEED * delta
			boss.position = boss_pos
		"orbs":
			orb_wave_t -= delta
			if orb_wave_t <= 0.0 and phase_t < phase_dur - 1.2:
				orb_wave_t = ORB_WAVE
				_orb_wave()
			if orb_reds < ORB_RED_AT.size() and phase_t >= ORB_RED_AT[orb_reds]:
				orb_reds += 1
				_spawn_circles(2)
		"fan":
			_tick_fan(delta)
	# as faíscas seguem reto até sair da arena (mesmo depois que a fase acaba)
	for o in orbs.duplicate():
		var node: MeshInstance3D = o["node"]
		node.position += (o["dir"] as Vector3) * ORB_SPEED * delta
		node.rotate_y(delta * 6.0)
		if Vector2(node.position.x, node.position.z).length() > arena_r + 0.5:
			node.queue_free()
			orbs.erase(o)
			continue
		for u in units:
			if u.alive and u.invuln <= 0.0 and Vector2(u.position.x - node.position.x, u.position.z - node.position.z).length() <= ORB_R + 0.3:
				_burst(node.position, Color(0.6, 0.95, 1.0), 1.4)
				orb_hit[u.hero] = true
				if not autoplay and not (u == units[ctrl]):
					Knowledge.learn(u.hero, "eye", LEARN_HIT)
				hurt(u, ORB_DMG, "tomou uma faísca")
				node.queue_free()
				orbs.erase(o)
				break


func _tick_fan(delta: float) -> void:
	if fan_rig == null:
		return
	if not fan_on and phase_t >= FAN_WARN:
		fan_on = true
		fan_mat.albedo_color = Color(0.55, 1.15, 1.9, 0.9)
		for beam in fan_beams:
			beam.create_tween().tween_property(beam, "scale:z", FAN_W * 2.0, 0.15)
		shake_t = 0.2
		shake_amp = 0.25
	if not fan_on:
		return
	# abaixo de metade da vida: no meio da fase ele freia e inverte o sentido
	if not fan_flip_done and phase_t >= phase_dur * 0.5:
		fan_flip_done = true
		var now := fan_speed
		var tw := create_tween()
		tw.tween_property(self, "fan_speed", 0.0, 0.5)
		tw.tween_property(self, "fan_speed", -now, 0.5)
	fan_angle += fan_speed * delta
	_fan_place()
	fan_drop_t -= delta
	if fan_drop_t <= 0.0:
		fan_drop_t = FAN_DROP
		_spawn_circles(4)
	var player := units[ctrl]
	for u in units:
		if not u.alive:
			continue
		var rel := u.position - boss_pos
		rel.y = 0.0
		var under := false
		for n in fan_beams.size():
			var dir := _fan_dir(n)
			var along := rel.dot(dir)
			if along > FAN_INNER and (rel - dir * along).length() <= FAN_W:
				under = true
		if not under:
			continue
		if u.airborne():
			if u.fan_cross_t <= 0.0:
				u.fan_cross_t = 0.7
				_fan_passed(u, u == player and not autoplay)
		elif u.fan_safe_t <= 0.0 and u.invuln <= 0.0:
			u.fan_safe_t = 0.9
			hurt(u, FAN_DMG, "tomou um raio do ventilador")
			if not (u == player and not autoplay):
				Knowledge.learn(u.hero, "fan", LEARN_HIT)


## Alguém passou por cima de um raio. É daí que o conhecimento do ventilador mais cresce.
func _fan_passed(u: Unit, by_hand: bool) -> void:
	_impact_ring(u.position + Vector3(0, 0.2, 0), Color(0.6, 0.95, 1.0), 1.4)
	if by_hand:
		Knowledge.solve("fan")
		Knowledge.learn(u.hero, "fan", LEARN_HAND)
		for o in units:
			if o != u and o.alive:
				Knowledge.learn(o.hero, "fan", LEARN_WATCH)
	else:
		Knowledge.learn(u.hero, "fan", LEARN_OWN)


## Um pensamento em cima do boneco ("?" quando não sabe, "!" quando tenta algo).
func _think(u: Unit, text: String, col: Color) -> void:
	var l := Fx.label(u, text, Vector3(0, 2.7, 0), 56)
	l.modulate = col
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", 3.4, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


## A IA no ventilador. O conhecimento (0..100) não liga o pulo: ele dá a CHANCE de ela tentar pular
## e a PRECISÃO do tempo. Com pouco, quase sempre ela corre do raio (e apanha); de vez em quando
## arrisca um pulo, cedo ou tarde demais. Com muito, pula quase sempre, quase na hora.
func _fan_ai(u: Unit, delta: float) -> void:
	if phase != "fan" or fan_rig == null:
		return
	if u.ai_hop_at >= 0.0:
		u.ai_hop_at -= delta
		if u.ai_hop_at <= 0.0:
			u.ai_hop_at = -1.0
			jump(u)
	var eta := fan_eta(u)
	# o raio acabou de passar (o tempo até o próximo deu um salto pra cima): hora de decidir de novo
	var before: float = u.get_meta("fan_eta", INF)
	u.set_meta("fan_eta", eta)
	if eta > before + 0.2:
		u.ai_fan_decided = false
		u.ai_run = false
	if u.ai_fan_decided or eta > 1.0:
		return
	u.ai_fan_decided = true
	var k := Knowledge.knowledge(u.hero, "fan") / 100.0
	if randf() < lerpf(0.05, 0.97, k):
		# vai tentar pular: o ideal é estar no meio do pulo quando o raio passa
		var miss := randfn(0.0, lerpf(0.36, 0.04, k))
		u.ai_hop_at = maxf(0.0, eta - JUMP_AIR * 0.5 + miss)
		if k < 0.5:
			_think(u, "!", Color(1.0, 0.9, 0.3))
	else:
		u.ai_run = true
		if randf() < 0.5:
			_think(u, "?", Color(0.8, 0.85, 1.0))


## Pra onde a IA vai nas mecânicas do TROVÃO-KUN (null = segue a vida normal).
func _storm_goal(u: Unit):
	if phase == "orbs":
		# olho da tempestade: quem sabe, entra; quem não sabe, fica onde está e tenta desviar das faíscas.
		# Decide uma vez por fase, pela chance que o conhecimento ("eye") dá.
		if not u.has_meta("eye_plan"):
			var k := Knowledge.knowledge(u.hero, "eye") / 100.0
			u.set_meta("eye_plan", randf() < lerpf(0.15, 0.97, k))
			if not u.melee:
				_think(u, "!" if u.get_meta("eye_plan") else "?", Color(1.0, 0.9, 0.3) if u.get_meta("eye_plan") else Color(0.8, 0.85, 1.0))
		var rel0 := u.position - boss_pos
		rel0.y = 0.0
		if u.get_meta("eye_plan") and rel0.length() > ORB_START - 1.0:
			var inward := rel0.normalized() if rel0.length() > 0.1 else Vector3(1, 0, 0)
			return [boss_pos + inward * (ORB_START - 1.9), "Entrando no olho"]
	# faísca vindo na direção dele: dá um passo pro lado, pro buraco mais perto
	for o in orbs:
		var rel: Vector3 = u.position - o["node"].position
		rel.y = 0.0
		var dir: Vector3 = o["dir"]
		var along := rel.dot(dir)
		if along < 0.0 or along > ORB_SPEED * 0.9:
			continue
		var side := rel - dir * along
		if side.length() < ORB_R + 0.75:
			# vai pro meio do vão entre esta faísca e a vizinha (o vão abre conforme elas se afastam)
			var step := side.normalized() if side.length() > 0.05 else Vector3(-dir.z, 0, dir.x)
			var spacing: float = TAU * maxf(1.5, (u.position - boss_pos).length()) / ORB_COUNT
			var p := u.position + step * maxf(0.6, spacing * 0.5 - side.length() + 0.2)
			var flat := Vector2(p.x, p.z).limit_length(arena_r - 0.6)
			return [Vector3(flat.x, 0, flat.y), "Desviando da faísca"]
	if phase == "fan" and u.ai_run and fan_on:
		# sem saber o que fazer, corre na frente do raio (e ele alcança)
		var rel := u.position - boss_pos
		var side := Vector3(-rel.z, 0, rel.x).normalized() * signf(fan_speed)
		var p := u.position + side * 2.0
		var flat := Vector2(p.x, p.z).limit_length(arena_r - 0.6)
		return [Vector3(flat.x, 0, flat.y), "Fugindo do raio"]
	return null


# ---------------------------------------------------------------- MEL-CHAN (boss de desvio)

func _bee_act_now() -> int:
	var ratio := boss_hp / boss_max
	return 1 if ratio > BEE_ACT_AT[0] else (2 if ratio > BEE_ACT_AT[1] else 3)


## O próximo passo dela. Folga e golpe se alternam; cruzar 66% ou 33% da vida chama o Finale.
## No 1º ato a primeira volta do saco sai em ordem fixa (cada golpe aparece sozinho, pra ser lido);
## depois disso o saco é embaralhado e nunca repete o golpe que acabou de sair.
func _bee_next() -> Dictionary:
	if _bee_act_now() > bee_act:
		bee_act += 1
		bee_bag.clear()
		bee_n = 0
		return {"t": "bee_finale", "dur": 3.4}
	if not bee_hell_done and (boss_hp / boss_max <= HELL_AT_HP or fight_time >= HELL_AT_TIME):
		bee_hell_done = true
		bee_n = 0
		return {"t": "bee_hell", "dur": _hb(HELL_BARS, 1.0)}
	bee_n += 1
	if bee_n % 2 == 1:
		return {"t": "bee_idle", "dur": 2.5 if bee_n == 1 else float(BEE_REST[bee_act - 1])}
	if bee_bag.is_empty():
		bee_bag = (BEE_POOL[bee_act - 1] as Array).duplicate()
		if bee_first:
			bee_first = false
		else:
			bee_bag.shuffle()
			if bee_bag.size() > 1 and bee_bag[0] == bee_last:
				bee_bag.append(bee_bag.pop_front())
	bee_last = bee_bag.pop_front()
	return {"t": "bee_" + bee_last, "dur": float(BEE_DUR[bee_last][bee_act - 1])}


func _bee_flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## Direção (no chão) daqui da boss até um herói. Colado nela, sai uma direção qualquer.
func _bee_dir_to(u: Unit) -> Vector3:
	var d := Vector3.ZERO
	if u != null:
		d = _bee_flat(u.position - boss_pos)
	if d.length() < 0.3:
		var a := randf() * TAU
		return Vector3(cos(a), 0, sin(a))
	return d.normalized()


func _bee_event(at: float, fn: Callable) -> void:
	bee_events.append([at, fn])
	bee_events.sort_custom(func(x, y): return float(x[0]) < float(y[0]))


## Dica de primeira vez (uma por luta e por golpe): o que fazer, em duas palavras.
func _bee_tip(id: String, text: String) -> void:
	if bee_tips.has(id):
		return
	bee_tips[id] = true
	hud.toast(text, 1.8)


func _bee_start(s: Dictionary) -> void:
	bee_events.clear()
	var a := bee_act - 1
	# os padrões densos miram em quem o jogador controla; o alvo trava aqui, no começo do golpe
	bee_focus = units[ctrl] if units[ctrl].alive else _aggro_target()
	match s["t"]:
		"bee_idle":
			# a primeira folga de cada ato novo apresenta os corações teleguiados, sozinhos
			if bee_act >= 2 and bee_n == 1:
				_bee_homing(2)
				_bee_tip("homing", "FUJA DOS CORAÇÕES! (o dash estoura)")
		"bee_finale":
			cast_name = "Finale" if bee_act == 2 else "Bis!"
			boss.casting = true
			boss.rage_t = s["dur"]
			_bee_clear()
			hud.shout("2º ATO!" if bee_act == 2 else "ÚLTIMO ATO!")
			_bee_event(2.8, _bee_finale_hit)
		"bee_hell":
			_bee_hell_start()
		"bee_wave":
			cast_name = "Onda de Mel"
			boss.casting = true
			var d := _bee_card_dir()
			var sp: float = BEE_WAVE_SPEED[a]
			match bee_act:
				1:
					_bee_wave(d, 0.0, sp)
				2:
					# duas, uma de cada lado: no meio elas chegam juntas
					_bee_wave(d, 0.0, sp)
					_bee_wave(-d, 0.0, sp)
				_:
					# três em ritmo e uma atravessada por cima
					for k in 3:
						_bee_wave(d, k * 0.95, sp)
					_bee_wave(Vector3(-d.z, 0, d.x), 3.15, sp)
			_bee_tip("wave", "PULE A ONDA DE MEL!")
		"bee_ring":
			cast_name = "Batida do Palco"
			boss.casting = true
			# sobe (aviso), cai e solta as ondas de choque: uma por ato
			_bee_lift_to(3.4, 0.6)
			_add_hazard({"shape": "circle", "pos": boss_pos, "r": 2.1, "total": 0.9, "dmg": 20.0 * bee_power,
				"card": "dodge", "why": "ficou embaixo da Batida do Palco", "bee": true})
			_bee_event(0.74, _bee_lift_to.bind(0.0, 0.14))
			for k in bee_act:
				_bee_event(0.9 + k * 0.95, _bee_ring.bind(float(BEE_RING_SPEED[a])))
			_bee_tip("ring", "PULE A ONDA DE CHOQUE!")
		"bee_sting":
			cast_name = "Rajada de Ferrões"
			boss.casting = true
			_bee_aim(0.85)
			var gap: float = [0.75, 0.62, 0.55][a]
			for k in [3, 5, 6][a]:
				_bee_event(0.9 + k * gap, _bee_volley.bind(k))
		"bee_spiral":
			cast_name = "Chuva de Pólen"
			boss.casting = true
			bee_spin = randf() * TAU
			bee_spin_dir = 1.0 if randf() < 0.5 else -1.0
			bee_spin_flip = bee_act < 3
			bee_spiral_t = 0.7
		"bee_dive":
			cast_name = "Mergulho"
			boss.casting = true
			for k in bee_act:
				_bee_event(k * 1.2, _bee_dive.bind(k))
		"bee_slash":
			cast_name = "Corte Ferroado"
			boss.casting = true
			# só no primeiro do aggro: é ele quem decide pra onde o corte vai
			var d := _bee_dir_to(_aggro_target())
			_bee_slash(d, 1.15)
			if bee_act >= 2:
				_bee_event(1.25, _bee_slash.bind(-d, 0.8))
			if bee_act >= 3:
				var side := Vector3(-d.z, 0, d.x)
				_bee_event(2.2, _bee_slash.bind(side, 0.8))
				_bee_event(2.2, _bee_slash.bind(-side, 0.8))
	# do 2º ato em diante os corações teleguiados entram por cima dos golpes
	if s["t"] != "bee_idle" and s["t"] != "bee_finale" and s["t"] != "bee_hell":
		if bee_act == 3 or (bee_act == 2 and bee_n % 4 == 0):
			_bee_homing(2)


func _bee_end_phase() -> void:
	if phase == "bee_hell":
		_bee_hell_stop()
	bee_events.clear()
	bee_aim_t = 0.0
	if bee_aim_node != null:
		bee_aim_node.visible = false
	if bee_lift > 0.01 and (bee_lift_tw == null or not bee_lift_tw.is_running()):
		_bee_lift_to(0.0, 0.14)


## Some com tudo que está voando (Finale).
func _bee_clear() -> void:
	for list in [bee_waves, bee_rings, bee_shots, bee_homing]:
		for o in list:
			_burst(o["node"].global_position, BEE_COL, 0.9)
			o["node"].queue_free()
		list.clear()


func _bee_finale_hit() -> void:
	_raidwide(0.2, "Finale da MEL-CHAN")
	for u in units:
		if bee_hearts[u.idx] > 0:
			_burst(u.position + Vector3(0, 2.4, 0), BEE_COL, 1.6)
		bee_hearts[u.idx] = 0


func _bee_lift_to(h: float, time: float) -> void:
	if bee_lift_tw != null:
		bee_lift_tw.kill()
	bee_lift_tw = create_tween()
	bee_lift_tw.tween_property(self, "bee_lift", h, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if h > 0.0 else Tween.EASE_IN)
	if h <= 0.0:
		bee_lift_tw.tween_callback(func():
			shake_t = 0.35
			shake_amp = 0.45
			_burst(boss_pos, BEE_HONEY, 2.6))


func _bee_card_dir() -> Vector3:
	var a := (randi() % 8) * PI / 4.0
	return Vector3(cos(a), 0, sin(a))


## Onda de Mel: uma barra baixa que atravessa a arena inteira. Fica um instante parada na borda
## (aviso) e depois corre. É rente ao chão: só o pulo passa.
func _bee_wave(dir: Vector3, delay: float, speed: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(arena_r * 2.0 + 2.0, 0.55, BEE_WAVE_W * 2.0)
	var m := Fx.mat(Color(BEE_HONEY.r, BEE_HONEY.g, BEE_HONEY.b, 0.35), 0.0, true)
	var s0 := -(arena_r + 0.8)
	var node := Fx.inst(fx_root, box, m, dir * s0 + Vector3(0, 0.28, 0))
	node.rotation.y = atan2(-dir.x, -dir.z)
	node.scale = Vector3(1, 0.3, 1)
	node.visible = delay <= 0.0
	# setas no chão, na frente da barra: mostram pra que lado ela vai
	for k in 3:
		var tip := Fx.inst(node, Fx.cyl(0.0, 0.45, 0.9), Fx.mat(Color(1.0, 0.5, 0.75, 0.85), 0.0, true), Vector3((k - 1) * arena_r * 0.55, 0, -1.3))
		tip.rotation.x = -PI / 2.0
		tip.scale = Vector3(1, 1, 0.25)
	bee_waves.append({"node": node, "mat": m, "dir": dir, "s": s0, "delay": delay, "warn": BEE_WAVE_WARN,
		"speed": speed, "done": {}, "seen": {}})


## Onda de choque: um anel que cresce a partir de onde ela caiu. Também é rente ao chão.
func _bee_ring(speed: float) -> void:
	var mesh := Fx.torus(0.2, 0.2 + BEE_RING_W * 2.0)
	var node := Fx.inst(fx_root, mesh, Fx.mat(Color(BEE_COL.r, BEE_COL.g, BEE_COL.b, 0.95), 0.0, true), boss_pos + Vector3(0, 0.25, 0))
	node.scale = Vector3(1, 0.55, 1)
	bee_rings.append({"node": node, "mesh": mesh, "pos": boss_pos, "r": 0.6, "speed": speed, "done": {}, "seen": {}})
	shake_t = 0.25
	shake_amp = 0.3
	_burst(boss_pos, BEE_COL, 2.0)


func _bee_shot(from: Vector3, dir: Vector3, speed: float) -> void:
	var node := Fx.inst(fx_root, Fx.sphere(0.28), Fx.mat(Color(1.25, 0.5, 0.85), 0.0, true), from + dir * 1.2 + Vector3(0, 0.7, 0))
	Fx.inst(node, Fx.torus(0.36, 0.46), Fx.mat(Color(1.0, 0.95, 0.4, 0.95), 0.0, true))
	bee_shots.append({"node": node, "dir": dir, "speed": speed})


## Linha de mira: um fio fino da boss até o alvo, pelo tempo do aviso.
func _bee_aim(time: float) -> void:
	if bee_aim_node == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.1, 0.05, 1.0)
		bee_aim_node = Fx.inst(fx_root, box, Fx.mat(Color(1.0, 0.4, 0.7, 0.8), 0.0, true))
	bee_aim_t = time
	bee_aim_node.visible = true


## Uma leva de ferrões em leque. Leva par: 5, com um no meio (desvie pro lado). Leva ímpar: 4, com um
## vão no meio (fique parado). A leva pesada vai em quem o jogador controla; outro herói recebe um só.
func _bee_volley(k: int) -> void:
	if bee_focus == null or not bee_focus.alive:
		bee_focus = _aggro_target()
	if bee_focus == null:
		return
	var a := bee_act - 1
	var base := _bee_dir_to(bee_focus)
	var count := 5 if k % 2 == 0 else 4
	for i in count:
		var off := (i - (count - 1) * 0.5) * 0.34
		_bee_shot(boss_pos, base.rotated(Vector3.UP, off), float(BEE_SHOT_SPEED[a]))
	bee_face = atan2(base.x, base.z)
	for u in _alive_shuffled():
		if u != bee_focus:
			_bee_shot(boss_pos, _bee_dir_to(u), float(BEE_SHOT_SPEED[a]) * 0.7)
			break


## Mergulho: marca uma faixa da boss até o outro lado da arena, passando pelo alvo, e atravessa.
func _bee_dive(k: int) -> void:
	var tgt: Unit = bee_focus if k == 0 and bee_focus != null and bee_focus.alive else null
	if tgt == null:
		var pool := _alive_shuffled()
		tgt = pool[0] if not pool.is_empty() else null
	var dir := _bee_dir_to(tgt)
	# até onde dá pra ir nessa direção sem sair da arena
	var lim := arena_r - 1.6
	var b := boss_pos.dot(dir)
	var out := -b + sqrt(maxf(0.0, b * b - (boss_pos.length_squared() - lim * lim)))
	var run := maxf(out, 2.0)
	var to := boss_pos + dir * run
	var flat := Vector2(to.x, to.z).limit_length(lim)
	to = Vector3(flat.x, 0, flat.y)
	_add_hazard({"shape": "rect", "pos": boss_pos + dir * run * 0.5, "dir": dir, "half_l": run * 0.5 + 0.8, "half_w": 1.25,
		"total": 0.85, "dmg": float(BEE_DMG["dive"]) * bee_power, "card": "dodge", "why": "ficou no caminho do Mergulho", "bee": true})
	bee_face = atan2(dir.x, dir.z)
	var tw := create_tween()
	tw.tween_interval(0.85)
	tw.tween_property(self, "boss_pos", to, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Corte Ferroado: uma faixa larga saindo dela. O primeiro vai em quem está no topo do aggro.
func _bee_slash(dir: Vector3, total: float) -> void:
	_add_hazard({"shape": "rect", "pos": boss_pos + dir * 3.7, "dir": dir, "half_l": 3.7, "half_w": 1.8,
		"total": total, "dmg": float(BEE_DMG["slash"]) * bee_power, "card": "dodge", "why": "ficou no Corte Ferroado", "bee": true})
	bee_face = atan2(dir.x, dir.z)


## Corações teleguiados: nascem na borda, param um instante (aviso) e perseguem devagar. O primeiro
## sempre vai em quem o jogador controla. Encostar dá coração; passar de dash por dentro estoura.
func _bee_homing(n: int) -> void:
	var targets: Array = []
	if units[ctrl].alive:
		targets.append(units[ctrl])
	for u in _alive_shuffled():
		if not targets.has(u):
			targets.append(u)
	for k in mini(n, targets.size()):
		var tgt: Unit = targets[k]
		var away := _bee_flat(tgt.position)
		var a := (atan2(away.z, away.x) if away.length() > 0.5 else randf() * TAU) + PI + randf_range(-0.9, 0.9)
		var node := Node3D.new()
		node.position = Vector3(cos(a), 0, sin(a)) * (arena_r - 0.8) + Vector3(0, 0.9, 0)
		fx_root.add_child(node)
		var pink := Fx.mat(Color(1.3, 0.35, 0.7), 0.0, true)
		for sx in [-1.0, 1.0]:
			Fx.inst(node, Fx.sphere(0.27), pink, Vector3(sx * 0.17, 0.12, 0))
		Fx.inst(node, Fx.cyl(0.4, 0.0, 0.48), pink, Vector3(0, -0.2, 0))
		node.scale = Vector3.ONE * 0.2
		bee_homing.append({"node": node, "unit": tgt, "life": BEE_HOMING_LIFE, "warn": 0.9})


## Um golpe da MEL-CHAN pegou: dano, um instante de invulnerabilidade (pra não tomar dois seguidos)
## e +1 coração.
func _bee_hit(u: Unit, kind: String, why: String) -> void:
	if not u.alive or u.immortal_t > 0.0:
		return
	# quem a IA controla recebe a versão leve do golpe; o coração conta igual
	var soft := 1.0 if (u == units[ctrl] and not autoplay) else (BEE_AI_SOFT_HELL if bee_hell else BEE_AI_SOFT)
	hurt(u, float(BEE_DMG[kind]) * bee_power * soft, why)
	_bee_heart(u)


## +1 coração. No quarto: encantado (parado e intocável), e ela se cura e fica mais forte pra sempre.
func _bee_heart(u: Unit) -> void:
	if not bee or not u.alive:
		return
	u.invuln = maxf(u.invuln, BEE_IFRAMES)
	bee_hearts[u.idx] += 1
	_burst(u.position + Vector3(0, 2.4, 0), BEE_COL, 1.1)
	if bee_hearts[u.idx] < BEE_HEARTS:
		return
	bee_hearts[u.idx] = 0
	bee_charms += 1
	# o encanto de quem a IA controla rende bem menos pra ela: quem decide a luta é o jogador
	var mine: bool = u == units[ctrl] and not autoplay
	var gain := 1.0 if mine else BEE_AI_CHARM
	bee_power = minf(BEE_POWER_MAX, bee_power + BEE_POWER_UP * gain)
	u.lock_t = maxf(u.lock_t, BEE_CHARM)
	u.invuln = maxf(u.invuln, BEE_CHARM)
	u.channel_t = 0.0
	boss_hp = minf(boss_max, boss_hp + boss_max * BEE_HEAL * gain)
	boss.rage()
	boss.scale = Vector3.ONE * float(boss_def["scale"]) * (1.0 + 0.05 * mini(bee_charms, 6))
	if u.controlled:
		hud.shout("ENCANTADO!")
	else:
		hud.toast("%s ficou encantado!" % u.unit_name, 1.6)
	# anel rosa girando em volta de quem está encantado
	var m := Fx.mat(Color(BEE_COL.r, BEE_COL.g, BEE_COL.b, 0.9), 0.0, true)
	var ring := Fx.inst(u, Fx.torus(0.75, 0.9), m, Vector3(0, 1.1, 0))
	var tw := ring.create_tween()
	tw.tween_property(ring, "rotation:y", TAU * 3.0, BEE_CHARM)
	tw.parallel().tween_property(ring, "position:y", 2.0, BEE_CHARM)
	tw.tween_callback(ring.queue_free)


## Os corações em cima da cabeça de cada herói. No terceiro eles piscam: o próximo encanta.
func _bee_pips() -> void:
	for u in units:
		if not bee_pip_nodes.has(u.idx):
			var arr: Array = []
			for k in BEE_HEARTS - 1:
				var pip := Node3D.new()
				pip.position = Vector3((k - 1) * 0.42, 3.05, 0)
				u.add_child(pip)
				var pink := Fx.mat(Color(1.3, 0.35, 0.7), 0.0, true)
				for sx in [-1.0, 1.0]:
					Fx.inst(pip, Fx.sphere(0.11), pink, Vector3(sx * 0.07, 0.05, 0))
				Fx.inst(pip, Fx.cyl(0.165, 0.0, 0.2), pink, Vector3(0, -0.08, 0))
				arr.append(pip)
			bee_pip_nodes[u.idx] = arr
		var n: int = bee_hearts[u.idx] if u.alive else 0
		var pips: Array = bee_pip_nodes[u.idx]
		for k in pips.size():
			pips[k].visible = k < n
			var pulse := 1.0 + (0.35 * absf(sin(fight_time * 11.0)) if n >= BEE_HEARTS - 1 else 0.0)
			pips[k].scale = Vector3.ONE * pulse


## Encostou num ataque rente ao chão (onda ou anel). No ar: passou. No chão: tomou.
func _bee_low_touch(u: Unit, o: Dictionary, kind: String, why: String) -> void:
	if o["done"].has(u.idx):
		return
	o["done"][u.idx] = true
	var by_hand: bool = u == units[ctrl] and not autoplay
	if u.airborne():
		_fan_passed(u, by_hand)
	elif u.invuln <= 0.0:
		_bee_hit(u, kind, why)
		if not by_hand:
			Knowledge.learn(u.hero, "fan", LEARN_HIT)


func _tick_bee(delta: float) -> void:
	var now := _bee_clock()
	while not bee_events.is_empty() and now >= float(bee_events[0][0]):
		var ev: Array = bee_events.pop_front()
		(ev[1] as Callable).call()
	_tick_hell_fire()
	match phase:
		"bee_hell":
			# parada no meio, girando devagar; o pólen sai em colcheias, no tempo da música
			bee_face += delta * 1.4
			if bee_hell_dir != 0.0:
				bee_spin += bee_hell_dir * 1.05 * delta
				while now >= bee_hell_next:
					bee_hell_next += HELL_BEAT * 0.5
					for n in 4:
						var sa := bee_spin + n * TAU / 4.0
						_bee_shot(boss_pos, Vector3(cos(sa), 0, sin(sa)), BEE_SPIRAL_SPEED)
		"bee_idle":
			# anda atrás do primeiro do aggro e para no limite do corpo a corpo
			var top := _aggro_target()
			if top != null:
				var to := _bee_flat(top.position - boss_pos)
				if to.length() > ROAM_MELEE - 0.6:
					boss_pos += to.normalized() * BEE_CHASE * delta
				if to.length() > 0.2:
					bee_face = atan2(to.x, to.z)
		"bee_spiral":
			if not bee_spin_flip and phase_t >= phase_dur * 0.5:
				bee_spin_flip = true
				bee_spin_dir = -bee_spin_dir
			bee_spin += bee_spin_dir * 1.15 * delta
			bee_spiral_t -= delta
			if bee_spiral_t <= 0.0 and phase_t < phase_dur - 0.8:
				bee_spiral_t = 0.17
				var arms: int = [3, 3, 4][bee_act - 1]
				for n in arms:
					var a := bee_spin + n * TAU / arms
					_bee_shot(boss_pos, Vector3(cos(a), 0, sin(a)), BEE_SPIRAL_SPEED)
	var flat := Vector2(boss_pos.x, boss_pos.z).limit_length(arena_r - 1.4)
	boss_pos = Vector3(flat.x, 0, flat.y)
	boss.position = boss_pos + Vector3(0, bee_lift, 0)
	boss.rotation.y = lerp_angle(boss.rotation.y, bee_face, minf(1.0, delta * 9.0))
	# linha de mira
	if bee_aim_t > 0.0 and bee_aim_node != null and bee_focus != null:
		bee_aim_t -= delta
		var d := _bee_flat(bee_focus.position - boss_pos)
		bee_aim_node.position = boss_pos + d * 0.5 + Vector3(0, 0.12, 0)
		bee_aim_node.rotation.y = atan2(d.x, d.z)
		bee_aim_node.scale = Vector3(1.0 + sin(fight_time * 30.0) * 0.4, 1, maxf(d.length(), 0.1))
		bee_aim_node.visible = bee_aim_t > 0.0
	# ondas de mel
	for w in bee_waves.duplicate():
		var node: MeshInstance3D = w["node"]
		if w["delay"] > 0.0:
			w["delay"] -= delta
			node.visible = w["delay"] <= 0.0
			continue
		var dir: Vector3 = w["dir"]
		if w["warn"] > 0.0:
			w["warn"] -= delta
			# treme na borda, como quem pega impulso
			node.position = dir * (float(w["s"]) + sin(fight_time * 26.0) * 0.12) + Vector3(0, 0.28, 0)
			if w["warn"] <= 0.0:
				(w["mat"] as StandardMaterial3D).albedo_color = Color(BEE_HONEY.r * 1.2, BEE_HONEY.g * 1.1, BEE_HONEY.b, 0.95)
				node.create_tween().tween_property(node, "scale:y", 1.0, 0.1)
			continue
		w["s"] += float(w["speed"]) * delta
		node.position = dir * float(w["s"]) + Vector3(0, 0.28, 0)
		if w["s"] > arena_r + 1.0:
			node.queue_free()
			bee_waves.erase(w)
			continue
		for u in units:
			if u.alive and absf(u.position.dot(dir) - float(w["s"])) <= BEE_WAVE_W + 0.2:
				_bee_low_touch(u, w, "wave", "tomou a Onda de Mel")
	# ondas de choque
	for r in bee_rings.duplicate():
		r["r"] += float(r["speed"]) * delta
		var rad: float = r["r"]
		var tm: TorusMesh = r["mesh"]
		tm.inner_radius = maxf(0.05, rad - BEE_RING_W)
		tm.outer_radius = rad + BEE_RING_W
		var c: Vector3 = r["pos"]
		if rad > arena_r + c.length() + 1.0:
			r["node"].queue_free()
			bee_rings.erase(r)
			continue
		for u in units:
			if u.alive and absf(_bee_flat(u.position - c).length() - rad) <= BEE_RING_W + 0.15:
				_bee_low_touch(u, r, "ring", "tomou a onda de choque")
	# ferrões e pólen: seguem reto até sair da arena. A área de acerto é menor que o desenho.
	for o in bee_shots.duplicate():
		var node: MeshInstance3D = o["node"]
		node.position += (o["dir"] as Vector3) * float(o["speed"]) * delta
		node.rotate_y(delta * 7.0)
		if Vector2(node.position.x, node.position.z).length() > arena_r + 0.5:
			node.queue_free()
			bee_shots.erase(o)
			continue
		for u in units:
			if u.alive and u.invuln <= 0.0 and Vector2(u.position.x - node.position.x, u.position.z - node.position.z).length() <= BEE_SHOT_R + 0.14:
				_burst(node.position, BEE_COL, 1.2)
				_bee_hit(u, "shot", "tomou um ferrão")
				node.queue_free()
				bee_shots.erase(o)
				break
	# corações teleguiados
	for h in bee_homing.duplicate():
		var node: Node3D = h["node"]
		node.rotate_y(delta * 3.0)
		if h["warn"] > 0.0:
			h["warn"] -= delta
			node.scale = Vector3.ONE * lerpf(1.0, 0.2, clampf(float(h["warn"]) / 0.9, 0.0, 1.0))
			continue
		h["life"] -= delta
		var tgt: Unit = h["unit"]
		if tgt == null or not tgt.alive:
			var pool := _alive_shuffled()
			tgt = pool[0] if not pool.is_empty() else null
			h["unit"] = tgt
		if h["life"] <= 0.0 or tgt == null:
			_burst(node.position, BEE_COL, 1.0)
			node.queue_free()
			bee_homing.erase(h)
			continue
		var to := _bee_flat(tgt.position - node.position)
		if to.length() > 0.05:
			node.position += to.normalized() * BEE_HOMING_SPEED * (1.0 + 0.12 * (bee_act - 1)) * delta
		# perto do fim ele pisca: vai estourar sozinho
		node.visible = h["life"] > 1.2 or fmod(float(h["life"]), 0.2) > 0.08
		for u in units:
			if u.alive and _bee_flat(u.position - node.position).length() <= 0.62:
				if u.invuln > 0.0:
					_impact_ring(node.position, BEE_COL, 1.6)  # estourou no dash
				else:
					_bee_hit(u, "homing", "foi pego por um coração")
				_burst(node.position, BEE_COL, 1.3)
				node.queue_free()
				bee_homing.erase(h)
				break
	_bee_pips()


# ---------------------------------------------------------------- MEL-CHAN: HELL TIME

## Instante (dentro do passo) de um compasso e tempo da música. Compasso 0 = fim da subida.
func _hb(bar: int, beat: float) -> float:
	return HELL_PRE + (bar * 4.0 + beat) * HELL_BEAT


## O relógio dos eventos do passo. No HELL TIME é o tempo da MÚSICA, pra os golpes saírem na batida;
## sem áudio (testes), ou se ela escorregar demais, vale o tempo do passo.
func _bee_clock() -> float:
	if phase == "bee_hell" and hell_player != null and hell_player.playing:
		var mt := hell_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if absf(mt - phase_t) < 0.35:
			return mt
	return phase_t


## HELL TIME: ela volta pro meio do palco durante a subida da música e fica lá até o fim. O fogo
## roxo sobe atrás do cenário e os golpes saem em cima da batida (ver _bee_hell_plan).
func _bee_hell_start() -> void:
	cast_name = "HELL TIME"
	boss.casting = true
	bee_hell = true
	bee_hell_dir = 0.0
	hud.shout("HELL TIME!!!")
	_bee_clear()
	_bee_lift_to(3.2, HELL_PRE * 0.45)
	var tw := create_tween()
	tw.tween_property(self, "boss_pos", Vector3.ZERO, HELL_PRE * 0.8).set_trans(Tween.TRANS_SINE)
	_hell_fire(true)
	if not autoplay and ResourceLoader.exists(HELL_MUSIC):
		if hell_player == null:
			hell_player = AudioStreamPlayer.new()
			hell_player.stream = load(HELL_MUSIC)
			hell_player.bus = &"SFX"
			add_child(hell_player)
		hell_player.volume_db = -5.0
		hell_player.play()
	_bee_hell_plan()


## A partitura do HELL TIME: 32 compassos em quatro seções de 8, iguais às da música.
##   A (0-7)   Pulso  — onda de choque a cada dois tempos, leques de ferrões no 4º tempo
##   B (8-15)  Pólen  — quatro braços de pólen girando (inverte no meio), cruzes de corte
##   C (16-23) Marés  — ondas de mel de um lado e do outro, corações teleguiados
##   D (24-31) Tudo   — choque + pólen + ferrões, e o palco alternando "pra dentro" e "pra fora"
func _bee_hell_plan() -> void:
	var evs: Array = []
	var ev := func(at: float, fn: Callable): evs.append([at, fn])
	ev.call(HELL_PRE - 0.3, _bee_lift_to.bind(0.0, 0.3))
	# A
	for bar in range(0, 8):
		ev.call(_hb(bar, 0), _bee_ring.bind(HELL_RING))
		ev.call(_hb(bar, 2), _bee_ring.bind(HELL_RING))
		if bar >= 1:
			ev.call(_hb(bar, 3) - 0.8, _bee_aim.bind(0.8))
			ev.call(_hb(bar, 3), _bee_volley.bind(bar))
		if bar >= 4:
			ev.call(_hb(bar, 1), _bee_volley.bind(bar + 1))
	# B
	ev.call(_hb(8, 0), _bee_hell_spiral.bind(1.0))
	ev.call(_hb(12, 0), _bee_hell_spiral.bind(-1.0))
	ev.call(_hb(16, 0), _bee_hell_spiral.bind(0.0))
	for bar in range(8, 16):
		ev.call(_hb(bar, 0), _bee_ring.bind(HELL_RING))
		if bar % 2 == 1:
			# a cruz aparece no começo do compasso e bate no começo do seguinte
			ev.call(_hb(bar, 0), _bee_cross.bind(0.0 if (bar / 2) % 2 == 0 else PI / 4.0, HELL_BEAT * 4.0))
	# C
	for bar in range(16, 24):
		var axis := Vector3(0, 0, 1) if bar < 20 else Vector3(1, 0, 0)
		for half in 2:
			var k := (bar - 16) * 2 + half
			# a onda começa a correr em cima do tempo
			ev.call(_hb(bar, half * 2.0) - BEE_WAVE_WARN, _bee_wave.bind(axis * (1.0 if k % 2 == 0 else -1.0), 0.0, HELL_WAVE))
		if bar % 2 == 0:
			ev.call(_hb(bar, 3) - 0.8, _bee_aim.bind(0.8))
			ev.call(_hb(bar, 3), _bee_volley.bind(1))
	ev.call(_hb(16, 0), _bee_homing.bind(3))
	ev.call(_hb(20, 0), _bee_homing.bind(3))
	# D
	for bar in range(24, 32):
		ev.call(_hb(bar, 0), _bee_ring.bind(HELL_RING))
		ev.call(_hb(bar, 2), _bee_ring.bind(HELL_RING))
		if bar % 2 == 0:
			ev.call(_hb(bar, 0), _bee_hell_spiral.bind(1.0 if (bar / 2) % 2 == 0 else -1.0))
			# dentro e fora: a explosão cai dois compassos depois, no tempo forte
			ev.call(_hb(bar, 0), _bee_inout.bind((bar / 2) % 2 == 0, HELL_BEAT * 8.0))
		ev.call(_hb(bar, 3) - 0.8, _bee_aim.bind(0.8))
		ev.call(_hb(bar, 3), _bee_volley.bind(bar))
	ev.call(_hb(HELL_BARS, 0), _bee_hell_end)
	evs.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	bee_events = evs


func _bee_hell_spiral(dir: float) -> void:
	if bee_hell_dir == 0.0 and dir != 0.0:
		bee_hell_next = _bee_clock()
	bee_hell_dir = dir


## Quatro faixas saindo do meio, em cruz (ângulo 0) ou em X (45 graus).
func _bee_cross(angle: float, total: float) -> void:
	for k in 4:
		var a := angle + k * PI / 2.0
		var dir := Vector3(cos(a), 0, sin(a))
		_add_hazard({"shape": "rect", "pos": dir * (arena_r * 0.5 + 0.2), "dir": dir, "half_l": arena_r * 0.5 + 0.4, "half_w": 1.3,
			"total": total, "dmg": 30.0 * bee_power, "card": "dodge", "why": "ficou na cruz do HELL TIME", "bee": true})


## Pra dentro (a borda explode: cole nela) ou pra fora (o meio explode: vá pra borda).
func _bee_inout(inward: bool, total: float) -> void:
	if inward:
		_add_hazard({"shape": "donut", "pos": Vector3.ZERO, "r": 3.8, "total": total, "dmg": 30.0 * bee_power,
			"card": "dodge", "why": "ficou na borda do palco no HELL TIME", "bee": true})
	else:
		_add_hazard({"shape": "circle", "pos": Vector3.ZERO, "r": 5.4, "total": total, "dmg": 30.0 * bee_power,
			"card": "dodge", "why": "ficou no meio do palco no HELL TIME", "bee": true})


func _bee_hell_end() -> void:
	bee_hell = false
	bee_hell_dir = 0.0
	shake_t = 0.5
	shake_amp = 0.6
	_burst(Vector3(0, 1.0, 0), Color(0.8, 0.3, 1.0), arena_r)
	hud.flash(Color(0.8, 0.4, 1.0, 0.4))
	_hell_fire(false)


## Corta o HELL TIME no meio (a luta acabou, ou o passo foi trocado): apaga o fogo e a música.
func _bee_hell_stop() -> void:
	bee_hell = false
	bee_hell_dir = 0.0
	_hell_fire(false)
	if hell_player != null and hell_player.playing:
		var tw := hell_player.create_tween()
		tw.tween_property(hell_player, "volume_db", -40.0, 0.7)
		tw.tween_callback(hell_player.stop)


## Uma chama low-poly: três cones de quatro lados, um dentro do outro (do roxo escuro ao rosa), e
## duas línguas tortas dos lados. `inward` aponta pro meio do palco: as camadas claras ficam na frente.
func _flame(parent: Node3D, at: Vector3, h: float, w: float, inward: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var cols := [Color(0.3, 0.06, 0.55), Color(0.62, 0.12, 0.8), Color(0.95, 0.42, 0.95)]
	for k in 3:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = w * (1.0 - k * 0.28)
		m.height = h * (1.0 - k * 0.25)
		m.radial_segments = 4
		m.rings = 1
		var mi := Fx.inst(root, m, Fx.mat(cols[k], 0.0, true), Vector3(0, m.height * 0.5, 0) + inward * (k * 0.5))
		mi.rotation.y = randf() * TAU
	var side := Vector3(-inward.z, 0, inward.x)
	for s in [-1.0, 1.0]:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = w * 0.5
		m.height = h * randf_range(0.45, 0.62)
		m.radial_segments = 3
		m.rings = 1
		var mi := Fx.inst(root, m, Fx.mat(cols[0] if s < 0.0 else cols[1], 0.0, true), side * (s * w * 0.8) + Vector3(0, m.height * 0.5, 0))
		mi.rotation = Vector3(inward.z, 0, -inward.x) * (s * 0.22)
	# cada chama estica e encolhe no seu tempo
	var tw := root.create_tween().set_loops()
	var d := randf_range(0.26, 0.5)
	tw.tween_property(root, "scale", Vector3(0.9, 1.16, 0.9), d).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "scale", Vector3(1.08, 0.86, 1.08), d).set_trans(Tween.TRANS_SINE)


## O fogo do HELL TIME: uma muralha de chamas atrás da arquibancada e algumas dos lados, mais três
## luzes roxas. Nasce apagado (hell_glow 0) e só sobe em _hell_fire.
func _build_hell_fire() -> void:
	hell_fire = Node3D.new()
	hell_fire.scale = Vector3(1, 0.001, 1)
	hell_fire.visible = false
	add_child(hell_fire)
	for n in 15:
		var a := -PI / 2.0 + lerpf(-1.5, 1.5, n / 14.0)
		var out := Vector3(cos(a), 0, sin(a))
		_flame(hell_fire, out * (arena_r + 13.6 + randf_range(-0.8, 0.8)) + Vector3(0, 1.5, 0), randf_range(11.0, 18.0), randf_range(2.8, 3.8), -out)
	for s in [-1.0, 1.0]:
		for n in 3:
			var a: float = -PI / 2.0 + s * (1.85 + n * 0.3)
			var out := Vector3(cos(a), 0, sin(a))
			_flame(hell_fire, out * (arena_r + 9.5 + n * 1.5), randf_range(6.5, 9.5), randf_range(2.0, 2.8), -out)
	for p in [Vector3(0, 7, -(arena_r + 8.0)), Vector3(-(arena_r + 7.0), 6, -2), Vector3(arena_r + 7.0, 6, -2)]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(0.8, 0.3, 1.0)
		light.omni_range = 30.0
		light.light_energy = 0.0
		add_child(light)
		hell_lights.append(light)


func _hell_fire(on: bool) -> void:
	if hell_fire == null:
		return
	if hell_tw != null:
		hell_tw.kill()
	hell_tw = create_tween().set_parallel(true)
	hell_tw.tween_property(self, "hell_glow", 1.0 if on else 0.0, 1.8 if on else 1.2)
	if stage_env != null:
		hell_tw.tween_property(stage_env, "ambient_light_color", Color(0.72, 0.4, 0.95) if on else Color(0.75, 0.62, 0.78), 1.8)
		hell_tw.tween_property(stage_env, "background_color", Color(0.14, 0.02, 0.2) if on else Color(0.09, 0.03, 0.12), 1.8)
	floor_mat.set_shader_parameter("rim_col", Color(0.75, 0.3, 1.0) if on else Color(1.0, 0.45, 0.72))


## O fogo acompanha a música: cresce um pouco em cada batida, e as luzes piscam junto.
func _tick_hell_fire() -> void:
	if hell_fire == null:
		return
	hell_fire.visible = hell_glow > 0.002
	if not hell_fire.visible:
		for light in hell_lights:
			light.light_energy = 0.0
		return
	var pulse := 0.0
	if bee_hell:
		pulse = exp(-fposmod(_bee_clock() - HELL_PRE, HELL_BEAT) / HELL_BEAT * 4.0)
	hell_fire.scale = Vector3(1, maxf(0.001, hell_glow * (1.0 + 0.13 * pulse)), 1)
	for i in hell_lights.size():
		(hell_lights[i] as OmniLight3D).light_energy = hell_glow * (3.0 + 1.8 * pulse + sin(fight_time * 17.0 + i * 2.0) * 0.5)


## Quanto falta (em segundos) pro próximo ataque rente ao chão chegar neste herói, e qual é ele.
func _bee_low_eta(u: Unit) -> Array:
	var best := INF
	var which = null
	for w in bee_waves:
		var gap: float = u.position.dot(w["dir"]) - float(w["s"])
		if gap <= 0.0:
			continue
		var eta: float = maxf(0.0, w["delay"]) + maxf(0.0, w["warn"]) + gap / float(w["speed"])
		if eta < best:
			best = eta
			which = w
	for r in bee_rings:
		var gap: float = _bee_flat(u.position - r["pos"]).length() - float(r["r"])
		if gap <= 0.0:
			continue
		var eta: float = gap / float(r["speed"])
		if eta < best:
			best = eta
			which = r
	return [best, which]


## A IA nas ondas: é o mesmo saber do ventilador de raios (pular na hora). O conhecimento dá a
## chance de tentar e a precisão do tempo; cada onda é decidida uma vez por herói.
func _bee_ai(u: Unit, delta: float) -> void:
	if u.ai_hop_at >= 0.0:
		u.ai_hop_at -= delta
		if u.ai_hop_at <= 0.0:
			u.ai_hop_at = -1.0
			jump(u)
	var low := _bee_low_eta(u)
	if low[1] == null or float(low[0]) > 0.95:
		return
	var o: Dictionary = low[1]
	if o["seen"].has(u.idx):
		return
	o["seen"][u.idx] = true
	var k := Knowledge.knowledge(u.hero, "fan") / 100.0
	if randf() < lerpf(0.3, 0.97, k):
		var miss := randfn(0.0, lerpf(0.3, 0.04, k))
		u.ai_hop_at = maxf(0.0, float(low[0]) - JUMP_AIR * 0.5 + miss)
		if k < 0.5:
			_think(u, "!", Color(1.0, 0.9, 0.3))
	elif randf() < 0.5:
		_think(u, "?", Color(0.8, 0.85, 1.0))


## Pra onde a IA vai nos padrões da MEL-CHAN (null = segue a vida normal).
func _bee_goal(u: Unit):
	# coração teleguiado chegando perto: corre dele
	for h in bee_homing:
		if h["warn"] <= 0.0 and _bee_flat(u.position - h["node"].position).length() < 2.6:
			return [_flee_from(u, h["node"].position), "Fugindo do coração"]
	# ferrão vindo na direção dele: um passo pro lado
	for o in bee_shots:
		var rel: Vector3 = _bee_flat(u.position - o["node"].position)
		var dir: Vector3 = o["dir"]
		var along := rel.dot(dir)
		if along < 0.0 or along > float(o["speed"]) * 0.8:
			continue
		var side := rel - dir * along
		if side.length() < BEE_SHOT_R + 0.6:
			var step := side.normalized() if side.length() > 0.05 else Vector3(-dir.z, 0, dir.x)
			var p := u.position + step * 1.3
			var flat := Vector2(p.x, p.z).limit_length(arena_r - 0.6)
			return [Vector3(flat.x, 0, flat.y), "Desviando do ferrão"]
	return null


func _flee_from(u: Unit, from: Vector3) -> Vector3:
	var away := u.position - from
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var p := u.position + away * 2.6
	if Vector2(p.x, p.z).length() > arena_r - 0.8:
		# encurralado na borda: escorrega pelo lado em vez de parar
		p = u.position + away.rotated(Vector3.UP, 1.25) * 2.6
	var flat := Vector2(p.x, p.z).limit_length(arena_r - 0.6)
	return Vector3(flat.x, 0, flat.y)


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
			_burst(_bp(Vector3(0, 5, -12)), Color(0.5, 0.9, 1.0), 9.0)
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
	if survivors == 4 and not autoplay and not Knowledge.practice and Knowledge.grant("mark"):
		Knowledge.mark_new("mark", units[ctrl].hero)
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
	var say := Fx.label(fx_root, "BORA BISCOITAR!", _bp(Vector3(0, 6.4, -9.5)), 120)
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
		var r := sqrt(randf()) * arena_r
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
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.6), 5.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(1.0), m, p + Vector3(0, 0.3, 0))
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.5, radius), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)
	# miolo de luz: um clarão curto, quase branco, na cor do efeito
	var core_m := Fx.mat(Color(col.r, col.g, col.b, 0.9).lightened(0.55), 9.0, true)
	var core := Fx.inst(fx_root, Fx.sphere(1.0), core_m, p + Vector3(0, 0.3, 0))
	core.scale = Vector3.ONE * radius * 0.28
	var tc := core.create_tween().set_parallel(true)
	tc.tween_property(core, "scale", Vector3.ONE * radius * 0.05, 0.22)
	tc.tween_property(core_m, "albedo_color:a", 0.0, 0.22)
	tc.chain().tween_callback(core.queue_free)
