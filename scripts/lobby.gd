extends Node3D
## LOBBY — a cafeteria onde a party é montada (cena lobby.tscn).
## Todos os heróis jogáveis estão no salão, cada vez num lugar diferente. Não é uma área jogável:
## ninguém anda. O jogador FOCA um herói (clique nele ou setas) e, numa ficha ao lado dele,
## confirma a entrada na party. Com os quatro lugares cheios, READY TO PLAY libera os bosses.
##   clique num herói: foca · ← ↑ ↓ →: foca o herói mais próximo NAQUELA direção da tela
##   (não uma lista: sem ninguém pra lá, a seta não faz nada) · ENTER: escolhe / confirma
##   clique num lugar cheio da party: tira o herói · ESC: volta pros saves
## HUD no kit de papel (Paper), como a tela de cartas. O cenário é montado em código.

const GAME := preload("res://scripts/game.gd")
const PURPLE := Color("5B2BB8")
const NAVY2 := Color("2B3384")
const DIM := Color("B9BEEA")
const CARD := Vector2(330, 262)
const FOCUS_COL := Color(0.3, 0.9, 1.0)

## Lugares do salão: onde fica e pra onde olha. A cada entrada os heróis são sorteados entre eles.
const SPOTS := [
	{"at": Vector3(-3.4, 0, -2.2), "look": Vector3(0.4, 0, 1)},    # balcão, esquerda
	{"at": Vector3(-1.2, 0, -2.2), "look": Vector3(-0.3, 0, 1)},   # balcão, meio
	{"at": Vector3(1.4, 0, -2.4), "look": Vector3(-0.6, 0, 1)},    # balcão, perto da máquina
	{"at": Vector3(-5.6, 0, 1.0), "look": Vector3(1, 0, 0.3)},     # mesa da esquerda
	{"at": Vector3(-3.5, 0, 1.4), "look": Vector3(-1, 0, 0.4)},    # mesa da esquerda, outro lado
	{"at": Vector3(3.0, 0, 0.4), "look": Vector3(1, 0, 0.5)},      # mesa da direita
	{"at": Vector3(5.2, 0, 0.8), "look": Vector3(-1, 0, 0.5)},     # mesa da direita, outro lado
	{"at": Vector3(5.6, 0, -3.0), "look": Vector3(-0.5, 0, 1)},    # janela
	{"at": Vector3(0.2, 0, 2.6), "look": Vector3(0, 0, 1)},        # de pé, no meio
	{"at": Vector3(-6.4, 0, -2.6), "look": Vector3(0.8, 0, 1)},    # canto das plantas
]

var cam: Camera3D
var figs: Array[Unit] = []      # um boneco por herói; figs[k].hero = índice em Knowledge.HEROES
var marks: Array = []           # por boneco: {"focus": anel de foco, "in": anel de party, "tag": Label3D}
var team: Array = []            # heróis já na party, na ordem em que entraram
var focus := -1                 # índice em figs do herói em foco (-1 = nenhum)
var _t := 0.0

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
	if OS.get_cmdline_user_args().size() > 0:
		Knowledge.persist = false
	Knowledge.load_save()
	Settings.boot()
	randomize()
	_build_room()
	_build_heroes()
	_build_ui()
	# save que já tinha party volta com ela nos lugares; save novo começa vazio
	team = Knowledge.party.duplicate() if Knowledge.party_ready() else []
	_refresh()


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
	_refresh()


## Herói mais próximo do ponto da tela, se estiver perto o bastante pra contar como clique nele.
func _pick(at: Vector2) -> int:
	var best := -1
	var best_d := 90.0
	for k in figs.size():
		var p := cam.unproject_position(figs[k].position + Vector3(0, 0.9, 0))
		var d := Vector2((at.x - p.x), (at.y - p.y) * 0.6).length()  # o boneco é mais alto que largo
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
		_pop(figs[focus].position)
	_refresh()


func _remove(hero: int) -> void:
	if dialog.visible:
		return
	team.erase(hero)
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


func _pop(at: Vector3) -> void:
	var m := Fx.mat(Color(1.0, 0.8, 0.25, 0.6), 2.0, true)
	var mi := Fx.inst(self, Fx.sphere(1.0), m, at + Vector3(0, 0.4, 0))
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.0, 1.0, 2.0), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)


# ---------------------------------------------------------------- tela

func _refresh() -> void:
	for k in figs.size():
		marks[k]["focus"].visible = k == focus
		marks[k]["in"].visible = _in_team(k)
		marks[k]["tag"].visible = _in_team(k)
	for n in 4:
		var s: Dictionary = slots[n]
		var filled := n < team.size()
		s["face"].visible = filled
		s["plus"].visible = not filled
		s["name"].text = String(Knowledge.HEROES[team[n]]["name"]).to_upper() if filled else ""
		if filled:
			s["face"].texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[team[n]]["key"])
		s["panel"].fill = Paper.CREAM if filled else Color("1A1E52")
	count_chip.text = "PARTY  %d / 4" % team.size()
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
		var art := "res://assets/portraits/%s_art.webp" % h["key"]
		card_art.texture = load(art if ResourceLoader.exists(art) else "res://assets/portraits/%s_face.png" % h["key"])
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


func _process(delta: float) -> void:
	_t += delta
	for k in figs.size():
		var u := figs[k]
		# vida de cafeteria: cada um respira e balança no seu ritmo
		var ph := k * 1.7
		u.visual.position.y = 0.04 * sin(_t * 1.6 + ph)
		u.visual.rotation.z = 0.05 * sin(_t * 0.9 + ph)
		u.visual.rotation.y = float(u.get_meta("yaw")) + 0.25 * sin(_t * 0.5 + ph)
		marks[k]["focus"].rotate_y(delta * 2.5)
		marks[k]["focus"].scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 6.0))
	if focus >= 0 and card.visible:
		# a ficha fica ao lado do herói em foco: à direita, ou à esquerda se não couber
		var view := get_viewport().get_visible_rect().size
		var p := _screen(focus)
		var x := p.x + 70.0
		if x + CARD.x > view.x - 16.0:
			x = p.x - 70.0 - CARD.x
		card.position = Vector2(x, clampf(p.y - CARD.y * 0.55, 70.0, view.y - CARD.y - 150.0))


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
		# o rosto do herói flutuando em cima da cabeça, pra dar pra reconhecer de longe
		var face := Sprite3D.new()
		face.texture = load("res://assets/portraits/%s_face.png" % u.key)
		face.pixel_size = 0.9 / face.texture.get_height()
		face.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		face.shaded = false
		face.position = Vector3(0, 2.75, 0)
		u.add_child(face)
		var name_l := Fx.label(u, u.unit_name.to_upper(), Vector3(0, 3.45, 0), 34)
		name_l.outline_size = 14
		name_l.outline_modulate = Paper.INK
		var f := Fx.inst(u, Fx.torus(0.72, 0.9), Fx.mat(FOCUS_COL, 3.5, true), Vector3(0, 0.05, 0))
		var inn := Fx.inst(u, Fx.torus(0.95, 1.1), Fx.mat(Paper.GOLD, 3.5, true), Vector3(0, 0.04, 0))
		var tag := Fx.label(u, "NA PARTY", Vector3(0, 2.05, 0.3), 30)
		tag.modulate = Paper.GOLD
		tag.outline_size = 14
		tag.outline_modulate = Paper.INK
		marks.append({"focus": f, "in": inn, "tag": tag})
		figs.append(u)


# ---------------------------------------------------------------- cenário

func _box(size: Vector3, at: Vector3, col: Color, glow := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return Fx.inst(self, b, Fx.mat(col, glow, glow > 0.0), at)


func _build_room() -> void:
	var wood := Color(0.45, 0.28, 0.17)
	var dark := Color(0.26, 0.15, 0.1)
	var cream := Color(0.93, 0.86, 0.72)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.82, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 46.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 7.4, 12.6), Vector3(0, 1.0, -0.6))
	cam.current = true

	# chão de tábuas, tapete e paredes
	_box(Vector3(17, 0.2, 12), Vector3(0, -0.1, 0), wood)
	for n in 8:
		_box(Vector3(0.05, 0.02, 12), Vector3(-7.4 + n * 2.1, 0.01, 0), dark)
	Fx.inst(self, Fx.disc(2.6), Fx.mat(Color(0.62, 0.2, 0.22)), Vector3(0.2, 0.02, 2.6))
	Fx.inst(self, Fx.disc(2.1), Fx.mat(Color(0.86, 0.6, 0.3)), Vector3(0.2, 0.03, 2.6))
	_box(Vector3(17, 6, 0.3), Vector3(0, 3, -5.9), cream)
	_box(Vector3(0.3, 6, 12), Vector3(-8.4, 3, 0), cream.darkened(0.08))
	_box(Vector3(0.3, 6, 12), Vector3(8.4, 3, 0), cream.darkened(0.08))
	_box(Vector3(17, 1.1, 0.34), Vector3(0, 0.55, -5.86), dark)   # lambri

	# janela grande com a luz da rua, e a lousa do cardápio
	_box(Vector3(4.2, 2.6, 0.1), Vector3(5.4, 3.2, -5.7), Color(0.75, 0.9, 1.0), 1.6)
	_box(Vector3(4.5, 0.16, 0.2), Vector3(5.4, 4.55, -5.68), dark)
	_box(Vector3(4.5, 0.16, 0.2), Vector3(5.4, 1.85, -5.68), dark)
	_box(Vector3(0.16, 2.7, 0.2), Vector3(5.4, 3.2, -5.68), dark)
	_box(Vector3(3.4, 1.9, 0.1), Vector3(-2.0, 4.0, -5.7), Color(0.12, 0.16, 0.14))
	for n in 4:
		_box(Vector3(2.2 - n * 0.3, 0.07, 0.04), Vector3(-2.2, 4.6 - n * 0.36, -5.62), Color(0.95, 0.95, 0.9), 0.6)
	var sign := Fx.label(self, "CAFÉ BISCOITAR", Vector3(1.6, 5.3, -5.6), 56)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.modulate = Color(1.0, 0.8, 0.25)
	sign.outline_size = 16
	sign.outline_modulate = Paper.INK

	# balcão, máquina de café, vitrine de biscoitos e prateleira de xícaras
	_box(Vector3(8.6, 1.15, 1.0), Vector3(-1.2, 0.58, -3.9), dark)
	_box(Vector3(8.9, 0.14, 1.25), Vector3(-1.2, 1.22, -3.9), Color(0.82, 0.62, 0.4))
	_box(Vector3(1.1, 0.9, 0.7), Vector3(2.2, 1.75, -4.0), Color(0.75, 0.2, 0.2))
	_box(Vector3(0.7, 0.2, 0.5), Vector3(2.2, 2.3, -4.0), Color(0.9, 0.9, 0.9))
	_box(Vector3(1.8, 0.7, 0.8), Vector3(-3.6, 1.65, -3.95), Color(0.8, 0.95, 1.0, 0.35))
	for n in 4:
		Fx.inst(self, Fx.disc(0.2, 0.06), Fx.mat(Color(0.86, 0.6, 0.3)), Vector3(-4.2 + n * 0.4, 1.38, -3.9))
	_box(Vector3(5.0, 0.1, 0.5), Vector3(1.6, 2.9, -5.55), dark)
	for n in 7:
		Fx.inst(self, Fx.cyl(0.13, 0.1, 0.24), Fx.mat(Color(0.95, 0.93, 0.88)), Vector3(-0.4 + n * 0.66, 3.07, -5.5))
	for n in 3:
		_stool(Vector3(-3.4 + n * 2.3, 0, -2.9))

	# mesas com cadeiras, plantas e a porta
	_table(Vector3(-4.6, 0, 1.2))
	_table(Vector3(4.1, 0, 0.6))
	_plant(Vector3(-7.4, 0, -4.6))
	_plant(Vector3(7.5, 0, 4.4))
	_plant(Vector3(-7.5, 0, 4.6))
	_box(Vector3(0.12, 3.6, 2.0), Vector3(-8.2, 1.8, 2.6), dark)
	Fx.inst(self, Fx.sphere(0.1), Fx.mat(Paper.GOLD, 1.0), Vector3(-8.05, 1.7, 1.9))

	# lustres: bola de luz quente pendurada, com luz de verdade
	for at in [Vector3(-4.6, 4.6, 1.2), Vector3(4.1, 4.6, 0.6), Vector3(-1.2, 4.6, -3.2), Vector3(0.2, 4.8, 3.0)]:
		_box(Vector3(0.04, 1.4, 0.04), at + Vector3(0, 0.8, 0), dark)
		Fx.inst(self, Fx.sphere(0.32), Fx.mat(Color(1.0, 0.8, 0.45), 3.0, true), at)
		var lamp := OmniLight3D.new()
		lamp.position = at - Vector3(0, 0.3, 0)
		lamp.light_color = Color(1.0, 0.78, 0.5)
		lamp.light_energy = 1.6
		lamp.omni_range = 7.5
		add_child(lamp)


func _table(at: Vector3) -> void:
	var top := Color(0.82, 0.62, 0.4)
	Fx.inst(self, Fx.disc(1.05, 0.1), Fx.mat(top), at + Vector3(0, 1.0, 0))
	Fx.inst(self, Fx.cyl(0.09, 0.12, 1.0), Fx.mat(Color(0.2, 0.2, 0.22)), at + Vector3(0, 0.5, 0))
	Fx.inst(self, Fx.disc(0.5, 0.06), Fx.mat(Color(0.2, 0.2, 0.22)), at + Vector3(0, 0.03, 0))
	# duas xícaras e um prato de biscoito
	Fx.inst(self, Fx.cyl(0.12, 0.09, 0.2), Fx.mat(Color(0.95, 0.93, 0.88)), at + Vector3(-0.4, 1.15, 0.1))
	Fx.inst(self, Fx.cyl(0.12, 0.09, 0.2), Fx.mat(Color(0.95, 0.93, 0.88)), at + Vector3(0.45, 1.15, -0.2))
	Fx.inst(self, Fx.disc(0.22, 0.05), Fx.mat(Color(0.86, 0.6, 0.3)), at + Vector3(0.0, 1.09, 0.35))
	for side in [-1, 1]:
		var seat := at + Vector3(side * 1.75, 0, 0.9)
		_box(Vector3(0.7, 0.1, 0.7), seat + Vector3(0, 0.55, 0), Color(0.7, 0.25, 0.25))
		_box(Vector3(0.7, 0.9, 0.1), seat + Vector3(0, 1.0, 0.33), Color(0.7, 0.25, 0.25))
		_box(Vector3(0.08, 0.55, 0.08), seat + Vector3(-0.28, 0.27, -0.28), Color(0.2, 0.12, 0.08))
		_box(Vector3(0.08, 0.55, 0.08), seat + Vector3(0.28, 0.27, -0.28), Color(0.2, 0.12, 0.08))


func _stool(at: Vector3) -> void:
	Fx.inst(self, Fx.disc(0.36, 0.1), Fx.mat(Color(0.7, 0.25, 0.25)), at + Vector3(0, 0.8, 0))
	Fx.inst(self, Fx.cyl(0.05, 0.07, 0.8), Fx.mat(Color(0.2, 0.2, 0.22)), at + Vector3(0, 0.4, 0))


func _plant(at: Vector3) -> void:
	Fx.inst(self, Fx.cyl(0.42, 0.32, 0.7), Fx.mat(Color(0.75, 0.4, 0.28)), at + Vector3(0, 0.35, 0))
	Fx.inst(self, Fx.sphere(0.75), Fx.mat(Color(0.25, 0.6, 0.32)), at + Vector3(0, 1.35, 0))
	Fx.inst(self, Fx.sphere(0.5), Fx.mat(Color(0.3, 0.7, 0.38)), at + Vector3(0.3, 1.95, 0.1))


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

	# título e contagem
	var head := _anchored(ui, Vector2(0, 0), Vector2(520, 90), Vector2(20, 14))
	var tag := CutPanel.make(Rect2(0, 0, 300, 66), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 5, Vector2(7, 7))
	head.add_child(tag)
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
	var bar := _anchored(ui, Vector2(0.5, 1), Vector2(520, 132), Vector2(0, -18))
	bar.add_child(CutPanel.make(Rect2(0, 18, 520, 114), [[.01, 0], [1, .06], [.99, 1], [0, .94]], Paper.NAVY, 5, Vector2(8, 8)))
	var bar_tag := Chip.new()
	bar_tag.px = 14
	bar_tag.text = "SUA PARTY"
	bar_tag.position = Vector2(20, 0)
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
		slots.append({"panel": panel, "face": face, "plus": plus, "name": nm})

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

	hint = Paper.label("", 14, Paper.CREAM, Paper.body(700))
	var hint_box := _anchored(ui, Vector2(0, 1), Vector2(330, 60), Vector2(22, -16))
	hint_box.add_child(CutPanel.make(Rect2(0, 0, 330, 60), [[.02, 0], [1, .06], [.98, 1], [0, .94]], Paper.INK, 0, Vector2.ZERO))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(14, 6)
	hint.size = Vector2(304, 48)
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
