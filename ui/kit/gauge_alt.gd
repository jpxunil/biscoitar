class_name GaugeAlt
## Os modelos alternativos do recurso de cada herói (o modelo 0 de cada um mora em hero_gauge.gd).
## Nenhum é barra: tambor, arco de estrelas, bolsa de sangue, coração, salão, leque, frascão,
## brotinho, lua e nuvem de sonho. Tudo desenhado em volta do centro C da faixa; quem decide onde a
## faixa fica na tela (em cima das habilidades, do lado ou em cima do boneco) é HeroGauge.place.
## Animação: todo ganho dá um "pulo" (HeroGauge.bump), os desenhos respiram, piscam e soltam brilho.

const C := Vector2(210, 35)


# ---------------------------------------------------------------- peças fofas

static func _t() -> float:
	return Time.get_ticks_msec() * 0.001


static func _circle_pts(c: Vector2, r: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := k * TAU / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Bola de papel: sombra dura, contorno e miolo.
static func _ball(ci: CanvasItem, c: Vector2, r: float, fill: Color, line := 3.0, shadow := Vector2(3, 3)) -> void:
	if shadow != Vector2.ZERO:
		ci.draw_circle(c + shadow, r, Paper.INK)
	ci.draw_circle(c, r, Paper.INK)
	ci.draw_circle(c, r - line, fill)


## Líquido dentro de uma forma: enche de baixo pra cima até `k` (0..1), com a superfície ondulando.
static func _liquid(ci: CanvasItem, shape: PackedVector2Array, box: Rect2, k: float, col: Color, wave := 2.0) -> void:
	if k <= 0.005:
		return
	var top := box.position.y + box.size.y * (1.0 - clampf(k, 0.0, 1.0))
	var surf := PackedVector2Array()
	var steps := 10
	for n in steps + 1:
		var x := box.position.x - 4.0 + (box.size.x + 8.0) * n / steps
		var w := sin(_t() * 4.0 + n * 1.1) * wave * (0.0 if k >= 0.999 else 1.0)
		surf.append(Vector2(x, top + w))
	surf.append(Vector2(box.end.x + 4.0, box.end.y + 4.0))
	surf.append(Vector2(box.position.x - 4.0, box.end.y + 4.0))
	for piece in Geometry2D.intersect_polygons(shape, surf):
		# lasca fina demais não vira polígono: pula
		if piece.size() >= 3 and absf(_area(piece)) > 3.0:
			ci.draw_colored_polygon(piece, col)


static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for n in pts.size():
		var p := pts[n]
		var q := pts[(n + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Carinha: dois olhos que piscam, bochechas e boca. mood: "calm", "happy" (olhos fechados sorrindo),
## "sleep" (dormindo), "love" (olhos de coração).
static func _face(ci: CanvasItem, c: Vector2, s: float, mood := "calm", ink := Paper.INK) -> void:
	var blink := fmod(_t() + c.x * 0.013, 3.4) < 0.12
	for sx in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(sx * 6.0, -1.0) * s
		ci.draw_circle(c + Vector2(sx * 9.5, 3.5) * s, 2.6 * s, Color(1.0, 0.45, 0.6, 0.75))
		match mood:
			"happy":
				ci.draw_arc(e + Vector2(0, 1.5) * s, 2.6 * s, PI, TAU, 8, ink, 1.8 * s, true)
			"sleep":
				ci.draw_arc(e - Vector2(0, 1.0) * s, 2.6 * s, 0.0, PI, 8, ink, 1.8 * s, true)
			"love":
				_heart(ci, e, 3.4 * s, Color(1.0, 0.3, 0.5))
			_:
				if blink:
					ci.draw_line(e - Vector2(2.4, 0) * s, e + Vector2(2.4, 0) * s, ink, 1.8 * s)
				else:
					ci.draw_circle(e, 2.2 * s, ink)
					ci.draw_circle(e + Vector2(-0.7, -0.8) * s, 0.8 * s, Color.WHITE)
	if mood == "sleep":
		ci.draw_circle(c + Vector2(0, 4.5) * s, 1.5 * s, ink)
	else:
		ci.draw_arc(c + Vector2(0, 2.5) * s, 2.8 * s, 0.25, PI - 0.25, 8, ink, 1.7 * s, true)


static func _heart_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for n in 30:
		var a := n * TAU / 30.0
		var x := 16.0 * pow(sin(a), 3.0)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * (r / 16.0))
	return pts


static func _heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(_heart_pts(c, r), col)


static func _star_pts(c: Vector2, r: float, points := 5, inner := 0.46, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for n in points * 2:
		var a := rot + n * PI / points - PI / 2.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if n % 2 == 0 else r * inner))
	return pts


## Estrelinhas piscando em volta de um ponto (cheio, pronto, carregado).
static func _sparkles(ci: CanvasItem, c: Vector2, radius: float, col: Color, count := 5) -> void:
	for n in count:
		var ph := fmod(_t() * 0.9 + n * 0.37, 1.0)
		var a := n * TAU / count + _t() * 0.6
		var p := c + Vector2(cos(a), sin(a)) * radius * (0.8 + 0.35 * ph)
		var sr := 5.5 * sin(ph * PI)
		if sr > 0.8:
			ci.draw_colored_polygon(_star_pts(p, sr, 4, 0.36), Color(col.r, col.g, col.b, 0.95))


## As etiquetas de momento, empilhadas a partir de `at` (o centro da primeira). Cada item:
## {"t": texto, "bg": cor, "fg": cor, "k": tempo 0..1 (opcional), "bar": cor do tempo}.
static func _notes(ci: CanvasItem, at: Vector2, items: Array, up := false) -> void:
	var y := at.y
	for it in items:
		var text: String = it["t"]
		var w := 22.0 + text.length() * 7.4
		var pos := Vector2(at.x - w * 0.5, y - 10.0)
		if it.has("k"):
			HeroGauge._timer_tag(ci, pos, Vector2(w, 20), float(it["k"]), text, it["bg"], it["bar"], it["fg"], 11)
		else:
			HeroGauge._tag(ci, pos, Vector2(w, 20), text, it["bg"], it["fg"], 11)
		y += -25.0 if up else 25.0


static func _xf(ci: CanvasItem, at: Vector2, scale := 1.0, rot := 0.0) -> void:
	ci.draw_set_transform(at, rot, Vector2(scale, scale))


static func _xf_off(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- avisos de momento de cada herói

static func status(me: Unit, g: Node) -> Array:
	var out: Array = []
	var pulse := 0.5 + 0.5 * sin(_t() * 10.0)
	match me.key:
		"nurse":
			var blood: Color = g.BLOOD
			if me.party_t > 0.0:
				var ok: bool = me.hp >= me.max_hp - 0.5
				out.append({"t": ("VIDA CHEIA: AGUENTE %d s" % ceili(me.party_t)) if ok else ("RECUPERE A VIDA: %d / %d · %d s" % [int(me.hp), int(me.max_hp), ceili(me.party_t)]),
					"bg": Paper.INK, "fg": Paper.CREAM, "k": me.party_t / float(g.PARTY_TIME), "bar": Color(0.2, 0.7, 0.4) if ok else Color(0.85, 0.15 + 0.25 * pulse, 0.25)})
			elif me.stacks >= int(g.PARTY_NEED):
				out.append({"t": "CADA GOLPE CURA %d%%" % roundi(float(g.GAUGE_STEAL) * 100.0), "bg": blood, "fg": Paper.CREAM})
			elif me.hp / me.base_hp <= float(g.LOW_HP_FLOOR) + 0.25:
				out.append({"t": "VIDA BAIXA: +%d%% DANO" % roundi((float(g.low_hp_mult(me)) - 1.0) * 100.0), "bg": Paper.GOLD, "fg": Paper.INK})
			if me.bath_window > 0.0 and me.bath_charges > 0:
				out.append({"t": "ESCOLHA: %d FORTALECIDA%s" % [me.bath_charges, "S" if me.bath_charges > 1 else ""], "bg": Paper.INK, "fg": Paper.CREAM, "k": me.bath_window / float(g.BATH_WINDOW), "bar": blood})
		"maga":
			if me.bullets.size() >= int(g.BULLET_MAX):
				out.append({"t": "SUPERCANHÃO PRONTO", "bg": Paper.CREAM, "fg": Color.from_hsv(fmod(_t() * 0.6, 1.0), 0.85, 0.72)})
		"valsa":
			var gold: Color = g.ROSE_GOLD
			if me.ball_t > 0.0:
				out.append({"t": "GRANDE BAILE  %d s" % ceili(me.ball_t), "bg": gold, "fg": Paper.INK})
			elif me.crescendo_t > 0.0:
				out.append({"t": "CRESCENDO  %d s" % ceili(me.crescendo_t), "bg": gold, "fg": Paper.INK})
			elif me.partner != null and me.partner.alive:
				out.append({"t": "PAR: %s" % me.partner.unit_name.to_upper(), "bg": (g.LILAC as Color).lightened(0.25), "fg": Paper.INK})
			else:
				out.append({"t": "SEM PAR: PASSO A DOIS", "bg": Paper.CREAM, "fg": Paper.INK})
		"apothecary":
			if me.patient != null and me.patient_t > 0.0 and me.patient.alive:
				out.append({"t": "PACIENTE: %s  %d s" % [me.patient.unit_name.to_upper(), ceili(me.patient_t)], "bg": Paper.CREAM, "fg": Color("175030")})
		"sleepwalker":
			if me.window_t > 0.0 and not me.asleep:
				out.append({"t": "AGORA: %s" % String(g.SKILLS["sleepwalker"][me.window_slot]["name"]).to_upper(), "bg": Paper.INK, "fg": Paper.CREAM, "k": me.window_t / float(g.SW_WINDOW), "bar": Color(0.75, 0.55, 0.1)})
			elif me.wake_t > 0.0:
				out.append({"t": "SEM TORPOR, ACORDANDO", "bg": Paper.RED, "fg": Paper.CREAM})
			if me.silence_t > 0.0:
				out.append({"t": "SONOLENTO: SEM AGIR  %.1f s" % me.silence_t, "bg": Paper.INK, "fg": Paper.CREAM, "k": minf(1.0, me.silence_t / float(g.SW_LOCK_BROKEN)), "bar": Paper.RED})
			if int(g.dream_stacks) > 0:
				out.append({"t": "ONÍRICA +%d%%  %d s" % [int(g.dream_stacks) * 2, ceili(float(g.dream_t))], "bg": Color("191a45"), "fg": Paper.GOLD})
			if me.near_t > 0.0:
				out.append({"t": "PERTO DO SONHO  %d s" % ceili(me.near_t), "bg": Paper.CYAN, "fg": Paper.INK})
	return out


# ---------------------------------------------------------------- Maga

## Tambor: as oito balas em roda, a próxima em cima. O anel arco-íris em volta é a recarga.
static func maga_drum(ci: CanvasItem, me: Unit, g: Node) -> void:
	var max_n: int = g.BULLET_MAX
	var have: int = me.bullets.size()
	var all: bool = have >= max_n
	var pop: float = HeroGauge.bump("maga", have)
	var rainbow := [Color("ff4d5e"), Color("ff9a3d"), Color("ffd84d"), Color("54de85"), Color("4de6ff"), Color("9e5cff")]
	var k := 1.0 if all else clampf(me.bullet_t / float(g.BULLET_EVERY), 0.0, 1.0)
	# anel de recarga
	for n in 6:
		var a0 := -PI / 2.0 + n * TAU / 6.0 + 0.05
		var a1 := -PI / 2.0 + (n + 1) * TAU / 6.0 - 0.05
		var lit: bool = (n + 0.5) / 6.0 <= k
		var col: Color = rainbow[(n + (int(_t() * 8.0) if all else 0)) % 6]
		ci.draw_arc(C, 49.0, a0, a1, 10, Paper.INK, 9.0)
		ci.draw_arc(C, 49.0, a0, a1, 10, col if lit else col.darkened(0.72), 5.0)
	_xf(ci, C, 1.0 + 0.1 * pop, (_t() * 1.6) if all else 0.0)
	_ball(ci, Vector2.ZERO, 41.0, Color("4a2612"))
	for n in max_n:
		var a := -PI / 2.0 + n * TAU / max_n
		var p := Vector2(cos(a), sin(a)) * 27.0
		if n < have:
			var col: Color = g.BULLETS[me.bullets[n]]["col"]
			var r := 9.5 if n == 0 else 7.5
			ci.draw_circle(p, r + 2.5, Paper.CREAM)
			ci.draw_circle(p, r, col)
			ci.draw_circle(p + Vector2(-2.5, -2.5), r * 0.3, col.lightened(0.6))
		else:
			ci.draw_circle(p, 7.5, Color("2b1509"))
	_xf(ci, C, 1.0 + 0.1 * pop)
	_ball(ci, Vector2.ZERO, 14.0, Paper.CREAM, 2.5, Vector2.ZERO)
	if all:
		_face(ci, Vector2(0, -1), 1.0, "happy")
	else:
		HeroGauge._text(ci, Vector2(-14, 6), str(have), 15, Paper.INK, 28, HORIZONTAL_ALIGNMENT_CENTER)
	_xf_off(ci)
	# a seta da próxima bala
	if have > 0:
		ci.draw_colored_polygon(PackedVector2Array([C + Vector2(-7, -62), C + Vector2(7, -62), C + Vector2(0, -52)]), Paper.CREAM)
	if all:
		_sparkles(ci, C, 56.0, Color.from_hsv(fmod(_t() * 0.6, 1.0), 0.6, 1.0), 6)
	_notes(ci, C + Vector2(0, 72), status(me, g))


## Arco-íris: as balas são estrelas num arco por cima da cabeça. A próxima fica na ponta esquerda.
static func maga_arc(ci: CanvasItem, me: Unit, g: Node) -> void:
	var max_n: int = g.BULLET_MAX
	var have: int = me.bullets.size()
	var all: bool = have >= max_n
	var pop: float = HeroGauge.bump("maga", have)
	var mid := C + Vector2(0, 62)
	var bands := [Color("ff4d5e"), Color("ffd84d"), Color("4de6ff")]
	ci.draw_arc(mid, 78.0, PI * 1.14, PI * 1.86, 24, Paper.INK, 15.0)
	for n in 3:
		ci.draw_arc(mid, 82.0 - n * 4.0, PI * 1.15, PI * 1.85, 24, (bands[n] as Color).darkened(0.0 if all else 0.45), 4.0)
	var k := clampf(me.bullet_t / float(g.BULLET_EVERY), 0.0, 1.0)
	for n in max_n:
		var a := lerpf(PI * 1.13, PI * 1.87, n / float(max_n - 1))
		var wave := sin(_t() * 6.0 + n * 0.8) * (3.0 if all else 0.0)
		var p := mid + Vector2(cos(a), sin(a)) * (78.0 + wave)
		if n < have:
			var col: Color = g.BULLETS[me.bullets[n]]["col"]
			var r := (12.5 if n == 0 else 10.0) * (1.0 + (0.35 * pop if n == have - 1 else 0.0))
			var bob := Vector2(0, -absf(sin(_t() * 5.0)) * 4.0) if n == 0 else Vector2.ZERO
			ci.draw_colored_polygon(_star_pts(p + bob + Vector2(2, 2), r + 3.0), Paper.INK)
			ci.draw_colored_polygon(_star_pts(p + bob, r + 3.0), Paper.CREAM)
			ci.draw_colored_polygon(_star_pts(p + bob, r), col)
		elif n == have:
			# a que está carregando cresce no lugar
			ci.draw_colored_polygon(_star_pts(p, 9.0), Paper.INK)
			if k > 0.12:
				ci.draw_colored_polygon(_star_pts(p, 8.0 * k), Paper.CREAM)
		else:
			ci.draw_colored_polygon(_star_pts(p, 6.5), Paper.INK)
	if all:
		_sparkles(ci, mid + Vector2(0, -78), 34.0, Color.from_hsv(fmod(_t() * 0.6, 1.0), 0.6, 1.0), 5)
	_notes(ci, C + Vector2(0, -44), status(me, g), true)


# ---------------------------------------------------------------- Malpractice

## Bolsa de sangue: pendurada, com carinha. Enche de baixo pra cima e pinga.
static func nurse_bag(ci: CanvasItem, me: Unit, g: Node) -> void:
	var need: int = g.PARTY_NEED
	var k := clampf(float(me.stacks) / need, 0.0, 1.0)
	var full: bool = me.stacks >= need
	var blood: Color = g.BLOOD
	var pop: float = HeroGauge.bump("nurse", me.stacks)
	var sway := sin(_t() * 2.2) * 0.05 + (sin(_t() * 30.0) * 0.06 if me.party_t > 0.0 else 0.0)
	var beat := 1.0 + (0.06 * absf(sin(_t() * 6.0)) if full else 0.0) + 0.1 * pop
	# gancho
	ci.draw_line(C + Vector2(0, -62), C + Vector2(0, -44), Paper.INK, 4.0)
	ci.draw_arc(C + Vector2(0, -66), 6.0, 0.0, TAU, 12, Paper.INK, 3.0)
	_xf(ci, C + Vector2(0, -44), beat, sway)
	var bag := PackedVector2Array([Vector2(-26, 8), Vector2(-20, 0), Vector2(20, 0), Vector2(26, 8), Vector2(26, 62), Vector2(16, 74), Vector2(-16, 74), Vector2(-26, 62)])
	ci.draw_colored_polygon(Paper.moved(bag, Vector2(4, 4)), Paper.INK)
	ci.draw_colored_polygon(bag, Paper.INK)
	var inner := Paper.inset(bag, 3.0)
	ci.draw_colored_polygon(inner, Color("f1ecf7"))
	_liquid(ci, inner, Rect2(-23, 3, 46, 68), k, blood.lightened(0.18 * absf(sin(_t() * 6.0))) if full else blood)
	# marcas de 5 em 5
	for n in range(1, 4):
		var y := 71.0 - 68.0 * n / 4.0
		ci.draw_line(Vector2(15, y), Vector2(23, y), Paper.INK, 2.0)
	# rótulo com a cruz
	ci.draw_rect(Rect2(-9, 6, 18, 12), Paper.CREAM)
	ci.draw_rect(Rect2(-2, 8, 4, 8), blood)
	ci.draw_rect(Rect2(-5, 10.5, 10, 3), blood)
	_face(ci, Vector2(0, 42), 1.15, "love" if full else ("happy" if k > 0.6 else "calm"), Paper.INK if k < 0.45 else Color("3a0612"))
	# tubinho e a gota
	ci.draw_rect(Rect2(-3, 74, 6, 9), Paper.INK)
	_xf_off(ci)
	if me.stacks > 0:
		var ph := fmod(_t() * (1.6 if full else 0.8), 1.0)
		var drop := C + Vector2(0, 42 + ph * ph * 22.0)
		ci.draw_circle(drop, 4.0 * (1.0 - ph * 0.5), Paper.INK)
		ci.draw_circle(drop, 2.6 * (1.0 - ph * 0.5), blood)
	HeroGauge._tag(ci, C + Vector2(-36, 66), Vector2(72, 20), "%d / %d" % [me.stacks, need], Color("1a1e52"), Paper.CREAM, 12)
	if full:
		_sparkles(ci, C + Vector2(0, -6), 44.0, Color(1.0, 0.5, 0.6), 5)
	_notes(ci, C + Vector2(0, 100), status(me, g))


## Coração: enche de sangue e bate. As quatro gotas embaixo são os quartos do Blood Party.
static func nurse_heart(ci: CanvasItem, me: Unit, g: Node) -> void:
	var need: int = g.PARTY_NEED
	var k := clampf(float(me.stacks) / need, 0.0, 1.0)
	var full: bool = me.stacks >= need
	var blood: Color = g.BLOOD
	var pop: float = HeroGauge.bump("nurse", me.stacks)
	var rate := 3.0 + 6.0 * k
	var beat := 1.0 + 0.07 * maxf(0.0, sin(_t() * rate)) * (0.4 + k) + 0.14 * pop
	_xf(ci, C + Vector2(0, -8), beat)
	var shape := _heart_pts(Vector2.ZERO, 40.0)
	ci.draw_colored_polygon(Paper.moved(_heart_pts(Vector2.ZERO, 44.0), Vector2(4, 4)), Paper.INK)
	ci.draw_colored_polygon(_heart_pts(Vector2.ZERO, 44.0), Paper.INK)
	ci.draw_colored_polygon(shape, Color("f1ecf7"))
	_liquid(ci, shape, Rect2(-41, -34, 82, 76), k, blood.lightened(0.2 * absf(sin(_t() * 6.0))) if full else blood, 2.5)
	# curativo
	ci.draw_set_transform(C + Vector2(20, -30), 0.6, Vector2(beat, beat))
	ci.draw_rect(Rect2(-11, -4, 22, 8), Paper.INK)
	ci.draw_rect(Rect2(-9, -2.5, 18, 5), Color("f0c9a0"))
	_xf(ci, C + Vector2(0, -8), beat)
	_face(ci, Vector2(0, 0), 1.3, "love" if full else ("happy" if k > 0.6 else "calm"), Paper.INK if k < 0.5 else Color("3a0612"))
	_xf_off(ci)
	for n in 4:
		var c := C + Vector2(-33 + n * 22, 46)
		var on: bool = me.stacks >= (n + 1) * need / 4
		var drop := PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 1), c + Vector2(4, 6), c + Vector2(-4, 6), c + Vector2(-6, 1)])
		ci.draw_colored_polygon(Geometry2D.offset_polygon(drop, 2.2)[0], Paper.INK)
		ci.draw_colored_polygon(drop, blood if on else Color("3a2030"))
	HeroGauge._tag(ci, C + Vector2(54, -18), Vector2(64, 20), "%d / %d" % [me.stacks, need], Color("1a1e52"), Paper.CREAM, 12)
	if full:
		_sparkles(ci, C + Vector2(0, -8), 54.0, Color(1.0, 0.5, 0.6), 6)
	_notes(ci, C + Vector2(0, -68), status(me, g), true)


# ---------------------------------------------------------------- Valsa

## Salão: um disco de baile. As rosas do Embalo em volta, o compasso girando no meio.
static func valsa_floor(ci: CanvasItem, me: Unit, g: Node) -> void:
	var gold: Color = g.ROSE_GOLD
	var lilac: Color = g.LILAC
	var show: bool = me.crescendo_t > 0.0 or me.ball_t > 0.0
	var bonus: float = (float(g.SKIRT_BONUS) + float(g.SKIRT_BONUS_PER) * me.embalo) * (float(g.CRESC_MULT) if me.crescendo_t > 0.0 else 1.0)
	var pop: float = HeroGauge.bump("valsa", me.embalo)
	var step_pop: float = HeroGauge.bump("valsa_step", me.waltz_step + _step_turn(me))
	if show:
		ci.draw_circle(C, 52.0 + 3.0 * sin(_t() * 12.0), Color(gold.r, gold.g, gold.b, 0.55))
	_ball(ci, C, 46.0 * (1.0 + 0.05 * pop), Color("2e2266"))
	ci.draw_arc(C, 37.0, 0.0, TAU, 40, lilac.darkened(0.3), 1.5, true)
	# a saia: abre mais a cada rosa
	var spin := _t() * (1.2 + 0.7 * me.embalo)
	var petals := 3 + me.embalo
	for n in petals:
		var a := spin + n * TAU / petals
		var tip := C + Vector2(cos(a), sin(a)) * (12.0 + 3.0 * me.embalo)
		var l := C + Vector2(cos(a - 0.5), sin(a - 0.5)) * 6.0
		var r := C + Vector2(cos(a + 0.5), sin(a + 0.5)) * 6.0
		ci.draw_colored_polygon(PackedVector2Array([l, tip, r]), lilac.lightened(0.25) if n % 2 == 0 else gold)
	ci.draw_circle(C, 5.0, Paper.CREAM)
	# o compasso: três contas na borda de dentro
	for n in 3:
		var a := -PI / 2.0 + (n - 1) * 0.62
		var p := C + Vector2(cos(a), sin(a)) * 30.0
		var on: bool = n == me.waltz_step
		var r := (7.5 + 3.0 * step_pop) if on else 5.0
		ci.draw_circle(p, r + 2.0, Paper.CREAM if on else Paper.INK)
		ci.draw_circle(p, r, (gold if n == 2 else lilac.lightened(0.3)) if on else Color("1c1440"))
	# rosas em volta, por baixo
	for n in int(g.EMBALO_MAX):
		var a := PI / 2.0 + (n - 2) * 0.52
		var p := C + Vector2(cos(a), sin(a)) * 46.0
		var on: bool = n < me.embalo
		HeroGauge._rose(ci, p, 9.5 * (1.0 + (0.4 * pop if n == me.embalo - 1 else 0.0)), gold, on)
	if me.embalo > 0 and not show:
		ci.draw_arc(C, 58.0, PI / 2.0 - 1.1, PI / 2.0 - 1.1 + 2.2 * clampf(me.embalo_t / float(g.EMBALO_HOLD), 0.0, 1.0), 16, gold, 3.0)
	HeroGauge._tag(ci, C + Vector2(-46, -68), Vector2(92, 22), "PARTY +%d%%" % roundi(bonus * 100.0), gold if (show or me.embalo >= int(g.EMBALO_MAX)) else Paper.CREAM, Paper.INK, 12)
	if show:
		_sparkles(ci, C, 58.0, gold, 6)
	_notes(ci, C + Vector2(0, 80), status(me, g))


## O Giro zera o compasso: pra o "pulo" da conta acesa contar cada passo, some um número que só cresce.
static func _step_turn(me: Unit) -> float:
	var s: Dictionary = HeroGauge._st.get("valsa_turns", {"last": me.waltz_step, "n": 0.0})
	if me.waltz_step < int(s["last"]):
		s["n"] = float(s["n"]) + 3.0
	s["last"] = me.waltz_step
	HeroGauge._st["valsa_turns"] = s
	return float(s["n"])


## Leque: cinco varetas que abrem com o Embalo. O cabo leva as três contas do compasso.
static func valsa_fan(ci: CanvasItem, me: Unit, g: Node) -> void:
	var gold: Color = g.ROSE_GOLD
	var lilac: Color = g.LILAC
	var show: bool = me.crescendo_t > 0.0 or me.ball_t > 0.0
	var bonus: float = (float(g.SKIRT_BONUS) + float(g.SKIRT_BONUS_PER) * me.embalo) * (float(g.CRESC_MULT) if me.crescendo_t > 0.0 else 1.0)
	var pop: float = HeroGauge.bump("valsa", me.embalo)
	var step_pop: float = HeroGauge.bump("valsa_step", me.waltz_step + _step_turn(me))
	var pivot := C + Vector2(0, 40)
	var flutter := sin(_t() * 9.0) * (0.05 if show else 0.015)
	var max_n: int = g.EMBALO_MAX
	# cada vareta é um setor; as fechadas ficam empilhadas na esquerda
	for n in range(max_n - 1, -1, -1):
		var open: bool = n < me.embalo
		var slot := float(n) if open else float(me.embalo) - 0.5 + (n - me.embalo) * 0.12
		var a := -PI / 2.0 + (slot - (max_n - 1) * 0.5) * 0.44 + flutter * (n - 2)
		var half := 0.2
		var len := 74.0 * (1.0 + (0.12 * pop if n == me.embalo - 1 else 0.0))
		var pts := PackedVector2Array([pivot])
		for s in 5:
			var aa := a - half + s * half * 0.5
			pts.append(pivot + Vector2(cos(aa), sin(aa)) * len)
		ci.draw_colored_polygon(Geometry2D.offset_polygon(pts, 2.5)[0], Paper.INK)
		ci.draw_colored_polygon(pts, (gold if n % 2 == 0 else lilac.lightened(0.3)) if open else Color("2e2266"))
		if open:
			HeroGauge._rose(ci, pivot + Vector2(cos(a), sin(a)) * len * 0.68, 7.0, Color("ff7aa8"), true)
	# cabo e as contas do compasso
	_ball(ci, pivot, 9.0, Paper.CREAM, 2.5, Vector2(2, 2))
	for n in 3:
		var p := pivot + Vector2((n - 1) * 24.0, 22)
		var on: bool = n == me.waltz_step
		var r := (7.5 + 3.0 * step_pop) if on else 5.0
		ci.draw_circle(p, r + 2.0, Paper.CREAM if on else Paper.INK)
		ci.draw_circle(p, r, (gold if n == 2 else lilac.lightened(0.3)) if on else Color("1c1440"))
		HeroGauge._text(ci, p + Vector2(-10, 4.5), str(n + 1), 10, Paper.INK if on else lilac, 20, HORIZONTAL_ALIGNMENT_CENTER)
	if me.embalo > 0 and not show:
		ci.draw_rect(Rect2(pivot.x - 40, pivot.y + 36, 80.0 * clampf(me.embalo_t / float(g.EMBALO_HOLD), 0.0, 1.0), 3), gold)
	HeroGauge._tag(ci, C + Vector2(78, 6), Vector2(96, 22), "PARTY +%d%%" % roundi(bonus * 100.0), gold if (show or me.embalo >= max_n) else Paper.CREAM, Paper.INK, 12)
	if show:
		_sparkles(ci, C + Vector2(0, -10), 70.0, gold, 6)
	_notes(ci, C + Vector2(0, -62), status(me, g), true)


# ---------------------------------------------------------------- Apotecário

## Frascão: um balão de vidro com carinha. Cada Vestígio enche um terço; com três, a rolha salta.
static func apo_flask(ci: CanvasItem, me: Unit, g: Node) -> void:
	var max_n: int = g.VESTIGE_MAX
	var k := clampf(float(me.vestiges) / max_n, 0.0, 1.0)
	var full: bool = me.vestiges >= max_n
	var pop: float = HeroGauge.bump("apothecary", me.vestiges)
	var chem: Color = (g.CHEM as Color).lerp(Color("4cff5a"), 0.45)
	var wob := sin(_t() * 2.4) * 0.04
	_xf(ci, C + Vector2(0, 30), 1.0 + 0.12 * pop, wob)
	var body := _circle_pts(Vector2(0, -22), 30.0, 32)
	var neck := PackedVector2Array([Vector2(-9, -70), Vector2(9, -70), Vector2(9, -46), Vector2(-9, -46)])
	for shape in [body, neck]:
		ci.draw_colored_polygon(Paper.moved(Geometry2D.offset_polygon(shape, 3.0)[0], Vector2(4, 4)), Paper.INK)
	for shape in [body, neck]:
		ci.draw_colored_polygon(Geometry2D.offset_polygon(shape, 3.0)[0], Paper.INK)
	ci.draw_colored_polygon(body, Color("dff5ea"))
	ci.draw_colored_polygon(neck, Color("dff5ea"))
	_liquid(ci, body, Rect2(-30, -52, 60, 60), k * 0.86, chem, 2.5)
	# bolhas
	if me.vestiges > 0:
		for b in 3:
			var ph := fmod(_t() * (0.7 + 0.5 * k) + b * 0.33, 1.0)
			var y := 4.0 - ph * 50.0 * k
			ci.draw_circle(Vector2(-12 + b * 12, y), 2.6 * (1.0 - ph * 0.5), Color(1, 1, 1, 0.8 * (1.0 - ph)))
	# marcas dos terços
	for n in range(1, max_n):
		var y := 8.0 - 60.0 * 0.86 * n / max_n
		ci.draw_line(Vector2(17, y), Vector2(25, y), Paper.INK, 2.0)
	ci.draw_arc(Vector2(-12, -34), 9.0, PI * 1.05, PI * 1.5, 8, Color(1, 1, 1, 0.85), 3.0)
	_face(ci, Vector2(0, -18), 1.2, "happy" if full else "calm", Color("0c2018"))
	# rolha: salta e flutua quando está cheio
	var lift := (10.0 + 4.0 * sin(_t() * 7.0)) if full else 0.0
	ci.draw_rect(Rect2(-11, -80 - lift, 22, 12), Paper.INK)
	ci.draw_rect(Rect2(-9, -78 - lift, 18, 8), Paper.BROWN.lightened(0.3))
	_xf_off(ci)
	if full:
		_sparkles(ci, C + Vector2(0, -54), 22.0, Color("4cff5a"), 5)
	HeroGauge._tag(ci, C + Vector2(-46, 48), Vector2(92, 20), "VESTÍGIOS %d/%d" % [me.vestiges, max_n], Color("0c2018"), Color("4cff5a"), 11)
	_notes(ci, C + Vector2(0, 82), status(me, g))


## Brotinho: um vasinho. Cada Vestígio abre uma folha; com três, nasce a flor.
static func apo_sprout(ci: CanvasItem, me: Unit, g: Node) -> void:
	var max_n: int = g.VESTIGE_MAX
	var full: bool = me.vestiges >= max_n
	var pop: float = HeroGauge.bump("apothecary", me.vestiges)
	var leaf := Color("54de85")
	var sway := sin(_t() * 2.6) * 0.07
	var base := C + Vector2(0, 34)
	# vaso
	var pot := PackedVector2Array([base + Vector2(-22, 0), base + Vector2(22, 0), base + Vector2(16, 26), base + Vector2(-16, 26)])
	ci.draw_colored_polygon(Paper.moved(Geometry2D.offset_polygon(pot, 3.0)[0], Vector2(4, 4)), Paper.INK)
	ci.draw_colored_polygon(Geometry2D.offset_polygon(pot, 3.0)[0], Paper.INK)
	ci.draw_colored_polygon(pot, Color("d9622a"))
	ci.draw_rect(Rect2(base.x - 27, base.y - 6, 54, 9), Paper.INK)
	ci.draw_rect(Rect2(base.x - 25, base.y - 4, 50, 5), Color("ff9a4d"))
	_face(ci, base + Vector2(0, 14), 0.95, "happy" if full else "calm", Color("4a2010"))
	# caule: cresce com os Vestígios
	var h := 18.0 + 20.0 * me.vestiges + 6.0 * pop
	_xf(ci, base + Vector2(0, -6), 1.0, sway)
	ci.draw_line(Vector2(0, 0), Vector2(0, -h), Paper.INK, 7.0)
	ci.draw_line(Vector2(0, 0), Vector2(0, -h), leaf.darkened(0.15), 3.5)
	for n in max_n:
		if n >= me.vestiges:
			continue
		var side := -1.0 if n % 2 == 0 else 1.0
		var at := Vector2(0, -14.0 - 20.0 * n)
		var grow := 1.0 + (0.5 * pop if n == me.vestiges - 1 else 0.0)
		var tip := at + Vector2(side * 24.0, -9.0) * grow
		var pts := PackedVector2Array([at, at + Vector2(side * 10.0, -13.0) * grow, tip, at + Vector2(side * 13.0, 3.0) * grow])
		ci.draw_colored_polygon(Geometry2D.offset_polygon(pts, 2.5)[0], Paper.INK)
		ci.draw_colored_polygon(pts, leaf)
		ci.draw_line(at, tip, leaf.darkened(0.3), 1.5)
	if full:
		# a flor
		var top := Vector2(0, -h)
		for n in 5:
			var a := n * TAU / 5.0 + _t() * 0.8
			ci.draw_circle(top + Vector2(cos(a), sin(a)) * 8.0, 7.5, Paper.INK)
		for n in 5:
			var a := n * TAU / 5.0 + _t() * 0.8
			ci.draw_circle(top + Vector2(cos(a), sin(a)) * 8.0, 5.5, Color("4cff5a"))
		ci.draw_circle(top, 5.5, Paper.GOLD)
	else:
		ci.draw_circle(Vector2(0, -h), 5.0, Paper.INK)
		ci.draw_circle(Vector2(0, -h), 3.0, leaf.lightened(0.3))
	_xf_off(ci)
	if full:
		_sparkles(ci, base + Vector2(0, -6 - h), 22.0, Color("4cff5a"), 5)
	HeroGauge._tag(ci, base + Vector2(-46, 34), Vector2(92, 20), "VESTÍGIOS %d/%d" % [me.vestiges, max_n], Color("0c2018"), Color("4cff5a"), 11)
	_notes(ci, base + Vector2(0, 68), status(me, g))


# ---------------------------------------------------------------- Sleepwalker

static func _sw_marks(g: Node) -> Array:
	var out: Array = []
	var spent := 0.0
	for n in 5:
		spent += float(g.SKILLS_ASLEEP[n]["cost"])
		out.append(clampf(spent / 100.0, 0.0, 1.0))
	return out


## Lua: enche de Torpor de baixo pra cima. As estrelinhas ao lado marcam o custo de cada passo do
## sonho; as de cima são a Vulnerabilidade Onírica.
static func sw_moon(ci: CanvasItem, me: Unit, g: Node) -> void:
	var k := clampf(me.torpor / 100.0, 0.0, 1.0)
	var dream: Color = Color("9e5cff") if me.asleep else (g.DREAM as Color)
	var pink := Color("ffc8e6")
	var pop: float = HeroGauge.bump("sleepwalker", floorf(me.torpor / 5.0))
	var float_y := sin(_t() * 1.7) * 3.0
	var mc := C + Vector2(0, float_y)
	_xf(ci, mc, 1.0 + 0.06 * pop, sin(_t() * 1.1) * 0.05)
	var disc := _circle_pts(Vector2.ZERO, 36.0, 36)
	ci.draw_colored_polygon(Paper.moved(_circle_pts(Vector2.ZERO, 40.0, 36), Vector2(4, 4)), Paper.INK)
	ci.draw_colored_polygon(_circle_pts(Vector2.ZERO, 40.0, 36), Paper.INK)
	ci.draw_colored_polygon(disc, Color("191a45"))
	_liquid(ci, disc, Rect2(-36, -36, 72, 72), k, dream, 2.0)
	# crateras
	for cr in [[-14.0, -16.0, 5.0], [15.0, 6.0, 4.0], [-6.0, 18.0, 3.0]]:
		ci.draw_circle(Vector2(cr[0], cr[1]), cr[2], Color(1, 1, 1, 0.13))
	_face(ci, Vector2(0, 0), 1.35, "sleep" if me.asleep or k < 0.15 else ("happy" if k > 0.8 else "calm"), pink if k < 0.5 else Paper.INK)
	# touca de dormir
	var cap := PackedVector2Array([Vector2(-26, -28), Vector2(8, -40), Vector2(34, -56 + sin(_t() * 3.0) * 3.0), Vector2(20, -22)])
	ci.draw_colored_polygon(Geometry2D.offset_polygon(cap, 2.5)[0], Paper.INK)
	ci.draw_colored_polygon(cap, pink)
	_ball(ci, cap[2], 5.5, Paper.CREAM, 2.0, Vector2.ZERO)
	_xf_off(ci)
	# custos: estrelinhas na altura certa, à direita
	var marks := _sw_marks(g)
	for n in marks.size():
		var m: float = marks[n]
		var y := mc.y + 36.0 - 72.0 * m
		var reached: bool = me.torpor >= m * 100.0 - 0.01
		var p := Vector2(mc.x + 52.0, y)
		ci.draw_line(Vector2(mc.x + 40.0, y), p, Paper.INK, 2.0)
		ci.draw_colored_polygon(_star_pts(p, 8.0, 4, 0.4), Paper.INK)
		ci.draw_colored_polygon(_star_pts(p, 5.5 + (2.0 * pop if reached else 0.0), 4, 0.4), Paper.GOLD if reached else Color("2a2c6b"))
	# Vulnerabilidade Onírica: arco de estrelas por cima
	for n in int(g.DREAM_MAX):
		var a := lerpf(PI * 1.2, PI * 1.8, n / float(int(g.DREAM_MAX) - 1))
		var p := mc + Vector2(cos(a), sin(a)) * 62.0
		ci.draw_colored_polygon(_star_pts(p, 5.5, 4, 0.4), Paper.GOLD if n < int(g.dream_stacks) else Color(0.16, 0.17, 0.42))
	if me.asleep:
		for n in 3:
			var ph := fmod(_t() * 0.6 + n * 0.33, 1.0)
			HeroGauge._text(ci, mc + Vector2(-58 - ph * 10.0, -20 - ph * 34.0), "z", 10 + int(ph * 8.0), Color(pink.r, pink.g, pink.b, 1.0 - ph))
	HeroGauge._tag(ci, C + Vector2(-44, 48), Vector2(88, 20), "TORPOR %d" % int(me.torpor), Color("191a45"), pink, 12)
	_notes(ci, C + Vector2(0, 82), status(me, g))


## Nuvem de sonho: um balão de pensamento em cima da cabeça, que enche de Torpor.
static func sw_cloud(ci: CanvasItem, me: Unit, g: Node) -> void:
	var k := clampf(me.torpor / 100.0, 0.0, 1.0)
	var dream: Color = Color("9e5cff") if me.asleep else (g.DREAM as Color)
	var pink := Color("ffc8e6")
	var pop: float = HeroGauge.bump("sleepwalker", floorf(me.torpor / 5.0))
	var cc := C + Vector2(0, -6 + sin(_t() * 1.6) * 2.5)
	var puffs := [[-34.0, 6.0, 20.0], [-14.0, -10.0, 24.0], [14.0, -8.0, 26.0], [36.0, 6.0, 19.0], [0.0, 12.0, 24.0]]
	# bolinhas do pensamento, descendo pro boneco
	_ball(ci, C + Vector2(-22, 44), 6.0, Paper.CREAM, 2.0, Vector2(2, 2))
	_ball(ci, C + Vector2(-30, 58), 3.8, Paper.CREAM, 1.5, Vector2(2, 2))
	var grow := 1.0 + 0.06 * pop
	for p in puffs:
		ci.draw_circle(cc + Vector2(p[0], p[1]) * grow + Vector2(4, 4), p[2] * grow + 3.0, Paper.INK)
	for p in puffs:
		ci.draw_circle(cc + Vector2(p[0], p[1]) * grow, p[2] * grow + 3.0, Paper.INK)
	for p in puffs:
		ci.draw_circle(cc + Vector2(p[0], p[1]) * grow, p[2] * grow, Paper.CREAM)
	var box := Rect2(cc.x - 56, cc.y - 36, 112, 74)
	for p in puffs:
		_liquid(ci, _circle_pts(cc + Vector2(p[0], p[1]) * grow, p[2] * grow, 24), box, k, dream, 2.0)
	# os custos de cada passo: risquinhos na beira, com luas
	var marks := _sw_marks(g)
	for n in marks.size():
		var m: float = marks[n]
		var y := box.end.y - box.size.y * m
		var reached: bool = me.torpor >= m * 100.0 - 0.01
		var p := Vector2(cc.x + 66.0, y)
		ci.draw_circle(p, 6.0, Paper.INK)
		ci.draw_circle(p, 4.2, pink if reached else Color("2a2c6b"))
		ci.draw_circle(p + Vector2(2.0, -1.2), 3.3, Paper.INK if not reached else pink.darkened(0.25))
	_face(ci, cc + Vector2(0, 0), 1.3, "sleep" if me.asleep or k < 0.15 else ("happy" if k > 0.8 else "calm"), Paper.INK)
	for n in int(g.DREAM_MAX):
		var p := cc + Vector2(-49 + n * 14, -44)
		ci.draw_colored_polygon(_star_pts(p, 7.0, 4, 0.4), Paper.INK)
		ci.draw_colored_polygon(_star_pts(p, 5.0, 4, 0.4), Paper.GOLD if n < int(g.dream_stacks) else Color("2a2c6b"))
	if me.asleep:
		for n in 3:
			var ph := fmod(_t() * 0.6 + n * 0.33, 1.0)
			HeroGauge._text(ci, cc + Vector2(62 + ph * 10.0, -30 - ph * 30.0), "z", 10 + int(ph * 8.0), Color(pink.r, pink.g, pink.b, 1.0 - ph))
	HeroGauge._tag(ci, cc + Vector2(-110, -4), Vector2(48, 20), "%d" % int(me.torpor), Color("191a45"), pink, 12)
	_notes(ci, cc + Vector2(0, -70), status(me, g), true)
