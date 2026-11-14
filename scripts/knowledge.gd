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
		"blurb": "O mais fácil de jogar. Escudo enorme, Égide e Muralha da Fé."},
	# Soulflame (era a Healer; a chave interna continua "healer").
	{"key": "healer", "name": "Soulflame", "role": "Curandeira", "color": Color(0.4, 0.95, 0.55), "hp": 90,
		"blurb": "Chama vital: cura direta, fogueira que cura, escudo e a fênix do Renascimento."},
	{"key": "assassina", "name": "Assassina", "role": "DPS corpo a corpo", "color": Color(0.78, 0.38, 1.0), "hp": 100,
		"blurb": "Rápida e simples: três golpes de um lado da boss, três do outro, sem parar."},
	{"key": "maga", "name": "Maga", "role": "DPS à distância", "color": Color(1.0, 0.72, 0.25), "hp": 90,
		"blurb": "Atiradora arcana: junta balas Rainbow coloridas e escolhe quando descarregar."},
	# Segunda tank: entra na party no lugar do Paladino (ver `tank_pick`).
	# Malpractice (era a Gothic Nurse; a chave interna continua "nurse" por causa do save e da arte).
	{"key": "nurse", "name": "Malpractice", "role": "Tanque de Sangue", "color": Color(0.36, 0.4, 0.95), "hp": 80, "tank": true,
		"blurb": "De papel: sangra a cada golpe. Vive de parry e bate mais forte quase morta."},
	# Classes novas (design/classes-v2.md).
	{"key": "burner", "name": "Soulburner", "role": "DPS à distância", "color": Color(0.12, 0.82, 0.78), "hp": 90,
		"blurb": "Anjo do fogo: marca o inimigo e estoura a marca com uma lança na hora certa."},
	{"key": "ringstar", "name": "Ringstar", "role": "DPS corpo a corpo", "color": Color(1.0, 0.45, 0.75), "hp": 110,
		"blurb": "Boxeadora estelar: Jab, Direto, Gancho. O botão que brilha é o próximo."},
	{"key": "apothecary", "name": "Apotecário", "role": "Curandeiro químico", "color": Color(0.35, 0.8, 0.66), "hp": 90,
		"blurb": "Healer que bate: mantém a Decomposição, junta Vestígios e escolhe entre curar forte ou envenenar."},
	{"key": "sleepwalker", "name": "Sleepwalker", "role": "DPS à distância", "color": Color(0.55, 0.58, 1.0), "hp": 85,
		"blurb": "O mais difícil: prepara acordado em janelas de 1 s e descarrega dormindo, imóvel."},
	{"key": "valsa", "name": "Valsa", "role": "Suporte dançarina", "color": Color(0.74, 0.62, 1.0), "hp": 95,
		"blurb": "Um, dois, três e gira: cada Giro abre a saia, e quem dança dentro dela bate mais forte."},
]

## Mesma ordem de BOSSES em game.gd.
const BOSS_INFO := [
	{"name": "BISCOITO-KUN", "mini": true, "blurb": "Mini boss. Fraquinho, bom pra juntar moedas."},
	{"name": "MINI-CHAN", "mini": false, "blurb": "Desvios, círculos e um grande final."},
	{"name": "PROTÓTIPO-CHAN", "mini": false, "blurb": "Marca Elemental, zonas e Cataclismo."},
	{"name": "FUSÃO-CHAN", "mini": false, "blurb": "Tudo junto e mais rápido."},
	{"name": "TROVÃO-KUN", "mini": true, "blurb": "Mini boss. Salta, solta faíscas e gira um ventilador de raios: pule!"},
	# "open": já vem aberta, sem precisar vencer a luta anterior
	{"name": "MEL-CHAN", "mini": false, "open": true, "blurb": "Desvio puro: pule o mel, fuja dos ferrões e não junte 4 corações."},
]

## TRÊS COISAS DIFERENTES, que não competem entre si:
##   APRENDIZADO — carta que ensina a party a resolver algo. Fica no baralho enquanto o herói aprende
##                 (progress, 0..100); em 100 vira PASSIVA dele pra sempre e sai do slot.
##   CRITÉRIO    — carta de preferência (PREF_IDS): uma decisão de como jogar, com custo. Não é
##                 conhecimento, então nunca vira passiva: disputa slot do baralho sempre.
##   EQUIPAMENTO — todo buff de número (GEAR_IDS). Não é carta: vai nos GEAR_SLOTS do herói, na tela
##                 de gear, e é vendido na loja de itens. Os consumíveis (kind "item") seguem no slot
##                 de item do baralho e são vendidos na mesma loja.
const GEAR_IDS := ["sharpen", "plate", "breath", "burst", "executor", "secondskin", "spark", "phoenix", "overdrive",
	"heart", "scope", "boots", "dice"]
const PREF_IDS := ["eshield", "revive"]
const GEAR_SLOTS := 4
## Quanto uma luta vencida e limpa (sem morrer e sem tomar aquela mecânica) rende de aprendizado
## pra carta equipada: três lutas assim e ela vira passiva.
const LEARN_WIN := 34.0
## As mecânicas de cada boss (mesma ordem de BOSS_INFO), pro painel "o que a party sabe".
## Cada entrada é o id de uma carta de aprendizado ou a chave de um conhecimento de KNOW_NAME.
const BOSS_MECHS := [
	["dodge", "stack"],
	["dodge", "stack", "pair", "spread", "link", "mitigate", "final"],
	["dodge", "zone", "partner", "shelter", "mitigate"],
	["dodge", "stack", "spread", "zone", "partner", "shelter", "mitigate"],
	["dodge", "fan", "eye", "mitigate", "stack"],
	["dodge", "fan"],
]
const KNOW_NAME := {"fan": "Pulo no ventilador de raios", "eye": "Olho da tempestade"}
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
	"instinct": {"name": "Instinto", "kind": "gold", "cat": "utility", "who": ["healer", "apothecary"], "mastery": "heal",
		"desc": "Cura quem está com pouca vida."},
	"eshield": {"name": "Escudo de Emergência", "kind": "gold", "cat": "defense", "who": ["healer", "apothecary"], "price": 220,
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
	"dps": {"name": "Rotação", "kind": "purple", "cat": "attack", "earn": "Jogue bem com o herói: DPS bom e rotação limpa por 25 s.",
		"desc": "Consegue fazer uma rotação funcional com um DPS bom: usa as habilidades do próprio kit, na ordem certa, logo que elas voltam."},
	"mark": {"name": "Marca Elemental", "kind": "purple", "cat": "special", "earn": "Passe pelo Cataclismo com a party inteira viva.",
		"desc": "Resolve a Marca Elemental sozinho: zona oposta, par e abrigo."},
	"revive": {"name": "Reviver Automático", "kind": "purple", "cat": "special", "who": ["healer"], "ticket": 1,
		"desc": "Quando alguém morre, revive sozinha assim que for seguro."},
	"phoenix": {"name": "Fênix", "kind": "purple", "cat": "special", "ticket": 1,
		"desc": "Uma vez por luta, em vez de morrer, volta com metade da vida."},
	"overdrive": {"name": "Sobrecarga", "kind": "purple", "cat": "attack", "ticket": 1,
		"desc": "+20% de dano, mas recebe 15% a mais."},
	# ---- equipamentos de atributo (GEAR_IDS): nunca vão no baralho, só nos slots de gear
	"heart": {"name": "Coração de Açúcar", "kind": "white", "cat": "defense", "price": 140,
		"desc": "+20 de vida máxima."},
	"scope": {"name": "Luneta", "kind": "white", "cat": "utility", "price": 140,
		"desc": "+10% de alcance."},
	"boots": {"name": "Botas Leves", "kind": "white", "cat": "utility", "price": 160,
		"desc": "+12% de velocidade de movimento."},
	"dice": {"name": "Dado Viciado", "kind": "gold", "cat": "attack", "price": 240,
		"desc": "25% de chance de acerto crítico: o golpe dá +50% de dano."},
	# ---- itens
	"potion": {"name": "Poção", "kind": "item", "cat": "utility", "price": 80,
		"desc": "Uma vez por luta, cura 50 quando a vida cai abaixo de 30%."},
	"cookie": {"name": "Biscoito da Sorte", "kind": "item", "cat": "special", "price": 150,
		"desc": "O Limit Break começa a luta com 25% de carga."},
}

## Carta ainda não liberada: o nome fica "???" e a tela de cartas mostra, no lugar da descrição,
## uma frase de mistério e uma pista de como ela se consegue. id -> [mistério, pista].
## A pista aponta pro jeito de verdade (maestria da mecânica, loja, ticket, feito), sem dizer com
## todas as letras. Mudou como uma carta é liberada? Mude a pista junto.
const SECRETS := {
	"dodge": ["O primeiro reflexo de quem quer ficar de pé.", "Ninguém entra na arena sem isto."],
	"heart": ["Um doce que bate.", "O ferreiro guarda um desses na vitrine, pra quem quer aguentar mais."],
	"scope": ["Um tubo com vidro nas pontas.", "Na loja de itens, pra quem prefere bater de mais longe."],
	"boots": ["Quase não pesam.", "Na loja de itens: quem calça chega antes em qualquer lugar."],
	"dice": ["Cai sempre do mesmo lado.", "Na loja de itens. De vez em quando, o golpe de quem carrega sai bem mais forte."],
	# maestria: resolver a mecânica certo, na mão, MASTERY_NEED vezes
	"stack": ["Um peso que ninguém aguenta sozinho.",
		"O laranja pesa menos com gente junto. Quem corre pra perto na hora certa, algumas vezes, ensina o caminho."],
	"pair": ["Dois chamados ao mesmo tempo.",
		"Quando o laranja se divide, a conta só fecha com a party bem repartida. Acerte essa conta mais de uma vez."],
	"spread": ["Tem hora em que a companhia é o perigo.",
		"O roxo não gosta de multidão. Dar espaço a todo mundo, vez após vez, vira hábito."],
	"link": ["Uma corrente que só existe de perto.",
		"Certos laços só se desfazem com distância. Quem os rompe com as próprias pernas aprende a saída."],
	"zone": ["Fogo não se apaga com fogo.",
		"Carregar um elemento é saber onde mora o seu contrário. O chão certo, pisado algumas vezes, fica na memória."],
	"partner": ["Ninguém cruza a tempestade sem o seu avesso.",
		"No pior momento de certa luta, alguém carrega o oposto do que você carrega. Ache essa pessoa a tempo."],
	"shelter": ["Quem não carrega nada também quer um teto.",
		"Quando o céu desaba e você está de mãos vazias, existe um lugar feito pra isso. Chegue lá sozinho."],
	"safe_cast": ["A paciência de quem conjura.",
		"Quem vive de palavras longas e ainda escapa ilesa do vermelho, vez após vez, aprende onde não conjurar."],
	"mitigate": ["O golpe mais pesado tem hora marcada.",
		"Quem fica na frente aprende a ler o gesto antes do impacto. Feche-se no instante certo e fique de pé."],
	"provoke": ["A atenção dela é disputada.",
		"Quando ela desvia o olhar de quem deveria apanhar, alguém precisa chamá-la de volta com a própria voz."],
	"instinct": ["Um olho sempre na vida dos outros.",
		"Quem socorre com as próprias mãos alguém por um fio, mais de uma vez, passa a fazer isso sem pensar."],
	"final": ["O último ato tem regras próprias.",
		"Perto do fim, ela levanta uma das mãos, e há pilares esperando dono. Saia ileso desse ato algumas vezes."],
	# feitos
	"breath": ["Até o adversário mais doce deixa algo pra trás.",
		"Algumas recompensas esperam atrás da luta que quase ninguém leva a sério."],
	"dps": ["Cada herói tem um ritmo próprio.",
		"Não basta bater forte: quem não deixa botão parado nem golpe esperando ensina o herói a dançar sozinho."],
	"mark": ["A tempestade respeita quem a cruza inteiro.",
		"Há um cataclismo que cobra um preço de quase todo grupo. Passe por ele sem deixar ninguém pra trás."],
	# loja, por moedas (ela abre depois da primeira vitória)
	"sharpen": ["Um fio a mais na lâmina.", "Nem tudo se conquista suando. Depois da primeira vitória, alguém passa a aceitar moedas."],
	"plate": ["Uma camada entre você e o golpe.", "Tem coisa que não se aprende: se encomenda. Um certo balcão só abre pra quem já venceu."],
	"eshield": ["Proteção que chega um segundo antes.", "Quem cuida dos outros acha isto numa prateleira, não numa arena. Leve moedas."],
	"burst": ["O golpe forte, lapidado até brilhar.", "Não é a boss que guarda isto. É alguém que cobra pelo polimento, e cobra caro."],
	"executor": ["Quem está quase caindo cai mais rápido.", "Certas crueldades têm preço fixo. Procure onde se pesa moeda."],
	"secondskin": ["Você nunca entra de todo desprotegido.", "Uma vendedora guarda peles sobressalentes atrás do balcão."],
	"spark": ["O limite chega cedo pra quem tem pressa.", "Brilha numa vitrine. Vitrines pedem moedas, e só aparecem depois de uma vitória."],
	"potion": ["Um gole guardado pro pior momento.", "Coisa de bolso, comprada, não conquistada. Barata, pra quem já venceu uma vez."],
	"cookie": ["A sorte, em forma de sobremesa.", "Quem vende biscoito também vende sorte. Junte moedas."],
	# loja, por ticket (ranking máximo num boss de verdade)
	"revive": ["Ninguém fica no chão por muito tempo.",
		"A vendedora não troca isto por moedas. Só um papel roxo a convence, e ele é de quem vence sem defeito."],
	"phoenix": ["Cair não precisa ser o fim.",
		"Fica longe do balcão comum. O que abre essa gaveta é raro: é o prêmio de uma luta impecável."],
	"overdrive": ["Mais força do que é prudente carregar.",
		"Moeda nenhuma compra isto. Uma nota perfeita deixa cair outro tipo de pagamento."],
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
const DPS_GOAL := {"tank": 14.0, "nurse": 14.0, "healer": 7.0, "assassina": 40.0, "maga": 30.0, "burner": 26.0, "ringstar": 36.0, "apothecary": 22.0, "sleepwalker": 45.0, "valsa": 24.0}
const DPS_WINDOW := 25
## Saves: SLOT_COUNT arquivos independentes (user://save_1.json ...). Cada um guarda o progresso,
## as cartas e a party daquele save; nada passa de um pro outro. LEGACY_SAVE é o arquivo único de
## antes dos slots: na primeira vez ele vira o save 1.
const SLOT_COUNT := 4
const LEGACY_SAVE := "save.json"
const LAST_SLOT_FILE := "last_slot.txt"
## Party usada quando ainda não existe uma escolhida (testes, cenas abertas sozinhas).
const DEFAULT_PARTY := [0, 1, 2, 3]

## Pasta dos saves. Os testes apontam pra outra pasta pra nunca tocar no progresso do jogador.
static var save_dir := "user://"
## Save ativo (1..SLOT_COUNT). 0 = nenhum escolhido ainda: nada é gravado.
static var slot := 0
## A party do save: quatro heróis (índices em HEROES) quaisquer, na ordem em que foram escolhidos
## na cafeteria. Vazia = ainda não montou. Quem monta é a cena do lobby (scripts/lobby.gd).
static var party: Array = []

static var owned := {"dodge": true}
static var decks := {}
static var mastery := {}
static var money := 0
static var tickets := 0
static var shop_unlocked := false
## Cartas novas ainda não vistas: herói (índice) -> lista de ids. É UM estado só, usado pelo aviso no
## personagem (has_new) e pelo selo NOVO na carta (is_new). Sai da lista quando o jogador passa o
## mouse na carta, na tela de cartas daquele herói (see_new). Vai pro save.
static var fresh := {}
## Ordem das habilidades na barra, por herói: layouts[hero][posição] = habilidade do kit. O jogador
## arruma na tela SKILLS (arrastando). Quem não mexeu não tem entrada: vale a ordem do kit. As teclas
## (Binds skill_1..6) são das POSIÇÕES, então trocar a ordem troca qual tecla solta cada habilidade.
## CONHECIMENTO: o quanto cada herói sabe resolver cada mecânica, de 0 a 100 (know[hero][mecânica]).
## Não liga nem desliga comportamento: muda a CHANCE de o herói tentar a coisa certa e a PRECISÃO com
## que ele acerta o tempo. Sobe com a experiência (ver game.gd, LEARN_*): tomar a mecânica ensina
## pouco, acertar sozinho ensina mais, e ver o jogador resolver na mão ensina também.
## Todo mundo começa em KNOW_START: tem uma vaga ideia, não é um zumbi.
const KNOW_START := 1.0
static var know := {}
## Quantas vezes o jogador resolveu cada mecânica na mão (solved[chave]); ver mech_seen.
const REVEAL_NEED := 2
static var solved := {}
## Equipamentos por herói (gear[hero] = GEAR_SLOTS ids, "" = vazio), passivas aprendidas
## (passive[hero] = [ids]) e o progresso de cada carta de aprendizado (progress[hero][id] = 0..100).
static var gear := {}
static var passive := {}
static var progress := {}
## Cartas que acabaram de virar passiva e ainda não foram comemoradas: [[hero, id], ...].
static var learned_now: Array = []
static var layouts := {}
static var layout_rev := 0
## Rotação é de cada herói: chave do herói -> true.
static var dps_known := {}
## Melhor ranking por boss (índice -> índice em RANKS). Boss vencido libera o próximo.
static var best_rank := {}
## Quem você controla quando a luta começa, e a luta escolhida.
static var start_hero := 2
## Com isso ligado a luta começa sozinha depois de recarregar a cena.
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


## A party já tem os quatro?
static func party_ready() -> bool:
	return party.size() == 4


## Os quatro que entram na luta: a party do save, ou a padrão enquanto não houver uma.
static func fight_party() -> Array:
	return party if party_ready() else DEFAULT_PARTY


## Lugar do herói na party (-1 se ele ficou de fora), e o herói que ocupa um lugar.
static func slot_of(hero: int) -> int:
	return fight_party().find(hero)


static func hero_at(at: int) -> int:
	return fight_party()[at]


static func in_party(hero: int) -> bool:
	return fight_party().has(hero)


## Fecha a party escolhida na cafeteria. Quem você controla passa a ser um dos quatro.
static func set_party(list: Array) -> void:
	party = list.duplicate()
	if party_ready() and not party.has(start_hero):
		start_hero = party[0]


## Garante que `hero` está na party (argumentos de teste como --hero=N): entra no lugar de alguém
## da mesma função (tank no lugar de tank), ou do último.
static func ensure_in_party(hero: int) -> void:
	if in_party(hero):
		return
	var list: Array = fight_party().duplicate()
	var at := list.size() - 1
	for n in list.size():
		if is_tank(list[n]) == is_tank(hero):
			at = n
			break
	list[at] = hero
	party = list


static func is_tank(hero: int) -> bool:
	return HEROES[hero].get("tank", false)


static func kind_of(id: String) -> String:
	return CARDS[id]["kind"]


static func role(id: String) -> String:
	if GEAR_IDS.has(id):
		return "gear"
	if CARDS[id]["kind"] == "item":
		return "item"
	return "pref" if PREF_IDS.has(id) else "learn"


static func gear_of(i: int) -> Array:
	if not gear.has(i):
		var arr: Array = []
		for n in GEAR_SLOTS:
			arr.append("")
		gear[i] = arr
	return gear[i]


static func is_passive(i: int, id: String) -> bool:
	return passive.has(i) and passive[i].has(id)


static func passives(i: int) -> Array:
	return passive.get(i, [])


## O herói i está valendo dessa carta/equipamento? (equipado, ou já aprendido como passiva)
static func has(i: int, id: String) -> bool:
	if not CARDS.has(id):
		return false
	if GEAR_IDS.has(id):
		return gear_of(i).has(id)
	if is_passive(i, id):
		return true
	var arr: Array = deck(i)[CARDS[id]["kind"]]
	return arr.has(id)


## Está no baralho dele agora? (sem contar passiva)
static func in_deck(i: int, id: String) -> bool:
	return CARDS.has(id) and not GEAR_IDS.has(id) and deck(i)[CARDS[id]["kind"]].has(id)


static func learn_progress(i: int, id: String) -> float:
	if is_passive(i, id):
		return 100.0
	if not progress.has(i):
		return 0.0
	return float(progress[i].get(id, 0.0))


## Soma aprendizado numa carta do herói. Em 100 ela vira passiva: sai do baralho, entra em passive
## e fica na fila da comemoração. Devolve true se virou agora.
static func add_progress(i: int, id: String, amount: float) -> bool:
	if sandbox or practice or role(id) != "learn" or is_passive(i, id):
		return false
	if not progress.has(i):
		progress[i] = {}
	progress[i][id] = clampf(learn_progress(i, id) + amount, 0.0, 100.0)
	if progress[i][id] < 100.0:
		return false
	unequip(i, id)
	if not passive.has(i):
		passive[i] = []
	passive[i].append(id)
	learned_now.append([i, id])
	return true


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
	if is_passive(i, id):
		return true  # já é dele pra sempre: não ocupa slot
	var arr: Array = gear_of(i) if GEAR_IDS.has(id) else deck(i)[CARDS[id]["kind"]]
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
	var arr: Array = gear_of(i) if GEAR_IDS.has(id) else deck(i)[CARDS[id]["kind"]]
	var at := arr.find(id)
	if at >= 0:
		arr[at] = ""


## Cópia única: itens e tudo que se compra na loja (moedas ou ticket). Você tem UMA, e só um herói
## usa por vez. As cartas conquistadas jogando (maestria, Rotação, etc.) são conhecimento: valem pra todos.
static func is_unique(id: String) -> bool:
	var c: Dictionary = CARDS[id]
	return c["kind"] == "item" or c.has("price") or c.has("ticket") or GEAR_IDS.has(id)


## Quem está com a carta de cópia única (índice do herói), ou -1 se ela está solta.
static func holder(id: String) -> int:
	var kind: String = CARDS[id]["kind"]
	for j in HEROES.size():
		if (gear_of(j) if GEAR_IDS.has(id) else deck(j)[kind]).has(id):
			return j
	return -1


## Cartas que o herói i pode usar e que não estão equipadas nele, da mais rara pra mais comum.
static func inventory(i: int) -> Array:
	var out: Array = []
	for kind in KINDS:
		for id in CARDS:
			if CARDS[id]["kind"] == kind and not GEAR_IDS.has(id) and is_owned_by(i, id) and usable(i, id) and not has(i, id):
				out.append(id)
	return out


## Equipamentos que o herói i pode pôr e que não estão nele.
static func gear_bag(i: int) -> Array:
	var out: Array = []
	for id in GEAR_IDS:
		if is_owned_by(i, id) and usable(i, id) and not gear_of(i).has(id):
			out.append(id)
	return out


## Os atributos do herói i que os equipamentos mudam: [vida a mais, alcance x, velocidade x, crítico].
static func gear_stats(i: int) -> Dictionary:
	return {
		"hp": 20.0 if has(i, "heart") else 0.0,
		"range": 1.1 if has(i, "scope") else 1.0,
		"speed": 1.12 if has(i, "boots") else 1.0,
		"crit": 0.25 if has(i, "dice") else 0.0,
	}


static func grant(id: String) -> bool:
	if owned.has(id):
		return false
	owned[id] = true
	save()
	return true


## Texto da carta ainda desconhecida: a frase de mistério e a pista de como chegar nela.
static func mystery(id: String) -> String:
	return SECRETS[id][0] if SECRETS.has(id) else "Ninguém sabe dizer o que é."


static func hint(id: String) -> String:
	return SECRETS[id][1] if SECRETS.has(id) else "Continue jogando."


# ---------------------------------------------------------------- cartas novas

## Marca a carta como NOVA pro herói que a conquistou. Carta nova nunca é equipada sozinha: ela
## entra na coleção e fica esperando o jogador. Sem herói informado (loja, prêmio de boss), vale
## quem o jogador controla; se esse herói não pode usar a carta, vale o primeiro da party que pode.
static func mark_new(id: String, hero := -1) -> void:
	if not CARDS.has(id):
		return
	if hero < 0:
		hero = start_hero
	if not usable(hero, id):
		hero = -1
		for h in fight_party() + range(HEROES.size()):
			if usable(h, id):
				hero = h
				break
		if hero < 0:
			return
	if not fresh.has(hero):
		fresh[hero] = []
	if not fresh[hero].has(id):
		fresh[hero].append(id)


static func is_new(hero: int, id: String) -> bool:
	return fresh.has(hero) and fresh[hero].has(id)


## O herói tem alguma carta nova que o jogador ainda não viu?
static func has_new(hero: int) -> bool:
	return fresh.has(hero) and not fresh[hero].is_empty()


## O jogador viu a carta (passou o mouse nela): sai da lista e o save é atualizado.
static func see_new(hero: int, id: String) -> void:
	if not is_new(hero, id):
		return
	fresh[hero].erase(id)
	if fresh[hero].is_empty():
		fresh.erase(hero)
	save()


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

## O que cada loja vende. `shop` "cards": a loja de cartas (critérios e o que mais for carta);
## "gear": a loja de itens (equipamentos e consumíveis). "" = tudo.
static func shop_list(cat := "", shop := "") -> Array:
	var out: Array = []
	for kind in KINDS:
		for id in CARDS:
			var c: Dictionary = CARDS[id]
			if c["kind"] != kind or not (c.has("price") or c.has("ticket")) or not (cat == "" or c["cat"] == cat):
				continue
			var is_item: bool = GEAR_IDS.has(id) or kind == "item"
			if shop == "" or (shop == "gear") == is_item:
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
	mark_new(id)
	save()
	return true


# ---------------------------------------------------------------- bosses e ranking

static func boss_open(i: int) -> bool:
	# o mini boss e o primeiro boss estão sempre abertos; cada vitória abre o seguinte
	return i <= 1 or BOSS_INFO[i]["mini"] or BOSS_INFO[i].get("open", false) or best_rank.has(i - 1)


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
		mark_new("breath")
		out["card"] = "breath"
	if not best_rank.has(boss_i) or int(best_rank[boss_i]) < rank:
		best_rank[boss_i] = rank
	shop_unlocked = true
	save()
	return out


# ---------------------------------------------------------------- save

static func knowledge(hero: int, mech: String) -> float:
	if not know.has(hero):
		return KNOW_START
	return float(know[hero].get(mech, KNOW_START))


static func learn(hero: int, mech: String, amount: float) -> void:
	if sandbox or practice:
		return
	if not know.has(hero):
		know[hero] = {}
	know[hero][mech] = clampf(knowledge(hero, mech) + amount, 0.0, 100.0)


static func mech_name(key: String) -> String:
	if key == "dodge":
		return "Desvio de vermelho"
	if KNOW_NAME.has(key):
		return KNOW_NAME[key]
	return CARDS[key]["name"] if CARDS.has(key) else key


## A mecânica vale pra este herói? (cartas com "who" são só de algumas classes)
static func mech_applies(hero: int, key: String) -> bool:
	return not CARDS.has(key) or usable(hero, key)


## Quanto o herói entende de uma mecânica, de 0 a 100: 100 com a carta equipada ou como passiva;
## sem ela, o que ele já aprendeu na prática (knowledge).
static func understanding(hero: int, key: String) -> float:
	if CARDS.has(key) and has(hero, key):
		return 100.0
	return knowledge(hero, key)


## O jogador resolveu essa mecânica na mão mais uma vez (conta pra revelar o nome dela no painel).
static func solve(key: String) -> void:
	if sandbox or practice:
		return
	solved[key] = int(solved.get(key, 0)) + 1


## O nome da mecânica só aparece no painel depois que o JOGADOR a resolveu por conta própria
## REVEAL_NEED vezes. Antes disso é "??????": não é justo entregar o que ele ainda não descobriu.
static func mech_seen(key: String) -> bool:
	if int(solved.get(key, 0)) >= REVEAL_NEED:
		return true
	return CARDS.has(key) and mastery_key(key) != "" and mastery_of(mastery_key(key)) >= REVEAL_NEED


static func layout(hero: int, count := 6) -> Array:
	var base: Array = range(count)
	if sandbox or not layouts.has(hero):
		return base
	var l: Array = layouts[hero]
	# só vale se for mesmo uma permutação das habilidades do kit
	if l.size() != count:
		return base
	for n in count:
		if not l.has(n):
			return base
	return l


## A habilidade do kit que está na posição `pos` da barra do herói.
static func skill_at(hero: int, pos: int, count := 6) -> int:
	if pos < 0 or pos >= count:
		return pos
	return int(layout(hero, count)[pos])


## Em que posição da barra está a habilidade `slot` do kit.
static func pos_of(hero: int, slot: int, count := 6) -> int:
	var at: int = layout(hero, count).find(slot)
	return slot if at < 0 else at


## Troca de lugar o que está em duas posições da barra do herói, e grava.
static func swap_skills(hero: int, a: int, b: int, count := 6) -> void:
	if a == b or a < 0 or b < 0 or a >= count or b >= count:
		return
	var l: Array = layout(hero, count).duplicate()
	var keep = l[a]
	l[a] = l[b]
	l[b] = keep
	if l == range(count):
		layouts.erase(hero)
	else:
		layouts[hero] = l
	layout_rev += 1
	save()


static func reset_layout(hero: int) -> void:
	if layouts.has(hero):
		layouts.erase(hero)
		layout_rev += 1
		save()


## Tutorial (scripts/tutorial.gd): o jogador treina com um conjunto de cartas só do tutorial.
## enter_sandbox guarda o progresso de verdade e zera as cartas; leave_sandbox devolve tudo.
## Enquanto dura, nada é gravado em disco.
static var sandbox := false
static var _kept := {}


static func enter_sandbox() -> void:
	if sandbox:
		return
	_kept = {"owned": owned, "decks": decks, "mastery": mastery, "dps": dps_known, "hero": start_hero, "party": party, "fresh": fresh,
		"gear": gear, "passive": passive, "progress": progress}
	sandbox = true
	gear = {}
	passive = {}
	progress = {}
	fresh = {}
	owned = {}
	decks = {}
	mastery = {}
	dps_known = {}
	party = []


static func leave_sandbox() -> void:
	if not sandbox:
		return
	owned = _kept["owned"]
	decks = _kept["decks"]
	mastery = _kept["mastery"]
	dps_known = _kept["dps"]
	start_hero = _kept["hero"]
	party = _kept["party"]
	fresh = _kept["fresh"]
	gear = _kept["gear"]
	passive = _kept["passive"]
	progress = _kept["progress"]
	_kept = {}
	sandbox = false


# ---------------------------------------------------------------- run (uma tentativa de luta)

## Uma run é uma tentativa de luta, do GO até a tela de fim (vitória ou wipe).
## Tudo que o jogador ganha no meio dela (maestria, cartas, Rotação) é provisório:
##   begin_run   guarda como o save estava e para de gravar em disco;
##   commit_run  a run terminou (venceu ou morreu): o que foi ganho passa a valer e é gravado;
##   abort_run   o jogador saiu ou reiniciou pelo pause: volta tudo ao que era antes do GO.
## Fechar o jogo no meio da luta também não grava nada, porque save() não escreve durante a run.
static var in_run := false
static var _run_kept := {}
## Treino livre (dummy): luta sem progresso. Nada do que acontece nela é ganho nem gravado.
static var practice := false


static func begin_run() -> void:
	if in_run:
		return
	_run_kept = {"owned": owned.duplicate(), "decks": decks.duplicate(true), "mastery": mastery.duplicate(), "dps": dps_known.duplicate(), "fresh": fresh.duplicate(true),
		"gear": gear.duplicate(true), "passive": passive.duplicate(true), "progress": progress.duplicate(true), "know": know.duplicate(true)}
	in_run = true


static func commit_run() -> void:
	if not in_run:
		return
	if practice:
		abort_run()
		return
	in_run = false
	_run_kept = {}
	save()


static func abort_run() -> void:
	if not in_run:
		return
	owned = _run_kept["owned"]
	decks = _run_kept["decks"]
	mastery = _run_kept["mastery"]
	dps_known = _run_kept["dps"]
	fresh = _run_kept["fresh"]
	gear = _run_kept["gear"]
	passive = _run_kept["passive"]
	progress = _run_kept["progress"]
	know = _run_kept["know"]
	learned_now.clear()
	_run_kept = {}
	in_run = false


## Cartas ganhas nesta run e ainda não confirmadas (somem se a run for abandonada).
static func run_cards() -> Array:
	var out: Array = []
	if not in_run:
		return out
	for id in owned:
		if not _run_kept["owned"].has(id):
			out.append(id)
	if dps_known.size() > _run_kept["dps"].size():
		out.append("dps")
	return out


static func save_path(n: int) -> String:
	return save_dir + "save_%d.json" % n


static func slot_exists(n: int) -> bool:
	return FileAccess.file_exists(save_path(n))


static func save() -> void:
	if not persist or sandbox or in_run or slot <= 0:
		return
	var data := {
		"owned": owned.keys(), "decks": {}, "mastery": mastery, "money": money, "tickets": tickets,
		"shop": shop_unlocked, "dps": dps_known.keys(), "rank": {}, "hero": start_hero, "boss": boss, "party": party,
	}
	for name in ["gear", "passive", "progress"]:
		data[name] = {}
	for h in gear:
		data["gear"][str(h)] = gear[h]
	for h in passive:
		data["passive"][str(h)] = passive[h]
	for h in progress:
		data["progress"][str(h)] = progress[h]
	data["solved"] = solved
	data["know"] = {}
	for h in know:
		data["know"][str(h)] = know[h]
	data["layouts"] = {}
	for h in layouts:
		data["layouts"][str(h)] = layouts[h]
	data["fresh"] = {}
	for h in fresh:
		data["fresh"][str(h)] = fresh[h]
	for i in decks:
		data["decks"][str(i)] = decks[i]
	for b in best_rank:
		data["rank"][str(b)] = best_rank[b]
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


## Progresso zerado, como um save novo.
static func reset_progress() -> void:
	owned = {"dodge": true}
	fresh = {}
	layouts = {}
	know = {}
	solved = {}
	gear = {}
	passive = {}
	progress = {}
	learned_now.clear()
	layout_rev += 1
	decks = {}
	mastery = {}
	money = 0
	tickets = 0
	shop_unlocked = false
	dps_known = {}
	best_rank = {}
	start_hero = 2
	boss = 1
	attempts = 1
	party = []
	in_run = false
	_run_kept = {}
	practice = false


## Na abertura do jogo: converte o save antigo (arquivo único) no save 1 e reabre o último save usado.
static func load_save() -> void:
	if _loaded or not persist:
		return
	_loaded = true
	var any := false
	for n in range(1, SLOT_COUNT + 1):
		if slot_exists(n):
			any = true
	if not any and FileAccess.file_exists(save_dir + LEGACY_SAVE):
		# o arquivo antigo fica onde está, como cópia de segurança
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_dir + LEGACY_SAVE), ProjectSettings.globalize_path(save_path(1)))
	var last := 0
	if FileAccess.file_exists(save_dir + LAST_SLOT_FILE):
		last = int(FileAccess.get_file_as_string(save_dir + LAST_SLOT_FILE))
	if last >= 1 and last <= SLOT_COUNT and slot_exists(last):
		select_slot(last)


## Troca o save ativo: zera o que está na memória e lê o arquivo do slot (se existir).
## Slot vazio vira um save novo, gravado na hora.
static func select_slot(n: int) -> void:
	slot = clampi(n, 1, SLOT_COUNT)
	reset_progress()
	if slot_exists(slot):
		_read(save_path(slot))
	if not persist:
		return
	save()
	var f := FileAccess.open(save_dir + LAST_SLOT_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(str(slot))


## Apaga o save do slot. Se era o ativo, o jogo fica sem save escolhido.
static func delete_slot(n: int) -> void:
	if slot_exists(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path(n)))
	if n == slot:
		slot = 0
		reset_progress()


## Resumo de um slot pra tela de saves, sem carregar o save: {} se está vazio.
static func slot_info(n: int) -> Dictionary:
	if not slot_exists(n):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path(n)))
	if not (parsed is Dictionary):
		return {}
	var ranks := {}
	for b in parsed.get("rank", {}):
		ranks[int(b)] = int(parsed["rank"][b])
	var team: Array = []
	for h in parsed.get("party", []):
		if int(h) >= 0 and int(h) < HEROES.size():
			team.append(int(h))
	return {"party": team, "money": int(parsed.get("money", 0)), "tickets": int(parsed.get("tickets", 0)), "rank": ranks}


static func _read(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
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
	# party: quatro heróis diferentes que ainda existem. Save de antes da cafeteria tem só a tank
	# escolhida: ele continua sem party e o jogador monta uma na cafeteria.
	var team: Array = []
	for h in parsed.get("party", []):
		if int(h) >= 0 and int(h) < HEROES.size() and not team.has(int(h)):
			team.append(int(h))
	party = team if team.size() == 4 else []
	if party_ready() and not party.has(start_hero):
		start_hero = party[0]
	for b in parsed.get("rank", {}):
		best_rank[int(b)] = int(parsed["rank"][b])
	boss = clampi(int(parsed.get("boss", 1)), 0, BOSS_INFO.size() - 1)
	if not boss_open(boss):
		boss = 1
	var saved_solved: Dictionary = parsed.get("solved", {})
	for key in saved_solved:
		solved[str(key)] = int(saved_solved[key])
	var saved_know: Dictionary = parsed.get("know", {})
	for sh in saved_know:
		var hk := int(sh)
		if hk < 0 or hk >= HEROES.size() or not (saved_know[sh] is Dictionary):
			continue
		know[hk] = {}
		for mech in saved_know[sh]:
			know[hk][str(mech)] = clampf(float(saved_know[sh][mech]), 0.0, 100.0)
	# ordem das habilidades na barra (layout() confere se é uma permutação válida na hora de usar)
	var saved_layouts: Dictionary = parsed.get("layouts", {})
	for sh in saved_layouts:
		var h := int(sh)
		if h < 0 or h >= HEROES.size() or not (saved_layouts[sh] is Array):
			continue
		var l: Array = []
		for v in saved_layouts[sh]:
			l.append(int(v))
		layouts[h] = l
	layout_rev += 1
	# cartas novas ainda não vistas: só as que existem e são do jogador
	var news: Dictionary = parsed.get("fresh", {})
	for sh in news:
		var h := int(sh)
		if h < 0 or h >= HEROES.size():
			continue
		for id in news[sh]:
			if CARDS.has(str(id)) and is_owned_by(h, str(id)):
				mark_new(str(id), h)
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
	# passivas, progresso e equipamentos
	var saved_passive: Dictionary = parsed.get("passive", {})
	for sh in saved_passive:
		var hp := int(sh)
		if hp < 0 or hp >= HEROES.size() or not (saved_passive[sh] is Array):
			continue
		passive[hp] = []
		for id in saved_passive[sh]:
			if CARDS.has(str(id)) and role(str(id)) == "learn" and not passive[hp].has(str(id)):
				passive[hp].append(str(id))
				unequip(hp, str(id))
	var saved_progress: Dictionary = parsed.get("progress", {})
	for sh in saved_progress:
		var hg := int(sh)
		if hg < 0 or hg >= HEROES.size() or not (saved_progress[sh] is Dictionary):
			continue
		progress[hg] = {}
		for id in saved_progress[sh]:
			if CARDS.has(str(id)):
				progress[hg][str(id)] = clampf(float(saved_progress[sh][id]), 0.0, 100.0)
	var saved_gear: Dictionary = parsed.get("gear", {})
	for sh in saved_gear:
		var he := int(sh)
		if he < 0 or he >= HEROES.size() or not (saved_gear[sh] is Array):
			continue
		var slots := gear_of(he)
		for n in mini(GEAR_SLOTS, saved_gear[sh].size()):
			var id := str(saved_gear[sh][n])
			slots[n] = id if (GEAR_IDS.has(id) and owned.has(id) and usable(he, id)) else ""
	# save de antes dos equipamentos: o que era carta de buff no baralho passa pros slots de gear
	for i in HEROES.size():
		if not decks.has(i):
			continue
		for kind in KINDS:
			var cards: Array = decks[i][kind]
			for n in cards.size():
				if GEAR_IDS.has(cards[n]):
					var moved: String = cards[n]
					cards[n] = ""
					var free := gear_of(i).find("")
					if free >= 0 and holder(moved) < 0:
						gear_of(i)[free] = moved
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
