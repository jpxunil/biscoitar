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

const UNIT_DEFS := [
	{"name": "Paladino", "range": MELEE_RANGE, "key": "tank", "color": Color(0.3, 0.5, 1.0), "hp": 160.0, "melee": true, "ai_dps": 6.0, "hit": 8.0, "tank": true},
	{"name": "Healer", "range": RANGED_RANGE, "key": "healer", "color": Color(0.4, 0.95, 0.55), "hp": 90.0, "melee": false, "ai_dps": 3.0, "hit": 6.0},
	{"name": "Assassina", "range": MELEE_RANGE, "key": "assassina", "color": Color(0.78, 0.38, 1.0), "hp": 100.0, "melee": true, "ai_dps": 10.0, "hit": 17.0},
	{"name": "Maga", "range": RANGED_RANGE, "key": "maga", "color": Color(1.0, 0.72, 0.25), "hp": 90.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
	# segunda tank: ocupa o lugar 0 da party quando Knowledge.tank_pick aponta pra ela
	{"name": "Gothic Nurse", "range": MELEE_RANGE, "key": "nurse", "color": Color(0.36, 0.4, 0.95), "hp": 112.0, "melee": true, "ai_dps": 6.0, "hit": 8.0, "tank": true},
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
## O slot 4 do Tank é o Bora Biscoitar: é ele quem puxa o boss pra si.
const SKILLS := {
	"tank": [{"name": "Golpe", "cd": 1.0, "dmg": 22.0},
		{"name": "Mitigação", "cd": 10.0}, null, PROVOKE],
	# Gothic Nurse (tank de sangue): J estoca fraco e rouba vida, K é o parry, L rouba vida fixa e
	# junta acúmulos, U avança e provoca, O é o ultimate (não tem recarga: gasta PARTY_NEED acúmulos).
	"nurse": [{"name": "Syringe Poke", "cd": 1.0, "dmg": 8.0},
		{"name": "Blood Taste", "cd": 20.0}, {"name": "Blood Consumed", "cd": 5.0, "dmg": 40.0},
		{"name": "Emergency Response", "cd": 8.0}, {"name": "Blood Party", "cd": 0.0, "stacks": 20}],
	"healer": [{"name": "Faísca", "cd": 1.0, "dmg": 14.0, "cast": 0.5},
		{"name": "Cura", "cd": 4.0, "cast": 0.5}, {"name": "Reviver", "cd": 25.0, "cast": 1.5},
		{"name": "Cura em Área", "cd": 8.0, "cast": 1.0}, {"name": "Escudo", "cd": 20.0, "cast": 1.0}],
	"assassina": [{"name": "Corte", "cd": 1.0, "dmg": 46.0},
		{"name": "Execução", "cd": 7.0, "dmg": 70.0}, {"name": "Lâmina Final", "cd": 20.0, "dmg": 260.0, "cast": 2.0}, null],
	"maga": [{"name": "Raio", "cd": 1.0, "dmg": 34.0, "cast": 0.5},
		{"name": "Meteoro", "cd": 7.0, "dmg": 55.0, "cast": 0.5}, {"name": "Ruína", "cd": 20.0, "dmg": 240.0, "cast": 2.0}, null],
}
## Cast curto trava o personagem no lugar; cast longo pode ser interrompido andando.
const LOCKED_CAST := 1.0
## DPS da IA com a carta roxa Rotação (sem ela vale o ai_dps de UNIT_DEFS).
## Assassina e Maga, além disso, soltam o golpe forte de 20 s (Lâmina Final / Ruína) sempre que dá.
const ROTATION_DPS := {"tank": 10.0, "nurse": 4.0, "healer": 6.0, "assassina": 14.0, "maga": 10.0}
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
## Kit da Gothic Nurse.
const BLOOD := Color(0.86, 0.08, 0.2)
const POKE_STEAL := 0.0001     # Syringe Poke: rouba 0,01% da vida ATUAL da boss por estocada
const TASTE_TIME := 0.5        # Blood Taste: janela do parry
const TASTE_HP := 1.6          # ... vida (e vida máxima) vão a 160% da máxima normal
const TASTE_KEEP := 0.5        # ... parry perfeito guarda metade da vida ganha
const TASTE_CD_PARRY := 10.0   # ... e a recarga cai de 20 s pra 10 s
const TASTE_STACKS := 5
const CONSUMED_STEAL := 14.0   # Blood Consumed: vida fixa roubada por acerto
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
			if Knowledge.is_tank(Knowledge.start_hero):
				Knowledge.tank_pick = Knowledge.start_hero
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


func _build_units() -> void:
	for i in 4:
		var u := Unit.new()
		add_child(u)
		u.setup(i, UNIT_DEFS[Knowledge.hero_at(i)])
		u.hero = Knowledge.hero_at(i)
		u.position = START_POS[i]
		u.face(BOSS_POINT - u.position)
		units.append(u)
	ctrl = Knowledge.slot_of(Knowledge.start_hero)
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


## `i` é o herói (índice em Knowledge.HEROES). Se for uma tank diferente da que está montada,
## a cena precisa recarregar pra trocar o boneco e o HUD: devolve false e a luta começa sozinha depois.
func select_hero(i: int) -> bool:
	Knowledge.start_hero = i
	if Knowledge.is_tank(i):
		Knowledge.tank_pick = i
	if units[0].hero != Knowledge.tank_pick:
		Knowledge.autostart = true
		Knowledge.screen = "cards"
		Knowledge.save()
		get_tree().reload_current_scene()
		return false
	var slot := Knowledge.slot_of(i)
	units[ctrl].set_controlled(false)
	ctrl = slot
	units[slot].set_controlled(true)
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
	if not u.alive or u.dash_cd > 0.0:
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
	for u in units:
		if ended:
			return
		if not u.alive:
			continue
		u.invuln = maxf(0.0, u.invuln - delta)
		u.guard_t = maxf(0.0, u.guard_t - delta)
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

	if u.dash_t > 0.0:
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
		var must_move: bool = rot_card and u.channel_slot == 2 and not stacks.is_empty()
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
		goal = ATK_POS[i]
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

	if u.key == "healer" and not (careful and in_danger):
		# Escudo de Emergência: só no cast do ESMAGAR, e a tempo de sair antes do golpe
		if Knowledge.has(u.hero, "eshield") and buster != null and u.skill_cd[4] <= 0.0 and buster["t"] > 1.15 \
				and buster["target"].alive and buster["target"].shield_hp <= 0.0:
			if use_skill(u, 4, true, buster["target"]):
				u.set_action("Escudo no " + buster["target"].unit_name, 1)
				return
		# Reviver Automático: só quando parar 1,5 s não coloca ela em risco
		if Knowledge.has(u.hero, "revive") and u.skill_cd[2] <= 0.0 and stacks.is_empty() and spreads.is_empty() \
				and buster == null and not mechanic_active() and hazards.is_empty() and not void_on:
			for o in units:
				if not o.alive:
					if use_skill(u, 2, true):
						u.set_action("Revivendo " + o.unit_name, 1)
						return
					break

	# Instinto: só reage a pouca vida, então não fica gastando cura à toa.
	if Knowledge.has(u.hero, "instinct") and u.key == "healer":
		# no Dodge Time a explosão do fim tira 70% da vida: ele enche todo mundo antes
		var topping: bool = DODGE_PHASES.has(phase) or finale_state == 1
		var low: float = 0.95 if topping else Knowledge.LOW_HP
		# primeiro ele mesmo: healer morto não cura ninguém
		var ht: Unit = u if u.hp / u.max_hp < Knowledge.LOW_HP else _heal_target()
		# o Tank é socorrido mais cedo: ele precisa de folga pra aguentar o Esmagar
		if ht != null and ht.hp / ht.max_hp < low + (0.3 if ht.idx == 0 and not topping else 0.0):
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
		elif hurt_near >= (2 if topping else 3) and u.skill_cd[3] <= 0.0:
			use_skill(u, 3, true)
		elif heal_focus != null and u.skill_cd[1] <= 0.0:
			use_skill(u, 1, true, heal_focus)

	if u.tank and Knowledge.has(u.hero, "provoke") and target != null and target != u and u.skill_cd[3] <= 0.0:
		use_skill(u, 3, true)

	# Rotação: o golpe forte sai quando não tem nada pra resolver e ele já está no lugar
	if rot_card and u.skill_cd[2] <= 0.0 and _in_range(u) and not in_danger and stacks.is_empty() \
			and (goal == null or u.position.distance_to(goal) < 0.3):
		if use_skill(u, 2, true):
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
	# Guarda: aperta a defesa no Esmagar, como você faria. O Paladino solta a Mitigação no fim do cast;
	# a Gothic Nurse espera o último instante, porque a janela do Blood Taste é de meio segundo.
	if u.tank and Knowledge.has(u.hero, "mitigate") and buster != null and buster["target"] == u and buster["t"] <= (0.35 if u.key == "nurse" else 1.2):
		use_skill(u, 1, true)
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
		var score := u.hp / u.max_hp - (0.2 if u.idx == 0 else 0.0)
		if score < best_score:
			best_score = score
			best = u
	return best


## Tenta usar a habilidade. Com cast, só começa a conjurar; o efeito sai em _resolve_skill.
func use_skill(u: Unit, slot: int, by_ai := false, forced: Unit = null) -> bool:
	var list: Array = SKILLS[u.key]
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
		"Cura":
			var ht := _heal_target()
			# na sua mão, o alvo escolhido no card tem prioridade
			if not by_ai and sel >= 0 and units[sel].alive and units[sel].hp < units[sel].max_hp:
				ht = units[sel]
			if forced != null:
				ht = forced
			if ht == null:
				return false
			u.cast_target = ht
		"Escudo":
			# no alvo focado; sem foco, em quem o boss está batendo
			var st: Unit = target if target != null else u
			if not by_ai and sel >= 0 and units[sel].alive:
				st = units[sel]
			if forced != null:
				st = forced
			u.cast_target = st
		"Reviver":
			var dead: Unit = null
			for o in units:
				if not o.alive and (dead == null or o.idx == 0):
					dead = o
			if not by_ai and sel >= 0 and not units[sel].alive:
				dead = units[sel]
			if dead == null:
				return false
			u.cast_target = dead

	if sk.has("cast"):
		var cast: float = sk["cast"]
		# Golpe Lapidado: a Maga conjura o golpe forte mais rápido
		if slot == 2 and u.key == "maga" and Knowledge.has(u.hero, "burst"):
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
	var sk: Dictionary = SKILLS[u.key][slot]
	if not (sk.has("cast") and sk["cast"] < LOCKED_CAST):
		u.skill_cd[slot] = sk["cd"] * (1.15 if by_ai else 1.0)
	match sk["name"]:
		"Mitigação":
			u.guard_t = GUARD_TIME
			_burst(u.position, Color(0.3, 0.9, 1.0), 2.2)
		"Blood Taste":
			# a vida vai a 160% por meio segundo; quando acaba, volta ao que era (ver _end_taste)
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
		"Escudo":
			var st: Unit = u.cast_target
			if st == null or not st.alive:
				st = u
			st.shield_hp = st.max_hp * SHIELD_RATIO
			st.shield_t = SHIELD_TIME
			u.enmity += st.shield_hp * HEAL_ENMITY * 0.5
			_beam(u.position, st.position, Color(0.45, 0.9, 1.0, 0.95), 0.3)
			_burst(st.position, Color(0.45, 0.9, 1.0), 2.2)
		"Cura em Área":
			var each := (HEAL_AI if by_ai else HEAL_PLAYER) * 0.5
			_burst(u.position, Color(0.4, 1.0, 0.6), AOE_HEAL_R)
			for o in units:
				if o.alive and o.position.distance_to(u.position) <= AOE_HEAL_R and o.hp < o.max_hp:
					o.hp = minf(o.max_hp, o.hp + each)
					u.enmity += each * HEAL_ENMITY
					_burst(o.position, Color(0.4, 1.0, 0.6), 1.4)
					_popup(int(each), Color(0.5, 1.0, 0.65), 56, o.position + Vector3(0, 2.6, 0), "+")
		"Bora Biscoitar":
			_provoke(u, by_ai)
		"Cura":
			var ht: Unit = u.cast_target
			if ht == null or not ht.alive:
				ht = _heal_target()
			if ht == null:
				return
			var amount := HEAL_AI if by_ai else HEAL_PLAYER
			# socorreu na mão alguém com pouca vida: conta pra maestria do Instinto
			if not by_ai and ht.hp / ht.max_hp < Knowledge.LOW_HP:
				_master("heal")
			ht.hp = minf(ht.max_hp, ht.hp + amount)
			u.enmity += amount * HEAL_ENMITY
			_beam(u.position, ht.position, Color(0.5, 1.0, 0.65, 0.95), 0.3)
			_burst(ht.position, Color(0.4, 1.0, 0.6), 1.8)
			_popup(int(amount), Color(0.5, 1.0, 0.65), 64, ht.position + Vector3(0, 2.6, 0), "+")
		"Reviver":
			var dead: Unit = u.cast_target
			if dead == null or dead.alive:
				return
			dead.revive(0.5)
			dead.weak_t = WEAK_TIME  # voltou no susto: metade do dano por um tempo
			_spawn_cards(dead)
			_beam(u.position, dead.position, Color(1.0, 0.95, 0.6, 0.95), 0.4)
			_burst(dead.position, Color(1.0, 0.95, 0.6), 3.0)
			hud.toast(dead.unit_name + " voltou", 2.0)
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
			if slot == 2 and Knowledge.has(u.hero, "burst"):
				amount *= 1.3 if u.key == "assassina" else 1.15
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
		"healer":
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

## Golpe pesado só no alvo 1. Não dá pra desviar: é a defesa da tank (Mitigação ou Blood Taste) que salva.
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
	var dmg := amount * _dmg_mult()
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
	if u.taste_t > 0.0 and dmg > 0.0:
		u.taste_hit = true  # golpe durante o Blood Taste = parry perfeito
	if u.guard_t > 0.0:
		dmg *= MITIGATION
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
