class_name Knowledge
## O "deck" de cada personagem. Fica em variáveis estáticas pra sobreviver ao retry.
##
## ROXA   — resolve uma mecânica inteira sozinha. Rara: poucas cópias pra party toda.
## AMARELA — comportamento básico já pronto.
## BRANCA — em branco: você monta "QUANDO x → FAZ y" com as peças que descobriu lutando.

const PURPLE_SLOTS := 1
const YELLOW_SLOTS := 4
const WHITE_SLOTS := 3
## Quantas cópias da Marca Elemental a party tem no total. Uma pra cada herói:
## o boss de fusão mistura elementos com as outras mecânicas, e três brancas não dão conta de tudo.
const PURPLE_COPIES := 4

const PURPLE_NAME := "Marca Elemental"
## Roxas: "mark" resolve a mecânica elemental; "dps" é a rotação otimizada do personagem.
## A de DPS é de cada herói: você libera jogando bem com ele, e aí a IA dele bate mais forte.
const PURPLE := {"mark": "Marca Elemental", "dps": "Rotação"}
const PURPLE_ORDER := ["mark", "dps"]
## Texto que aparece ao passar o mouse na carta, no menu.
const PURPLE_DESC := {
	"mark": "Resolve a Marca Elemental sozinho: zona oposta, par e abrigo.",
	"dps": "Bate mais forte. Assassina e Maga soltam o golpe de 20 s sempre que dá.",
}
const YELLOW_DESC := {
	"dodge": "Sai dos ataques vermelhos.",
	"instinct": "Cura quem está com pouca vida.",
	"provoke": "Usa Bora Biscoitar quando o boss larga dele.",
	"safe_cast": "Não conjura em cima de ataque vermelho.",
	"spread": "No círculo roxo, corre pro próprio canto.",
}
## DPS que você precisa segurar por DPS_WINDOW segundos seguidos controlando o herói
## (uns 60% do que a classe rende com a rotação perfeita, pra sobrar folga pros desvios).
const DPS_GOAL := {"tank": 14.0, "healer": 7.0, "assassina": 40.0, "maga": 30.0}
const DPS_WINDOW := 20

## Um único desvio cobre todos os avisos vermelhos. Vem de fábrica, já equipado em todo mundo.
const YELLOW := {
	"dodge": "Desvio",
	"instinct": "Instinto",
	"provoke": "Biscoiteiro",
	"safe_cast": "Cautela",
	"spread": "Dispersão",
}
## Dispersão: no círculo roxo cada um corre pro próprio canto da arena.
## A party aprende quando você resolve um círculo roxo na mão sem ninguém te acertar.
const YELLOW_ORDER := ["dodge", "spread", "instinct", "provoke", "safe_cast"]
## Instinto: reage a pouca vida. O Healer cura quem está mal (ele mesmo primeiro).
## A party aprende quando alguém fica por um fio.
## Biscoiteiro: o Tank usa o Bora Biscoitar sozinho sempre que o boss não está nele
## (por exemplo depois de morrer e ser revivido). Aprende quando você recupera o aggro na mão.
## Cautela: Maga e Healer não conjuram em cima de ataque vermelho. Sem ela, terminam o cast
## antes de sair da área. A party aprende quando você desvia na mão jogando de Maga ou Healer.
const YELLOW_ONLY := {"instinct": ["healer"], "provoke": ["tank"], "safe_cast": ["healer", "maga"]}
const LOW_HP := 0.5


static func yellow_for(unit_key: String) -> Array:
	var out: Array = []
	for id in YELLOW_ORDER:
		if not YELLOW_ONLY.has(id) or YELLOW_ONLY[id].has(unit_key):
			out.append(id)
	return out

const TRIGGERS := {
	"stack": "um círculo laranja",
	"stack2": "dois círculos laranjas",
	"buster": "o boss preparar Esmagar",
	"got_element": "receber um elemento",
	"zones_done": "a Sobrecarga acabar",
	"cata": "o Cataclismo começar",
}
const TRIGGER_ORDER := ["stack", "stack2", "buster", "got_element", "zones_done", "cata"]

const ACTIONS := {
	"to_marked": "juntar com o marcado",
	"pair_up": "fazer dupla",
	"mitigate": "usar Mitigação",
	"zone_opp": "ir pra zona oposta",
	"zone_same": "ir pra zona igual",
	"partner": "achar o elemento oposto",
	"shelter": "ir pro abrigo",
	"center": "ir pro centro",
	"stay": "ficar parado",
}
const ACTION_ORDER := ["to_marked", "pair_up", "mitigate", "zone_opp", "zone_same", "partner", "shelter", "center", "stay"]

## Cada QUANDO só oferece os FAZ que fazem sentido pra ele.
const COMPAT := {
	"stack": ["to_marked", "center", "stay"],
	"stack2": ["pair_up", "to_marked", "center", "stay"],
	"buster": ["mitigate"],
	"got_element": ["zone_opp", "zone_same", "center", "stay"],
	"zones_done": ["partner", "center", "stay"],
	"cata": ["shelter", "partner", "center", "stay"],
}
## Peças exclusivas de uma classe (a Mitigação é do Tank, e só ele reage ao Esmagar).
const ONLY := {"buster": "tank", "mitigate": "tank"}


static func triggers_for(unit_key: String) -> Array:
	var out: Array = []
	for id in TRIGGER_ORDER:
		if not ONLY.has(id) or ONLY[id] == unit_key:
			out.append(id)
	return out


static func actions_for(trigger: String, unit_key: String) -> Array:
	var out: Array = []
	for id in COMPAT.get(trigger, []):
		if not ONLY.has(id) or ONLY[id] == unit_key:
			out.append(id)
	return out


static var triggers_known := {}
static var actions_known := {"center": true, "stay": true}
static var purple_known := false
static var dps_known := {}  # chave do herói -> true
static var yellow_known := {"dodge": true}
## Quem você controla quando a luta começa (escolhido no menu).
static var start_hero := 2
static var boss := 0
static var boss_unlocked := 0
static var decks := {}
static var attempts := 1


static func deck(i: int) -> Dictionary:
	if not decks.has(i):
		var whites: Array = []
		for n in WHITE_SLOTS:
			whites.append({"t": "", "a": ""})
		decks[i] = {"purple": "", "yellow": ["dodge"], "white": whites}
	return decks[i]


static func has_yellow(i: int, id: String) -> bool:
	var y: Array = deck(i)["yellow"]
	return y.has(id)


static func toggle_yellow(i: int, id: String) -> void:
	var y: Array = deck(i)["yellow"]
	if y.has(id):
		y.erase(id)
	elif y.size() < YELLOW_SLOTS:
		y.append(id)


static func purple_left() -> int:
	var used := 0
	for i in decks:
		if decks[i]["purple"] == "mark":
			used += 1
	return PURPLE_COPIES - used


static func purple_can(i: int, id: String, unit_key: String) -> bool:
	if id == "mark":
		return purple_known and (deck(i)["purple"] == "mark" or purple_left() > 0)
	return dps_known.has(unit_key)


## Um slot roxo por herói: equipar uma tira a outra.
static func toggle_purple(i: int, id: String, unit_key: String) -> void:
	var d := deck(i)
	if d["purple"] == id:
		d["purple"] = ""
	elif purple_can(i, id, unit_key):
		d["purple"] = id


static func set_white(i: int, slot: int, trigger: String, action: String) -> void:
	deck(i)["white"][slot] = {"t": trigger, "a": action}
