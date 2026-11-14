extends Node3D
## LOBBY — a cafeteria onde a party é montada (cena lobby.tscn).
## Todos os heróis jogáveis estão no salão, cada vez num lugar diferente: cinco na frente, no tapete,
## e cinco no palco do fundo (mais alto, pra ninguém tapar ninguém). Não é uma área jogável: ninguém
## anda. O jogador FOCA um herói (clique nele ou setas) e, numa ficha ao lado dele, confirma a entrada
## na party. Com os quatro lugares cheios, READY TO PLAY libera os bosses.
##   clique num herói: foca · ← ↑ ↓ →: foca o herói mais próximo NAQUELA direção da tela
##   (não uma lista: sem ninguém pra lá, a seta não faz nada) · ENTER: escolhe / confirma
##   clique num lugar cheio da party: tira o herói · ESC: volta pros saves
## HUD no kit de papel (Paper), como a tela de cartas. O cenário é montado em código.
## Captura (só com argumentos depois de `--`): --shot=<seg> --out=<nome> [--party=0,1,2,3]
##   [--focus=<k>] [--hover=<k>] [--ask] [--seed=<n>] salva user://<nome>.png e fecha.

const GAME := preload("res://scripts/game.gd")
const PURPLE := Color("5B2BB8")
const NAVY2 := Color("2B3384")
const DIM := Color("B9BEEA")
const CARD := Vector2(330, 262)
const FOCUS_COL := Color(0.3, 0.9, 1.0)
## Arte de corpo inteiro dos personagens: altura de uma figura alta e a maior largura, em metros.
const FIG_H := 2.9
const FIG_W := 2.3
## Altura do palco do fundo.
const STAGE_H := 1.25

## Lugares do salão: onde fica e pra onde olha. A cada entrada os heróis são sorteados entre eles.
## Duas fileiras desencontradas: a da frente no tapete, a de trás em cima do palco.
const SPOTS := [
	{"at": Vector3(-5.9, 0, 2.75), "look": Vector3(0.3, 0, 1)},
	{"at": Vector3(-3.3, 0, 2.65), "look": Vector3(0.2, 0, 1)},
	{"at": Vector3(-0.7, 0, 2.75), "look": Vector3(0, 0, 1)},
	{"at": Vector3(1.9, 0, 2.65), "look": Vector3(-0.2, 0, 1)},
	{"at": Vector3(4.5, 0, 2.75), "look": Vector3(-0.3, 0, 1)},
	{"at": Vector3(-5.1, 1.25, -2.4), "look": Vector3(0.3, 0, 1)},
	{"at": Vector3(-2.2, 1.25, -2.65), "look": Vector3(0.2, 0, 1)},
	{"at": Vector3(0.7, 1.25, -2.35), "look": Vector3(0, 0, 1)},
	{"at": Vector3(3.6, 1.25, -2.65), "look": Vector3(-0.2, 0, 1)},
	{"at": Vector3(6.5, 1.25, -2.4), "look": Vector3(-0.3, 0, 1)},
]

const SH_CHECK := "
shader_type spatial;
uniform vec3 a : source_color;
uniform vec3 b : source_color;
uniform float cell = 1.3;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wp.x + wp.z, wp.x - wp.z) / cell;
	float c = mod(floor(p.x) + floor(p.y), 2.0);
	ALBEDO = mix(a, b, c);
	ROUGHNESS = 0.9;
}"
const SH_PLANK := "
shader_type spatial;
uniform vec3 a : source_color;
uniform vec3 b : source_color;
uniform float w = 0.9;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = floor(wp.x / w);
	float c = fract(sin(n * 12.9898) * 43758.5453);
	vec3 col = mix(a, b, c);
	col *= mix(1.0, 0.55, step(0.95, fract(wp.x / w)));
	ALBEDO = col;
	ROUGHNESS = 0.9;
}"
const SH_WALL := "
shader_type spatial;
render_mode unshaded;
uniform vec3 a : source_color;
uniform vec3 b : source_color;
uniform float w = 1.1;
uniform float y0 = 3.5;
uniform float y1 = 8.0;
uniform float dark = 0.45;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float s = step(0.5, fract((wp.x + wp.z) / w));
	vec3 c = mix(a, b, s);
	c *= mix(1.0, dark, smoothstep(y0, y1, wp.y));
	ALBEDO = c;
}"
## Feixe de luz: some ao longo do comprimento (UV.y) e nas bordas (UV.x).
const SH_SHAFT := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.85, 0.5, 0.2);
void fragment() {
	ALBEDO = col.rgb;
	ALPHA = col.a * (1.0 - UV.y) * smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
}"
## Silhueta engordada da arte, numa cor só: o contorno de papel do herói em destaque.
const SH_HALO := "
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 col : source_color = vec4(1.0);
uniform vec2 grow = vec2(0.02);
uniform float pad = 0.1;
void fragment() {
	vec2 uv = UV * (1.0 + 2.0 * pad) - vec2(pad);
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3927;
		vec2 q = uv + vec2(cos(ang), sin(ang)) * grow;
		if (q.x > 0.0 && q.x < 1.0 && q.y > 0.0 && q.y < 1.0) {
			a = max(a, texture(tex, q).a);
		}
	}
	ALBEDO = col.rgb;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
}"
const SH_VIGNETTE := "
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p * vec2(1.0, 0.9));
	float v = smoothstep(0.36, 0.78, d);
	float top = smoothstep(0.2, 0.0, UV.y) * 0.18;
	COLOR = vec4(0.05, 0.03, 0.13, clamp(v * 0.7 + top, 0.0, 0.85));
}"

var cam: Camera3D
var figs: Array[Unit] = []      # um boneco por herói; figs[k].hero = índice em Knowledge.HEROES
var marks: Array = []           # por boneco: {"focus": anel de foco, "in": base de party, "tag": etiqueta 2D}
var team: Array = []            # heróis já na party, na ordem em que entraram
var focus := -1                 # índice em figs do herói em foco (-1 = nenhum)
var hover := -1                 # índice em figs do herói embaixo do ponteiro (-1 = nenhum)
var _t := 0.0
var _rigs: Array = []           # por boneco: a arte e o que anima nela (ver _build_heroes)
var _tags: Array = []           # por boneco: as etiquetas 2D (ver _build_tags)
var _lamps: Array = []          # lustres que balançam: [nó, fase]
var _steam: Array = []          # fumacinha das xícaras: [malha, base, fase, material]
var _spin: Array = []           # enfeites que giram devagar
var _force_hover := -1
var _args := {}

var ui: Control
var card: Control
var card_art: TextureRect
var card_name: Label
var card_role: Chip
var card_text: Label
var card_btn: ShineButton
var slots: Array = []           # por lugar: {"face": TextureRect, "plus": Label, "name": Label}
var count_chip: Chip
var ready_btn: ShineButton
var dialog: Control
var dialog_text: Label
var hint: Label


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--") and s.contains("="):
			_args[s.get_slice("=", 0).trim_prefix("--")] = s.get_slice("=", 1)
		elif s.begins_with("--"):
			_args[s.trim_prefix("--")] = "1"
	if OS.get_cmdline_user_args().size() > 0:
		Knowledge.persist = false
	Knowledge.load_save()
	Settings.boot()
	if _args.has("seed"):
		seed(int(_args["seed"]))
	else:
		randomize()
	_build_room()
	_build_heroes()
	_build_ui()
	# save que já tinha party volta com ela nos lugares; save novo começa vazio
	team = Knowledge.party.duplicate() if Knowledge.party_ready() else []
	if _args.has("party"):
		team = []
		for p in String(_args["party"]).split(",", false):
			team.append(int(p))
	_refresh()
	if _args.has("focus"):
		_set_focus(int(_args["focus"]))
	if _args.has("hover"):
		_force_hover = int(_args["hover"])
	if _args.has("ask"):
		_ask_add()
	if _args.has("shot"):
		get_tree().create_timer(float(_args["shot"])).timeout.connect(_shot)


func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://" + String(_args.get("out", "agent_lobby")) + ".png")
	for k in figs.size():
		var feet := cam.unproject_position(figs[k].position)
		var head := cam.unproject_position(figs[k].position + Vector3(0, float(_rigs[k]["tall"]), 0))
		print("fig ", k, " ", figs[k].key, " feet ", feet.round(), " head ", head.round())
	get_tree().quit()


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# ---------------------------------------------------------------- foco e navegação

## Onde o herói aparece na tela (altura do peito).
func _screen(k: int) -> Vector2:
	return cam.unproject_position(figs[k].position + Vector3(0, 1.0, 0))


func _set_focus(k: int) -> void:
	if k == focus:
		return
	focus = k
	if k >= 0:
		figs[k].punch()
		_bump(k, 0.6)
	_refresh()


## Herói mais próximo do ponto da tela, se estiver perto o bastante pra contar como clique nele.
func _pick(at: Vector2) -> int:
	var best := -1
	var best_d := 92.0
	for k in figs.size():
		var p := cam.unproject_position(figs[k].position + Vector3(0, 1.3, 0))
		var d := Vector2((at.x - p.x), (at.y - p.y) * 0.55).length()  # o boneco é mais alto que largo
		if d < best_d:
			best_d = d
			best = k
	return best


## Navegação espacial: o herói mais próximo na direção `dir` (em tela), dentro de um cone.
## Sem ninguém pra lá, devolve -1 e o foco não muda.
func _toward(dir: Vector2) -> int:
	if focus < 0:
		# nada em foco: começa por quem está mais perto do centro da tela
		var center := get_viewport().get_visible_rect().size * 0.5
		var first := -1
		var near := INF
		for k in figs.size():
			var d := _screen(k).distance_to(center)
			if d < near:
				near = d
				first = k
		return first
	var from := _screen(focus)
	var best := -1
	var best_score := INF
	for k in figs.size():
		if k == focus:
			continue
		var v := _screen(k) - from
		var along := v.dot(dir)
		var side := absf(v.dot(Vector2(-dir.y, dir.x)))
		if along < 12.0 or side > along * 1.6:
			continue  # está pro outro lado, ou muito mais de lado do que na direção pedida
		var score := along + side * 1.8
		if score < best_score:
			best_score = score
			best = k
	return best


# ---------------------------------------------------------------- party

func _in_team(k: int) -> bool:
	return k >= 0 and team.has(figs[k].hero)


## SELECT FOR PARTY: pede confirmação antes de pôr o herói em foco na party.
func _ask_add() -> void:
	if focus < 0 or _in_team(focus) or team.size() >= 4 or dialog.visible:
		return
	dialog_text.text = "Colocar %s na party?" % String(Knowledge.HEROES[figs[focus].hero]["name"]).to_upper()
	dialog.visible = true
	_refresh()


func _confirm_add() -> void:
	dialog.visible = false
	if focus >= 0 and not _in_team(focus) and team.size() < 4:
		team.append(figs[focus].hero)
		figs[focus].punch()
		_hop(focus)
		_pop(figs[focus].position)
	_refresh()


func _remove(hero: int) -> void:
	if dialog.visible:
		return
	team.erase(hero)
	for k in figs.size():
		if figs[k].hero == hero:
			_bump(k, 0.8)
	_refresh()


func _ready_to_play() -> void:
	if team.size() < 4 or dialog.visible:
		return
	Knowledge.set_party(team)
	Knowledge.save()
	Knowledge.screen = "bosses"
	get_tree().change_scene_to_file("res://main.tscn")


func _back() -> void:
	Knowledge.screen = "saves"
	get_tree().change_scene_to_file("res://main.tscn")


## Amassa a arte do herói (0..1) e deixa voltar: o "toque" de foco.
func _bump(k: int, amount: float) -> void:
	if k >= 0 and k < _rigs.size():
		_rigs[k]["sq"] = amount


## Pulinho de quem entrou na party.
func _hop(k: int) -> void:
	if k < 0 or k >= _rigs.size():
		return
	var rig: Dictionary = _rigs[k]
	var tw := create_tween()
	tw.tween_method(func(v: float): rig["hop"] = 4.0 * 0.7 * v * (1.0 - v), 0.0, 1.0, 0.42)
	tw.tween_callback(func(): rig["sq"] = 0.7)


## Entrou na party: anel dourado abrindo no chão e confete de papel.
func _pop(at: Vector3) -> void:
	var m := Fx.mat(Color(1.0, 0.8, 0.25, 0.7), 2.0, true)
	var mi := Fx.inst(self, Fx.torus(0.8, 1.0), m, at + Vector3(0, 0.12, 0))
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.4, 0.3, 2.4), 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)
	var cols := [Paper.GOLD, Paper.PINK, Paper.CYAN, Paper.CREAM, Paper.GREEN]
	for n in 18:
		var q := BoxMesh.new()
		q.size = Vector3(0.16, 0.16, 0.01)
		var bit := Fx.inst(self, q, Fx.flat(cols[n % cols.size()]), at + Vector3(0, 1.4, 0.1))
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := randf() * TAU
		var far := randf_range(0.9, 2.0)
		var top := at + Vector3(cos(ang) * far * 0.6, randf_range(2.6, 3.8), 0.3 + sin(ang) * 0.4)
		var land := at + Vector3(cos(ang) * far, 0.1, 0.4 + sin(ang) * far * 0.5)
		var ct := bit.create_tween()
		ct.tween_property(bit, "position", top, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		ct.parallel().tween_property(bit, "rotation", Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0), 0.9)
		ct.tween_property(bit, "position", land, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		ct.tween_property(bit, "scale", Vector3.ZERO, 0.15)
		ct.tween_callback(bit.queue_free)


# ---------------------------------------------------------------- tela

func _refresh() -> void:
	for k in figs.size():
		marks[k]["focus"].visible = k == focus
		marks[k]["in"].visible = _in_team(k)
	_refresh_tags()
	for n in 4:
		var s: Dictionary = slots[n]
		var filled := n < team.size()
		s["face"].visible = filled
		s["plus"].visible = not filled
		s["num"].visible = filled
		s["name"].text = String(Knowledge.HEROES[team[n]]["name"]).to_upper() if filled else ""
		if filled:
			s["face"].texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[team[n]]["key"])
		s["panel"].fill = Paper.CREAM if filled else Color("1A1E52")
		s["new"].visible = filled and Knowledge.has_new(team[n])
	count_chip.text = "PARTY  %d / 4" % team.size()
	count_chip.fill = Paper.GREEN if team.size() == 4 else Paper.GOLD
	count_chip.queue_redraw()
	ready_btn.disabled = team.size() < 4
	ready_btn.idle = team.size() == 4
	ready_btn.queue_redraw()
	card.visible = focus >= 0
	if focus >= 0:
		var h: Dictionary = Knowledge.HEROES[figs[focus].hero]
		card_name.text = String(h["name"]).to_upper()
		# nome comprido encolhe até caber na ficha
		var px := 24
		while px > 14 and Paper.display().get_string_size(card_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 180.0:
			px -= 1
		card_name.add_theme_font_size_override("font_size", px)
		card_role.text = String(h["role"]).to_upper()
		card_text.text = String(h["blurb"])
		# a moldura da ficha tem a proporção do retrato (5:7): a arte de corpo inteiro não caberia sem corte
		card_art.texture = load("res://assets/portraits/%s_face.png" % h["key"])
		if _in_team(focus):
			card_btn.text = "JÁ ESTÁ NA PARTY"
			card_btn.disabled = true
		elif team.size() >= 4:
			card_btn.text = "PARTY CHEIA"
			card_btn.disabled = true
		else:
			card_btn.text = "SELECT FOR PARTY"
			card_btn.disabled = false
		card_btn.queue_redraw()
	if dialog.visible:
		hint.text = "ENTER confirma  ·  ESC cancela"
	elif team.size() == 4:
		hint.text = "ENTER: READY TO PLAY  ·  clique num lugar da party pra tirar alguém  ·  ESC volta"
	else:
		hint.text = "Clique num herói ou use as setas  ·  ENTER escolhe  ·  ESC volta"


## Etiquetas de nome: cor e selo seguem o estado do herói (na party, em foco, embaixo do ponteiro).
func _refresh_tags() -> void:
	for k in _tags.size():
		var t: Dictionary = _tags[k]
		var u: Unit = t["unit"]
		var name_chip: Chip = t["name"]
		var num: Chip = t["num"]
		var role: Chip = t["role"]
		var news: Chip = t["new"]
		var box: Control = t["box"]
		var place := team.find(u.hero)
		var lit := k < figs.size() and (k == focus or k == hover)
		var fill := Paper.CREAM
		if k < figs.size() and k == focus:
			fill = Paper.CYAN
		elif place >= 0:
			fill = Paper.GOLD
		elif lit:
			fill = Paper.GOLD_HOVER
		if name_chip.fill != fill:
			name_chip.fill = fill
			name_chip.queue_redraw()
		num.visible = place >= 0
		if place >= 0 and num.text != str(place + 1):
			num.text = str(place + 1)
			num.position = Vector2(-name_chip.size.x * 0.5 - num.size.x + 7.0, -11.0)
		role.visible = k < figs.size() and k == hover and k != focus
		news.visible = Knowledge.has_new(u.hero)
		box.z_index = 1 if lit else 0
		t["lit"] = lit


func _process(delta: float) -> void:
	_t += delta
	# quem está embaixo do ponteiro (fora de botões e painéis do HUD)
	var h := _force_hover
	if h < 0 and not dialog.visible and DisplayServer.get_name() != "headless" and get_viewport().gui_get_hovered_control() == null:
		h = _pick(get_viewport().get_mouse_position())
	if h >= figs.size():
		h = -1
	if h != hover:
		hover = h
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover >= 0 else Input.CURSOR_ARROW)
		_refresh_tags()
	var ease_k := 1.0 - exp(-delta * 14.0)
	for k in figs.size():
		var u := figs[k]
		var rig: Dictionary = _rigs[k]
		# vida de cafeteria: cada um respira e balança no seu ritmo; o destacado cresce um pouco
		var ph := k * 1.7
		var grow: float = lerpf(float(rig["s"]), 1.07 if k == hover else (1.04 if k == focus else 1.0), ease_k)
		var sq: float = lerpf(float(rig["sq"]), 0.0, 1.0 - exp(-delta * 9.0))
		rig["s"] = grow
		rig["sq"] = sq
		var at := Vector3(0, 0.05 + float(rig["hop"]), 0)
		var sc := Vector3(grow * (1.0 + sq * 0.16), grow * (1.0 + 0.012 * sin(_t * 1.8 + ph)) * (1.0 - sq * 0.14), 1.0)
		var lean := 0.016 * sin(_t * 1.1 + ph)
		for part in [rig["art"], rig["back"]]:
			var n: Node3D = part
			if n != null:
				n.position = at
				n.scale = sc
				n.rotation.z = lean
		u.visual.position.y = 0.04 * sin(_t * 1.6 + ph)
		u.visual.rotation.z = 0.05 * sin(_t * 0.9 + ph)
		u.visual.rotation.y = float(u.get_meta("yaw")) + 0.25 * sin(_t * 0.5 + ph)
		var halo: MeshInstance3D = rig["halo"]
		if halo != null:
			var on := k == focus or k == hover or _in_team(k)
			halo.visible = on
			if on:
				var col := Paper.GOLD
				if k == focus:
					col = FOCUS_COL
				elif k == hover and not _in_team(k):
					col = Paper.CREAM
				(halo.material_override as ShaderMaterial).set_shader_parameter("col", col)
		marks[k]["focus"].rotate_y(delta * 2.5)
		marks[k]["focus"].scale = Vector3(1.0, 0.35, 1.0) * (1.0 + 0.06 * sin(_t * 6.0))
	for s in _spin:
		var sn: Node3D = s
		if is_instance_valid(sn):
			sn.rotate_y(delta * 0.8)
	for l in _lamps:
		var ln: Node3D = l[0]
		ln.rotation.z = 0.045 * sin(_t * 0.9 + float(l[1]))
		ln.rotation.x = 0.02 * sin(_t * 0.7 + float(l[1]) * 2.0)
	for s in _steam:
		var puff: MeshInstance3D = s[0]
		var base: Vector3 = s[1]
		var f := fmod(_t * 0.45 + float(s[2]), 1.0)
		puff.position = base + Vector3(0.06 * sin(f * 7.0 + float(s[2]) * 9.0), f * 0.75, 0)
		puff.scale = Vector3.ONE * (0.5 + f * 1.1)
		(s[3] as StandardMaterial3D).albedo_color.a = 0.55 * sin(f * PI)
	# etiquetas de nome: presas nos pés de cada herói
	for k in _tags.size():
		var t: Dictionary = _tags[k]
		var tu: Unit = t["unit"]
		var box: Control = t["box"]
		box.visible = tu.visible and k < figs.size()
		if box.visible:
			box.position = cam.unproject_position(tu.position + Vector3(0, 0.0, 0.25)).round()
			var want := 1.12 if bool(t["lit"]) else 1.0
			box.scale = Vector2.ONE * lerpf(box.scale.x, want, ease_k)
	if focus >= 0 and card.visible:
		# a ficha fica ao lado do herói em foco: à direita, ou à esquerda se não couber
		var view := get_viewport().get_visible_rect().size
		var p := _screen(focus)
		var x := p.x + 96.0
		if x + CARD.x > view.x - 16.0:
			x = p.x - 96.0 - CARD.x
		card.position = Vector2(x, clampf(p.y - CARD.y * 0.6, 84.0, view.y - CARD.y - 150.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not dialog.visible:
			var k := _pick(event.position)
			if k >= 0:
				_set_focus(k)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if dialog.visible:
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			_confirm_add()
		elif key == KEY_ESCAPE:
			dialog.visible = false
			_refresh()
		return
	var dir := Vector2.ZERO
	match key:
		KEY_LEFT, KEY_A: dir = Vector2.LEFT
		KEY_RIGHT, KEY_D: dir = Vector2.RIGHT
		KEY_UP, KEY_W: dir = Vector2.UP
		KEY_DOWN, KEY_S: dir = Vector2.DOWN
		KEY_ENTER, KEY_KP_ENTER:
			if team.size() == 4:
				_ready_to_play()
			else:
				_ask_add()
		KEY_ESCAPE: _back()
	if dir != Vector2.ZERO:
		var k := _toward(dir)
		if k >= 0:
			_set_focus(k)


# ---------------------------------------------------------------- heróis

func _build_heroes() -> void:
	var places := SPOTS.duplicate()
	places.shuffle()
	for hero in Knowledge.HEROES.size():
		var u := Unit.new()
		add_child(u)
		u.setup(figs.size(), GAME.UNIT_DEFS[hero])
		u.hero = hero
		u.set_process(false)  # o boneco da luta não roda aqui: o lobby só usa o corpo dele
		var spot: Dictionary = places[figs.size() % places.size()]
		u.position = spot["at"]
		u.face(spot["look"] as Vector3)
		u.set_meta("yaw", u.visual.rotation.y)
		# o que o _process anima: arte, o que vai atrás dela (sombra e contorno), escala, amassado e pulo
		var rig := {"art": null, "back": null, "halo": null, "tall": 2.6, "s": 1.0, "sq": 0.0, "hop": 0.0}
		var art_path := "res://assets/portraits/%s_art.webp" % u.key
		if ResourceLoader.exists(art_path):
			# a arte de corpo inteiro fica em pé no lugar do boneco, de frente pra câmera (que não gira).
			# Altura pela proporção do arquivo: figura alta tem FIG_H; figura larga encolhe pra não
			# ocupar o lugar dos vizinhos. Nada é esticado. O ponto de apoio é o pé (offset), pra
			# balançar, crescer e amassar a partir do chão.
			u.visual.visible = false
			var tex: Texture2D = load(art_path)
			var ts := tex.get_size()
			var tall := minf(FIG_H, FIG_W * ts.y / ts.x)
			var px := tall / ts.y
			var wide := ts.x * px
			var back := Node3D.new()
			u.add_child(back)
			# sombra gráfica: a mesma silhueta, escura, um pouco pro lado e pra trás da figura
			var shade := Sprite3D.new()
			shade.texture = tex
			shade.pixel_size = px
			shade.shaded = false
			shade.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			shade.modulate = Color(0.05, 0.05, 0.14)
			shade.offset = Vector2(0, ts.y * 0.5) + Vector2(0.13, -0.09) / px
			shade.position = Vector3(0, 0, -0.12)
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			back.add_child(shade)
			# contorno de destaque (foco, ponteiro, party): a silhueta engordada numa cor só
			var pad := 0.08
			var quad := QuadMesh.new()
			quad.size = Vector2(wide, tall) * (1.0 + 2.0 * pad)
			quad.center_offset = Vector3(0, tall * 0.5, 0)
			var halo := Fx.inst(back, quad, _shader(SH_HALO, {"tex": tex, "pad": pad, "grow": Vector2(0.075 / wide, 0.075 / tall)}), Vector3(0, 0, -0.05))
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			halo.visible = false
			var art := Sprite3D.new()
			art.texture = tex
			art.pixel_size = px
			art.shaded = false
			art.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			art.offset = Vector2(0, ts.y * 0.5)
			u.add_child(art)
			rig["art"] = art
			rig["back"] = back
			rig["halo"] = halo
			rig["tall"] = tall
		else:
			# sem arte: o rosto do herói flutuando em cima do boneco, pra dar pra reconhecer de longe
			var face := Sprite3D.new()
			face.texture = load("res://assets/portraits/%s_face.png" % u.key)
			face.pixel_size = 0.9 / face.texture.get_height()
			face.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			face.shaded = false
			face.position = Vector3(0, 2.75, 0)
			u.add_child(face)
		# sombra de contato no chão
		var blob := Fx.inst(u, Fx.disc(0.8, 0.01), Fx.mat(Color(0.04, 0.03, 0.1, 0.45), 0.0, true), Vector3(0, 0.045, 0))
		blob.scale = Vector3(1.0, 1.0, 0.55)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# foco: anel ciano girando · party: base dourada com estrela e um facho de luz
		var f := Fx.inst(u, Fx.torus(0.98, 1.24), Fx.mat(FOCUS_COL, 3.0, true), Vector3(0, 0.1, 0))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var inn := Node3D.new()
		u.add_child(inn)
		_lay(inn, Fx.disc(1.16, 0.02), Fx.flat(Paper.INK), Vector3(0, 0.06, 0))
		_lay(inn, Fx.disc(1.02, 0.02), Fx.flat(Paper.GOLD), Vector3(0, 0.075, 0))
		_lay(inn, Fx.disc(0.8, 0.02), Fx.flat(Color("F2A91E")), Vector3(0, 0.09, 0))
		var star := _lay(inn, _star_mesh(0.74, 0.34), Fx.flat(Paper.CREAM), Vector3(0, 0.11, 0))
		_spin.append(star)
		var beam_m := Fx.mat(Color(1.0, 0.82, 0.35, 0.065), 0.0, true)
		beam_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		beam_m.no_depth_test = false
		_lay(inn, Fx.cyl(0.25, 1.05, 5.5), beam_m, Vector3(0, 2.85, 0))
		marks.append({"focus": f, "in": inn, "tag": null})
		_rigs.append(rig)
		figs.append(u)


## Peça de enfeite sem sombra.
func _lay(parent: Node, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := Fx.inst(parent, mesh, material, at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Estrela de cinco pontas, deitada no chão.
func _star_mesh(r_out: float, r_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a0 := i * TAU / 10.0
		var a1 := (i + 1) * TAU / 10.0
		var r0 := r_out if i % 2 == 0 else r_in
		var r1 := r_in if i % 2 == 0 else r_out
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * r0, 0, sin(a0) * r0))
		st.add_vertex(Vector3(cos(a1) * r1, 0, sin(a1) * r1))
	return st.commit()


func _shader(code: String, params := {}) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for p in params:
		m.set_shader_parameter(p, params[p])
	return m


# ---------------------------------------------------------------- cenário

func _box(size: Vector3, at: Vector3, col: Color, glow := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return Fx.inst(self, b, Fx.mat(col, glow, glow > 0.0), at)


## Caixa de cor chapada (papel): não pega luz nem faz sombra.
func _flat(size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _lay(self, b, Fx.mat(col, 0.0, true), at)


## Quadrilátero solto no espaço (feixes e manchas de luz), com UV de 0 a 1.
func _quad(p: Array, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(p[i])
	return _lay(self, st.commit(), material, Vector3.ZERO)


func _build_room() -> void:
	var wood := Color("7A4424")
	var dark := Color("2A1610")
	var red := Color("B5262B")
	var teal := Color("1F7A72")
	var wall_z := -6.35
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.8, 0.66)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# sol de fim de tarde entrando pela janela do fundo: as sombras vêm na direção da câmera
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.42, -0.62, 0.66).normalized())
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.72
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 22.0
	add_child(cam)
	var aim := Vector3(-0.3, 1.36, 0.2)
	var pitch := deg_to_rad(25.0)
	cam.look_at_from_position(aim + 24.0 * Vector3(0, sin(pitch), cos(pitch)), aim)
	cam.current = true

	# chão xadrez em losango, palco de tábuas no fundo e paredes listradas
	var floor_m := PlaneMesh.new()
	floor_m.size = Vector2(34, 24)
	Fx.inst(self, floor_m, _shader(SH_CHECK, {"a": Color("8E4526"), "b": Color("B8632F")}), Vector3(0, 0, 3))
	var stage := BoxMesh.new()
	stage.size = Vector3(19.4, STAGE_H, 5.8)
	Fx.inst(self, stage, _shader(SH_PLANK, {"a": Color("6B3A20"), "b": Color("84492A")}), Vector3(0, STAGE_H * 0.5, -3.5))
	_flat(Vector3(19.4, STAGE_H - 0.16, 0.06), Vector3(0, (STAGE_H - 0.16) * 0.5, -0.58), Color("1E2460"))
	_flat(Vector3(19.4, 0.18, 0.1), Vector3(0, STAGE_H - 0.09, -0.57), Paper.GOLD)
	_flat(Vector3(19.4, 0.07, 0.1), Vector3(0, 0.035, -0.56), Paper.INK)
	for n in 16:
		var gem := _flat(Vector3(0.3, 0.3, 0.04), Vector3(-9.0 + n * 1.2, 0.42, -0.54), Paper.CREAM if n % 2 == 0 else Paper.PINK)
		gem.rotation.z = PI * 0.25
	var wall := BoxMesh.new()
	wall.size = Vector3(20.0, 10.0, 0.3)
	_lay(self, wall, _shader(SH_WALL, {"a": Color("262F86"), "b": Color("2E3A9E")}), Vector3(0, 5.0, wall_z - 0.15))
	for side in [-1.0, 1.0]:
		var sw := BoxMesh.new()
		sw.size = Vector3(0.3, 10.0, 20.0)
		_lay(self, sw, _shader(SH_WALL, {"a": Color("1C2368"), "b": Color("222B7A"), "w": 1.6}), Vector3(side * 9.85, 5.0, 3.0))
	# lambri e friso
	_flat(Vector3(19.4, 1.7, 0.08), Vector3(0, STAGE_H + 0.85, wall_z + 0.04), Color("5A2418"))
	_flat(Vector3(19.4, 0.12, 0.12), Vector3(0, STAGE_H + 1.72, wall_z + 0.06), Paper.GOLD)

	# tapete da fileira da frente: passadeira vermelha com faixa creme e losangos dourados
	_flat(Vector3(13.4, 0.02, 3.5), Vector3(-0.7, 0.012, 3.0), Paper.INK)
	_flat(Vector3(13.1, 0.02, 3.2), Vector3(-0.7, 0.02, 3.0), red)
	_flat(Vector3(12.5, 0.02, 2.6), Vector3(-0.7, 0.028, 3.0), Paper.CREAM)
	_flat(Vector3(12.2, 0.02, 2.3), Vector3(-0.7, 0.036, 3.0), Color("8E1B22"))
	for n in 9:
		var dia := _flat(Vector3(0.62, 0.02, 0.62), Vector3(-0.7 - 5.2 + n * 1.3, 0.042, 3.0), Paper.GOLD if n % 2 == 0 else red)
		dia.rotation.y = PI * 0.25
	for n in 14:
		for side in [-1.0, 1.0]:
			_flat(Vector3(0.1, 0.02, 0.34), Vector3(-0.7 + side * 6.95, 0.012, 1.45 + n * 0.24), Paper.CREAM).rotation.y = PI * 0.5

	# janela grande à direita, com o sol entrando
	var win_x := 7.3
	var win_y := 3.55
	_flat(Vector3(4.6, 2.5, 0.06), Vector3(win_x, win_y, wall_z + 0.03), dark)
	_box(Vector3(4.2, 2.1, 0.06), Vector3(win_x, win_y, wall_z + 0.06), Color(1.0, 0.86, 0.55), 2.2).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flat(Vector3(0.14, 2.1, 0.1), Vector3(win_x, win_y, wall_z + 0.1), dark)
	_flat(Vector3(4.2, 0.12, 0.1), Vector3(win_x, win_y + 0.25, wall_z + 0.1), dark)
	_flat(Vector3(4.9, 0.16, 0.4), Vector3(win_x, win_y - 1.3, wall_z + 0.2), Paper.CREAM)
	var ray := Vector3(-0.42, -0.62, 0.66).normalized()
	for n in 2:
		var x0 := win_x - 2.0 + n * 2.1
		var top_y := win_y + 0.9
		var reach := (top_y - STAGE_H) / -ray.y
		var a := Vector3(x0, top_y, wall_z + 0.15)
		var b := Vector3(x0 + 1.9, top_y, wall_z + 0.15)
		_quad([a, b, b + ray * reach, a + ray * reach], _shader(SH_SHAFT, {"col": Color(1.0, 0.82, 0.45, 0.2)}))
		# a mancha de sol no palco
		var low := (win_y - 1.0 - STAGE_H) / -ray.y
		var patch := Fx.mat(Color(1.0, 0.8, 0.4, 0.2), 0.0, true)
		patch.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var up := Vector3(0, 0.03, 0)
		_quad([a + ray * reach + up, b + ray * reach + up, Vector3(b.x, win_y - 1.0, b.z) + ray * low + up, Vector3(a.x, win_y - 1.0, a.z) + ray * low + up], patch)

	# balcão comprido com tampo creme, ripas e as coisas de cafeteria em cima
	var bar_z := -5.2
	var bar_top := STAGE_H + 1.2
	_flat(Vector3(11.6, 1.2, 0.9), Vector3(-1.6, STAGE_H + 0.6, bar_z), red)
	for n in 15:
		_flat(Vector3(0.14, 0.9, 0.04), Vector3(-7.2 + n * 0.8, STAGE_H + 0.62, bar_z + 0.47), Paper.CREAM)
	_flat(Vector3(11.6, 0.14, 0.94), Vector3(-1.6, STAGE_H + 0.07, bar_z), Paper.INK)
	_box(Vector3(12.0, 0.14, 1.2), Vector3(-1.6, bar_top + 0.07, bar_z), Paper.CREAM)
	bar_top += 0.14
	# máquina de café
	_box(Vector3(1.3, 0.95, 0.7), Vector3(1.6, bar_top + 0.48, bar_z), teal)
	_box(Vector3(1.4, 0.14, 0.8), Vector3(1.6, bar_top + 1.0, bar_z), Paper.CREAM)
	_flat(Vector3(0.9, 0.3, 0.04), Vector3(1.6, bar_top + 0.62, bar_z + 0.37), Paper.INK)
	for n in 3:
		_lay(self, Fx.sphere(0.07), Fx.mat([Paper.GOLD, Paper.PINK, Paper.CYAN][n], 1.5, true), Vector3(1.32 + n * 0.28, bar_top + 0.62, bar_z + 0.4))
	_cup(Vector3(1.6, bar_top, bar_z + 0.42), true)
	# potes de biscoito
	for n in 3:
		_jar(Vector3(-6.4 + n * 0.95, bar_top, bar_z), [Paper.PINK, Paper.GOLD, Paper.CYAN][n])
	# vitrine com biscoitões e bolo
	_box(Vector3(2.2, 0.08, 0.8), Vector3(-2.6, bar_top + 0.04, bar_z), dark)
	_lay(self, _mesh_box(Vector3(2.1, 0.8, 0.75)), Fx.mat(Color(0.75, 0.95, 1.0, 0.22)), Vector3(-2.6, bar_top + 0.48, bar_z))
	_flat(Vector3(2.2, 0.08, 0.8), Vector3(-2.6, bar_top + 0.9, bar_z), Paper.GOLD)
	for n in 3:
		_cookie(Vector3(-3.25 + n * 0.65, bar_top + 0.3, bar_z + 0.1), 0.26, true)
	_cup(Vector3(-0.6, bar_top, bar_z + 0.2), true)
	_cup(Vector3(-4.3, bar_top, bar_z + 0.25), true)
	_cup(Vector3(3.2, bar_top, bar_z + 0.2), false)

	# prateleiras na parede: potes, garrafas e xícaras
	for row in 2:
		var sy := STAGE_H + 2.35 + row * 0.95
		_box(Vector3(5.4, 0.1, 0.5), Vector3(-2.9, sy, wall_z + 0.28), Paper.CREAM)
		_flat(Vector3(5.4, 0.06, 0.04), Vector3(-2.9, sy - 0.08, wall_z + 0.54), Paper.INK)
		for n in 8:
			var at := Vector3(-5.35 + n * 0.7, sy + 0.05, wall_z + 0.3)
			var tone: Color = [Paper.PINK, Paper.GOLD, Paper.CYAN, Paper.GREEN, Paper.CREAM, red][(n + row * 2) % 6]
			match (n + row) % 3:
				0:
					_lay(self, Fx.cyl(0.07, 0.15, 0.55), Fx.mat(tone), at + Vector3(0, 0.28, 0))
					_lay(self, Fx.cyl(0.05, 0.05, 0.16), Fx.mat(tone.darkened(0.3)), at + Vector3(0, 0.62, 0))
				1:
					_lay(self, Fx.cyl(0.17, 0.17, 0.4), Fx.mat(tone), at + Vector3(0, 0.2, 0))
					_lay(self, Fx.disc(0.19, 0.07), Fx.mat(Paper.INK), at + Vector3(0, 0.43, 0))
				_:
					_lay(self, Fx.cyl(0.16, 0.11, 0.24), Fx.mat(Paper.CREAM), at + Vector3(0, 0.12, 0))
					_flat(Vector3(0.34, 0.06, 0.02), at + Vector3(0, 0.12, 0.15), tone)

	# lousa do cardápio, à esquerda
	var board := Vector3(-7.4, STAGE_H + 2.9, wall_z + 0.06)
	_flat(Vector3(2.9, 2.3, 0.08), board, Paper.CREAM)
	_flat(Vector3(2.6, 2.0, 0.1), board, Color("14261F"))
	var menu := _sign("MENU", board + Vector3(0, 0.62, 0.07), 0.0042, Paper.GOLD)
	menu.rotation.z = deg_to_rad(4.0)
	for n in 4:
		_flat(Vector3(1.3 - (n % 2) * 0.3, 0.07, 0.02), board + Vector3(-0.4, 0.15 - n * 0.3, 0.06), Paper.CREAM)
		_lay(self, Fx.disc(0.09, 0.02), Fx.flat(Paper.PINK if n % 2 == 0 else Paper.CYAN), board + Vector3(0.85, 0.15 - n * 0.3, 0.07)).rotation.x = PI * 0.5
	# letreiro pintado na parede, com o biscoitão de neon ao lado
	var cafe := _sign("CAFÉ", Vector3(1.9, STAGE_H + 2.84, wall_z + 0.1), 0.0034, Paper.CREAM)
	cafe.rotation.z = deg_to_rad(5.0)
	_sign("BISCOITAR", Vector3(3.15, STAGE_H + 2.3, wall_z + 0.1), 0.0058, Paper.GOLD).outline_size = 22
	var neon := Vector3(0.45, STAGE_H + 2.45, wall_z + 0.1)
	var ring := _lay(self, Fx.torus(0.5, 0.62), Fx.mat(Paper.PINK, 2.6, true), neon)
	ring.rotation.x = PI * 0.5
	for p in [Vector2(-0.2, 0.15), Vector2(0.18, 0.22), Vector2(0.05, -0.12), Vector2(-0.25, -0.2), Vector2(0.28, -0.08)]:
		var pv: Vector2 = p
		_lay(self, Fx.sphere(0.075), Fx.mat(Paper.GOLD, 2.6, true), neon + Vector3(pv.x, pv.y, 0))
	# quadros
	_poster(Vector3(-9.2, STAGE_H + 2.6, wall_z + 0.05), Paper.CYAN, Paper.PINK)

	# plantas, mesinhas e a porta
	_plant(Vector3(-8.3, STAGE_H, -3.6), 1.25)
	_plant(Vector3(9.0, STAGE_H, -4.4), 1.0)
	_plant(Vector3(7.4, 0, 3.6), 1.15)
	_table(Vector3(6.9, 0, 0.75))
	_flat(Vector3(0.1, 4.2, 2.4), Vector3(-9.66, 2.1, 4.6), Paper.CREAM)
	_flat(Vector3(0.12, 3.9, 2.1), Vector3(-9.64, 1.95, 4.6), teal)
	_lay(self, Fx.sphere(0.12), Fx.mat(Paper.GOLD, 1.0), Vector3(-9.5, 1.9, 3.8))

	# bandeirinhas atravessando o salão
	var flag_cols := [Paper.GOLD, Paper.PINK, Paper.CYAN, Paper.CREAM, Paper.GREEN]
	for n in 21:
		var k := n / 20.0
		var fx := lerpf(-9.6, 9.6, k)
		var fy := 6.55 - 0.75 * sin(k * PI)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.62, 0.68, 0.02)
		var flag := _lay(self, prism, Fx.flat(flag_cols[n % flag_cols.size()]), Vector3(fx, fy, -3.6))
		flag.rotation.z = PI + 0.25 * cos(k * PI)
	# lustres: cúpula colorida com a lâmpada acesa, balançando de leve
	var shades := [Paper.GOLD, Paper.PINK, Paper.CYAN, Paper.GOLD]
	var n_lamp := 0
	for at in [Vector3(-3.65, STAGE_H + 3.0, -4.4), Vector3(-0.75, STAGE_H + 2.75, -4.4), Vector3(5.2, STAGE_H + 2.9, -4.4)]:
		var hang := Node3D.new()
		hang.position = at + Vector3(0, 4.0, 0)
		add_child(hang)
		_lay(hang, _mesh_box(Vector3(0.05, 3.6, 0.05)), Fx.mat(Paper.INK, 0.0, true), Vector3(0, -1.8, 0))
		_lay(hang, Fx.cyl(0.1, 0.5, 0.44), Fx.mat(shades[n_lamp], 0.0, true), Vector3(0, -3.82, 0))
		_lay(hang, Fx.cyl(0.52, 0.52, 0.07), Fx.mat(Paper.INK, 0.0, true), Vector3(0, -4.06, 0))
		_lay(hang, Fx.sphere(0.2), Fx.mat(Color(1.0, 0.86, 0.55), 3.2, true), Vector3(0, -4.1, 0))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, -4.6, 0)
		lamp.light_color = Color(1.0, 0.76, 0.48)
		lamp.light_energy = 1.5
		lamp.omni_range = 8.5
		lamp.omni_attenuation = 1.3
		hang.add_child(lamp)
		_lamps.append([hang, n_lamp * 1.9])
		n_lamp += 1


func _mesh_box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Letreiro pintado na parede (não gira com a câmera).
func _sign(text: String, at: Vector3, pixel: float, col: Color) -> Label3D:
	var l := Fx.label(self, text, at, 96)
	l.font = Paper.display()
	l.pixel_size = pixel
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.modulate = col
	l.outline_size = 18
	l.outline_modulate = Paper.INK
	return l


## Biscoito com gotas de chocolate. `up` = em pé, de frente pra câmera.
func _cookie(at: Vector3, r: float, up := false) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_lay(root, Fx.disc(r, r * 0.3), Fx.mat(Color("D9963F")), Vector3.ZERO)
	for p in [Vector2(0.3, 0.2), Vector2(-0.35, 0.3), Vector2(0.0, -0.4), Vector2(-0.3, -0.15), Vector2(0.4, -0.3)]:
		var pv: Vector2 = p
		_lay(root, Fx.disc(r * 0.17, r * 0.34), Fx.mat(Color("4A2612")), Vector3(pv.x * r, 0.01, pv.y * r))
	if up:
		root.rotation.x = PI * 0.5 - 0.3


## Pote de vidro com biscoitos empilhados e tampa colorida.
func _jar(at: Vector3, lid: Color) -> void:
	for n in 4:
		_lay(self, Fx.disc(0.2, 0.09), Fx.mat(Color("D9963F") if n % 2 == 0 else Color("B8742C")), at + Vector3(0.02 * (n % 2), 0.08 + n * 0.11, 0))
	_lay(self, Fx.cyl(0.27, 0.27, 0.62), Fx.mat(Color(0.8, 0.95, 1.0, 0.25)), at + Vector3(0, 0.31, 0))
	_lay(self, Fx.cyl(0.29, 0.29, 0.1), Fx.mat(lid), at + Vector3(0, 0.67, 0))
	_lay(self, Fx.sphere(0.08), Fx.mat(Paper.INK), at + Vector3(0, 0.76, 0))


## Xícara com pires; `hot` solta fumacinha.
func _cup(at: Vector3, hot: bool) -> void:
	_lay(self, Fx.disc(0.2, 0.03), Fx.mat(Paper.CREAM), at + Vector3(0, 0.015, 0))
	_lay(self, Fx.cyl(0.14, 0.1, 0.2), Fx.mat(Paper.CREAM), at + Vector3(0, 0.13, 0))
	_lay(self, Fx.disc(0.115, 0.02), Fx.mat(Color("4A2612")), at + Vector3(0, 0.225, 0))
	if hot:
		for n in 3:
			var m := Fx.mat(Color(1.0, 0.97, 0.9, 0.5), 0.0, true)
			var puff := _lay(self, Fx.sphere(0.09), m, at)
			_steam.append([puff, at + Vector3(0, 0.3, 0), n / 3.0 + at.x * 0.37, m])


## Quadro na parede: moldura creme e um biscoitão estilizado.
func _poster(at: Vector3, bg: Color, accent: Color) -> void:
	_flat(Vector3(1.5, 2.0, 0.06), at, Paper.INK)
	_flat(Vector3(1.34, 1.84, 0.08), at, Paper.CREAM)
	_flat(Vector3(1.14, 1.64, 0.1), at, bg)
	var c := _lay(self, Fx.disc(0.4, 0.02), Fx.flat(accent), at + Vector3(0, 0.15, 0.07))
	c.rotation.x = PI * 0.5
	_flat(Vector3(0.8, 0.12, 0.12), at + Vector3(0, -0.5, 0.01), Paper.INK)


func _table(at: Vector3) -> void:
	var seat := Color("B5262B")
	Fx.inst(self, Fx.disc(1.0, 0.1), Fx.mat(Paper.CREAM), at + Vector3(0, 1.0, 0))
	_lay(self, Fx.disc(1.05, 0.04), Fx.mat(Paper.INK, 0.0, true), at + Vector3(0, 0.94, 0))
	Fx.inst(self, Fx.cyl(0.09, 0.12, 1.0), Fx.mat(Color(0.12, 0.12, 0.2)), at + Vector3(0, 0.5, 0))
	Fx.inst(self, Fx.disc(0.5, 0.06), Fx.mat(Color(0.12, 0.12, 0.2)), at + Vector3(0, 0.03, 0))
	_cup(at + Vector3(-0.4, 1.05, 0.2), true)
	_cookie(at + Vector3(0.3, 1.09, -0.1), 0.24)
	for side in [-1.0, 1.0]:
		_stool(at + Vector3(side * 1.5, 0, 0.5), seat)


func _stool(at: Vector3, col: Color) -> void:
	Fx.inst(self, Fx.disc(0.4, 0.14), Fx.mat(col), at + Vector3(0, 0.72, 0))
	_lay(self, Fx.disc(0.42, 0.04), Fx.mat(Paper.INK, 0.0, true), at + Vector3(0, 0.64, 0))
	Fx.inst(self, Fx.cyl(0.05, 0.07, 0.66), Fx.mat(Color(0.12, 0.12, 0.2)), at + Vector3(0, 0.33, 0))
	Fx.inst(self, Fx.disc(0.28, 0.04), Fx.mat(Color(0.12, 0.12, 0.2)), at + Vector3(0, 0.02, 0))


func _plant(at: Vector3, k := 1.0) -> void:
	Fx.inst(self, Fx.cyl(0.46 * k, 0.32 * k, 0.75 * k), Fx.mat(Paper.CREAM), at + Vector3(0, 0.37 * k, 0))
	_lay(self, Fx.cyl(0.48 * k, 0.48 * k, 0.1 * k), Fx.mat(Paper.PINK), at + Vector3(0, 0.72 * k, 0))
	var leaf := Color("2F9E5C")
	for p in [[Vector3(0, 1.4, 0), 0.78], [Vector3(0.38, 2.0, 0.1), 0.52], [Vector3(-0.42, 1.85, 0.05), 0.46], [Vector3(0.05, 2.5, 0), 0.36]]:
		var off: Vector3 = p[0]
		var r: float = p[1]
		var ball := SphereMesh.new()
		ball.radius = r * k
		ball.height = r * k * 2.0
		ball.radial_segments = 7
		ball.rings = 4
		Fx.inst(self, ball, Fx.mat(leaf.lightened(0.12 * (2.5 - off.y))), at + off * k)


# ---------------------------------------------------------------- interface (kit Paper)

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


func _small(text: String, fill: Color, fg: Color, px := 18) -> ShineButton:
	var b := ShineButton.new()
	b.text = text
	b.font_px = px
	b.skew = 12
	b.border = 4
	b.shadow = Vector2(5, 5)
	b.fill = fill
	b.fg = fg
	b.auto_hover = true
	b.hover_scale = 1.04
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	# cantos escuros: o salão fecha em volta do elenco
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_m := ShaderMaterial.new()
	vig_m.shader = Shader.new()
	vig_m.shader.code = SH_VIGNETTE
	vig.material = vig_m
	ui.add_child(vig)
	_build_tags()

	# faixa de baixo: o chão do HUD, onde ficam a dica, a party e o READY TO PLAY
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.anchor_right = 1.0
	band.offset_top = -92.0
	ui.add_child(band)
	for part in [[Paper.GOLD, -9.0], [Paper.INK, 0.0]]:
		var strip := CutPanel.make(Rect2(), [[0, .3], [1, 0], [1, 1.2], [0, 1.2]], part[0] as Color, 0, Vector2.ZERO)
		strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		strip.offset_top = float(part[1])
		band.add_child(strip)

	# título e contagem
	var head := _anchored(ui, Vector2(0, 0), Vector2(520, 110), Vector2(20, 14))
	var accent := CutPanel.make(Rect2(-34, -4, 372, 62), [[0, .1], [1, 0], [.96, .86], [.02, 1]], Paper.PINK, 0, Vector2.ZERO)
	accent.rotation = deg_to_rad(-3.5)
	head.add_child(accent)
	var tag := CutPanel.make(Rect2(0, 0, 300, 66), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	head.add_child(tag)
	var sub := Chip.new()
	sub.px = 12
	sub.fill = Paper.INK
	sub.ink = Paper.CREAM
	sub.shadow = Vector2.ZERO
	sub.text = "ESCOLHA 4 HERÓIS"
	sub.position = Vector2(34, 72)
	sub.rotation = deg_to_rad(-2.0)
	head.add_child(sub)
	var title := Paper.label("CAFETERIA", 36, Paper.INK, Paper.display())
	title.size = Vector2(300, 66)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.rotation = deg_to_rad(-2.0)
	title.pivot_offset = title.size * 0.5
	tag.add_child(title)
	count_chip = Chip.new()
	count_chip.px = 16
	count_chip.fill = Paper.GOLD
	count_chip.position = Vector2(330, 20)
	count_chip.rotation = deg_to_rad(2.0)
	head.add_child(count_chip)

	var back := _small("VOLTAR", Paper.CREAM, Paper.INK, 16)
	back.chevron = -1
	back.chevron_px = 14
	var back_box := _anchored(ui, Vector2(1, 0), Vector2(140, 44), Vector2(-24, 18))
	back.size = Vector2(140, 44)
	back.pressed.connect(_back)
	back_box.add_child(back)

	# ficha do herói em foco, ao lado dele no salão
	card = Control.new()
	card.size = CARD
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	ui.add_child(card)
	card.add_child(CutPanel.make(Rect2(0, 0, CARD.x, CARD.y), [[.02, 0], [1, .04], [.98, 1], [0, .96]], Paper.CREAM, 5, Vector2(8, 8)))
	var art_frame := CutPanel.make(Rect2(14, 16, 112, 150), [[0, 0], [1, 0], [1, 1], [0, 1]], Paper.INK, 0, Vector2.ZERO)
	art_frame.rotation = deg_to_rad(-2.0)
	art_frame.clip_contents = true
	card.add_child(art_frame)
	card_art = TextureRect.new()
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.position = Vector2(4, 4)
	card_art.size = Vector2(104, 142)
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(card_art)
	card_name = Paper.label("", 24, Paper.INK, Paper.display())
	card_name.position = Vector2(138, 14)
	card_name.size = Vector2(184, 32)
	card_name.clip_text = true
	card.add_child(card_name)
	card_role = Chip.new()
	card_role.px = 11
	card_role.fill = Paper.INK
	card_role.ink = Paper.CREAM
	card_role.shadow = Vector2.ZERO
	card_role.position = Vector2(140, 50)
	card.add_child(card_role)
	card_text = Paper.label("", 15, Paper.INK, Paper.body(700))
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.position = Vector2(138, 82)
	card_text.size = Vector2(180, 96)
	card_text.add_theme_constant_override("line_spacing", -4)
	card.add_child(card_text)
	card_btn = ShineButton.new()
	card_btn.shape = [[.03, .08], [1, 0], [.97, .9], [0, 1]]
	card_btn.border = 5
	card_btn.font_px = 20
	card_btn.shadow = Vector2(6, 6)
	card_btn.fill = Paper.GOLD
	card_btn.fill_hover = Paper.GOLD_HOVER
	card_btn.hover_scale = 1.04
	card_btn.position = Vector2(18, 190)
	card_btn.size = Vector2(294, 54)
	card_btn.pressed.connect(_ask_add)
	card.add_child(card_btn)

	# os quatro lugares da party, embaixo
	var bar := _anchored(ui, Vector2(0.5, 1), Vector2(520, 132), Vector2(0, -10))
	bar.add_child(CutPanel.make(Rect2(0, 18, 520, 114), [[.01, 0], [1, .06], [.99, 1], [0, .94]], Paper.NAVY, 5, Vector2(8, 8)))
	var bar_tag := Chip.new()
	bar_tag.px = 14
	bar_tag.text = "SUA PARTY"
	bar_tag.position = Vector2(20, 6)
	bar_tag.rotation = deg_to_rad(-2.0)
	bar.add_child(bar_tag)
	var rots := [-3.0, 2.0, -2.0, 3.0]
	for n in 4:
		var panel := CutPanel.make(Rect2(22 + n * 122, 34, 104, 86), [[0, .03], [1, 0], [.97, 1], [.03, .97]], Color("1A1E52"), 4, Vector2(4, 5))
		panel.rotation = deg_to_rad(rots[n])
		panel.pivot_offset = Vector2(52, 43)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and n < team.size():
				_remove(team[n]))
		bar.add_child(panel)
		var face := TextureRect.new()
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.position = Vector2(8, 7)
		face.size = Vector2(88, 56)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(face)
		var plus := Paper.label("+", 40, NAVY2, Paper.display())
		plus.size = Vector2(104, 86)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(plus)
		var nm := Paper.label("", 11, Paper.INK, Paper.display())
		nm.position = Vector2(4, 64)
		nm.size = Vector2(96, 18)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		panel.add_child(nm)
		# selo de carta nova do herói que está neste lugar
		var chip := Chip.new()
		chip.px = 11
		chip.pad = 7.0
		chip.skew = 8.0
		chip.border = 2.0
		chip.shadow = Vector2(-2, 3)
		chip.fill = Paper.PINK
		chip.ink = Paper.CREAM
		chip.text = "NOVO"
		chip.position = Vector2(52, -10)
		chip.rotation = deg_to_rad(6.0)
		chip.visible = false
		panel.add_child(chip)
		# número do lugar, o mesmo da etiqueta do herói no salão
		var num := Chip.new()
		num.px = 12
		num.pad = 7.0
		num.skew = 8.0
		num.border = 2.0
		num.shadow = Vector2(-2, 3)
		num.fill = Paper.GOLD
		num.text = str(n + 1)
		num.position = Vector2(-10, 24)
		num.visible = false
		panel.add_child(num)
		slots.append({"panel": panel, "face": face, "plus": plus, "name": nm, "new": chip, "num": num})

	# READY TO PLAY, no canto de baixo à direita: só libera com os quatro
	var ready_box := _anchored(ui, Vector2(1, 1), Vector2(330, 84), Vector2(-28, -26))
	ready_btn = ShineButton.new()
	ready_btn.text = "READY TO PLAY"
	ready_btn.shape = [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	ready_btn.border = 6
	ready_btn.font_px = 26
	ready_btn.text_rot = -3
	ready_btn.shadow = Vector2(9, 9)
	ready_btn.fill = Paper.GOLD
	ready_btn.fill_hover = Paper.GOLD_HOVER
	ready_btn.fg_hover = Paper.RED
	ready_btn.hover_scale = 1.05
	ready_btn.size = Vector2(330, 84)
	ready_btn.pressed.connect(_ready_to_play)
	ready_box.add_child(ready_btn)

	# a dica mora na faixa de baixo, à esquerda
	hint = Paper.label("", 14, Paper.CREAM, Paper.body(700))
	var hint_box := _anchored(ui, Vector2(0, 1), Vector2(330, 56), Vector2(22, -6))
	var how := Chip.new()
	how.px = 11
	how.pad = 8.0
	how.fill = Paper.CYAN
	how.shadow = Vector2.ZERO
	how.text = "COMO JOGAR"
	how.position = Vector2(2, -16)
	hint_box.add_child(how)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(4, 8)
	hint.size = Vector2(322, 46)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("line_spacing", -4)
	hint_box.add_child(hint)

	# confirmação de entrada na party
	dialog = Control.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.visible = false
	ui.add_child(dialog)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(dim)
	var box := _anchored(dialog, Vector2(0.5, 0.5), Vector2(520, 210), Vector2.ZERO)
	box.add_child(CutPanel.make(Rect2(0, 0, 520, 210), [[.02, 0], [1, .04], [.98, 1], [0, .96]], PURPLE, 5, Vector2(8, 8)))
	dialog_text = Paper.label("", 26, Paper.CREAM, Paper.display())
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.position = Vector2(24, 20)
	dialog_text.size = Vector2(472, 100)
	dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(dialog_text)
	var yes := _small("CONFIRMAR", Paper.GOLD, Paper.INK, 20)
	yes.position = Vector2(40, 138)
	yes.size = Vector2(210, 52)
	yes.pressed.connect(_confirm_add)
	box.add_child(yes)
	var no := _small("CANCELAR", Paper.CREAM, Paper.INK, 20)
	no.position = Vector2(270, 138)
	no.size = Vector2(210, 52)
	no.pressed.connect(func():
		dialog.visible = false
		_refresh())
	box.add_child(no)


## Etiquetas de nome dos heróis: papel creme recortado, presas nos pés de cada um (2D, por cima do
## salão e por baixo do resto do HUD). Na party ganham o número do lugar; com o ponteiro em cima,
## mostram a função; herói com carta nova ganha o selo NOVO.
func _build_tags() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	for k in figs.size():
		var u := figs[k]
		var h: Dictionary = Knowledge.HEROES[u.hero]
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)
		var name_chip := Chip.new()
		name_chip.px = 14
		name_chip.pad = 12.0
		name_chip.shadow = Vector2(-4, 5)
		name_chip.text = u.unit_name.to_upper()
		name_chip.position = Vector2(-name_chip.size.x * 0.5, -9.0)
		var role := Chip.new()
		role.px = 10
		role.pad = 8.0
		role.border = 0.0
		role.fill = Paper.INK
		role.ink = Paper.CREAM
		role.shadow = Vector2.ZERO
		role.text = String(h["role"]).to_upper()
		role.position = Vector2(-role.size.x * 0.5 - 6.0, name_chip.size.y - 9.0)
		role.visible = false
		box.add_child(role)
		box.add_child(name_chip)
		var num := Chip.new()
		num.px = 15
		num.pad = 9.0
		num.fill = Paper.INK
		num.ink = Paper.GOLD
		num.border = 0.0
		num.shadow = Vector2.ZERO
		num.visible = false
		box.add_child(num)
		var news := Chip.new()
		news.px = 10
		news.pad = 6.0
		news.skew = 8.0
		news.border = 2.0
		news.shadow = Vector2(-2, 3)
		news.fill = Paper.PINK
		news.ink = Paper.CREAM
		news.text = "NOVO"
		news.position = Vector2(name_chip.size.x * 0.5 - 16.0, -20.0)
		news.rotation = deg_to_rad(6.0)
		news.visible = false
		box.add_child(news)
		_tags.append({"box": box, "name": name_chip, "num": num, "role": role, "new": news, "unit": u, "lit": false})
		marks[k]["tag"] = box
