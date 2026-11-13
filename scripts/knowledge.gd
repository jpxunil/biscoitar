class_name Knowledge
## Tudo que o jogador carrega entre lutas: cartas, baralho de cada herói, maestria,
## dinheiro e tickets. Fica em variáveis estáticas (sobrevive ao retry) e é salvo em disco.
##
## Carta = uma ação única. Três raridades mais os itens:
##   BRANCA (comum)  — resolve uma mecânica ou dá um bônus pequeno.
##   DOURADA (rara)  — comportamento de classe ou bônus forte.
##   ROXA (épica)    — as mais fortes. Na loja só saem com ticket (ranking SSS).
##   ITEM            — um por herói ("item on hold").
##
## Carta de mecânica não cai por sorte nem na primeira vez: o jogador precisa resolver
## a mecânica certo, na mão, MASTERY_NEED vezes. Aí a carta é liberada e a IA aprende.

const HEROES := [
	{"key": "tank", "name": "Paladino", "role": "Tanque", "color": Color(0.3, 0.5, 1.0), "hp": 160, "tank": true,
		"blurb": "Segura a boss. Mitigação e Bora Biscoitar."},
	{"key": "healer", "name": "Healer", "role": "Curandeira", "color": Color(0.4, 0.95, 0.55), "hp": 90,
		"blurb": "Cura, revive e protege com escudo."},
	{"key": "assassina", "name": "Assassina", "role": "DPS corpo a corpo", "color": Color(0.78, 0.38, 1.0), "hp": 100,
		"blurb": "O maior dano, colada na boss."},
	{"key": "maga", "name": "Maga", "role": "DPS à distância", "color": Color(1.0, 0.72, 0.25), "hp": 90,
		"blurb": "Dano de longe, com cast."},
	# Segunda tank: entra na party no lugar do Paladino (ver `tank_pick`).
	{"key": "nurse", "name": "Gothic Nurse", "role": "Tanque de Sangue", "color": Color(0.36, 0.4, 0.95), "hp": 112, "tank": true,
		"blurb": "Rouba o sangue da boss. Pouca vida, parry e Blood Party."},
]

## Mesma ordem de BOSSES em game.gd.
const BOSS_INFO := [
	{"name": "BISCOITO-KUN", "mini": true, "blurb": "Mini boss. Fraquinho, bom pra juntar moedas."},
	{"name": "MINI-CHAN", "mini": false, "blurb": "Desvios, círculos e um grande final."},
	{"name": "PROTÓTIPO-CHAN", "mini": false, "blurb": "Marca Elemental, zonas e Cataclismo."},
	{"name": "FUSÃO-CHAN", "mini": false, "blurb": "Tudo junto e mais rápido."},
]

const KINDS := ["purple", "gold", "white", "item"]
const SLOTS := {"purple": 2, "gold": 3, "white": 4, "item": 1}
const KIND_NAME := {"purple": "Épica", "gold": "Rara", "white": "Comum", "item": "Item"}
const KIND_COLOR := {
	"purple": Color(0.62, 0.36, 1.0), "gold": Color(1.0, 0.8, 0.25),
	"white": Color(0.97, 0.96, 0.9), "item": Color(0.3, 0.9, 1.0),
}
const CATS := ["attack", "defense", "utility", "special"]
const CAT_NAME := {"attack": "Ataque", "defense": "Defesa", "utility": "Utilidade", "special": "Especial"}

const MASTERY_NEED := 3

## who = classes que podem usar (sem a chave = todas) · start = já vem com o jogador ·
## mastery = liberada pela maestria daquela mecânica · price = à venda por moedas ·
## ticket = à venda por tickets · earn = liberada por um feito (texto explica).
const CARDS := {
	# ---- brancas
	"dodge": {"name": "Desvio", "kind": "white", "cat": "defense", "start": true,
		"desc": "Sai dos ataques vermelhos."},
	"stack": {"name": "Laranja Junto", "kind": "white", "cat": "utility", "mastery": "stack",
		"desc": "Corre pro círculo laranja pra dividir o dano com a party."},
	"pair": {"name": "Dupla Laranja", "kind": "white", "cat": "utility", "mastery": "pair",
		"desc": "Com dois círculos laranjas, forma dupla: dois em cada."},
	"spread": {"name": "Dispersão", "kind": "white", "cat": "utility", "mastery": "spread",
		"desc": "No círculo roxo, corre pro próprio canto da arena."},
	"link": {"name": "Quebra-Elo", "kind": "white", "cat": "utility", "mastery": "link",
		"desc": "Preso no Elo Perdido, se afasta do par até a corrente quebrar."},
	"zone": {"name": "Zona Oposta", "kind": "white", "cat": "utility", "mastery": "zone",
		"desc": "Com um elemento, vai pra zona do elemento oposto."},
	"partner": {"name": "Par Elemental", "kind": "white", "cat": "utility", "mastery": "partner",
		"desc": "No Cataclismo, acha quem tem o elemento oposto."},
	"shelter": {"name": "Abrigo", "kind": "white", "cat": "defense", "mastery": "shelter",
		"desc": "No Cataclismo, sem elemento, corre pro abrigo."},
	"safe_cast": {"name": "Cautela", "kind": "white", "cat": "defense", "who": ["healer", "maga"], "mastery": "cast",
		"desc": "Não conjura em cima de ataque vermelho."},
	"sharpen": {"name": "Lâmina Afiada", "kind": "white", "cat": "attack", "price": 100,
		"desc": "+8% de dano."},
	"plate": {"name": "Couraça", "kind": "white", "cat": "defense", "price": 100,
		"desc": "Recebe 10% menos dano."},
	"breath": {"name": "Fôlego", "kind": "white", "cat": "utility", "earn": "Vença o BISCOITO-KUN.",
		"desc": "Recupera 1 de vida por segundo."},
	# ---- douradas
	"mitigate": {"name": "Guarda", "kind": "gold", "cat": "defense", "who": ["tank", "nurse"], "mastery": "buster",
		"desc": "Usa a defesa quando a boss solta o Esmagar."},
	"provoke": {"name": "Biscoiteiro", "kind": "gold", "cat": "utility", "who": ["tank", "nurse"], "mastery": "provoke",
		"desc": "Provoca sempre que a boss larga do tank."},
	"instinct": {"name": "Instinto", "kind": "gold", "cat": "utility", "who": ["healer"], "mastery": "heal",
		"desc": "Cura quem está com pouca vida."},
	"eshield": {"name": "Escudo de Emergência", "kind": "gold", "cat": "defense", "who": ["healer"], "price": 220,
		"desc": "Quando a boss conjura ESMAGAR, põe Escudo no Tank antes do golpe."},
	"burst": {"name": "Golpe Lapidado", "kind": "gold", "cat": "attack", "who": ["assassina", "maga"], "price": 260,
		"desc": "Golpe forte melhor. Assassina: +30% de dano. Maga: conjura 0,7 s mais rápido e +15%."},
	"executor": {"name": "Carrasco", "kind": "gold", "cat": "attack", "price": 200,
		"desc": "+25% de dano com a boss abaixo de 30% de vida."},
	"secondskin": {"name": "Segunda Pele", "kind": "gold", "cat": "defense", "price": 180,
		"desc": "Começa a luta, e volta de um reviver, com um escudo de 30."},
	"final": {"name": "Protocolo Final", "kind": "gold", "cat": "special", "mastery": "final",
		"desc": "No grande final: lê a mão que a boss levanta, vai pro seu quadrado e ocupa a sua torre."},
	"spark": {"name": "Faísca de Limite", "kind": "gold", "cat": "utility", "price": 200,
		"desc": "O dano dele enche o Limit Break 50% mais rápido."},
	# ---- roxas
	"dps": {"name": "Rotação", "kind": "purple", "cat": "attack", "earn": "Segure um DPS bom com o herói por 20 s.",
		"desc": "Bate mais forte. Assassina e Maga soltam o golpe de 20 s sempre que dá."},
	"mark": {"name": "Marca Elemental", "kind": "purple", "cat": "special", "earn": "Passe pelo Cataclismo com a party inteira viva.",
		"desc": "Resolve a Marca Elemental sozinho: zona oposta, par e abrigo."},
	"revive": {"name": "Reviver Automático", "kind": "purple", "cat": "special", "who": ["healer"], "ticket": 1,
		"desc": "Quando alguém morre, revive sozinha assim que for seguro."},
	"phoenix": {"name": "Fênix", "kind": "purple", "cat": "special", "ticket": 1,
		"desc": "Uma vez por luta, em vez de morrer, volta com metade da vida."},
	"overdrive": {"name": "Sobrecarga", "kind": "purple", "cat": "attack", "ticket": 1,
		"desc": "+20% de dano, mas recebe 15% a mais."},
	# ---- itens
	"potion": {"name": "Poção", "kind": "item", "cat": "utility", "price": 80,
		"desc": "Uma vez por luta, cura 50 quando a vida cai abaixo de 30%."},
	"cookie": {"name": "Biscoito da Sorte", "kind": "item", "cat": "special", "price": 150,
		"desc": "O Limit Break começa a luta com 25% de carga."},
}

## Mecânicas com maestria: o que o jogador precisa fazer na mão, e a carta que isso libera.
const MASTERY := {
	"stack": {"name": "Círculo laranja", "card": "stack"},
	"pair": {"name": "Duplas laranjas", "card": "pair"},
	"spread": {"name": "Círculo roxo", "card": "spread"},
	"link": {"name": "Elo Perdido", "card": "link"},
	"final": {"name": "Grande final (mão e torres)", "card": "final"},
	"zone": {"name": "Zonas elementais", "card": "zone"},
	"partner": {"name": "Par no Cataclismo", "card": "partner"},
	"shelter": {"name": "Abrigo no Cataclismo", "card": "shelter"},
	"cast": {"name": "Cast seguro", "card": "safe_cast"},
	"buster": {"name": "Esmagar", "card": "mitigate"},
	"provoke": {"name": "Recuperar a boss", "card": "provoke"},
	"heal": {"name": "Socorro", "card": "instinct"},
}

const RANKS := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
## Nota mínima (0 a 100) de cada ranking, e as moedas que ele paga num boss normal.
const RANK_MIN := [0, 20, 32, 44, 56, 68, 78, 87, 94]
const RANK_COINS := [20, 40, 60, 90, 120, 160, 220, 300, 400]
const MINI_REWARD := 0.4
const LOW_HP := 0.5
## DPS que você precisa segurar por DPS_WINDOW segundos seguidos controlando o herói pra liberar a Rotação.
const DPS_GOAL := {"tank": 14.0, "nurse": 14.0, "healer": 7.0, "assassina": 40.0, "maga": 30.0}
const DPS_WINDOW := 20
const SAVE_PATH := "user://save.json"

static var owned := {"dodge": true}
static var decks := {}
static var mastery := {}
static var money := 0
static var tickets := 0
static var shop_unlocked := false
## Rotação é de cada herói: chave do herói -> true.
static var dps_known := {}
## Melhor ranking por boss (índice -> índice em RANKS). Boss vencido libera o próximo.
static var best_rank := {}
## Quem você controla quando a luta começa, e a luta escolhida.
static var start_hero := 2
## Qual tank está na party: índice em HEROES (0 = Paladino, 4 = Gothic Nurse). A party tem sempre 4.
static var tank_pick := 0
## Trocar de tank recarrega a cena; com isso ligado a luta começa sozinha depois do recarregamento.
static var autostart := false
static var boss := 1
static var attempts := 1
## Em que tela o menu abre depois de recarregar a cena: "title", "bosses", "cards", "shop".
static var screen := "title"
## Testes automáticos desligam o save pra não ler nem sujar o progresso do jogador.
static var persist := true
static var _loaded := false


# ---------------------------------------------------------------- baralhos

static func deck(i: int) -> Dictionary:
	if not decks.has(i):
		var d := {}
		for kind in KINDS:
			var arr: Array = []
			for n in SLOTS[kind]:
				arr.append("")
			d[kind] = arr
		decks[i] = d
		# o que o jogador já tem de fábrica entra equipado
		for id in owned:
			if CARDS[id].get("start", false):
				equip(i, id)
	return decks[i]


## Lugar do herói na party (0 = tank, seja qual for), e o herói que ocupa um lugar.
static func slot_of(hero: int) -> int:
	return 0 if HEROES[hero].get("tank", false) else hero


static func hero_at(slot: int) -> int:
	return tank_pick if slot == 0 else slot


static func is_tank(hero: int) -> bool:
	return HEROES[hero].get("tank", false)


static func kind_of(id: String) -> String:
	return CARDS[id]["kind"]


static func has(i: int, id: String) -> bool:
	if not CARDS.has(id):
		return false
	var arr: Array = deck(i)[CARDS[id]["kind"]]
	return arr.has(id)


## A classe do herói i pode usar essa carta?
static func usable(i: int, id: String) -> bool:
	var c: Dictionary = CARDS[id]
	return not c.has("who") or c["who"].has(HEROES[i]["key"])


## O jogador tem essa carta pro herói i? (a Rotação é conquistada herói por herói)
static func is_owned_by(i: int, id: String) -> bool:
	if id == "dps":
		return dps_known.has(HEROES[i]["key"])
	return owned.has(id)


## Equipa no slot pedido (ou no primeiro livre). Se o slot estava ocupado, a carta antiga volta pro inventário.
static func equip(i: int, id: String, slot := -1) -> bool:
	if not is_owned_by(i, id) or not usable(i, id):
		return false
	var arr: Array = deck(i)[CARDS[id]["kind"]]
	var at := arr.find(id)
	if slot < 0:
		if at >= 0:
			return true
		slot = arr.find("")
		if slot < 0:
			return false
	if slot >= arr.size():
		return false
	if at >= 0:
		arr[at] = ""
	# cópia única: equipar aqui tira de quem estava com ela
	if is_unique(id):
		for j in HEROES.size():
			if j != i:
				unequip(j, id)
	arr[slot] = id
	return true


static func unequip(i: int, id: String) -> void:
	var arr: Array = deck(i)[CARDS[id]["kind"]]
	var at := arr.find(id)
	if at >= 0:
		arr[at] = ""


## Cópia única: itens e tudo que se compra na loja (moedas ou ticket). Você tem UMA, e só um herói
## usa por vez. As cartas conquistadas jogando (maestria, Rotação, etc.) são conhecimento: valem pra todos.
static func is_unique(id: String) -> bool:
	var c: Dictionary = CARDS[id]
	return c["kind"] == "item" or c.has("price") or c.has("ticket")


## Quem está com a carta de cópia única (índice do herói), ou -1 se ela está solta.
static func holder(id: String) -> int:
	var kind: String = CARDS[id]["kind"]
	for j in HEROES.size():
		if deck(j)[kind].has(id):
			return j
	return -1


## Cartas que o herói i pode usar e que não estão equipadas nele, da mais rara pra mais comum.
static func inventory(i: int) -> Array:
	var out: Array = []
	for kind in KINDS:
		for id in CARDS:
			if CARDS[id]["kind"] == kind and is_owned_by(i, id) and usable(i, id) and not has(i, id):
				out.append(id)
	return out


static func grant(id: String) -> bool:
	if owned.has(id):
		return false
	owned[id] = true
	save()
	return true


# ---------------------------------------------------------------- maestria

static func mastery_of(key: String) -> int:
	return mini(int(mastery.get(key, 0)), MASTERY_NEED)


## Registra uma resolução correta. Devolve true se foi a que liberou a carta.
static func add_mastery(key: String) -> bool:
	if not MASTERY.has(key) or mastery_of(key) >= MASTERY_NEED:
		return false
	mastery[key] = mastery_of(key) + 1
	var done := mastery_of(key) >= MASTERY_NEED
	if done:
		owned[MASTERY[key]["card"]] = true
	save()
	return done


## Chave de maestria que libera a carta, ou "" se ela vem de outro jeito.
static func mastery_key(id: String) -> String:
	return CARDS[id].get("mastery", "")


# ---------------------------------------------------------------- loja

static func shop_list(cat := "") -> Array:
	var out: Array = []
	for kind in KINDS:
		for id in CARDS:
			var c: Dictionary = CARDS[id]
			if c["kind"] == kind and (c.has("price") or c.has("ticket")) and (cat == "" or c["cat"] == cat):
				out.append(id)
	return out


static func can_buy(id: String) -> bool:
	var c: Dictionary = CARDS[id]
	if owned.has(id):
		return false
	if c.has("ticket"):
		return tickets >= int(c["ticket"])
	return c.has("price") and money >= int(c["price"])


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var c: Dictionary = CARDS[id]
	if c.has("ticket"):
		tickets -= int(c["ticket"])
	else:
		money -= int(c["price"])
	owned[id] = true
	save()
	return true


# ---------------------------------------------------------------- bosses e ranking

static func boss_open(i: int) -> bool:
	# o mini boss e o primeiro boss estão sempre abertos; cada vitória abre o seguinte
	return i <= 1 or best_rank.has(i - 1)


static func rank_for(score: float) -> int:
	var r := 0
	for k in RANKS.size():
		if score >= RANK_MIN[k]:
			r = k
	return r


## Paga a vitória. Devolve {"coins", "ticket", "card"} com o que o jogador ganhou.
static func reward(boss_i: int, rank: int) -> Dictionary:
	var mini_boss: bool = BOSS_INFO[boss_i]["mini"]
	var coins := int(RANK_COINS[rank] * (MINI_REWARD if mini_boss else 1.0))
	var out := {"coins": coins, "ticket": 0, "card": ""}
	money += coins
	if rank == RANKS.size() - 1 and not mini_boss:
		tickets += 1
		out["ticket"] = 1
	if mini_boss and not owned.has("breath"):
		owned["breath"] = true
		out["card"] = "breath"
	if not best_rank.has(boss_i) or int(best_rank[boss_i]) < rank:
		best_rank[boss_i] = rank
	shop_unlocked = true
	save()
	return out


# ---------------------------------------------------------------- save

## Tutorial (scripts/tutorial.gd): o jogador treina com um conjunto de cartas só do tutorial.
## enter_sandbox guarda o progresso de verdade e zera as cartas; leave_sandbox devolve tudo.
## Enquanto dura, nada é gravado em disco.
static var sandbox := false
static var _kept := {}


static func enter_sandbox() -> void:
	if sandbox:
		return
	_kept = {"owned": owned, "decks": decks, "mastery": mastery, "dps": dps_known, "hero": start_hero, "tank": tank_pick}
	sandbox = true
	owned = {}
	decks = {}
	mastery = {}
	dps_known = {}


static func leave_sandbox() -> void:
	if not sandbox:
		return
	owned = _kept["owned"]
	decks = _kept["decks"]
	mastery = _kept["mastery"]
	dps_known = _kept["dps"]
	start_hero = _kept["hero"]
	tank_pick = _kept["tank"]
	_kept = {}
	sandbox = false


static func save() -> void:
	if not persist or sandbox:
		return
	var data := {
		"owned": owned.keys(), "decks": {}, "mastery": mastery, "money": money, "tickets": tickets,
		"shop": shop_unlocked, "dps": dps_known.keys(), "rank": {}, "hero": start_hero, "boss": boss, "tank": tank_pick,
	}
	for i in decks:
		data["decks"][str(i)] = decks[i]
	for b in best_rank:
		data["rank"][str(b)] = best_rank[b]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


static func load_save() -> void:
	if _loaded or not persist:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary):
		return
	for id in parsed.get("owned", []):
		if CARDS.has(id):
			owned[id] = true
	for k in parsed.get("dps", []):
		dps_known[k] = true
	for key in parsed.get("mastery", {}):
		if MASTERY.has(key):
			mastery[key] = int(parsed["mastery"][key])
	money = int(parsed.get("money", 0))
	tickets = int(parsed.get("tickets", 0))
	shop_unlocked = bool(parsed.get("shop", false))
	start_hero = clampi(int(parsed.get("hero", 2)), 0, HEROES.size() - 1)
	tank_pick = int(parsed.get("tank", 0))
	if tank_pick < 0 or tank_pick >= HEROES.size() or not is_tank(tank_pick):
		tank_pick = 0
	for b in parsed.get("rank", {}):
		best_rank[int(b)] = int(parsed["rank"][b])
	boss = clampi(int(parsed.get("boss", 1)), 0, BOSS_INFO.size() - 1)
	if not boss_open(boss):
		boss = 1
	# baralhos: só entra o que ainda existe, é do jogador e cabe no slot
	var saved: Dictionary = parsed.get("decks", {})
	for si in saved:
		var i := int(si)
		if i < 0 or i >= HEROES.size():
			continue
		var d := deck(i)
		for kind in KINDS:
			for n in SLOTS[kind]:
				d[kind][n] = ""
		for kind in KINDS:
			var arr: Array = saved[si].get(kind, [])
			for n in mini(arr.size(), SLOTS[kind]):
				var id := str(arr[n])
				if id != "" and CARDS.has(id) and CARDS[id]["kind"] == kind and is_owned_by(i, id) and usable(i, id):
					d[kind][n] = id
	# saves antigos podem ter a mesma carta de cópia única em mais de um herói: fica com o primeiro
	var held := {}
	for i in HEROES.size():
		for kind in KINDS:
			var arr: Array = deck(i)[kind]
			for n in arr.size():
				if arr[n] == "" or not is_unique(arr[n]):
					continue
				if held.has(arr[n]):
					arr[n] = ""
				else:
					held[arr[n]] = true
