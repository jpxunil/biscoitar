class_name DpsMeter
extends Control
## Medidor de dano da LUTA INTEIRA, no canto de cima à direita. Substitui o "DPS dos últimos segundos"
## que ficava em cada card: aqui a conta é dano total / tempo de luta, então o número não despenca
## quando alguém para dois segundos pra desviar.
##   em cima: tempo de luta e o DPS somado da party;
##   uma linha por herói, do que mais bateu pro que menos: DPS, parte do dano da party e dano total;
##   clicar numa linha abre o detalhe do herói: dano por habilidade (game.gd: unit.dmg_log).
## Os números vêm de game.meter_rows(); este nó só desenha.

const W := 300.0
const PAD := 8.0
const HEAD := 54.0
const ROW := 30.0
const GAP := 4.0
const TITLE := 30.0
const TILES := 44.0
const COLS := 18.0
const SKILL_ROW := 24.0
const MAX_SKILLS := 8
const PANEL := Color(0.105, 0.115, 0.235)
const SLOT := Color(0.16, 0.175, 0.33)
const SOFT := Color(0.66, 0.69, 0.84)

var g
## Herói (índice em g.units) com o detalhe aberto; -1 = fechado.
var open := -1
var _icons := {}


func setup(game) -> void:
	g = game
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fit()


func _process(_delta: float) -> void:
	if g == null:
		return
	_fit()
	queue_redraw()


## Habilidades do herói aberto, da que mais deu dano pra que menos: [[nome, {"dmg", "hits"}], ...].
func skills_of(u: Unit) -> Array:
	var list: Array = []
	for name in u.dmg_log:
		list.append([name, u.dmg_log[name]])
	list.sort_custom(func(a, b): return a[1]["dmg"] > b[1]["dmg"])
	return list.slice(0, MAX_SKILLS)


func _list_h() -> float:
	return HEAD + g.units.size() * (ROW + GAP) + PAD


func _detail_h() -> float:
	if open < 0:
		return 0.0
	return TITLE + TILES + COLS + maxi(1, skills_of(g.units[open]).size()) * SKILL_ROW + PAD * 2.0


func _fit() -> void:
	var h := _list_h() + (_detail_h() + GAP * 2.0 if open >= 0 else 0.0)
	offset_left = -W - 14.0
	offset_right = -14.0
	offset_top = 14.0
	offset_bottom = 14.0 + h


static func fmt(v: float) -> String:
	if v >= 1000000.0:
		return ("%.1fM" % (v / 1000000.0)).replace(".", ",")
	if v >= 10000.0:
		return ("%.1fK" % (v / 1000.0)).replace(".", ",")
	return str(roundi(v))


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


## Painel no padrão do jogo: sombra dura deslocada, contorno de tinta grosso, fundo azul-noite.
func _panel(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Color(Paper.INK.r, Paper.INK.g, Paper.INK.b, 0.75))
	draw_rect(r.grow(3.0), Paper.INK)
	draw_rect(r, PANEL)


func _icon(u: Unit, skill: String) -> Texture2D:
	var id := u.key + "/" + skill
	if not _icons.has(id):
		_icons[id] = null
		for mode in ([false, true] if SkillInfo.has_alt(u.key) else [false]):
			var kit: Array = SkillInfo.kit(u.key, mode)
			for n in kit.size():
				if kit[n] != null and String(kit[n]["name"]) == skill:
					_icons[id] = SkillInfo.icon(u.key, n, mode)
	return _icons[id]


func _draw() -> void:
	if g == null:
		return
	var title := Paper.display(0.0)
	var body := Paper.body()
	var rows: Array = g.meter_rows()
	var total := 0.0
	var top := 1.0
	for r in rows:
		total += r["dmg"]
		top = maxf(top, r["dmg"])
	var time: float = maxf(g.fight_time, 1.0)
	_panel(Rect2(0, 0, W, _list_h()))
	# cabeçalho: tempo de luta e o DPS da party inteira
	draw_string(body, Vector2(PAD + 2, 18), "DANO DA LUTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SOFT)
	draw_string(title, Vector2(PAD, 18), _clock(g.fight_time), HORIZONTAL_ALIGNMENT_RIGHT, W - PAD * 2.0, 13, Paper.CREAM)
	draw_string(title, Vector2(PAD + 2, 44), fmt(total / time), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Paper.CYAN)
	var total_w := title.get_string_size(fmt(total / time), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(body, Vector2(PAD + 8 + total_w, 44), "DPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SOFT)
	draw_string(body, Vector2(PAD, 44), "total %s" % fmt(total), HORIZONTAL_ALIGNMENT_RIGHT, W - PAD * 2.0, 12, SOFT)
	# uma linha por herói
	for k in rows.size():
		var u: Unit = rows[k]["unit"]
		var r := Rect2(PAD, HEAD + k * (ROW + GAP), W - PAD * 2.0, ROW)
		draw_rect(r, SLOT)
		var col := Color(u.color.r, u.color.g, u.color.b).darkened(0.25)
		if not u.alive:
			col = col.darkened(0.5)
		draw_rect(Rect2(r.position, Vector2(r.size.x * float(rows[k]["dmg"]) / top, ROW)), col)
		draw_rect(Rect2(r.position, Vector2(4, ROW)), u.color.lightened(0.3))
		if u.controlled or u.idx == open:
			draw_rect(r, Paper.CREAM if u.controlled else Paper.CYAN, false, 2.0)
		var y := r.position.y + 20.0
		var name_col := Paper.CREAM if u.alive else SOFT
		draw_string_outline(title, Vector2(r.position.x + 10, y), u.unit_name, HORIZONTAL_ALIGNMENT_LEFT, 104, 12, 4, Paper.INK)
		draw_string(title, Vector2(r.position.x + 10, y), u.unit_name, HORIZONTAL_ALIGNMENT_LEFT, 104, 12, name_col)
		for cell in [[fmt(rows[k]["dps"]), 118.0, 52.0, 14, Paper.CREAM, title], ["%d%%" % roundi(rows[k]["share"] * 100.0), 172.0, 44.0, 12, SOFT.lightened(0.4), body],
				[fmt(rows[k]["dmg"]), 218.0, 60.0, 12, SOFT.lightened(0.4), body]]:
			var at := Vector2(r.position.x + float(cell[1]), y)
			draw_string_outline(cell[5], at, cell[0], HORIZONTAL_ALIGNMENT_RIGHT, cell[2], cell[3], 4, Paper.INK)
			draw_string(cell[5], at, cell[0], HORIZONTAL_ALIGNMENT_RIGHT, cell[2], cell[3], cell[4])
	if open < 0:
		return
	# detalhe: o herói aberto, habilidade por habilidade
	var hero: Unit = g.units[open]
	var d0 := _list_h() + GAP * 2.0
	_panel(Rect2(0, d0, W, _detail_h()))
	var share := hero.dmg_total / total if total > 0.0 else 0.0
	draw_string(title, Vector2(PAD + 2, d0 + 21), hero.unit_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, hero.color.lightened(0.35))
	draw_string(body, Vector2(PAD, d0 + 21), "fechar  ×", HORIZONTAL_ALIGNMENT_RIGHT, W - PAD * 2.0, 12, SOFT)
	var tile_w := (W - PAD * 2.0 - 12.0) / 3.0
	var tiles := [["DPS", fmt(hero.dmg_total / time)], ["DANO", fmt(hero.dmg_total)], ["DA PARTY", "%d%%" % roundi(share * 100.0)]]
	for n in 3:
		var tr := Rect2(PAD + n * (tile_w + 6.0), d0 + TITLE, tile_w, TILES - 6.0)
		draw_rect(tr, SLOT)
		draw_string(body, tr.position + Vector2(6, 13), tiles[n][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SOFT)
		draw_string(title, tr.position + Vector2(6, 32), tiles[n][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Paper.CREAM)
	var cy := d0 + TITLE + TILES
	draw_string(body, Vector2(PAD + 2, cy + 12), "HABILIDADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SOFT)
	for head in [["DANO", 142.0, 50.0], ["DPS", 194.0, 40.0], ["GOLPES", 236.0, 40.0]]:
		draw_string(body, Vector2(PAD + float(head[1]), cy + 12), head[0], HORIZONTAL_ALIGNMENT_RIGHT, head[2], 10, SOFT)
	var skills := skills_of(hero)
	var best := 1.0
	for s in skills:
		best = maxf(best, s[1]["dmg"])
	if skills.is_empty():
		draw_string(body, Vector2(PAD + 2, cy + COLS + 16), "ainda sem dano", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SOFT)
	for n in skills.size():
		var info: Dictionary = skills[n][1]
		var sr := Rect2(PAD, cy + COLS + n * SKILL_ROW, W - PAD * 2.0, SKILL_ROW - 3.0)
		draw_rect(sr, SLOT)
		draw_rect(Rect2(sr.position, Vector2(sr.size.x * float(info["dmg"]) / best, sr.size.y)), Color(0.2, 0.52, 0.6))
		var icon := _icon(hero, skills[n][0])
		if icon != null:
			draw_texture_rect(icon, Rect2(sr.position + Vector2(1, 0.5), Vector2(20, 20)), false)
		var sy := sr.position.y + 15.0
		draw_string(body, Vector2(sr.position.x + 26, sy), skills[n][0], HORIZONTAL_ALIGNMENT_LEFT, 116, 12, Paper.CREAM)
		for cell in [[fmt(info["dmg"]), 142.0, 50.0, Paper.CREAM], [fmt(float(info["dmg"]) / time), 194.0, 40.0, SOFT.lightened(0.4)], [str(int(info["hits"])), 236.0, 40.0, SOFT.lightened(0.4)]]:
			draw_string(body, Vector2(PAD + float(cell[1]), sy), cell[0], HORIZONTAL_ALIGNMENT_RIGHT, cell[2], 12, cell[3])


func _gui_input(event: InputEvent) -> void:
	if g == null or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var y: float = event.position.y
	if y >= HEAD and y < _list_h() - PAD:
		# clicou numa linha: abre o detalhe daquele herói (ou fecha, se já era ele)
		var rows: Array = g.meter_rows()
		var k := int((y - HEAD) / (ROW + GAP))
		if k >= 0 and k < rows.size():
			var idx: int = rows[k]["unit"].idx
			open = -1 if open == idx else idx
	elif y >= _list_h():
		open = -1
	accept_event()
