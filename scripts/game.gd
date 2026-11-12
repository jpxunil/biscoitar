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
	{"name": "Tank", "range": MELEE_RANGE, "key": "tank", "color": Color(0.3, 0.5, 1.0), "hp": 160.0, "melee": true, "ai_dps": 6.0, "hit": 8.0},
	{"name": "Healer", "range": RANGED_RANGE, "key": "healer", "color": Color(0.4, 0.95, 0.55), "hp": 90.0, "melee": false, "ai_dps": 3.0, "hit": 6.0},
	{"name": "Assassina", "range": MELEE_RANGE, "key": "assassina", "color": Color(0.78, 0.38, 1.0), "hp": 100.0, "melee": true, "ai_dps": 10.0, "hit": 17.0},
	{"name": "Maga", "range": RANGED_RANGE, "key": "maga", "color": Color(1.0, 0.72, 0.25), "hp": 90.0, "melee": false, "ai_dps": 8.0, "hit": 11.0},
]

## Cada passo: t = tipo, dur = quanto dura até o próximo. Ataques de desvio:
## stack need 4 (um círculo laranja: todos os vivos dentro) · stack need 2 (dois círculos: exatamente 2 em cada)
## buster (golpe pesado no alvo 1: o Tank precisa de Mitigação)
## circles (n alvos) · line (n faixas largas) · knives (n faixas finas e rápidas)
## core (explosão no centro: saia) · nova (explosão nas bordas: vá pro centro)
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
	{"t": "core", "dur": 3.0},
	{"t": "idle", "dur": 1.0},
	{"t": "circles", "n": 3, "dur": 2.4},
	{"t": "line", "n": 2, "dur": 2.8},
	{"t": "idle", "dur": 1.0},
	{"t": "stack", "need": 2, "dur": 5.5},
	{"t": "idle", "dur": 1.0},
	{"t": "nova", "dur": 3.4},
	{"t": "idle", "dur": 1.2},
	{"t": "buster", "dur": 3.0},
	{"t": "knives", "n": 4, "dur": 2.4},
	{"t": "circles", "n": 2, "dur": 2.0},
	{"t": "idle", "dur": 1.5},
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
## Uma lista por herói, na ordem das teclas J, K, L, U. null = tecla sem habilidade.
## U é o Bora Biscoitar, só do Tank: é ele quem puxa o boss pra si.
const SKILLS := {
	"tank": [{"name": "Golpe", "cd": 1.0, "dmg": 22.0},
		{"name": "Mitigação", "cd": 10.0}, null, PROVOKE],
	"healer": [{"name": "Faísca", "cd": 1.0, "dmg": 14.0, "cast": 0.5},
		{"name": "Cura", "cd": 4.0, "cast": 0.5}, {"name": "Reviver", "cd": 25.0, "cast": 1.5},
		{"name": "Cura em Área", "cd": 8.0, "cast": 1.0}],
	"assassina": [{"name": "Corte", "cd": 1.0, "dmg": 46.0},
		{"name": "Execução", "cd": 7.0, "dmg": 70.0}, {"name": "Lâmina Final", "cd": 20.0, "dmg": 260.0, "cast": 2.0}, null],
	"maga": [{"name": "Raio", "cd": 1.0, "dmg": 34.0, "cast": 0.5},
		{"name": "Meteoro", "cd": 7.0, "dmg": 55.0, "cast": 0.5}, {"name": "Ruína", "cd": 20.0, "dmg": 240.0, "cast": 2.0}, null],
}
## Cast curto trava o personagem no lugar; cast longo pode ser interrompido andando.
const LOCKED_CAST := 1.0
## DPS da IA com a carta roxa Rotação (sem ela vale o ai_dps de UNIT_DEFS).
const ROTATION_DPS := {"tank": 10.0, "healer": 6.0, "assassina": 22.0, "maga": 16.0}
## Cura em Área: metade da Cura, em todo mundo perto do Healer.
const AOE_HEAL_R := 6.0
const HEAL_PLAYER := 55.0
const HEAL_AI := 45.0
const COOKIE_COL := Color(0.86, 0.6, 0.3)
const SKILL_KEYS := ["J", "K", "L", "U"]
const AUTO_EVERY := 2.0
const AUTO_DMG := 6.0
const GUARD_TIME := 4.0
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

const BOSSES := [
	{"name": "MINI-CHAN", "hp": 7400.0, "enrage": 120.0, "steps": STEPS_DODGE, "hair": Color(0.25, 0.8, 0.9), "scale": 0.95},
	{"name": "PROTÓTIPO-CHAN", "hp": 10400.0, "enrage": 150.0, "steps": STEPS_ELEMENT, "elements": true, "hair": Color(1.0, 0.38, 0.66), "scale": 1.2},
]

var units: Array[Unit] = []
var ctrl := 0
var swap_cd := 0.0
var lb := 0.0  # carga do Limit Break, 0..1, da party toda
var enrage := 120.0
var swap_test := 0.0  # só pra teste: --swaptest=N troca de herói aos N segundos
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
var stack_need := 4
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
var hit_count := {}  # só pro relatório de teste: quantas vezes cada motivo acertou alguém
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
	for a in args:
		if a.begins_with("--boss="):
			Knowledge.boss = clampi(int(a.trim_prefix("--boss=")), 0, BOSSES.size() - 1)
			Knowledge.boss_unlocked = maxi(Knowledge.boss_unlocked, Knowledge.boss)
	boss_def = BOSSES[Knowledge.boss]
	steps = boss_def["steps"]
	boss_max = boss_def["hp"]
	enrage = boss_def["enrage"]
	for a in args:
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
		for i in 4:
			var d := Knowledge.deck(i)
			d["yellow"] = [["dodge", "provoke"], ["dodge", "instinct"], ["dodge"], ["dodge"]][i]
			if Knowledge.boss == 0:
				d["white"] = [
					{"t": "stack", "a": "to_marked"},
					{"t": "stack2", "a": "pair_up"},
					{"t": "buster", "a": "mitigate"},
				]
			else:
				d["white"] = [
					{"t": "got_element", "a": "zone_opp"},
					{"t": "zones_done", "a": "partner"},
					{"t": "cata", "a": "shelter"},
				]
	if args.has("--naive"):
		autoplay = true
		auto_left = 90.0
		Engine.time_scale = 6.0
	if args.has("--known"):
		for id in Knowledge.TRIGGERS:
			Knowledge.triggers_known[id] = true
		for id in Knowledge.ACTIONS:
			Knowledge.actions_known[id] = true
		for id in Knowledge.YELLOW:
			Knowledge.yellow_known[id] = true
		Knowledge.purple_known = true
		for def in UNIT_DEFS:
			Knowledge.dps_known[def["key"]] = true
		Knowledge.set_white(0, 0, "got_element", "zone_opp")
		Knowledge.toggle_yellow(1, "dodge")
		Knowledge.toggle_purple(2, "mark", "assassina")
		Knowledge.toggle_purple(3, "dps", "maga")
	prep = not autoplay
	hud.set_prep(prep)
	for a in args:
		if a.begins_with("--swaptest="):
			swap_test = float(a.trim_prefix("--swaptest="))
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
	boss.position = Vector3(0, 0, -13.3)
	boss.scale = Vector3.ONE * float(boss_def["scale"])
	add_child(boss)

	fx_root = Node3D.new()
	add_child(fx_root)


func _build_units() -> void:
	for i in 4:
		var u := Unit.new()
		add_child(u)
		u.setup(i, UNIT_DEFS[i])
		u.position = START_POS[i]
		u.face(BOSS_POINT - u.position)
		units.append(u)
	ctrl = Knowledge.start_hero
	units[ctrl].set_controlled(true)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if ended:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			retry()
		return
	if fury:
		return
	if prep:
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			start_fight()
		return
	match k:
		KEY_TAB: _cycle_ctrl()
		KEY_1: pick_hero(0)
		KEY_2: pick_hero(1)
		KEY_3: pick_hero(2)
		KEY_4: pick_hero(3)
		KEY_F1: select_target(0)
		KEY_F2: select_target(1)
		KEY_F3: select_target(2)
		KEY_F4: select_target(3)
		KEY_Q: give_order("gather")
		KEY_E: give_order("spread")
		KEY_R: give_order("hold")
		KEY_F: give_order("atk")
		KEY_SPACE: _try_dash()
		KEY_K: use_skill(units[ctrl], 1)
		KEY_L: use_skill(units[ctrl], 2)
		KEY_U: use_skill(units[ctrl], 3)
		KEY_I: use_lb()
		KEY_ESCAPE: retry()  # desistir e voltar pras cartas


func start_fight() -> void:
	prep = false
	hud.set_prep(false)
	intro_left = hud.play_intro()


func retry() -> void:
	if won:
		Knowledge.boss_unlocked = mini(Knowledge.boss + 1, BOSSES.size() - 1)
		Knowledge.boss = Knowledge.boss_unlocked
		Knowledge.attempts = 1
	else:
		Knowledge.attempts += 1
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func select_hero(i: int) -> void:
	Knowledge.start_hero = i
	units[ctrl].set_controlled(false)
	ctrl = i
	units[i].set_controlled(true)


func select_boss(i: int) -> void:
	Knowledge.boss = i
	Knowledge.attempts = 1
	get_tree().reload_current_scene()


## Clique num card: escolhe aquele personagem como alvo das suas habilidades de suporte.
func select_target(i: int) -> void:
	sel = -1 if sel == i else i
	for u in units:
		u.chosen = u.idx == sel


func mechanic_active() -> bool:
	return zones_active or phase == "cata" or not stacks.is_empty()


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
## Clique no card ou teclas 1-4: assume o herói na hora.
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
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): d.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): d.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): d.x += 1.0
	return d.normalized()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if shot_left >= 0.0:
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
	if swap_test > 0.0 and fight_time >= swap_test:
		swap_test = 0.0
		_cycle_ctrl()
	if lb_test > 0.0 and fight_time >= lb_test:
		lb_test = 0.0
		lb = 1.0
		use_lb()
	swap_cd = maxf(0.0, swap_cd - delta)
	_tick_boss(delta)
	_tick_hazards(delta)
	_tick_stacks(delta)
	_tick_buster(delta)
	_tick_pairs(delta)
	for u in units:
		if ended:
			return
		if not u.alive:
			continue
		u.invuln = maxf(0.0, u.invuln - delta)
		u.guard_t = maxf(0.0, u.guard_t - delta)
		u.weak_t = maxf(0.0, u.weak_t - delta)
		u.immortal_t = maxf(0.0, u.immortal_t - delta)
		for n in 4:
			u.skill_cd[n] = maxf(0.0, u.skill_cd[n] - delta)
		u.dash_cd = maxf(0.0, u.dash_cd - delta)
		if u.controlled and not autoplay:
			_tick_player(u, delta)
		else:
			_tick_ai(u, delta)
		_clamp_to_arena(u)
	_tick_auto(delta)
	_tick_dps(delta)

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
		if Knowledge.deck(u.idx)["purple"] == "":
			Knowledge.toggle_purple(u.idx, "dps", u.key)
		hud.toast("Carta roxa: " + Knowledge.PURPLE["dps"] + " · " + u.unit_name, 3.5)


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
	var want_attack := Input.is_physical_key_pressed(KEY_J)
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
	if moving and u.channel_total >= LOCKED_CAST:
		# cast longo: andar ou esquivar interrompe, sem gastar a recarga
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
	if _tick_cast(u, delta, false):
		return
	var goal = null
	var text := "Atacando"
	var kind := 0
	var i := u.idx

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
		goal = SPREAD_POS[i]
		text = "Espalhando"
	else:
		goal = ATK_POS[i]
		# Sem carta pra isso: o personagem recebe a mecânica e não sabe o que fazer.
		if (zones_active or phase == "cata") and u.element >= 0:
			text = "???"
			kind = 2
		elif not stacks.is_empty():
			text = "???"
			kind = 2
		elif phase == "cata" and shelter_pos != null:
			text = "???"
			kind = 2

	# Desvio: cada personagem só enxerga os ataques pros quais tem a carta amarela.
	var in_danger := _danger_at(u.position, u, true, 0.1)
	if u.dodge_goal != null and not in_danger and (hazards.is_empty() or u.position.distance_to(u.dodge_goal) <= 0.15):
		u.dodge_goal = null  # chegou na saída (ou o ataque já passou)
	if in_danger:
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

	# Instinto (carta amarela): só reage a pouca vida, então não fica gastando cura à toa.
	if Knowledge.has_yellow(i, "instinct"):
		if u.key == "healer" and u.skill_cd[1] <= 0.0:
			# primeiro ele mesmo: healer morto não cura ninguém
			var ht: Unit = u if u.hp / u.max_hp < Knowledge.LOW_HP else _heal_target()
			# o Tank é socorrido mais cedo: ele precisa de folga pra aguentar o Esmagar
			if ht != null and ht.hp / ht.max_hp < Knowledge.LOW_HP + (0.3 if ht.idx == 0 else 0.0):
				heal_focus = ht
			# começou a socorrer alguém, termina o serviço (até 80%) antes de parar
			if heal_focus != null and (not heal_focus.alive or heal_focus.hp / heal_focus.max_hp >= 0.9):
				heal_focus = null
			# dois ou mais machucados por perto: a cura em área rende mais que a de um alvo só
			var hurt_near := 0
			for o in units:
				if o.alive and o.hp / o.max_hp < 0.7 and o.position.distance_to(u.position) <= AOE_HEAL_R:
					hurt_near += 1
			if hurt_near >= 3 and u.skill_cd[3] <= 0.0:
				use_skill(u, 3, true)
			elif heal_focus != null:
				use_skill(u, 1, true, heal_focus)

	if u.key == "tank" and Knowledge.has_yellow(i, "provoke") and target != null and target != u and u.skill_cd[3] <= 0.0:
		use_skill(u, 3, true)

	# Auto-ataque conservador: bem mais fraco que o jogador no controle.
	if _in_range(u):
		# carta roxa Rotação: a IA usa a rotação que você mostrou jogando bem com esse herói
		var rate: float = ROTATION_DPS[u.key] if Knowledge.deck(i)["purple"] == "dps" else u.ai_dps
		_damage_boss(u, rate * delta, false, false)
		u.dmg_acc += rate * delta * _dmg_mult()
		u.dmg_timer += delta
		if u.dmg_timer >= 1.2:
			_popup(int(u.dmg_acc), Color(0.75, 0.75, 0.8), 30)
			u.dmg_acc = 0.0
			u.dmg_timer = 0.0
	elif text == "Atacando":
		text = "Indo atacar"
	u.set_action(text, kind)


## Devolve [posição, texto] da primeira carta que se aplica agora, ou null.
func _card_plan(u: Unit):
	var d := Knowledge.deck(u.idx)
	if d["purple"] == "mark":
		var r = null
		if zones_active:
			r = _act(u, "zone_opp")
		elif phase == "cata" and u.element >= 0:
			r = _act(u, "partner")
		elif phase == "cata":
			r = _act(u, "shelter")
		if r != null:
			return r
	for w in d["white"]:
		if w["t"] == "" or w["a"] == "" or not _trigger_on(u, w["t"]):
			continue
		if w["a"] == "mitigate":
			# carta que usa habilidade em vez de andar: aperta no fim do cast, como você faria
			if u.key == "tank" and buster != null and buster["target"] == u and buster["t"] <= 1.2:
				use_skill(u, 1, true)
			continue
		var r2 = _act(u, w["a"])
		if r2 != null:
			return r2
	return null


func _trigger_on(u: Unit, t: String) -> bool:
	match t:
		"stack": return not stacks.is_empty() and stack_need == 4
		"stack2": return not stacks.is_empty() and stack_need == 2
		"buster": return buster != null
		"got_element": return zones_active and u.element >= 0
		"zones_done": return phase == "cata" and u.element >= 0
		"cata": return phase == "cata"
	return false


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
	u.cast_target = null
	if sk.has("dmg") and not _in_range(u):
		u.set_action("Longe demais", 2)
		return false
	match sk["name"]:
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
		u.channel_t = sk["cast"]
		u.channel_total = sk["cast"]
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
			# provoke: quem usa pula pro topo da lista de enmity na hora, com folga
			var top := 0.0
			for o in units:
				if o != u and o.alive:
					top = maxf(top, o.enmity)
			# recuperou o aggro na mão: a party aprende a carta que faz isso sozinha
			if not by_ai and u.key == "tank" and target != null and target != u:
				learn_yellow("provoke")
			u.enmity = maxf(u.enmity, top) + PROVOKE_BONUS
			_burst(u.position, Color(1.0, 0.35, 0.6), 3.2)
			_beam(u.position, Vector3(0, 5.0, -11.5), Color(1.0, 0.35, 0.6, 0.95), 0.45)
			boss.rage()
			hud.toast("BORA BISCOITAR", 1.6)
		"Cura":
			var ht: Unit = u.cast_target
			if ht == null or not ht.alive:
				ht = _heal_target()
			if ht == null:
				return
			var amount := HEAL_AI if by_ai else HEAL_PLAYER
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
			_damage_boss(u, sk["dmg"], true, big)


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
	hud.toast("LIMIT BREAK", 2.0)
	_burst(u.position, u.color.lightened(0.4), 7.0)
	match u.key:
		"tank":
			for o in units:
				if o.alive:
					o.immortal_t = LB_IMMORTAL
					_burst(o.position, Color(1.0, 0.9, 0.5), 2.2)
		"healer":
			for o in units:
				if not o.alive:
					o.revive(0.6)  # sem Fraqueza: é a vantagem sobre o Reviver comum
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
	h["t"] = h["total"]
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
	return false


## Tem perigo em p? Com `known`, só conta os ataques pros quais a unidade tem carta.
func _danger_at(p: Vector3, u: Unit, known: bool, margin: float) -> bool:
	for h in hazards:
		if known and not Knowledge.has_yellow(u.idx, h["card"]):
			continue
		if not known and Knowledge.has_yellow(u.idx, h["card"]):
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
			if u.alive and u.invuln <= 0.0 and _hit_test(h, u.position, 0.0):
				if u == player:
					player_hit = true
				hurt(u, h["dmg"], h["why"])
		# desviou na mão de um ataque que ia te pegar: a carta daquele desvio é sua
		if player.alive and not player_hit and h["inside"].has(player.idx):
			learn_yellow(h["card"])


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
func _start_stacks(total: float, need: int) -> void:
	var pool := _alive_shuffled()
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
	learn_trigger("stack" if need == 4 else "stack2")
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
			var total := STACK_TOTAL if stack_need == 4 else PAIR_TOTAL
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
		learn_action("to_marked" if stack_need == 4 else "pair_up")
	for u in units:
		u.hold_pos = null


## Plano de dupla: cada não-marcado vai pro círculo que dá a menor caminhada total,
## os marcados se afastam um do outro, e quem sobra fica fora de todos.
func _pair_plan(u: Unit):
	var marked: Array = []
	for st in stacks:
		marked.append(st["target"])
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
		if o.alive and not marked.has(o):
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


# ---------------------------------------------------------------- Esmagar (tank buster)

## Golpe pesado só no alvo 1. Não dá pra desviar: é a Mitigação do Tank que salva.
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
	learn_trigger("buster")


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
	var mitigated := t.guard_t > 0.0
	hud.flash(Color(1.0, 0.2, 0.35) * Color(1, 1, 1, 0.35))
	_burst(t.position, DANGER, 3.0)
	hurt(t, BUSTER_DMG, "tomou o Esmagar sem Mitigação" if not mitigated else "não aguentou o Esmagar")
	if mitigated and t.alive and t == units[ctrl]:
		learn_action("mitigate")


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
		var u: Unit = pool[k]
		var from := Vector3(0, 0, -ARENA_R - 1.0)
		var dir := Vector3(u.position.x, 0, u.position.z) - from
		dir = dir.normalized()
		# a faixa cobre só o trecho que cruza a arena, sem sobrar pra fora do chão
		var b := from.dot(dir)
		var disc := b * b - (from.length_squared() - ARENA_R * ARENA_R)
		if disc <= 0.0:
			continue
		var t1 := -b - sqrt(disc)
		var t2 := -b + sqrt(disc)
		_add_hazard({"shape": "rect", "pos": from + dir * ((t1 + t2) * 0.5), "dir": dir, "half_l": (t2 - t1) * 0.5, "half_w": half_w,
			"total": total + k * 0.25, "dmg": dmg, "card": "dodge", "why": why})


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
	boss_hp -= dmg
	lb = minf(1.0, lb + dmg / (boss_max * LB_NEED))
	u.dmg_total += dmg
	u.dmg_bucket += dmg
	u.enmity += dmg * (TANK_STANCE if u.key == "tank" else 1.0)
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
	if u.guard_t > 0.0:
		dmg *= MITIGATION
	u.hp -= dmg
	hit_count[reason] = hit_count.get(reason, 0) + 1
	u.flash_hit(dmg / u.max_hp)
	_popup(int(dmg), DANGER.lightened(0.3), 72, u.position + Vector3(0, 2.6, 0), "-")
	# alguém ficou por um fio: a party aprende a reagir a pouca vida
	if u.hp > 0.0 and u.hp / u.max_hp < 0.35:
		learn_yellow("instinct")
	if u.hp <= 0.0:
		kill(u, reason)


func kill(u: Unit, reason: String, force := false) -> void:
	if not u.alive:
		return
	# imortal (Limit Break do Tank) ignora até as mecânicas que matam na hora; só a Fúria passa
	if u.immortal_t > 0.0 and not force:
		_burst(u.position, Color(1.0, 0.9, 0.5), 1.8)
		return
	if u.controlled and not fury:
		hud.flash(Color(1.0, 0.1, 0.2) * Color(1, 1, 1, 0.6))
	u.die()
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
	hud.show_end(victory, log_lines)


func learn_trigger(id: String) -> void:
	if Knowledge.triggers_known.has(id) or autoplay:
		return
	Knowledge.triggers_known[id] = true
	hud.toast("Nova peça: QUANDO " + Knowledge.TRIGGERS[id], 3.0)


func learn_action(id: String) -> void:
	if Knowledge.actions_known.has(id) or autoplay:
		return
	Knowledge.actions_known[id] = true
	hud.toast("Nova peça: " + Knowledge.ACTIONS[id].to_upper(), 3.0)


func learn_yellow(id: String) -> void:
	if Knowledge.yellow_known.has(id) or autoplay:
		return
	Knowledge.yellow_known[id] = true
	# você desviou, a party viu: todo mundo com slot livre já sai usando
	for i in 4:
		if not Knowledge.has_yellow(i, id) and Knowledge.yellow_for(UNIT_DEFS[i]["key"]).has(id):
			Knowledge.toggle_yellow(i, id)
	hud.toast("A party aprendeu: " + Knowledge.YELLOW[id], 3.0)


# ---------------------------------------------------------------- boss

func _next_step() -> void:
	step = (step + 1) % steps.size()
	var s: Dictionary = steps[step]
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
			_add_hazard({"shape": "circle", "pos": Vector3.ZERO, "r": 5.6, "total": 2.5, "dmg": 34.0,
				"card": "dodge", "why": "ficou no meio da Implosão"})
		"nova":
			cast_name = "Supernova"
			boss.casting = true
			_add_hazard({"shape": "donut", "pos": Vector3.ZERO, "r": 3.2, "total": 3.0, "dmg": 34.0,
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
			learn_trigger("zones_done")
			learn_trigger("cata")
		"burn":
			vulnerable = not shield


func _tick_boss(delta: float) -> void:
	phase_t += delta
	var s: Dictionary = steps[step]
	if s.has("volley_at") and not volley_done and phase_t >= s["volley_at"]:
		volley_done = true
		_spawn_circles(1)
	if phase_t < phase_dur:
		return
	match phase:
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
	learn_trigger("got_element")


func _resolve_zones() -> void:
	var player := units[ctrl]
	for u in units:
		if not u.alive or u.element < 0:
			continue
		var inside = null
		for z in zones:
			if z["pos"].distance_to(u.position) <= ZONE_R:
				inside = z
		if u == player and inside != null:
			learn_action("zone_opp")
			learn_action("zone_same")
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
			learn_action("partner")
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
			learn_action("shelter")
	var survivors := 0
	for u in units:
		if u.alive:
			survivors += 1
			u.set_element(-1)
			u.hold_pos = null
	# A carta roxa é prêmio por já ter resolvido a mecânica inteira com a party toda viva.
	if survivors == 4 and not Knowledge.purple_known and not autoplay:
		Knowledge.purple_known = true
		hud.toast("Carta roxa: " + Knowledge.PURPLE_NAME, 3.5)
	if order == "hold":
		order = "atk"
	if shelter_node != null:
		shelter_node.queue_free()
		shelter_node = null
	shelter_pos = null


## Fim do DPS check: o boss chama os biscoitos e cada um cai em cima de alguém.
func _start_fury() -> void:
	fury = true
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


func _burst(p: Vector3, col: Color, radius: float) -> void:
	var m := Fx.mat(Color(col.r, col.g, col.b, 0.6), 2.0, true)
	var mi := Fx.inst(fx_root, Fx.sphere(1.0), m, p + Vector3(0, 0.3, 0))
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.5, radius), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)
