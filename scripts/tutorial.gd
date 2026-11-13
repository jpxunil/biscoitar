extends Node3D
## TUTORIAL DO JOGO: uma aula guiada pela Shopkeeper, sem boss e sem combate (cena tutorial.tscn).
##   1. Quatro mecânicas, uma por vez: ela explica, DEMONSTRA, e o jogador acerta NEED vezes.
##      Errou ou travou: dicas cada vez mais diretas (a última desenha no chão onde ir).
##   2. Conversa: as cartas servem pra ENSINAR os companheiros.
##   3. Tela de cartas guiada: arrastar a Laranja Junto pro baralho do companheiro.
##   4. Prova: o jogador fica imóvel e o companheiro, com a carta, vem resolver sozinho.
##   5. Fim numa tela preta (reservada pra algo futuro); ENTER volta pro menu principal.
## As cartas ganhas aqui são só do tutorial: Knowledge.enter_sandbox() guarda o progresso de
## verdade e nada é gravado. A sequência toda é a corrotina _run(); cada exercício é uma
## tentativa (`ex`) que termina emitindo attempt_done.

signal confirmed
signal attempt_done(ok: bool, why: String)

const GAME := preload("res://scripts/game.gd")
## Os dois heróis mais simples de pilotar (índices em Knowledge.HEROES): Assassina e Maga.
const HEROES := [2, 3]
const NEED := 3
const ORDER := ["stack", "pair", "spread", "link"]

const ARENA_R := 8.6
const STACK_R := 2.5
const PAIR_R := 1.8
const SPREAD_R := 5.0
const LINK_BREAK := 8.0
const LINK_TICK := 0.5
const LINK_DMG := 6.0
const STACK_COL := Color(1.0, 0.6, 0.1)
const SPREAD_COL := Color(0.72, 0.35, 1.0)
const LINK_COL := Color(1.0, 0.4, 0.75)
const GUIDE_COL := Color(0.3, 0.9, 1.0)
## Tudo acontece na metade de trás da arena: a da frente fica embaixo da caixa de fala.
const DUMMY_POS := [Vector3(-5.0, 0, -4.0), Vector3(5.0, 0, -4.0)]
const ART := "res://assets/portraits/shopkeeper_art.webp"
const BUST := "res://assets/portraits/shopkeeper_bust.webp"

## Tempo de cada tentativa (a corrente não tem relógio: quem marca o tempo é a queimadura).
const TIME := {"stack": 7.0, "pair": 11.0, "spread": 6.5, "link": 0.0}
const DEMO_TIME := {"stack": 4.5, "pair": 5.0, "spread": 4.5, "link": 0.0}
const CARD := {"stack": "stack", "pair": "pair", "spread": "spread", "link": "link"}
const BANNER := {
	"stack": ["1/4  ·  UMA BOLA LARANJA", "juntar"],
	"pair": ["2/4  ·  DUAS BOLAS LARANJAS", "dividir em dois"],
	"spread": ["3/4  ·  BOLA ROXA", "afastar"],
	"link": ["4/4  ·  CORRENTE", "arrebentar"],
}

const INTRO := [
	"Ah. Cliente novo. ...Tá, eu dou a aula. Eu sou a garota da loja, mas hoje sou sua instrutora.",
	"Aqui não tem boss nem pancadaria. Só eu, você e esses dois aí.",
	"Você anda com {move}. Pra trocar de herói, aperta {swap} ou clica no retrato dele.",
	"Vou te mostrar quatro sinais. Cada um, você acerta três vezes. Bora.",
]
const EXPLAIN := {
	"stack": [
		"Primeiro sinal: UMA bola laranja em cima de alguém, com um círculo laranja no chão.",
		"Isso é um STACK. O golpe é dividido entre quem estiver dentro do círculo. Então todo mundo se JUNTA nele.",
		"Olha só. Eu faço uma vez pra você ver.",
	],
	"pair": [
		"Agora presta atenção, que essa pega muita gente: DUAS bolas laranjas ao mesmo tempo.",
		"Duas bolas NÃO são uma bola grande. São dois STACKS separados, e o grupo se DIVIDE: um pouco em cada.",
		"Uma bola laranja: todo mundo junto. Duas bolas laranjas: cada um vai pra uma.",
		"Botei as bolas nesses bonecos de treino. Olha como fica.",
	],
	"spread": [
		"Terceiro sinal: bola ROXA. É o contrário da laranja.",
		"Laranja: juntar. Roxo: SEPARAR. Ninguém pode estar dentro do círculo roxo de outra pessoa quando ele estoura.",
		"Assim, ó.",
	],
	"link": [
		"Último: a CORRENTE. Ela prende dois heróis um no outro e vai QUEIMANDO os dois.",
		"Ficar parado não resolve nada. Ela só arrebenta se os dois ficarem bem longe um do outro.",
		"Repara que ela afina e clareia quando está quase arrebentando.",
	],
}
const YOUR_TURN := {
	"stack": "Sua vez. Faz os dois ficarem dentro do círculo laranja antes dele encher.",
	"pair": "Sua vez. Um herói em cada boneco. Você vai precisar trocar de herói com {swap}.",
	"spread": "Sua vez. Tira um herói de dentro do círculo roxo do outro.",
	"link": "Sua vez. Afasta os dois até a corrente arrebentar. Sem enrolar, que queima.",
}
## Instrução curta que fica na tela durante a tentativa (antes de qualquer erro).
const GOAL := {
	"stack": "Laranja = JUNTAR. Os dois dentro do círculo.",
	"pair": "Duas laranjas = DIVIDIR. Um herói em cada boneco ({swap} troca).",
	"spread": "Roxo = SEPARAR. Sai de dentro do círculo roxo.",
	"link": "Corrente = AFASTAR os dois até arrebentar.",
}
## Dicas, da mais leve pra mais direta. A última vem junto com o anel azul no chão.
const HINTS := {
	"stack": [
		"Quase. Laranja é pra JUNTAR: leva um herói até o outro antes do círculo encher.",
		"O círculo laranja fica em volta de quem tem a bola. Anda com {move} até os DOIS estarem dentro dele.",
		"Marquei no chão. Leva o seu herói até o anel azul e fica lá até o círculo encher.",
	],
	"pair": [
		"Duas bolas não são uma só. Cada boneco precisa de UM herói: nem dois no mesmo, nem nenhum.",
		"Leva um herói até um boneco. Aperta {swap} pra trocar. Leva o outro até o outro boneco. O primeiro fica onde você deixou.",
		"Marquei os dois lugares. Um herói em cada anel azul: anda, {swap}, anda.",
	],
	"spread": [
		"Roxo é o contrário do laranja: AFASTA. Vocês ainda estavam perto demais.",
		"O círculo roxo é grande. Anda pra longe do outro herói até sair dele inteiro, e não volta.",
		"Marquei um lugar seguro. Leva o seu herói até o anel azul.",
	],
	"link": [
		"Parado, queima. A corrente só arrebenta com os dois BEM longe um do outro.",
		"Escolhe um lado e corre com {move} sem parar. Quando a corrente ficar fina e branca, falta pouco.",
		"Marquei até onde ir. Corre pro anel azul que ela arrebenta.",
	],
}
const FAIL_SAY := {
	"apart": "Hm. Ficou alguém de fora do círculo.",
	"same": "Os dois no mesmo boneco. Aí é gente demais num e ninguém no outro.",
	"missing": "Ficou um boneco sozinho.",
	"close": "Vocês ainda estavam grudados.",
	"burn": "Queimou. Relaxa, eu levanto vocês. De novo.",
}
const NUDGE := {
	"stack": "Tá esperando o quê? Anda com {move} até o outro herói.",
	"pair": "Cada um num boneco. Começa andando com {move}.",
	"spread": "Não fica aí. Anda pra longe com {move}.",
	"link": "Tá queimando! Corre pra longe com {move}.",
}
const PRAISE := ["Isso.", "Boa.", "Olha só, aprendeu.", "É isso aí.", "Certinho."]
const LEARNED := {
	"stack": "Três de três. Uma bola laranja: juntar. Guarda isso. E toma: uma carta.",
	"pair": "Pronto. Duas bolas laranjas nunca são uma só. Mais uma carta pra você.",
	"spread": "Laranja junta, roxo separa. Não esquece. Carta.",
	"link": "E corrente a gente arrebenta correndo. Última carta.",
}
const TRANSITION := [
	"Você percebeu uma coisa?",
	"Durante todos esses exercícios, você aprendeu a reconhecer diferentes situações e a reagir a elas.",
	"Mas existe algo que talvez você ainda não tenha percebido...",
	"Você também estava aprendendo a ensinar.",
	"Sim, você mesmo! Do outro lado da tela.",
	"Com as cartas, você pode ensinar seus companheiros o que fazer quando determinadas situações acontecerem.",
	"Vamos experimentar?",
]
const CARDS_INTRO := [
	"Agora tente dar uma ordem para o seu companheiro.",
	"Escolha uma das cartas que você aprendeu a conseguir durante os exercícios.",
]
const CARDS_HINTS := [
	"A carta {card} é a que está brilhando e pulando. Clica nela, SEGURA e arrasta pra cima.",
	"Segura o botão do mouse em cima da {card} e leva até um dos espaços claros do baralho, lá em cima. Solta lá.",
]
const ENDING := [
	"Viu só?",
	"Agora ele sabe exatamente o que fazer quando isso acontece!",
	"Existem várias cartas de ações espalhadas pelo jogo.",
	"Cada uma delas pode ensinar algo novo aos seus companheiros.",
	"Você não precisa fazer tudo sozinho. Basta ensiná-los!",
	"Mas ainda existe muito mais para aprender.",
	"Se você conseguir vencer este desafio sozinho três vezes, será abençoado com o comando!",
]

var units: Array[Unit] = []
var ctrl := 0
var dummies: Array[Node3D] = []
var fx_root: Node3D
var floor_mat: ShaderMaterial
var shop: Sprite3D
var wins := {"stack": 0, "pair": 0, "spread": 0, "link": 0}
var fails := {"stack": 0, "pair": 0, "spread": 0, "link": 0}
## Tentativa em andamento ({} = nenhuma): kind, demo, t, total, marked, nodes, goals...
var ex := {}
var lock_move := false
var lock_swap := false
## Em que parte da aula estamos: "intro", "stack"..."link", "talk", "cards", "test", "end", "black".
var stage := "intro"
var comp := 1  # índice (em units) do companheiro que recebe a carta
var finished := false

var _t := 0.0
var _moved := false
var _nudged := false
var _waiting := false
var _typing: Tween
var _black_ready := false

var ui: Control
var fight_ui: Control
var party_cards: Array = []
var banner_title: Label
var banner_sub: Label
var pips: Control
var demo_tag: Control
var talk_box: Control
var talk_text: Label
var talk_next: Control
var keys_hint: Label
var card_pop: Control
var cards: CardsScreen
var blocker: Control
var black: ColorRect
var black_hint: PanelContainer
var pause_menu: PauseMenu
var options: OptionsScreen
var guides: Array[Node3D] = []


func _ready() -> void:
	# qualquer argumento de teste desliga o save, como na luta
	if OS.get_cmdline_user_args().size() > 0:
		Knowledge.persist = false
	Knowledge.load_save()
	Settings.boot()
	Knowledge.enter_sandbox()
	_build_world()
	_build_units()
	_build_ui()
	_set_banner("")
	_run.call_deferred()


func _exit_tree() -> void:
	Knowledge.leave_sandbox()


# ---------------------------------------------------------------- a aula, do começo ao fim

func _run() -> void:
	await _talk(INTRO)
	for kind in ORDER:
		await _lesson(kind)
	stage = "talk"
	_set_banner("")
	await _talk(TRANSITION)
	await _cards_part()
	await _npc_test()
	stage = "end"
	await _talk(ENDING)
	await _to_black()


func _lesson(kind: String) -> void:
	stage = kind
	_set_banner(kind)
	await _talk(EXPLAIN[kind])
	demo_tag.visible = true
	_begin(kind, true)
	await attempt_done
	demo_tag.visible = false
	await _sleep(0.9)
	await _talk([YOUR_TURN[kind]])
	while wins[kind] < NEED:
		_begin(kind, false)
		var level: int = fails[kind]
		_say(GOAL[kind] if level == 0 else HINTS[kind][mini(level, HINTS[kind].size()) - 1])
		var res: Array = await attempt_done
		if res[0]:
			wins[kind] += 1
			pips.queue_redraw()
			_shop_hop()
			_say("%s  %d de %d." % [PRAISE[(wins[kind] + ORDER.find(kind)) % PRAISE.size()], wins[kind], NEED])
			await _sleep(1.4)
		else:
			fails[kind] += 1
			_say(FAIL_SAY.get(res[1], "Não foi dessa vez."))
			await _sleep(1.9)
	Knowledge.owned[CARD[kind]] = true
	await _show_card(CARD[kind])
	await _talk([LEARNED[kind]])


func _cards_part() -> void:
	stage = "cards"
	comp = 1 - ctrl
	var hero: int = units[comp].hero
	var want := "stack"
	fight_ui.visible = false
	cards = preload("res://ui/screens/cards_screen.tscn").instantiate()
	cards.tutor = {"card": want, "art": ART, "art_w": 400.0}
	ui.add_child(cards)
	ui.move_child(cards, blocker.get_index())
	cards.open(hero, false)
	cards.back_pressed.connect(_pause)
	if cards._hand.has(want):
		cards._set_focus(cards._hand.find(want))
	await _talk(CARDS_INTRO)
	var card_name := String(Knowledge.CARDS[want]["name"]).to_upper()
	var who := String(Knowledge.HEROES[hero]["name"]).to_upper()
	_say("Arrasta a carta %s, a que está brilhando, até um espaço claro do baralho da %s." % [card_name, who])
	var waited := 0.0
	var level := 0
	var scolded := ""
	while not Knowledge.has(hero, want):
		await get_tree().process_frame
		waited += get_process_delta_time()
		# equipou outra carta: serve, mas não é a da aula
		for id in ["pair", "spread", "link"]:
			if Knowledge.has(hero, id) and scolded != id:
				scolded = id
				_say("Essa aí também ensina uma coisa, mas fica pra depois. Agora eu quero a %s, a que está brilhando." % card_name)
				waited = 0.0
		if level < CARDS_HINTS.size() and waited > 14.0 + level * 12.0:
			_say(CARDS_HINTS[level].replace("{card}", card_name))
			level += 1
	blocker.visible = true  # a carta já está no lugar: ninguém tira ela de lá durante a fala
	_shop_hop()
	await _talk(["Perfeito! Vamos ver se funcionou!"])
	blocker.visible = false
	cards.queue_free()
	cards = null
	fight_ui.visible = true


## A prova: o jogador não anda nem troca; o companheiro, que agora tem a carta, vem sozinho.
func _npc_test() -> void:
	stage = "test"
	_set_ctrl(1 - comp, true)
	fight_ui.get_node("Banner").visible = true
	banner_title.text = "A PROVA  ·  A CARTA FUNCIONA?"
	banner_sub.text = "só olha"
	pips.visible = false
	var who := String(units[comp].unit_name).to_upper()
	await _talk([
		"Vou botar uma bola laranja em você. Dessa vez você NÃO anda e NÃO troca de herói. Travei tudo.",
		"Só olha a %s. Eu não ensinei nada pra ela. Quem ensinou foi você, com a carta." % who,
	])
	while true:
		lock_move = true
		lock_swap = true
		_begin("stack", false, units[ctrl])
		_say("Parado aí. Olha a %s vindo." % who)
		var res: Array = await attempt_done
		lock_move = false
		lock_swap = false
		if res[0]:
			break
		_say("Ué. De novo.")
		await _sleep(1.5)
	_shop_hop()
	await _sleep(1.0)


func _to_black() -> void:
	stage = "black"
	finished = true
	black.visible = true
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := black.create_tween()
	tw.tween_property(black, "color:a", 1.0, 1.6)
	await tw.finished
	await _sleep(2.5)
	_black_ready = true
	black_hint.visible = true
	black_hint.modulate.a = 0.0
	black_hint.create_tween().tween_property(black_hint, "modulate:a", 0.5, 1.2)


func _leave() -> void:
	Knowledge.leave_sandbox()
	Knowledge.screen = "title"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main.tscn")


# ---------------------------------------------------------------- fala da Shopkeeper

func _fmt(text: String) -> String:
	var move := "%s %s %s %s" % [Binds.label("move_up"), Binds.label("move_left"), Binds.label("move_down"), Binds.label("move_right")]
	return text.replace("{move}", move).replace("{swap}", Binds.label("swap"))


## Mostra uma fala e segue em frente (fica na tela até a próxima).
func _say(text: String, wait := false) -> void:
	text = _fmt(text)
	_waiting = wait
	if cards != null:
		cards.tutor_say(text + ("   [ENTER]" if wait else ""))
		return
	talk_box.visible = true
	talk_text.text = text
	talk_next.visible = wait
	talk_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = talk_text.create_tween()
	_typing.tween_property(talk_text, "visible_ratio", 1.0, minf(1.1, text.length() * 0.014))


## Falas que esperam o jogador confirmar (ENTER, espaço ou clique na caixa), uma por vez.
func _talk(lines: Array) -> void:
	for line in lines:
		_say(line, true)
		await confirmed
	_waiting = false
	talk_next.visible = false


func _confirm() -> void:
	if not _waiting:
		return
	# ainda escrevendo: o primeiro toque só completa o texto
	if cards == null and _typing != null and _typing.is_running():
		_typing.kill()
		talk_text.visible_ratio = 1.0
		return
	confirmed.emit()


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _shop_hop() -> void:
	var tw := shop.create_tween()
	tw.tween_property(shop, "scale", Vector3(1.06, 0.92, 1.0), 0.08)
	tw.tween_property(shop, "scale", Vector3(0.96, 1.08, 1.0), 0.12)
	tw.tween_property(shop, "scale", Vector3.ONE, 0.16)


# ---------------------------------------------------------------- uma tentativa de exercício

## Começa uma tentativa. `demo`: os dois heróis andam sozinhos pra mostrar como se faz.
## `marked`: quem recebe a bola (sem isso, alterna a cada tentativa).
func _begin(kind: String, demo: bool, marked: Unit = null) -> void:
	_clear_ex()
	var n: int = wins[kind] + fails[kind]
	var flip: bool = n % 2 == 1 and not demo
	for u in units:
		if not u.alive:
			u.revive(1.0)
		u.hp = u.max_hp
		u.set_element(-1)
		u.set_action("", 0)
	if marked == null:
		marked = units[1 if flip else 0]
	var a := Vector3(-0.9, 0, -1.5)
	var b := Vector3(0.9, 0, -1.5)
	if kind == "stack":
		a = Vector3(-4.4, 0, -1.5)
		b = Vector3(4.4, 0, -1.5)
	elif kind == "pair":
		a = Vector3(-0.9, 0, 0.5)
		b = Vector3(0.9, 0, 0.5)
	units[0].position = b if flip else a
	units[1].position = a if flip else b
	for u in units:
		u.face(Vector3(0, 0, -1))
		_burst(u.position, u.color, 1.2)
	ex = {"kind": kind, "demo": demo, "t": 0.0, "total": DEMO_TIME[kind] if demo else TIME[kind], "marked": marked,
		"nodes": [], "goals": {}, "tick": 0.0, "fills": []}
	_moved = false
	_nudged = false
	match kind:
		"stack":
			ex["nodes"].append(_circle(STACK_COL, STACK_R, true))
			marked.set_element(0, STACK_COL)
			var other := _other(marked)
			ex["goals"][other] = marked.position + (other.position - marked.position).normalized() * 0.9
		"pair":
			for i in 2:
				var c := _circle(STACK_COL, PAIR_R, true)
				c.position = Vector3(DUMMY_POS[i].x, 0.04, DUMMY_POS[i].z)
				ex["nodes"].append(c)
				dummies[i].visible = true
				_burst(DUMMY_POS[i], STACK_COL, 1.4)
				ex["goals"][units[i]] = DUMMY_POS[i] + Vector3(0.9 if i == 0 else -0.9, 0, 0.5)
		"spread":
			ex["nodes"].append(_circle(SPREAD_COL, SPREAD_R, false))
			marked.set_element(0, SPREAD_COL)
			ex["goals"][units[0]] = Vector3(-4.6, 0, -1.5) if not flip else Vector3(4.6, 0, -1.5)
			ex["goals"][units[1]] = Vector3(4.6, 0, -1.5) if not flip else Vector3(-4.6, 0, -1.5)
		"link":
			var node := Fx.inst(fx_root, BoxMesh.new(), Fx.mat(LINK_COL, 3.0, true))
			ex["nodes"].append(node)
			ex["goals"][units[0]] = Vector3(-5.6, 0, -1.5) if not flip else Vector3(5.6, 0, -1.5)
			ex["goals"][units[1]] = Vector3(5.6, 0, -1.5) if not flip else Vector3(-5.6, 0, -1.5)
	_tick_ex(0.0)


func _other(u: Unit) -> Unit:
	return units[1 - u.idx]


## Círculo de mecânica no chão: disco claro, borda forte e (se `fill`) um miolo que enche com o tempo.
func _circle(col: Color, r: float, fill: bool) -> Node3D:
	var node := Node3D.new()
	fx_root.add_child(node)
	Fx.inst(node, Fx.disc(r), Fx.mat(Color(col.r, col.g, col.b, 0.14), 0.0, true))
	Fx.inst(node, Fx.torus(r - 0.1, r), Fx.mat(col, 3.0, true))
	if fill:
		ex_fill_add(Fx.inst(node, Fx.disc(r), Fx.mat(Color(col.r, col.g, col.b, 0.3), 0.0, true), Vector3(0, 0.01, 0)))
	return node


var _pending_fills: Array = []


func ex_fill_add(mi: MeshInstance3D) -> void:
	_pending_fills.append(mi)


func _clear_ex() -> void:
	if not ex.is_empty():
		for n in ex["nodes"]:
			if is_instance_valid(n):
				n.queue_free()
	ex = {}
	_pending_fills.clear()
	for d in dummies:
		d.visible = false
	for g in guides:
		g.visible = false
	for u in units:
		u.set_element(-1)
		u.set_action("", 0)


func _tick_ex(delta: float) -> void:
	if ex.is_empty():
		return
	ex["t"] += delta
	var kind: String = ex["kind"]
	var marked: Unit = ex["marked"]
	var k: float = clampf(ex["t"] / ex["total"], 0.01, 1.0) if ex["total"] > 0.0 else 0.0
	for f in _pending_fills:
		if is_instance_valid(f):
			f.scale = Vector3(k, 1, k)
	match kind:
		"stack", "spread":
			ex["nodes"][0].position = Vector3(marked.position.x, 0.04, marked.position.z)
		"link":
			if _tick_link(delta):
				return
	# quem não sabe o que fazer mostra "???", igual na luta
	if not ex["demo"]:
		for u in units:
			if not u.controlled and u.alive:
				u.set_action("???" if _ai_goal(u) == null else "→ " + marked.unit_name, 2 if _ai_goal(u) == null else 1)
		if not _nudged and not _moved and not lock_move and fails[kind] == 0 and ex["t"] > (4.0 if kind == "link" else ex["total"] * 0.5):
			_nudged = true
			_say(NUDGE[kind])
	_tick_guides()
	if ex["total"] > 0.0 and ex["t"] >= ex["total"]:
		_resolve()


## Corrente: estica entre os dois, queima a cada LINK_TICK e arrebenta em LINK_BREAK. true = acabou.
func _tick_link(delta: float) -> bool:
	var a := units[0]
	var b := units[1]
	var pa := a.position + Vector3(0, 1.0, 0)
	var pb := b.position + Vector3(0, 1.0, 0)
	var dist := pa.distance_to(pb)
	var node: MeshInstance3D = ex["nodes"][0]
	node.position = (pa + pb) * 0.5
	if dist > 0.05:
		node.look_at(pb, Vector3.UP)
	var k := clampf(dist / LINK_BREAK, 0.0, 1.0)
	var thick := lerpf(0.34, 0.07, k)
	node.scale = Vector3(thick, thick, maxf(dist, 0.1))
	(node.material_override as StandardMaterial3D).albedo_color = LINK_COL.lerp(Color.WHITE, k * k)
	if dist >= LINK_BREAK:
		_burst(pa, LINK_COL, 2.0)
		_burst(pb, LINK_COL, 2.0)
		_finish(true, "")
		return true
	# na demonstração a corrente não queima: é só pra ver o movimento
	if ex["demo"] or ex["t"] < 1.2:
		return false
	ex["tick"] += delta
	if ex["tick"] >= LINK_TICK:
		ex["tick"] = 0.0
		for u in units:
			u.hp = maxf(0.0, u.hp - LINK_DMG)
			u.flash_hit(0.12)
		if a.hp <= 0.0 or b.hp <= 0.0:
			for u in units:
				u.die()
			_finish(false, "burn")
			return true
	return false


func _resolve() -> void:
	var kind: String = ex["kind"]
	var marked: Unit = ex["marked"]
	var ok := false
	var why := ""
	match kind:
		"stack":
			ok = _other(marked).position.distance_to(marked.position) <= STACK_R
			why = "apart"
			_burst(marked.position, Color(1.0, 0.9, 0.6) if ok else STACK_COL, STACK_R + 0.6)
		"pair":
			var count := [0, 0]
			for i in 2:
				for u in units:
					if u.position.distance_to(DUMMY_POS[i]) <= PAIR_R:
						count[i] += 1
			ok = count[0] == 1 and count[1] == 1
			why = "same" if (count[0] == 2 or count[1] == 2) else "missing"
			for i in 2:
				_burst(DUMMY_POS[i], Color(1.0, 0.9, 0.6) if count[i] == 1 else STACK_COL, PAIR_R + 0.6)
		"spread":
			ok = _other(marked).position.distance_to(marked.position) > SPREAD_R
			why = "close"
			_burst(marked.position, SPREAD_COL.lightened(0.4) if ok else SPREAD_COL, 3.0)
	if not ok:
		for u in units:
			u.flash_hit(0.3)
	_finish(ok, why)


func _finish(ok: bool, why: String) -> void:
	_clear_ex()
	attempt_done.emit(ok, why)


## Pra onde este herói anda sozinho agora (null = fica parado).
## Na demonstração, os dois vão pra solução. Fora dela, só anda quem tem a carta da mecânica:
## é exatamente isso que a prova do final mostra.
func _ai_goal(u: Unit):
	if ex.is_empty():
		return null
	if ex["demo"]:
		return ex["goals"].get(u) if ex["t"] > 1.1 else null
	if u.controlled:
		return null
	if ex["kind"] == "stack" and Knowledge.has(u.hero, "stack") and ex["marked"] != u:
		var m: Unit = ex["marked"]
		var side := u.position - m.position
		side = side.normalized() * 0.9 if side.length() > 0.05 else Vector3(0.9, 0, 0)
		return m.position + side
	return null


## Última dica: anéis azuis no chão mostrando onde o herói controlado tem que ir.
func _tick_guides() -> void:
	var pts: Array = []
	if not ex.is_empty() and not ex["demo"] and not lock_move and fails[ex["kind"]] >= HINTS[ex["kind"]].size():
		var me := units[ctrl]
		var him := _other(me)
		var away := me.position - him.position
		away = away.normalized() if away.length() > 0.2 else Vector3(1 if me.position.x >= 0.0 else -1, 0, 0)
		match ex["kind"]:
			"stack":
				pts.append(him.position if ex["marked"] == him else me.position)
			"pair":
				pts.append(DUMMY_POS[0] + Vector3(0.9, 0, 0.5))
				pts.append(DUMMY_POS[1] + Vector3(-0.9, 0, 0.5))
			"spread":
				pts.append(_in_arena(him.position + away * (SPREAD_R + 1.2)))
			"link":
				pts.append(_in_arena(him.position + away * (LINK_BREAK + 0.4)))
	for i in guides.size():
		guides[i].visible = i < pts.size()
		if i < pts.size():
			guides[i].position = Vector3(pts[i].x, 0.06, pts[i].z)
			guides[i].scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 6.0))


func _in_arena(p: Vector3) -> Vector3:
	var flat := Vector2(p.x, p.z)
	if flat.length() > ARENA_R - 0.3:
		flat = flat.normalized() * (ARENA_R - 0.3)
	return Vector3(flat.x, 0, flat.y)


func _burst(p: Vector3, col: Color, radius: float) -> void:
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.6), 2.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(1.0), m, p + Vector3(0, 0.3, 0))
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.5, radius), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)


# ---------------------------------------------------------------- heróis: andar e trocar

func _set_ctrl(i: int, force := false) -> void:
	if i == ctrl or i < 0 or i >= units.size():
		return
	if not force and (lock_swap or finished or cards != null or (not ex.is_empty() and ex["demo"])):
		return
	units[ctrl].set_controlled(false)
	ctrl = i
	units[i].set_controlled(true)
	_burst(units[i].position, units[i].color, 1.6)


func _input_dir() -> Vector3:
	var d := Vector3.ZERO
	if Input.is_action_pressed("move_up"): d.z -= 1.0
	if Input.is_action_pressed("move_down"): d.z += 1.0
	if Input.is_action_pressed("move_left"): d.x -= 1.0
	if Input.is_action_pressed("move_right"): d.x += 1.0
	return d.normalized()


func _try_dash() -> void:
	var u := units[ctrl]
	if lock_move or not u.alive or u.dash_cd > 0.0 or cards != null or (not ex.is_empty() and ex["demo"]):
		return
	var d := _input_dir()
	if d == Vector3.ZERO:
		d = Vector3(sin(u.visual.rotation.y) * -1.0, 0, cos(u.visual.rotation.y) * -1.0)
	u.dash_dir = d.normalized()
	u.dash_t = 0.22
	u.dash_cd = 0.9
	u.dash_fx()


func _tick_units(delta: float) -> void:
	var demo: bool = not ex.is_empty() and ex["demo"]
	for u in units:
		if not u.alive:
			continue
		u.dash_cd = maxf(0.0, u.dash_cd - delta)
		if u.controlled and not demo:
			if lock_move or cards != null or finished:
				continue
			if u.dash_t > 0.0:
				u.dash_t -= delta
				u.position += u.dash_dir * 19.0 * delta
				_moved = true
			else:
				var d := _input_dir()
				if d != Vector3.ZERO:
					u.position += d * u.speed * delta
					u.face(d)
					_moved = true
		else:
			var goal = _ai_goal(u)
			if goal != null:
				var to: Vector3 = goal - u.position
				to.y = 0.0
				if to.length() > 0.08:
					u.position += to.normalized() * minf(to.length(), u.speed * delta)
					u.face(to)
		u.position = _in_arena(u.position) if Vector2(u.position.x, u.position.z).length() > ARENA_R else u.position


func _process(delta: float) -> void:
	_t += delta
	shop.position.y = 6.3 + sin(_t * 1.5) * 0.15
	_tick_units(delta)
	_tick_ex(delta)
	for i in party_cards.size():
		var u := units[i]
		var card: CharacterCard = party_cards[i]
		if card.hp != u.hp or card.max_hp != u.max_hp:
			card.max_hp = u.max_hp
			card.hp = u.hp
		if card.state_text != u.action_text or card.state_kind != u.action_kind:
			card.state_kind = u.action_kind
			card.state_text = u.action_text
		if card.selected != u.controlled:
			card.selected = u.controlled
		if card.dead != (not u.alive):
			card.dead = not u.alive
	if talk_next.visible:
		# a placa fica sólida (papel não pisca): só balança um pouco pra chamar o olho
		talk_next.position.y = 94.0 + 2.5 * sin(_t * 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed or event.is_echo():
		return
	if stage == "black":
		if _black_ready and event is InputEventKey:
			_leave()
		return
	if event.is_action_pressed("pause"):
		_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _waiting:
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("swap"):
		_set_ctrl(1 - ctrl)
	elif event.is_action_pressed("hero_1"):
		_set_ctrl(0)
	elif event.is_action_pressed("hero_2"):
		_set_ctrl(1)
	elif event.is_action_pressed("dash"):
		_try_dash()


# ---------------------------------------------------------------- pause e opções

func _pause() -> void:
	if finished:
		return
	get_tree().paused = true
	pause_menu.open()


func _resume() -> void:
	pause_menu.close()
	get_tree().paused = false


# ---------------------------------------------------------------- cenário

func _build_world() -> void:
	# o mesmo palco da luta (game.gd), sem a boss
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
	cam.current = true

	floor_mat = ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/floor.gdshader")
	floor_mat.set_shader_parameter("arena_r", ARENA_R + 0.35)
	floor_mat.set_shader_parameter("melee_on", 0.0)
	Fx.inst(self, Fx.disc(ARENA_R + 0.7, 0.5), floor_mat, Vector3(0, -0.25, 0))
	for i in 9:
		var a := lerpf(-1.25, 1.25, i / 8.0)
		var p := Vector3(sin(a) * 26.0, 7.0, -cos(a) * 26.0 - 2.0)
		var col := Color(0.55, 0.25, 1.0) if i % 2 == 0 else Color(0.25, 0.5, 1.0)
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 22.0 + (i % 3) * 5.0, 0.35)
		Fx.inst(self, b, Fx.mat(col, 1.6, true), p)

	fx_root = Node3D.new()
	add_child(fx_root)

	# a instrutora, no lugar onde ficaria a boss, de frente pros dois
	shop = Sprite3D.new()
	shop.texture = load(ART)
	shop.pixel_size = 13.0 / shop.texture.get_height()
	shop.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	shop.shaded = false
	shop.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	shop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shop.position = Vector3(0, 6.3, -13.0)
	add_child(shop)
	Fx.inst(self, Fx.disc(3.6), Fx.mat(Color(0.42, 0.22, 0.86, 0.35), 0.0, true), Vector3(0, 0.03, -13.0))

	# bonecos de treino: seguram as duas bolas laranjas do segundo exercício
	for i in 2:
		var d := Node3D.new()
		d.position = DUMMY_POS[i]
		add_child(d)
		var wood := Fx.mat(Color(0.78, 0.6, 0.4), 0.1)
		Fx.inst(d, Fx.cyl(0.16, 0.2, 1.5), wood, Vector3(0, 0.75, 0))
		Fx.inst(d, Fx.sphere(0.34), wood, Vector3(0, 1.75, 0))
		var arm := BoxMesh.new()
		arm.size = Vector3(1.3, 0.16, 0.16)
		Fx.inst(d, arm, wood, Vector3(0, 1.15, 0))
		Fx.inst(d, Fx.sphere(0.26), Fx.mat(STACK_COL, 3.0, true), Vector3(0, 2.6, 0))
		d.visible = false
		dummies.append(d)

	for i in 2:
		var g := Node3D.new()
		add_child(g)
		Fx.inst(g, Fx.torus(0.78, 0.95), Fx.mat(GUIDE_COL, 3.5, true))
		var l := Fx.label(g, "AQUI", Vector3(0, 1.0, 0), 44)
		l.modulate = GUIDE_COL
		g.visible = false
		guides.append(g)


func _build_units() -> void:
	var home := [Vector3(-1.6, 0, -1.0), Vector3(1.6, 0, -1.0)]
	for i in 2:
		var u := Unit.new()
		add_child(u)
		u.setup(i, GAME.UNIT_DEFS[HEROES[i]])
		u.hero = HEROES[i]
		u.position = home[i]
		u.face(Vector3(0, 0, -1))
		units.append(u)
	ctrl = 0
	units[0].set_controlled(true)


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	fight_ui = Control.new()
	fight_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fight_ui)

	# retratos: clicar troca de herói
	var party := VBoxContainer.new()
	party.add_theme_constant_override("separation", 10)
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(party)
	for i in units.size():
		var u := units[i]
		var card: CharacterCard = preload("res://ui/character_card.tscn").instantiate()
		card.index = i + 1
		card.char_name = u.unit_name
		card.accent = u.color
		card.face = load("res://assets/portraits/%s_face.png" % u.key)
		party.add_child(card)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_set_ctrl(i))
		party_cards.append(card)
	party.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 22)

	# faixa do exercício: nome, o que fazer e os três acertos
	var top := _anchored(fight_ui, Vector2(0.5, 0.0), Vector2(560, 84), Vector2(0, 16))
	var plate := Ink.panel(Ink.NAVY, 13)
	plate.size = Vector2(560, 84)
	top.add_child(plate)
	banner_title = Ink.title("", 26)
	banner_title.position = Vector2(26, 10)
	banner_title.size = Vector2(420, 34)
	top.add_child(banner_title)
	banner_sub = Ink.text("", 17, Ink.COIN)
	banner_sub.position = Vector2(28, 46)
	banner_sub.size = Vector2(380, 24)
	top.add_child(banner_sub)
	pips = Control.new()
	pips.position = Vector2(420, 22)
	pips.size = Vector2(120, 40)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(_draw_pips)
	top.add_child(pips)
	top.name = "Banner"

	demo_tag = _anchored(fight_ui, Vector2(0.5, 0.0), Vector2(420, 46), Vector2(0, 108))
	var dplate := Ink.panel(Ink.COIN, 5)
	dplate.size = Vector2(420, 46)
	demo_tag.add_child(dplate)
	var dtext := Ink.title("DEMONSTRAÇÃO  ·  só olha", 22, Ink.OUT)
	dtext.size = Vector2(420, 44)
	dtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dtext.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demo_tag.add_child(dtext)
	demo_tag.visible = false

	# caixa de fala: busto da Shopkeeper, nome e texto
	talk_box = _anchored(fight_ui, Vector2(0.5, 1.0), Vector2(900, 124), Vector2(0, -16))
	talk_box.mouse_filter = Control.MOUSE_FILTER_STOP
	talk_box.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_confirm())
	var tplate := Ink.panel(Ink.NAVY, 9)
	tplate.size = Vector2(900, 124)
	talk_box.add_child(tplate)
	var frame := Ink.panel(Ink.GRAPE, 21)
	frame.position = Vector2(-16, -56)
	frame.size = Vector2(168, 168)
	frame.rotation = -0.04
	talk_box.add_child(frame)
	var clip := Control.new()
	clip.position = Vector2(8, 8)
	clip.size = Vector2(152, 152)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(clip)
	var bust := TextureRect.new()
	bust.texture = load(BUST)
	bust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bust.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bust.position = Vector2(-18, -4)
	bust.size = Vector2(190, 180)
	bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(bust)
	var name_tag := Ink.panel(Ink.OUT, 7)
	name_tag.position = Vector2(170, -18)
	name_tag.size = Vector2(190, 36)
	talk_box.add_child(name_tag)
	var name_l := Ink.title("SHOPKEEPER", 19, Ink.COIN)
	name_l.size = Vector2(190, 34)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_tag.add_child(name_l)
	talk_text = Ink.text("", 20)
	talk_text.position = Vector2(176, 20)
	talk_text.size = Vector2(700, 84)
	talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	talk_box.add_child(talk_text)
	# "ENTER" numa placa de papel inclinada, como na tela de fim da luta (regra 1 do UiStyle:
	# texto nunca fica solto, sempre em cima de uma placa INK ou PAPER)
	# Embaixo dela, uma sombra dura e escura, deslocada pra baixo e pra esquerda (sem desfoque).
	talk_next = Control.new()
	talk_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talk_next.position = Vector2(756, 94)
	talk_box.add_child(talk_next)
	for ply in 2:
		var slab := UiStyle.slab(Ink.OUT if ply == 0 else UiStyle.PAPER, UiStyle.SKEW, 20, 3)
		var word := UiStyle.text("ENTER  ▶", 15, UiStyle.INK)
		word.modulate.a = float(ply)  # a sombra só precisa do tamanho do texto
		slab.add_child(word)
		slab.position = Vector2(-6, 8) if ply == 0 else Vector2.ZERO
		talk_next.add_child(slab)
	talk_box.visible = false

	keys_hint = Ink.text("", 14, UiStyle.DIM)
	keys_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	keys_hint.offset_left = -330
	keys_hint.offset_right = -18
	keys_hint.offset_top = 16
	keys_hint.offset_bottom = 90
	keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fight_ui.add_child(keys_hint)
	_refresh_keys()

	# carta ganha: aparece no meio da tela por um instante
	card_pop = _anchored(ui, Vector2(0.5, 0.5), Vector2(360, 260), Vector2(0, -40))
	card_pop.visible = false

	blocker = Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	ui.add_child(blocker)

	black = ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.visible = false
	ui.add_child(black)
	black_hint = UiStyle.slab(UiStyle.PAPER, UiStyle.SKEW, 20, 3)
	black_hint.add_child(UiStyle.text("ENTER", 15, UiStyle.INK))
	black_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	black_hint.offset_top -= 44
	black_hint.offset_bottom -= 44
	black_hint.visible = false
	black.add_child(black_hint)

	pause_menu = PauseMenu.new()
	pause_menu.in_tutorial = true
	ui.add_child(pause_menu)
	pause_menu.resume_pressed.connect(_resume)
	pause_menu.title_pressed.connect(_leave)
	options = OptionsScreen.new()
	ui.add_child(options)
	pause_menu.options_pressed.connect(func():
		pause_menu.visible = false
		options.open(units[ctrl].hero))
	options.closed.connect(func():
		pause_menu.back_from_options()
		_refresh_keys())


## Caixa de tamanho fixo presa num ponto da tela (anchor 0..1), com deslocamento em pixels.
func _anchored(parent: Control, anchor: Vector2, s: Vector2, shift: Vector2) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = -s.x * anchor.x + shift.x
	c.offset_right = s.x * (1.0 - anchor.x) + shift.x
	c.offset_top = -s.y * anchor.y + shift.y
	c.offset_bottom = s.y * (1.0 - anchor.y) + shift.y
	parent.add_child(c)
	return c


func _refresh_keys() -> void:
	keys_hint.text = _fmt("{move}  andar\n{swap}  trocar de herói\n%s  desvio   ·   %s  pause" % [Binds.label("dash"), Binds.label("pause")])


func _set_banner(kind: String) -> void:
	var top: Control = fight_ui.get_node("Banner")
	top.visible = kind != ""
	if kind == "":
		return
	banner_title.text = BANNER[kind][0]
	banner_sub.text = BANNER[kind][1]
	pips.visible = true
	pips.queue_redraw()


func _draw_pips() -> void:
	var n: int = wins.get(stage, 0)
	for i in NEED:
		var c := Vector2(20 + i * 38, 20)
		pips.draw_circle(c, 15, Ink.OUT)
		pips.draw_circle(c, 11, Ink.COIN if i < n else Ink.NIGHT)


## "Carta nova": a carta ganha estampa no meio da tela e some.
func _show_card(id: String) -> void:
	for c in card_pop.get_children():
		c.queue_free()
	var plate := Ink.panel(Ink.GRAPE, 17)
	plate.size = Vector2(360, 260)
	card_pop.add_child(plate)
	var t := Ink.title("CARTA NOVA", 26, Ink.COIN)
	t.position = Vector2(0, 12)
	t.size = Vector2(360, 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_pop.add_child(t)
	var cv := CardView.make(id)
	cv.position = Vector2(180 - CardView.W * 0.5, 54)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_pop.add_child(cv)
	var n := Ink.title(String(Knowledge.CARDS[id]["name"]).to_upper(), 20)
	n.position = Vector2(0, 216)
	n.size = Vector2(360, 30)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_pop.add_child(n)
	card_pop.visible = true
	card_pop.pivot_offset = Vector2(180, 130)
	card_pop.scale = Vector2.ONE * 0.6
	card_pop.modulate.a = 0.0
	var tw := card_pop.create_tween().set_parallel(true)
	tw.tween_property(card_pop, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_pop, "modulate:a", 1.0, 0.12)
	await _sleep(1.9)
	var out := card_pop.create_tween()
	out.tween_property(card_pop, "modulate:a", 0.0, 0.2)
	await out.finished
	card_pop.visible = false
