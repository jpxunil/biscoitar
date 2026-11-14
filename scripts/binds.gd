class_name Binds
## Sistema central de atalhos. Toda ação do jogador é uma entrada de ACTIONS e vira uma ação
## do InputMap do Godot; o código do jogo só pergunta "a ação X foi apertada?", nunca "a tecla Y?".
##   event.is_action_pressed("skill_2")   Input.is_action_pressed("move_up")   Binds.label("swap")
## Cada ação tem até SLOTS atalhos (principal e alternativo). Um atalho é um inteiro:
##   > 0  tecla física (Key)      < 0  botão do mouse (-MouseButton)      0  vazio
## Os slots de habilidade são POSIÇÕES da barra (skill_1..skill_6), não habilidades: o que cada
## slot faz depende do herói (e do modo dele), o atalho é sempre o do slot.
## Quem salva em disco é o Settings (scripts/settings.gd).

const SLOTS := 2
const SKILL_SLOTS := 6

## Ordem = ordem na tela de atalhos. `need`: a ação não pode ficar sem atalho nenhum.
const ACTIONS := [
	{"id": "skill_1", "name": "Slot 1", "group": "HABILIDADES", "keys": [KEY_J, 0]},
	{"id": "skill_2", "name": "Slot 2", "group": "HABILIDADES", "keys": [KEY_K, 0]},
	{"id": "skill_3", "name": "Slot 3", "group": "HABILIDADES", "keys": [KEY_L, 0]},
	{"id": "skill_4", "name": "Slot 4", "group": "HABILIDADES", "keys": [KEY_U, 0]},
	{"id": "skill_5", "name": "Slot 5", "group": "HABILIDADES", "keys": [KEY_O, 0]},
	{"id": "skill_6", "name": "Slot 6", "group": "HABILIDADES", "keys": [KEY_P, 0]},
	{"id": "limit", "name": "Limit Break", "group": "HABILIDADES", "keys": [KEY_I, 0]},
	{"id": "swap", "name": "Trocar de personagem", "group": "PERSONAGENS", "keys": [KEY_TAB, 0]},
	{"id": "hero_1", "name": "Controlar herói 1", "group": "PERSONAGENS", "keys": [KEY_1, 0]},
	{"id": "hero_2", "name": "Controlar herói 2", "group": "PERSONAGENS", "keys": [KEY_2, 0]},
	{"id": "hero_3", "name": "Controlar herói 3", "group": "PERSONAGENS", "keys": [KEY_3, 0]},
	{"id": "hero_4", "name": "Controlar herói 4", "group": "PERSONAGENS", "keys": [KEY_4, 0]},
	{"id": "move_up", "name": "Andar pra cima", "group": "MOVIMENTO", "keys": [KEY_W, KEY_UP], "need": true},
	{"id": "move_down", "name": "Andar pra baixo", "group": "MOVIMENTO", "keys": [KEY_S, KEY_DOWN], "need": true},
	{"id": "move_left", "name": "Andar pra esquerda", "group": "MOVIMENTO", "keys": [KEY_A, KEY_LEFT], "need": true},
	{"id": "move_right", "name": "Andar pra direita", "group": "MOVIMENTO", "keys": [KEY_D, KEY_RIGHT], "need": true},
	{"id": "dash", "name": "Desvio", "group": "MOVIMENTO", "keys": [KEY_SPACE, 0]},
	{"id": "jump", "name": "Pulo", "group": "MOVIMENTO", "keys": [KEY_C, 0]},
	{"id": "target_1", "name": "Alvo: herói 1", "group": "ALVO DE SUPORTE", "keys": [KEY_F1, 0]},
	{"id": "target_2", "name": "Alvo: herói 2", "group": "ALVO DE SUPORTE", "keys": [KEY_F2, 0]},
	{"id": "target_3", "name": "Alvo: herói 3", "group": "ALVO DE SUPORTE", "keys": [KEY_F3, 0]},
	{"id": "target_4", "name": "Alvo: herói 4", "group": "ALVO DE SUPORTE", "keys": [KEY_F4, 0]},
	{"id": "order_gather", "name": "Ordem: juntar", "group": "ORDENS PRA PARTY", "keys": [KEY_Q, 0]},
	{"id": "order_spread", "name": "Ordem: espalhar", "group": "ORDENS PRA PARTY", "keys": [KEY_E, 0]},
	{"id": "order_hold", "name": "Ordem: segurar", "group": "ORDENS PRA PARTY", "keys": [KEY_R, 0]},
	{"id": "order_atk", "name": "Ordem: atacar", "group": "ORDENS PRA PARTY", "keys": [KEY_F, 0]},
	{"id": "pause", "name": "Pause", "group": "SISTEMA", "keys": [KEY_ESCAPE, 0], "need": true},
]

## Botões do mouse que não podem virar atalho: são os da própria interface.
const MOUSE_TAKEN := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
const MOUSE_NAME := {MOUSE_BUTTON_MIDDLE: "MOUSE 3", MOUSE_BUTTON_XBUTTON1: "MOUSE 4", MOUSE_BUTTON_XBUTTON2: "MOUSE 5"}
const KEY_NAME := {
	KEY_ESCAPE: "ESC", KEY_SPACE: "ESPAÇO", KEY_TAB: "TAB", KEY_ENTER: "ENTER", KEY_KP_ENTER: "ENTER NUM",
	KEY_UP: "SETA CIMA", KEY_DOWN: "SETA BAIXO", KEY_LEFT: "SETA ESQ", KEY_RIGHT: "SETA DIR", KEY_SHIFT: "SHIFT", KEY_CTRL: "CTRL", KEY_ALT: "ALT",
	KEY_BACKSPACE: "BACKSPACE", KEY_DELETE: "DELETE", KEY_CAPSLOCK: "CAPS", KEY_QUOTELEFT: "`",
}

## id -> [principal, alternativo]
static var keys: Dictionary = {}
static var _index: Dictionary = {}


## Garante que os atalhos existem (padrão) e estão no InputMap. Pode chamar quantas vezes quiser.
static func boot() -> void:
	if keys.is_empty():
		for a in ACTIONS:
			_index[a["id"]] = a
			keys[a["id"]] = (a["keys"] as Array).duplicate()
		apply()


static func def(id: String) -> Dictionary:
	boot()
	return _index[id]


static func needed(id: String) -> bool:
	return bool(def(id).get("need", false))


## Passa os atalhos atuais pro InputMap do Godot. É isso que faz o remapeamento valer no jogo.
static func apply() -> void:
	for id in keys:
		if InputMap.has_action(id):
			InputMap.action_erase_events(id)
		else:
			InputMap.add_action(id)
		for code in keys[id]:
			var e := event_of(code)
			if e:
				InputMap.action_add_event(id, e)


static func event_of(code: int) -> InputEvent:
	if code > 0:
		var k := InputEventKey.new()
		k.physical_keycode = code as Key
		return k
	if code < 0:
		var m := InputEventMouseButton.new()
		m.button_index = -code as MouseButton
		return m
	return null


## Código de atalho de um evento de entrada, ou 0 se o evento não serve pra atalho.
static func code_of(event: InputEvent) -> int:
	if event is InputEventKey:
		return int(event.physical_keycode)
	if event is InputEventMouseButton and event.button_index not in MOUSE_TAKEN:
		return -int(event.button_index)
	return 0


static func code_name(code: int) -> String:
	if code == 0:
		return "—"
	if code < 0:
		return MOUSE_NAME.get(-code, "MOUSE %d" % -code)
	if KEY_NAME.has(code):
		return KEY_NAME[code]
	return OS.get_keycode_string(code as Key).to_upper()


## Texto do atalho principal da ação, pra mostrar no HUD (cai no alternativo se o principal está vazio).
static func label(id: String) -> String:
	boot()
	for code in keys[id]:
		if code != 0:
			return code_name(code)
	return "—"


## Qual ação (e slot) já usa esse atalho. {} se está livre. `skip_id`/`skip_slot` ignoram o próprio lugar.
static func find(code: int, skip_id := "", skip_slot := -1) -> Dictionary:
	boot()
	if code == 0:
		return {}
	for a in ACTIONS:
		var id: String = a["id"]
		for s in SLOTS:
			if keys[id][s] == code and not (id == skip_id and s == skip_slot):
				return {"id": id, "slot": s}
	return {}


## Dá pra pôr `code` neste slot? Só não dá quando ele é o único atalho de uma ação obrigatória
## e este slot está vazio: não haveria tecla pra dar em troca.
static func can_assign(id: String, slot: int, code: int) -> bool:
	boot()
	var other := find(code, id, slot)
	if other.is_empty() or other["id"] == id:
		return true
	return not (needed(other["id"]) and count(other["id"]) == 1 and keys[id][slot] == 0)


## Põe `code` no slot da ação. Se outra ação usava esse atalho, ela perde: quem chama já confirmou
## com o jogador. Uma ação obrigatória que ficaria sem nada herda o atalho antigo deste slot (troca).
## Devolve false (sem mudar nada) quando can_assign diz que não dá.
static func assign(id: String, slot: int, code: int) -> bool:
	if not can_assign(id, slot, code):
		return false
	var old: int = keys[id][slot]
	var other := find(code, id, slot)
	if not other.is_empty():
		var oid: String = other["id"]
		keys[oid][other["slot"]] = 0
		if oid != id and needed(oid) and count(oid) == 0:
			keys[oid][other["slot"]] = old
	keys[id][slot] = code
	apply()
	return true


static func count(id: String) -> int:
	var n := 0
	for code in keys[id]:
		if code != 0:
			n += 1
	return n


## Dá pra remover o atalho deste slot? Ação obrigatória não pode ficar sem nenhum.
static func can_clear(id: String, slot: int) -> bool:
	boot()
	if keys[id][slot] == 0:
		return false
	return not needed(id) or count(id) > 1


static func clear(id: String, slot: int) -> bool:
	if not can_clear(id, slot):
		return false
	keys[id][slot] = 0
	apply()
	return true


static func is_default(id: String) -> bool:
	return keys[id] == def(id)["keys"]


## Atalhos padrão da ação que hoje estão em uso por OUTRA ação (o reset individual precisa avisar).
static func reset_conflicts(id: String) -> Array:
	var out: Array = []
	for code in def(id)["keys"]:
		var o := find(code, id, -1)
		if not o.is_empty() and o["id"] != id:
			out.append(o)
	return out


## Volta a ação pro padrão, tirando o atalho de quem estiver usando (já confirmado com o jogador).
static func reset(id: String) -> void:
	boot()
	var want: Array = def(id)["keys"]
	var freed: Array = (keys[id] as Array).duplicate()
	keys[id] = [0, 0]
	for s in SLOTS:
		var o := find(want[s])
		if not o.is_empty():
			var oid: String = o["id"]
			keys[oid][o["slot"]] = 0
			if needed(oid) and count(oid) == 0:
				# devolve um dos atalhos que esta ação acabou de largar
				for f in freed:
					if f != 0 and find(f).is_empty() and f not in want:
						keys[oid][o["slot"]] = f
						break
		keys[id][s] = want[s]
	apply()


static func reset_all() -> void:
	boot()
	for a in ACTIONS:
		keys[a["id"]] = (a["keys"] as Array).duplicate()
	apply()


## Pro arquivo de configuração: só o que o jogador mudou.
static func to_dict() -> Dictionary:
	boot()
	var out := {}
	for a in ACTIONS:
		if not is_default(a["id"]):
			out[a["id"]] = (keys[a["id"]] as Array).duplicate()
	return out


static func from_dict(d: Dictionary) -> void:
	reset_all()
	for id in d:
		if not _index.has(id) or not (d[id] is Array):
			continue  # ação que não existe mais
		for s in mini(SLOTS, d[id].size()):
			keys[id][s] = int(d[id][s])
	# arquivo mexido à mão: um atalho repetido fica só com a primeira ação que aparece
	var seen := {}
	for a in ACTIONS:
		for s in SLOTS:
			var code: int = keys[a["id"]][s]
			if code == 0:
				continue
			if seen.has(code):
				keys[a["id"]][s] = 0
			seen[code] = true
	for a in ACTIONS:
		if needed(a["id"]) and count(a["id"]) == 0:
			keys[a["id"]] = (a["keys"] as Array).duplicate()
	apply()
