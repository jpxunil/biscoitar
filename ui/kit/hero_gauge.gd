class_name HeroGauge
## O recurso de cada herói, desenhado em cima da barra de habilidades (hud.gd, bullet_row), no kit
## Paper: contorno grosso, sombra dura, etiquetas inclinadas. Cada um tem a cara do boneco:
##   Malpractice — seringa de sangue          Maga       — pente de balas Rainbow
##   Valsa       — carnê de baile com rosas   Apotecário — estante de tubos de ensaio
##   Sleepwalker — travesseiro de Torpor com estrelas
## A área é de 420 x 70; o que é aviso de momento sai em etiquetas acima (y negativo) ou abaixo.

const W := 420.0
const SHADOW := Vector2(4, 4)


## Desenha o recurso do herói em `ci`. Devolve false se esse herói não tem recurso próprio.
static func draw(ci: CanvasItem, me: Unit, g: Node) -> bool:
	if not MODELS.has(me.key):
		return false
	match [me.key, model(me.key)]:
		["nurse", 1]: GaugeAlt.nurse_bag(ci, me, g)
		["nurse", 2]: GaugeAlt.nurse_heart(ci, me, g)
		["nurse", _]: _nurse(ci, me, g)
		["maga", 1]: GaugeAlt.maga_drum(ci, me, g)
		["maga", 2]: GaugeAlt.maga_arc(ci, me, g)
		["maga", _]: _maga(ci, me, g)
		["valsa", 1]: GaugeAlt.valsa_floor(ci, me, g)
		["valsa", 2]: GaugeAlt.valsa_fan(ci, me, g)
		["valsa", _]: _valsa(ci, me, g)
		["apothecary", 1]: GaugeAlt.apo_flask(ci, me, g)
		["apothecary", 2]: GaugeAlt.apo_sprout(ci, me, g)
		["apothecary", _]: _apothecary(ci, me, g)
		["sleepwalker", 1]: GaugeAlt.sw_moon(ci, me, g)
		["sleepwalker", 2]: GaugeAlt.sw_cloud(ci, me, g)
		["sleepwalker", _]: _sleepwalker(ci, me, g)
	return true


# ---------------------------------------------------------------- modelos (pra comparar jogando)

## Cada herói tem três modelos do mesmo recurso. F6 troca durante a luta; a escolha fica gravada.
## O primeiro é o desenho deste arquivo; os outros dois moram em gauge_alt.gd.
const MODELS := {
	"maga": ["PENTE", "TAMBOR", "ARCO-ÍRIS"],
	"nurse": ["SERINGA", "BOLSA DE SANGUE", "CORAÇÃO"],
	"valsa": ["CARNÊ DE BAILE", "SALÃO", "LEQUE"],
	"apothecary": ["ESTANTE", "FRASCÃO", "BROTINHO"],
	"sleepwalker": ["TRAVESSEIRO", "LUA", "NUVEM DE SONHO"],
}
## Onde cada modelo fica na tela: "bar" = em cima das habilidades · "right"/"left" = do lado do
## boneco que você controla · "head" = em cima da cabeça dele.
const ANCHOR := {
	"maga": ["bar", "right", "head"],
	"nurse": ["bar", "left", "bar_tall"],
	"valsa": ["bar", "right", "bar_tall"],
	"apothecary": ["bar", "left", "right"],
	"sleepwalker": ["bar", "right", "head"],
}
const OFFSET := {"right": Vector2(120, -6), "left": Vector2(-120, -6), "head": Vector2(0, -150)}
const PICK_PATH := "user://gauge.cfg"

static var pick := {}
static var _loaded := false
static var _forced := -1
static var _st := {}


static func model(key: String) -> int:
	if not _loaded:
		_loaded = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--gauge="):
				_forced = int(a.trim_prefix("--gauge="))
		var cfg := ConfigFile.new()
		if Knowledge.persist and cfg.load(PICK_PATH) == OK:
			for k in MODELS:
				pick[k] = int(cfg.get_value("gauge", k, 0))
	var n: int = (MODELS[key] as Array).size()
	return posmod(_forced if _forced >= 0 else int(pick.get(key, 0)), n)


## Passa pro próximo modelo deste herói e devolve o nome dele.
static func cycle(key: String) -> String:
	if not MODELS.has(key):
		return ""
	var n: int = (MODELS[key] as Array).size()
	pick[key] = posmod(model(key) + 1, n)
	_forced = -1
	if Knowledge.persist:
		var cfg := ConfigFile.new()
		cfg.load(PICK_PATH)
		cfg.set_value("gauge", key, pick[key])
		cfg.save(PICK_PATH)
	return "%s  (%d/%d)" % [MODELS[key][pick[key]], int(pick[key]) + 1, n]


## Põe a faixa (420 x 70) no lugar do modelo atual. Os modelos "do lado" e "em cima" seguem o
## boneco na tela, com um atraso curto pra não tremer, e nunca saem da área de jogo.
static func place(row: Control, me: Unit, g: Node) -> void:
	var vp := row.get_viewport_rect().size
	var kind: String = ANCHOR[me.key][model(me.key)] if ANCHOR.has(me.key) else "bar"
	var target := Vector2(vp.x * 0.5 - 210.0, vp.y - 214.0)
	if kind == "bar_tall":
		target.y = vp.y - 236.0
	elif kind != "bar":
		var sp: Vector2 = g.cam.unproject_position(me.position + Vector3(0, 1.0, 0))
		var c: Vector2 = sp + (OFFSET[kind] as Vector2)
		c.x = clampf(c.x, 330.0, vp.x - 110.0)
		c.y = clampf(c.y, 150.0, vp.y - 250.0)
		target = c - Vector2(210, 35)
	row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.size = Vector2(420, 70)
	var snap: bool = kind.begins_with("bar") or row.get_meta("gauge_kind", "") != kind
	row.set_meta("gauge_kind", kind)
	row.position = target if snap else row.position.lerp(target, 0.3)


## Pulo de ganho: vale 1 no instante em que `value` sobe e some em menos de meio segundo.
static func bump(id: String, value: float) -> float:
	var s: Dictionary = _st.get(id, {"v": value, "t": -10.0})
	if value > float(s["v"]) + 0.001:
		s["t"] = _now()
	s["v"] = value
	_st[id] = s
	return exp(-(_now() - float(s["t"])) * 7.0)


# ---------------------------------------------------------------- peças

static func _now() -> float:
	return Time.get_ticks_msec() * 0.001


## Recorte de papel: sombra dura, contorno de tinta e o miolo.
static func _cut(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line := 3.0, shadow := SHADOW) -> void:
	if shadow != Vector2.ZERO:
		ci.draw_colored_polygon(Paper.moved(pts, shadow), Paper.INK)
	ci.draw_colored_polygon(pts, Paper.INK)
	ci.draw_colored_polygon(Paper.inset(pts, line), fill)


static func _skew(at: Vector2, size: Vector2, deg := 12.0) -> PackedVector2Array:
	return Paper.moved(Paper.skew_rect(size, deg), at)


static func _text(ci: CanvasItem, at: Vector2, text: String, px: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, title := true) -> void:
	var f: Font = Paper.display(0.0) if title else Paper.body(800)
	ci.draw_string(f, at, text, align, width, px, col)


## Etiqueta inclinada com texto no meio.
static func _tag(ci: CanvasItem, at: Vector2, size: Vector2, text: String, bg: Color, fg: Color, px := 12) -> void:
	_cut(ci, _skew(at, size), bg, 2.5, Vector2(3, 3))
	_text(ci, at + Vector2(0, size.y * 0.5 + px * 0.36), text, px, fg, size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Etiqueta com um tempo escorrendo por dentro (0..1).
static func _timer_tag(ci: CanvasItem, at: Vector2, size: Vector2, k: float, text: String, bg: Color, bar: Color, fg: Color, px := 12) -> void:
	_cut(ci, _skew(at, size), bg, 2.5, Vector2(3, 3))
	var inner := size - Vector2(8, 8)
	if k > 0.01:
		ci.draw_colored_polygon(_skew(at + Vector2(4, 4), Vector2(inner.x * clampf(k, 0.0, 1.0), inner.y)), bar)
	_text(ci, at + Vector2(0, size.y * 0.5 + px * 0.36), text, px, fg, size.x, HORIZONTAL_ALIGNMENT_CENTER)


static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color, points := 4) -> void:
	var pts := PackedVector2Array()
	for n in points * 2:
		var a := n * PI / points - PI / 2.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if n % 2 == 0 else r * 0.42))
	ci.draw_colored_polygon(pts, col)


# ---------------------------------------------------------------- Malpractice: seringa de sangue

static func _nurse(ci: CanvasItem, me: Unit, g: Node) -> void:
	var need: int = g.PARTY_NEED
	var k := clampf(float(me.stacks) / need, 0.0, 1.0)
	var full: bool = me.stacks >= need
	var pulse := 0.5 + 0.5 * sin(_now() * 10.0)
	var blood: Color = g.BLOOD
	var navy := Color("1a1e52")
	# agulha, corpo da seringa e êmbolo
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-34, 55), Vector2(14, 49), Vector2(14, 61)]), Paper.INK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, 55), Vector2(14, 51.5), Vector2(14, 58.5)]), Color("d9dcf5"))
	var barrel := PackedVector2Array([Vector2(8, 38), Vector2(372, 38), Vector2(372, 72), Vector2(8, 72)])
	if full:
		ci.draw_colored_polygon(Paper.moved(Geometry2D.offset_polygon(barrel, 4.0 + 2.0 * pulse)[0], Vector2.ZERO), Color(1.0, 0.25, 0.4, 0.55 + 0.4 * pulse))
	_cut(ci, barrel, Color("e9ebfa"))
	var fill_w := 358.0 * k
	if fill_w > 1.0:
		ci.draw_rect(Rect2(11, 41, fill_w, 28), blood.lightened(0.22 * pulse) if full else blood)
		# brilho do vidro e a "onda" na ponta do sangue
		ci.draw_rect(Rect2(11, 43, fill_w, 5), Color(1, 1, 1, 0.22))
		if not full:
			ci.draw_rect(Rect2(11 + fill_w - 3, 41, 3, 28), blood.darkened(0.35))
	# graduação: um risco por acúmulo de 5, mais alto nos quartos
	for n in range(1, 20):
		var x := 11.0 + 358.0 * n / 20.0
		var tall := n % 5 == 0
		ci.draw_rect(Rect2(x - 1, 41, 2, 14 if tall else 7), Paper.INK)
	# êmbolo: empurra pra dentro conforme enche
	ci.draw_rect(Rect2(372, 50, 30, 10), Paper.INK)
	ci.draw_rect(Rect2(374, 52, 26, 6), navy.lightened(0.25))
	_cut(ci, PackedVector2Array([Vector2(398, 36), Vector2(416, 36), Vector2(416, 74), Vector2(398, 74)]), navy, 3.0)
	# rótulo
	_tag(ci, Vector2(18, 22), Vector2(150, 22), "SANGUE  %d / %d" % [me.stacks, need], navy, Paper.CREAM, 12)
	if me.party_t > 0.0:
		# Blood Party: o tempo que falta e a vida que ainda precisa recuperar, bem à vista
		var ok: bool = me.hp >= me.max_hp - 0.5
		var warn := Color(0.4, 1.0, 0.6) if ok else Color(1.0, 0.3 + 0.5 * pulse, 0.35)
		_cut(ci, _skew(Vector2(-6, -30), Vector2(432, 44), 6.0), Paper.INK, 0.0)
		ci.draw_colored_polygon(_skew(Vector2(0, -26), Vector2(420.0 * clampf(me.party_t / float(g.PARTY_TIME), 0.0, 1.0), 9), 6.0), warn)
		ci.draw_colored_polygon(_skew(Vector2(0, -13), Vector2(420, 20), 6.0), Color(0.2, 0.03, 0.08))
		ci.draw_colored_polygon(_skew(Vector2(0, -13), Vector2(420.0 * clampf(me.hp / me.max_hp, 0.001, 1.0), 20), 6.0), warn)
		var line := ("VIDA CHEIA: AGUENTE %d s" % ceili(me.party_t)) if ok else ("RECUPERE A VIDA: %d / %d  ·  %d s" % [int(me.hp), int(me.max_hp), ceili(me.party_t)])
		_text(ci, Vector2(0, 2), line, 12, Paper.INK if ok else Paper.CREAM, 420, HORIZONTAL_ALIGNMENT_CENTER)
		_tag(ci, Vector2(232, 22), Vector2(150, 22), "BLOOD PARTY  %d s" % ceili(me.party_t), blood, Paper.CREAM, 12)
	elif full:
		_tag(ci, Vector2(196, 22), Vector2(186, 22), "CADA GOLPE CURA %d%%" % roundi(float(g.GAUGE_STEAL) * 100.0), blood.lightened(0.15 * pulse), Paper.CREAM, 12)
	elif me.hp / me.base_hp <= float(g.LOW_HP_FLOOR) + 0.25:
		_tag(ci, Vector2(196, 22), Vector2(186, 22), "VIDA BAIXA: +%d%% DANO" % roundi((float(g.low_hp_mult(me)) - 1.0) * 100.0), Paper.GOLD, Paper.INK, 12)
	if me.bath_window > 0.0 and me.bath_charges > 0:
		# tempo de escolher a habilidade fortalecida pelo Bloodbath
		_timer_tag(ci, Vector2(60, 80), Vector2(300, 22), me.bath_window / float(g.BATH_WINDOW), "ESCOLHA: %d FORTALECIDA%s" % [me.bath_charges, "S" if me.bath_charges > 1 else ""], Paper.INK, blood, Paper.CREAM, 12)


# ---------------------------------------------------------------- Maga: pente Rainbow

static func _maga(ci: CanvasItem, me: Unit, g: Node) -> void:
	var max_n: int = g.BULLET_MAX
	var have: int = me.bullets.size()
	var all: bool = have >= max_n
	var hue := fmod(_now() * 0.6, 1.0)
	var rainbow := [Color("ff4d5e"), Color("ff9a3d"), Color("ffd84d"), Color("54de85"), Color("4de6ff"), Color("9e5cff")]
	# o pente: uma caixa escura inclinada, com as balas deitadas dentro
	var clip := _skew(Vector2(30, 34), Vector2(360, 34), 14.0)
	if all:
		ci.draw_colored_polygon(Geometry2D.offset_polygon(clip, 5.0)[0], Color.from_hsv(hue, 0.75, 1.0))
	_cut(ci, clip, Color("2b1509"))
	var step := 348.0 / max_n
	for n in max_n:
		var c := Vector2(38 + step * (n + 0.5), 51)
		var first := n == 0
		var body := _skew(c - Vector2(13, 10) * (1.2 if first else 1.0), Vector2(26, 20) * (1.2 if first else 1.0), 14.0)
		if n < have:
			var col: Color = g.BULLETS[me.bullets[n]]["col"]
			ci.draw_colored_polygon(Geometry2D.offset_polygon(body, 2.5)[0], Paper.CREAM)
			ci.draw_colored_polygon(body, col)
			# brilho da ponta
			ci.draw_colored_polygon(_skew(c - Vector2(9, 8), Vector2(7, 5), 14.0), col.lightened(0.55))
		else:
			ci.draw_colored_polygon(body, Color("4a2612"))
	# a próxima a sair
	if have > 0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(16, 42), Vector2(32, 51), Vector2(16, 60)]), Paper.INK)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(19, 46.5), Vector2(27, 51), Vector2(19, 55.5)]), Paper.CREAM)
	# faixa arco-íris: acende conforme a próxima bala carrega (cheio: corre sozinha)
	var k := 1.0 if all else clampf(me.bullet_t / float(g.BULLET_EVERY), 0.0, 1.0)
	for n in 6:
		var seg := _skew(Vector2(48 + n * 54, 74), Vector2(50, 7), 14.0)
		ci.draw_colored_polygon(Paper.moved(seg, Vector2(2, 2)), Paper.INK)
		var lit: bool = (float(n) + 0.5) / 6.0 <= k
		var col: Color = rainbow[(n + (int(_now() * 8.0) if all else 0)) % 6]
		ci.draw_colored_polygon(seg, col if lit else col.darkened(0.72))
	if all:
		# pente cheio: o Canhão Estelar vira o supercanhão
		_tag(ci, Vector2(105, 8), Vector2(210, 22), "SUPERCANHÃO PRONTO", Paper.CREAM, Color.from_hsv(hue, 0.85, 0.75), 12)
	else:
		_tag(ci, Vector2(150, 10), Vector2(120, 20), "BALAS  %d / %d" % [have, max_n], Color("c4201c"), Paper.CREAM, 11)


# ---------------------------------------------------------------- Valsa: carnê de baile

static func _rose(ci: CanvasItem, c: Vector2, r: float, col: Color, open: bool) -> void:
	if not open:
		ci.draw_circle(c, r * 0.62, Paper.INK)
		ci.draw_circle(c, r * 0.4, Color("2e2266").lightened(0.2))
		return
	for n in 5:
		var a := n * TAU / 5.0 - PI / 2.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.62, Paper.INK)
	for n in 5:
		var a := n * TAU / 5.0 - PI / 2.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.46, col)
	ci.draw_circle(c, r * 0.42, col.lightened(0.45))
	ci.draw_circle(c, r * 0.16, Paper.INK)


static func _valsa(ci: CanvasItem, me: Unit, g: Node) -> void:
	var gold: Color = g.ROSE_GOLD
	var lilac: Color = g.LILAC
	var cresc: bool = me.crescendo_t > 0.0
	var show: bool = cresc or me.ball_t > 0.0
	var bonus: float = (float(g.SKIRT_BONUS) + float(g.SKIRT_BONUS_PER) * me.embalo) * (float(g.CRESC_MULT) if cresc else 1.0)
	var beat := 0.5 + 0.5 * sin(_now() * 12.0)
	var card := _skew(Vector2(4, 36), Vector2(412, 36), 10.0)
	if show:
		ci.draw_colored_polygon(Geometry2D.offset_polygon(card, 4.0 + 2.0 * beat)[0], Color(gold.r, gold.g, gold.b, 0.5 + 0.45 * beat))
	_cut(ci, card, Color("2e2266"))
	# o compasso: 1 · 2 · 3, com o terceiro (o Giro) em ouro
	for n in 3:
		var c := Vector2(34 + n * 32, 54)
		var on: bool = n == me.waltz_step
		var tone: Color = gold if n == 2 else lilac.lightened(0.3)
		var r := 13.0 if on else 9.5
		var dia := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		ci.draw_colored_polygon(Geometry2D.offset_polygon(dia, 2.5)[0], Paper.CREAM if on else Paper.INK)
		ci.draw_colored_polygon(dia, tone if on else Color("1c1440"))
		_text(ci, c + Vector2(-12, 5), str(n + 1), 12, Paper.INK if on else lilac, 24, HORIZONTAL_ALIGNMENT_CENTER)
		if n < 2:
			ci.draw_line(c + Vector2(15, 0), c + Vector2(19, 0), lilac, 2.0)
	# as rosas do Embalo
	for n in g.EMBALO_MAX:
		_rose(ci, Vector2(150 + n * 30, 54), 11.0, gold, n < me.embalo)
	# o Embalo vai cair: a fita encolhe
	if me.embalo > 0 and not show:
		ci.draw_rect(Rect2(138, 69, 144.0 * clampf(me.embalo_t / float(g.EMBALO_HOLD), 0.0, 1.0), 3), gold)
	_tag(ci, Vector2(298, 41), Vector2(108, 26), "PARTY +%d%%" % roundi(bonus * 100.0), gold if (show or me.embalo >= int(g.EMBALO_MAX)) else Paper.CREAM, Paper.INK, 13)
	var above := ""
	var bg := gold
	if me.ball_t > 0.0:
		above = "GRANDE BAILE  %d s" % ceili(me.ball_t)
	elif cresc:
		above = "CRESCENDO  %d s" % ceili(me.crescendo_t)
	elif me.partner != null and me.partner.alive:
		above = "PAR: %s" % me.partner.unit_name.to_upper()
		bg = lilac.lightened(0.25)
	else:
		above = "SEM PAR: PASSO A DOIS"
		bg = Paper.CREAM
	_tag(ci, Vector2(100, 10), Vector2(220, 22), above, bg, Paper.INK, 12)


# ---------------------------------------------------------------- Apotecário: estante de tubos

static func _apothecary(ci: CanvasItem, me: Unit, g: Node) -> void:
	var chem: Color = g.CHEM
	var bright := Color("4cff5a")
	_cut(ci, _skew(Vector2(70, 40), Vector2(280, 32), 10.0), Color("163a2c"))
	_tag(ci, Vector2(82, 45), Vector2(112, 22), "VESTÍGIOS", Color("0c2018"), bright, 12)
	for n in g.VESTIGE_MAX:
		var x: float = 222.0 + n * 40.0
		var on: bool = n < me.vestiges
		# tubo de ensaio: sai da estante, com rolha
		var tube := PackedVector2Array([Vector2(x - 9, 26), Vector2(x + 9, 26), Vector2(x + 9, 60), Vector2(x + 5, 67), Vector2(x - 5, 67), Vector2(x - 9, 60)])
		_cut(ci, tube, Color("dff5ea"), 2.5, Vector2(3, 3))
		if on:
			var liquid := PackedVector2Array([Vector2(x - 6, 40), Vector2(x + 6, 40), Vector2(x + 6, 59), Vector2(x + 3.5, 64), Vector2(x - 3.5, 64), Vector2(x - 6, 59)])
			ci.draw_colored_polygon(liquid, chem.lerp(bright, 0.45))
			# bolhas subindo
			for b in 2:
				var ph := fmod(_now() * 0.9 + n * 0.37 + b * 0.5, 1.0)
				ci.draw_circle(Vector2(x - 2 + b * 4, 61 - ph * 19.0), 1.8, Color(1, 1, 1, 0.75 * (1.0 - ph)))
		ci.draw_rect(Rect2(x - 11, 21, 22, 7), Paper.INK)
		ci.draw_rect(Rect2(x - 9, 23, 18, 3), Paper.BROWN.lightened(0.3))
	if me.patient != null and me.patient_t > 0.0 and me.patient.alive:
		# a receita: quem é o Paciente e por quanto tempo
		_tag(ci, Vector2(70, -4), Vector2(280, 22), "PACIENTE: %s  %d s" % [me.patient.unit_name.to_upper(), ceili(me.patient_t)], Paper.CREAM, Color("175030"), 12)


# ---------------------------------------------------------------- Sleepwalker: travesseiro de Torpor

static func _sleepwalker(ci: CanvasItem, me: Unit, g: Node) -> void:
	var dream: Color = g.DREAM
	var deep := Color("191a45")
	var pink := Color("ffc8e6")
	var k := clampf(me.torpor / 100.0, 0.0, 1.0)
	# o travesseiro: uma barra de cantos fofos
	var pill := PackedVector2Array()
	for n in 9:
		var a := PI / 2.0 + n * PI / 8.0
		pill.append(Vector2(14, 57) + Vector2(cos(a), sin(a)) * 14.0)
	for n in 9:
		var a := -PI / 2.0 + n * PI / 8.0
		pill.append(Vector2(406, 57) + Vector2(cos(a), sin(a)) * 14.0)
	_cut(ci, pill, deep)
	var fill_w := 406.0 * k
	if fill_w > 2.0:
		var col: Color = Color("9e5cff") if me.asleep else dream
		ci.draw_rect(Rect2(7, 47, fill_w, 20), col)
		# a ponta do Torpor é uma nuvem
		for n in 3:
			ci.draw_circle(Vector2(7 + fill_w, 50 + n * 7), 5.0, col)
		ci.draw_rect(Rect2(7, 48, fill_w, 4), Color(1, 1, 1, 0.2))
	# as marcas de quanto custa chegar em cada passo do sonho: luas
	var spent := 0.0
	for n in 5:
		spent += float(g.SKILLS_ASLEEP[n]["cost"])
		var x := 7.0 + 406.0 * clampf(spent / 100.0, 0.0, 1.0)
		var reached: bool = me.torpor >= spent
		ci.draw_circle(Vector2(x, 42), 6.5, Paper.INK)
		ci.draw_circle(Vector2(x, 42), 4.5, pink if reached else deep.lightened(0.25))
		ci.draw_circle(Vector2(x + 2.2, 40.8), 3.6, Paper.INK if not reached else pink.darkened(0.25))
		ci.draw_rect(Rect2(x - 1, 47, 2, 20), Color(Paper.CREAM.r, Paper.CREAM.g, Paper.CREAM.b, 0.55))
	_text(ci, Vector2(16, 62), "TORPOR  %d" % int(me.torpor), 12, Paper.CREAM)
	if me.asleep:
		_text(ci, Vector2(0, 62), "Z z z", 12, pink, 404, HORIZONTAL_ALIGNMENT_RIGHT)
	# Vulnerabilidade Onírica: oito estrelas e o tempo
	_cut(ci, _skew(Vector2(0, 8), Vector2(238, 22), 10.0), deep, 2.5, Vector2(3, 3))
	for n in g.DREAM_MAX:
		_star(ci, Vector2(16 + n * 15, 19), 6.5, Paper.GOLD if n < int(g.dream_stacks) else deep.lightened(0.22))
	if int(g.dream_stacks) > 0:
		_text(ci, Vector2(136, 24), "+%d%%  %d s" % [int(g.dream_stacks) * 2, ceili(float(g.dream_t))], 11, Paper.GOLD)
	if me.near_t > 0.0:
		_tag(ci, Vector2(252, 8), Vector2(164, 22), "PERTO DO SONHO  %d s" % ceili(me.near_t), Paper.CYAN, Paper.INK, 10)
	# janela de 1 s pra próxima da sequência
	if me.window_t > 0.0 and not me.asleep:
		_timer_tag(ci, Vector2(60, -20), Vector2(300, 22), me.window_t / float(g.SW_WINDOW), "AGORA: %s" % String(g.SKILLS["sleepwalker"][me.window_slot]["name"]).to_upper(), Paper.INK, Paper.GOLD, Paper.CREAM, 12)
	elif me.wake_t > 0.0:
		_tag(ci, Vector2(40, -20), Vector2(340, 22), "SEM TORPOR NECESSÁRIO, ACORDANDO", Paper.RED, Paper.CREAM, 12)
	if me.silence_t > 0.0:
		# punição de quem acordou mal: anda, mas não age
		_timer_tag(ci, Vector2(60, -20), Vector2(300, 22), minf(1.0, me.silence_t / float(g.SW_LOCK_BROKEN)), "SONOLENTO: SEM AGIR  %.1f s" % me.silence_t, Paper.INK, Paper.RED, Paper.CREAM, 12)
