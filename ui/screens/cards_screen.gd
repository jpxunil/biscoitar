class_name CardsScreen
extends Control
## Cartas de UM herói por vez (design em design/tela-cartas-v2, prancha "Motion").
## À esquerda os slots equipados; embaixo a mão, numa roleta; à direita a arte do herói,
## os detalhes da carta e o botão de luta. As cores do cenário seguem o tema do herói.
##   clicar numa carta da roleta: traz pro foco · clicar numa equipada: mostra os detalhes
##   segurar e arrastar: roleta -> slot equipa (ou troca) · slot -> slot troca · slot -> roleta tira
## A tela é montada em código sobre um palco fixo de 1280x720; as medidas estão nas constantes.

signal ready_pressed
signal back_pressed
## Abrir a tela SKILLS no herói que está sendo visto (o botão pequeno embaixo do VOLTAR).
signal skills_pressed(hero: int)
## Uma carta mudou de lugar (equipou, tirou ou trocou de slot).
signal deck_changed

## Modo guiado do tutorial (scripts/tutorial.gd). Com `tutor` preenchido a tela vira uma aula:
## só aparecem as cartas que o jogador tem, não dá pra trocar de herói nem sair, a arte da direita
## é de quem ensina e a carta `tutor["card"]` brilha e saltita até ser arrastada pra um slot.
##   {"card": id da carta em destaque, "art": caminho da arte, "art_w": largura da arte}
var tutor := {}
var _tutor_panel: CutPanel
var _tutor_text: Label
var _tutor_next: Chip
var _d_panel: CutPanel


## Fala de quem ensina, no painel da direita (só no modo guiado).
## `wait`: a fala espera o jogador; aparece a etiqueta ENTER no canto do painel.
func tutor_say(text: String, wait := false) -> void:
	if _tutor_panel == null:
		_tutor_next = Chip.new()
		_tutor_next.px = 13
		_tutor_next.arrow = true
		_tutor_next.text = "ENTER"
		_tutor_next.z_index = 2
		_add(_top, _tutor_next, Vector2(1264 - _tutor_next.size.x - 4, 452))
		_tutor_panel = _add(_top, CutPanel.make(Rect2(892, 356, 372, 112), [[.02, 0], [1, .05], [.97, 1], [0, .94]], Paper.CREAM, 5, Vector2(8, 8)))
		_tutor_text = Paper.label("", 17, Paper.INK, Paper.body(700))
		_tutor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tutor_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tutor_text.add_theme_constant_override("line_spacing", -3)
		_add(_top, _tutor_text, Vector2(912, 364), Vector2(336, 96))
	_tutor_next.visible = wait
	_tutor_text.text = text
	_tutor_text.visible_ratio = 0.0
	_tutor_text.create_tween().tween_property(_tutor_text, "visible_ratio", 1.0, minf(0.9, text.length() * 0.012))

const STAGE := Vector2(1280, 720)
## Roleta: centro fora da tela, cartas a RADIUS do centro, uma a cada STEP graus.
const HUB := Vector2(450, 1100)
const RADIUS := 560.0
const STEP := 13.0
const RIM := 672.0
const SLOT_AT := {
	"purple": [Vector2(60, 96), Vector2(176, 96)],
	"gold": [Vector2(308, 96), Vector2(424, 96), Vector2(540, 96)],
	"white": [Vector2(118, 240), Vector2(234, 240), Vector2(350, 240), Vector2(466, 240)],
	"item": [Vector2(741, 184)],
}
## Frase do balão. Quem não tem frase própria usa o `blurb` do herói.
const QUOTES := {
	"tank": "Atrás de mim. Sempre.",
	"healer": "Ninguém morre no meu turno.",
	"assassina": "Pisca e já acabou.",
	"maga": "Relaxa, eu resolvo. Como sempre.",
	"nurse": "Fica parado. Vai doer.",
	"burner": "Queima primeiro. Pergunta depois.",
	"ringstar": "Um, dois... nocaute!",
	"apothecary": "Remédio ou veneno? Depende da dose.",
	"sleepwalker": "Zzz... só mais cinco minutinhos.",
}
## Ordem dos heróis no seletor: as duas tanks ficam lado a lado.
const ORDER := [0, 4, 1, 2, 3, 5, 6, 7, 8]
## Enquadramento da arte. As artes (assets/portraits/<chave>_art.webp) são de corpo inteiro, recortadas
## rente à figura, cada uma com uma proporção. A largura na tela sai da proporção do arquivo (ver
## _art_frame): figura alta aparece da cabeça até a cintura e o resto fica atrás dos painéis; figura
## larga (a Sleepwalker na almofada, a Maga com as marias-chiquinhas) aparece inteira.
## ART_FRAME é só pra corrigir um herói à mão: {"w", "x", "y"} em pixels da tela.
const ART_FRAME := {}
const ART_DEFAULT := {"w": 430.0, "x": 860.0, "y": 50.0}
## Centro da área da arte e o maior tamanho que ela ocupa.
const ART_MID_X := 1076.0
const ART_TOP := 22.0
const ART_MAX_W := 440.0
const ART_MAX_H := 840.0
## Onde fica o rosto na arte, de cima pra baixo (0..1). Quem levanta o braço (espada, luva, frasco)
## tem o rosto mais embaixo: a arte encolhe até o rosto ficar acima da placa do nome (ART_FACE_Y).
const ART_FACE := {"tank": 0.44, "ringstar": 0.37, "apothecary": 0.37}
const ART_FACE_Y := 245.0
const CARD_HALF := Vector2(CardView.W, CardView.H) * 0.5


## Control que desenha com uma função: `fn` recebe o próprio nó.
class Draw extends Control:
	var fn: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## Etiqueta inclinada com texto; `fit()` ajusta a largura ao texto.
class Tag extends Control:
	var text := ""
	var px := 12
	var bg := Paper.INK
	var fg := Paper.CREAM
	var border := 0.0
	var skew := 12.0
	var pad := 8.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func fit(height: float) -> void:
		size = Vector2(Paper.display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + (pad + border) * 2.0, height)
		queue_redraw()

	func _draw() -> void:
		var pts := Paper.skew_rect(size, skew)
		if border > 0.0:
			draw_colored_polygon(pts, Paper.INK)
		draw_colored_polygon(Paper.inset(pts, border), bg)
		var f := Paper.display()
		draw_string(f, Vector2(0, size.y * 0.5 + (f.get_ascent(px) - f.get_descent(px)) * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, px, fg)


## Uma peça do seletor de herói: fechada (k = 0) é só o rosto; aberta (k = 1) é a placa com nome e classe.
class HeroTile extends BaseButton:
	var hero := 0: set = _set_hero
	var k := 0.0: set = _set_k
	var dim := false: set = _set_dim
	var slot := -1
	var tw: Tween
	var hover_tw: Tween
	var _face: TextureRect
	var _hot := false
	## Este herói tem carta nova ainda não vista: um selo rosa com "!" pisca no canto do rosto.
	var fresh := false: set = _set_fresh
	var _mark: Control
	var _mark_t := 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		clip_contents = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_face = TextureRect.new()
		_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.position = Vector2(3, 3)
		add_child(_face)
		_mark = Control.new()
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.visible = false
		_mark.draw.connect(_draw_mark)
		add_child(_mark)
		set_process(false)
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))

	func _set_fresh(v: bool) -> void:
		fresh = v
		_mark.visible = v
		set_process(v)

	func _process(delta: float) -> void:
		_mark_t += delta
		_mark.queue_redraw()

	func _draw_mark() -> void:
		# selo no canto de cima do rosto: losango rosa com contorno INK e "!" creme
		var p := 0.5 + 0.5 * sin(_mark_t * 5.0)
		var c := Vector2(_face.size.x - 6.0, 12.0)
		var r := 9.0 + 1.5 * p
		for spec in [[r + 3.0, Paper.INK], [r, Paper.PINK]]:
			var rr: float = spec[0]
			_mark.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)]), spec[1])
		_mark.draw_string(Paper.display(0.0), c + Vector2(-10, 5), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Paper.CREAM)

	func _set_hero(v: int) -> void:
		hero = v
		_face.texture = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[v]["key"])

	func _set_k(v: float) -> void:
		k = v
		size = Vector2(lerpf(38.0, 164.0, v), lerpf(48.0, 58.0, v))
		pivot_offset = Vector2(minf(size.x, 50.0) * 0.5, size.y * 0.5)
		_face.size = Vector2(lerpf(32.0, 44.0, minf(v * 4.0, 1.0)), size.y - 6.0)
		_shade()
		queue_redraw()

	func _set_dim(v: bool) -> void:
		dim = v
		_shade()

	func _shade() -> void:
		# rosto fechado fica apagado (mais ainda a tank que está fora da party); aceso no hover e aberto
		var rest := 0.28 if dim else 0.6
		_face.modulate.a = 1.0 if (_hot or k > 0.05 or slot == 0) else rest

	func _hover(on: bool) -> void:
		_hot = on
		_shade()
		if k > 0.05 or (tw != null and tw.is_running()):
			return
		stop_hover()
		hover_tw = create_tween()
		hover_tw.tween_property(self, "scale", Vector2.ONE * (1.15 if on else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## A troca de herói assume a escala da peça: o crescer do hover não pode brigar com ela.
	func stop_hover() -> void:
		if hover_tw != null:
			hover_tw.kill()
			hover_tw = null

	func _draw() -> void:
		var h: Dictionary = Knowledge.HEROES[hero]
		draw_rect(Rect2(Vector2.ZERO, size), Paper.INK)
		var x0 := _face.size.x + 6.0
		if size.x - x0 < 6.0:
			return
		draw_rect(Rect2(x0, 3, size.x - x0 - 3.0, size.y - 6.0), Paper.CREAM)
		var f := Paper.display(0.0)
		var nm := String(h["name"]).to_upper()
		var px := 20
		while px > 11 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 96.0:
			px -= 1
		draw_string(f, Vector2(x0 + 8.0, 28), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Paper.INK)
		var fb := Paper.body(700)
		var rpx := 14
		while rpx > 9 and fb.get_string_size(h["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, rpx).x > 96.0:
			rpx -= 1
		draw_string(fb, Vector2(x0 + 8.0, 46), h["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, rpx, Color("3e2413"))


var hero := 0
var _show_ready := true
var _th: Dictionary = Paper.THEMES["tank"]
var _built := false
var _t := 0.0

var _stage: Control
var _cards: Control
var _top: Control
var _bg: Draw
var _wheel: Draw
var _ticks: Control
var _stripes: Array = []
var _stage_block: CutPanel
var _pointer: Draw
var _tray: CutPanel
var _tray_band: Draw
var _item_tray: CutPanel
var _art: Control
var _art_tex: TextureRect
var _face_frame: CutPanel
var _face_tex: TextureRect
var _bubble: Control
var _bubble_text: Label
var _bubble_panel: CutPanel
var _boss: Draw
var _strip_bar: CutPanel
## Seletor: uma peça por herói (índice em Knowledge.HEROES), sempre na ordem de ORDER girada.
var _tiles := {}
## Fila do seletor (heróis, o atual na frente) e o lugar onde o antigo acabou de ser inserido.
var _row: Array = []
## Carta sob o mouse: os detalhes mostram ela enquanto o mouse está em cima.
var _peek = null
var _pager: Draw
var _spin_prev: ShineButton
var _spin_next: ShineButton
var _art_tw: Tween
var _ticks_tw: Tween
var _push_at := -1
var _name_tag: Control
var _name_panel: CutPanel
var _name_label: Label
var _role_tag: Tag
var _hp: Draw
var _d_tile: Draw
var _d_name: Label
var _d_kind: Tag
var _d_cat: Tag
var _d_desc: Label
## Pista da carta desconhecida (some quando a carta é do jogador).
var _d_hint: Label
var _skills_btn: ShineButton
var _ready_btn: ShineButton
var _ready_shadow: Draw

## Mão: ids na ordem da roleta. `_focus` é a carta do topo.
var _hand: Array = []
var _focus := 0
## Carta equipada selecionada por clique (índice em _slots), ou -1: os detalhes mostram ela.
var _sel := -1
## Um dicionário por carta: {cv, src ("slot"/"hand"), idx, id, kind, home, rot0, hover, press, drag_ok, alt, tw, spoke}
var _slots: Array = []
var _spokes: Array = []
var _pend = null
var _drag = null
var _ghost: CardView
var _over := -1
var _detail_id := ""
var _art_home := Vector2(860, 50)
var _mouse_at := Vector2.ZERO


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		# aberta sozinha (F6): dados de exemplo, sem tocar no save
		Knowledge.persist = false
		for id in ["stack", "pair", "spread", "mitigate", "provoke", "instinct", "sharpen", "plate", "potion", "revive", "eshield", "spark", "secondskin", "phoenix"]:
			Knowledge.owned[id] = true
		Knowledge.dps_known["maga"] = true
		Knowledge.mastery["link"] = 2
		for id in ["stack", "sharpen", "potion", "dps"]:
			Knowledge.equip(3, id)
		open(3)


func open(hero_idx: int, show_ready := true) -> void:
	hero = clampi(hero_idx, 0, Knowledge.HEROES.size() - 1)
	_show_ready = show_ready
	# com a party montada, o seletor mostra só os quatro dela (na aula do tutorial, todos)
	# sem party montada (ou na aula), entram os primeiros da lista: o seletor tem lugar pra cinco
	var team: Array = Knowledge.party if (Knowledge.party_ready() and tutor.is_empty()) else ORDER.slice(0, TILE_X.size())
	if not team.has(hero):
		hero = team[0]
	# fila do seletor: o herói atual na frente, os outros na ordem padrão
	_row = [hero]
	for id in ORDER:
		if id != hero and team.has(id):
			_row.append(id)
	for id in _tiles:
		_tiles[id].slot = -1
		_tiles[id].visible = _row.has(id)
	refresh(true)


## Seta: pra frente pega o primeiro rosto da fila; pra trás pega o último.
func _switch(dir: int) -> void:
	_go(_row[1] if dir > 0 else _row[_row.size() - 1], dir)


## Troca de herói. O escolhido vai pra frente da fila e o antigo é inserido nela: no fim (o normal)
## ou logo depois da frente quando se volta com a seta (pra seta de voltar desfazer a de avançar).
func _go(to: int, dir: int) -> void:
	if to == hero or not tutor.is_empty():
		return
	var old := hero
	var back: bool = dir < 0 and _row[_row.size() - 1] == to
	_row.erase(to)
	_row.erase(old)
	if back:
		_row = [to, old] + _row
	else:
		_row = [to] + _row + [old]
	_push_at = 1 if back else _row.size() - 1
	hero = to
	Knowledge.start_hero = hero
	Knowledge.save()
	refresh(true, dir)


## Enquadra uma arte de corpo inteiro: a maior escala que cabe em ART_MAX_W x ART_MAX_H, sem
## distorcer, centrada em ART_MID_X.
func _art_frame(tex: Texture2D, key := "") -> Dictionary:
	var ts := tex.get_size()
	var max_h := minf(ART_MAX_H, ART_FACE_Y / float(ART_FACE.get(key, 0.28)))
	var w := minf(ART_MAX_W, max_h * ts.x / ts.y)
	var h := w * ts.y / ts.x
	# figura baixa (cabe inteira acima dos painéis) desce um pouco pra não ficar colada no topo
	var y := ART_TOP + maxf(0.0, (360.0 - h) * 0.5)
	return {"w": w, "x": ART_MID_X - w * 0.5, "y": y}


func refresh(animate := false, dir := 0) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	_th = Paper.THEMES.get(h["key"], Paper.THEMES["tank"])
	_cancel_drag()
	_sel = -1
	# cenário e painéis no tema do herói
	_bg.queue_redraw()
	_wheel.queue_redraw()
	_stage_block.fill = _th.get("stage", _th["deep"])
	_stripes[0].fill = _th["bg2"]
	_stripes[1].fill = _th["acc"]
	_stripes[2].fill = _th.get("stripe3", Paper.CREAM)
	_tray.fill = _th["deep"]
	_tray_band.queue_redraw()
	_item_tray.fill = _th["deep2"]
	_strip_bar.fill = _th["deep2"]
	_boss.queue_redraw()
	_layout_tiles(animate)
	_mark_new()
	# arte: ilustração inteira se existir, senão o rosto numa moldura
	var art := ""
	for ext in ["webp", "png"]:
		var p := "res://assets/portraits/%s_art.%s" % [h["key"], ext]
		if ResourceLoader.exists(p):
			art = p
			break
	_art_tex.visible = art != ""
	_face_frame.visible = art == ""
	var frame: Dictionary = ART_DEFAULT
	if art != "":
		frame = ART_FRAME[h["key"]] if ART_FRAME.has(h["key"]) else _art_frame(load(art), h["key"])
	if not tutor.is_empty():
		# quem aparece é quem ensina; nome, classe e vida do herói saem pra dar lugar à fala
		art = tutor["art"]
		_art_tex.visible = true
		_face_frame.visible = false
		frame = {"w": float(tutor.get("art_w", 400.0)), "x": 880.0, "y": 8.0}
	_bubble.visible = tutor.is_empty()
	_skills_btn.visible = tutor.is_empty()
	_name_tag.visible = tutor.is_empty()
	_role_tag.visible = tutor.is_empty()
	_hp.visible = tutor.is_empty()
	_art_home = Vector2(frame["x"], frame["y"])
	_art.position = _art_home
	if art != "":
		var tex: Texture2D = load(art)
		_art_tex.texture = tex
		var ts := tex.get_size()
		_art_tex.size = Vector2(frame["w"], frame["w"] * ts.y / ts.x)
		# silhueta colorida atrás da figura (cor do herói, com contorno INK pra não se misturar ao fundo)
		if tutor.is_empty():
			ArtShadow.for_hero(_art_tex, h["key"])
		else:
			ArtShadow.attach(_art_tex, Paper.GOLD)
		_art.pivot_offset = Vector2(frame["w"] * 0.5, minf(_art_tex.size.y * 0.8, 400.0))
	else:
		_face_tex.texture = load("res://assets/portraits/%s_face.png" % h["key"])
	_bubble_text.text = QUOTES.get(h["key"], h["blurb"])
	# o balão cresce pra baixo com o número de linhas da frase
	var bf := Paper.body(700)
	var lines := maxi(1, roundi(bf.get_multiline_string_size(_bubble_text.text, HORIZONTAL_ALIGNMENT_LEFT, 118, 14).y / bf.get_height(14)))
	_bubble_text.size = Vector2(118, lines * 18.0 + 4.0)
	_bubble_panel.size = Vector2(150, lines * 18.0 + 44.0)
	_bubble_panel.queue_redraw()
	# nome, classe e vida
	var nm := String(h["name"]).to_upper()
	_name_label.text = nm
	var nw := maxf(150.0, Paper.display().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x + 56.0)
	_name_panel.size = Vector2(nw, 58)
	_name_label.size = Vector2(nw, 58)
	_name_label.pivot_offset = _name_label.size * 0.5
	_name_tag.pivot_offset = Vector2(nw, 58) * 0.5
	_role_tag.text = String(h["role"]).to_upper()
	_role_tag.bg = _th["acc"]
	_role_tag.fg = _th["acc_t"]
	_role_tag.fit(28)
	_hp.position = Vector2(_role_tag.position.x + _role_tag.size.x + 14.0, 446)
	_hp.queue_redraw()
	_ready_btn.visible = _show_ready
	_ready_shadow.visible = _show_ready
	# mão: o que ele tem e não está equipado, depois o que ainda não conquistou
	_hand = _hand_list()
	# começa no meio das cartas que ele já tem
	var mine := 0
	for id in _hand:
		if Knowledge.is_owned_by(hero, id):
			mine += 1
	_focus = clampi(mine / 2, 0, maxi(0, _hand.size() - 1))
	# tem carta nova: a roleta abre nela (o selo só sai quando o mouse passar por cima)
	for k in _hand.size():
		if Knowledge.is_new(hero, _hand[k]):
			_focus = k
			break
	_ticks.rotation = deg_to_rad(-_focus * STEP)
	_build_cards(animate)
	if animate:
		_art.modulate.a = 0.0
		var from := 60.0 if dir >= 0 else -60.0
		_art.position.x = _art_home.x + from
		if _art_tw != null:
			_art_tw.kill()
		_art_tw = _art.create_tween().set_parallel(true)
		_art_tw.tween_property(_art, "position:x", _art_home.x, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_art_tw.tween_property(_art, "modulate:a", 1.0, 0.18)
	else:
		if _art_tw != null:
			_art_tw.kill()
			_art_tw = null
		_art.position.x = _art_home.x
		_art.modulate.a = 1.0


# ---------------------------------------------------------------- montagem (uma vez)

## Põe `node` em `parent`. Sem `at`, o nó fica onde já estava (painéis criados com um Rect2).
func _add(parent: Control, node: Control, at := Vector2.INF, sz := Vector2.ZERO):
	if at != Vector2.INF:
		node.position = at
	if sz != Vector2.ZERO:
		node.size = sz
	parent.add_child(node)
	return node


func _drawer(parent: Control, fn: Callable, at := Vector2.INF, sz := Vector2.ZERO) -> Draw:
	var d := Draw.new()
	d.fn = fn
	_add(parent, d, at, sz)
	return d


func _build() -> void:
	if _built:
		return
	_built = true
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	resized.connect(_center)
	_center()

	_bg = _drawer(_stage, _draw_bg)
	# palco da arte: bloco escuro + três faixas que deslizam devagar
	_add(_stage, CutPanel.make(Rect2(790, 0, 500, 720), [[.22, 0], [1, 0], [1, 1], [.06, 1], [.18, .56], [.08, .44]], Paper.INK, 0, Vector2.ZERO))
	_stage_block = _add(_stage, CutPanel.make(Rect2(800, 0, 480, 720), [[.22, 0], [1, 0], [1, 1], [.06, 1], [.18, .56], [.08, .44]], Paper.NAVY, 0, Vector2.ZERO))
	_stripes = [
		_add(_stage, CutPanel.make(Rect2(850, 96, 470, 190), [[0, .74], [1, 0], [1, .42], [.05, 1]], Paper.GOLD, 0, Vector2.ZERO)),
		_add(_stage, CutPanel.make(Rect2(866, 214, 450, 150), [[0, .78], [1, 0], [1, .3], [.06, 1]], Paper.RED, 0, Vector2.ZERO)),
		_add(_stage, CutPanel.make(Rect2(900, 300, 420, 120), [[0, .86], [1, 0], [1, .14], [.04, 1]], Paper.CREAM, 0, Vector2.ZERO)),
	]
	for s in _stripes:
		s.set_meta("home", s.position)

	# roleta: discos fixos, marcas do aro que giram com as cartas, ponteiro
	_wheel = _drawer(_stage, _draw_wheel)
	_ticks = Control.new()
	_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _ticks, HUB)
	_drawer(_ticks, _draw_ticks)
	var prev := _arrow(-1)
	_add(_stage, prev, Vector2(296, 668), Vector2(44, 44))
	prev.pressed.connect(func(): _spin(-1))
	_spin_prev = prev
	var nxt := _arrow(1)
	_add(_stage, nxt, Vector2(560, 668), Vector2(44, 44))
	nxt.pressed.connect(func(): _spin(1))
	_spin_next = nxt
	_pager = _drawer(_stage, _draw_pager)
	_pager.z_index = 8
	var hub_label := Paper.label("SUAS CARTAS", 21, Paper.CREAM, Paper.display())
	hub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_stage, hub_label, Vector2(348, 672), Vector2(204, 36))

	# bandejas dos slots
	_tray = _add(_stage, CutPanel.make(Rect2(36, 84, 632, 314), [[0, .04], [1, 0], [.98, 1], [.02, .96]], Paper.NAVY))
	_tray_band = _drawer(_stage, func(d: Draw): d.draw_rect(Rect2(Vector2.ZERO, d.size), _th["deep2"]), Vector2(46, 236), Vector2(612, 14))
	_tray_band.rotation = deg_to_rad(-1.0)
	_item_tray = _add(_stage, CutPanel.make(Rect2(700, 110, 190, 262), [[.08, 0], [1, .06], [.94, 1], [0, .92]], Paper.BROWN))
	var item_tag := Tag.new()
	item_tag.text = "ITEM ON HOLD"
	item_tag.px = 14
	item_tag.bg = Paper.CYAN
	item_tag.fg = Paper.INK
	item_tag.border = 3
	item_tag.skew = 10
	_add(_stage, item_tag, Vector2(716, 134), Vector2(158, 34))
	item_tag.pivot_offset = item_tag.size * 0.5
	item_tag.rotation = deg_to_rad(-4.0)

	# arte do herói (flutua) e o balão da frase
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _art, Vector2(860, 50), Vector2(430, 500))
	_art.pivot_offset = Vector2(215, 400)
	_art_tex = TextureRect.new()
	_art_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_art, _art_tex, Vector2.ZERO, Vector2(430, 500))
	_face_frame = _add(_art, CutPanel.make(Rect2(120, 70, 210, 290), [[.02, 0], [1, .03], [.97, 1], [0, .97]], Paper.CREAM, 6, Vector2(9, 9)))
	_face_frame.pivot_offset = _face_frame.size * 0.5
	_face_frame.rotation = deg_to_rad(-4.0)
	_face_tex = TextureRect.new()
	_face_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_face_frame, _face_tex, Vector2(14, 14), Vector2(182, 262))
	_bubble = Control.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _bubble, Vector2(876, 62), Vector2(156, 84))
	_bubble.pivot_offset = Vector2(78, 42)
	_bubble_panel = _add(_bubble, CutPanel.make(Rect2(0, 0, 150, 78), [[0, .1], [1, 0], [.96, .86], [.8, .88], [.84, 1], [.62, .9], [.04, .96]], Paper.CREAM, 3, Vector2(6, 6)))
	_bubble_text = Paper.label("", 14, Paper.INK, Paper.body(700))
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.add_theme_constant_override("line_spacing", -4)
	_bubble_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_bubble, _bubble_text, Vector2(22, 13), Vector2(118, 54))

	# cartas (slots + mão) e o ponteiro por cima delas
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_stage, _cards)
	_pointer = _drawer(_stage, _draw_pointer, Vector2(428, 398), Vector2(44, 36))
	_pointer.z_index = 8

	# tudo que fica por cima das cartas
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.z_index = 10
	_add(_stage, _top)
	_add(_top, CutPanel.make(Rect2(20, 10, 216, 62), [[0, 0], [1, .08], [.95, 1], [.03, .9]], Paper.CREAM, 4))
	var title := Paper.label("CARTAS", 38, Paper.INK, Paper.display())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_top, title, Vector2(20, 10), Vector2(216, 62))
	title.pivot_offset = title.size * 0.5
	title.rotation = deg_to_rad(-2.0)
	_boss = _drawer(_top, _draw_boss, Vector2(245, 22), Vector2(186, 42))

	# seletor de herói
	_strip_bar = _add(_top, CutPanel.make(Rect2(448, 10, 450, 62), [[.02, 0], [1, .06], [.98, 1], [0, .92]], Paper.NAVY, 4))
	var hp := _arrow(-1)
	_add(_top, hp, Vector2(464, 19), Vector2(40, 44))
	hp.pressed.connect(func(): _switch(-1))
	var hn := _arrow(1)
	_add(_top, hn, Vector2(854, 19), Vector2(40, 44))
	hn.pressed.connect(func(): _switch(1))
	for id in ORDER:
		var t := HeroTile.new()
		t.hero = id
		_top.add_child(t)
		t.k = 0.0
		t.pressed.connect(func(): _go(t.hero, 1))
		_tiles[id] = t

	# voltar
	_drawer(_top, func(d: Draw): d.draw_colored_polygon(Paper.skew_rect(d.size, 12), Paper.INK), Vector2(1141, 21), Vector2(120, 40))
	var back := ShineButton.new()
	back.text = "VOLTAR"
	back.font_px = 15
	back.chevron = -1
	back.chevron_px = 14
	back.skew = 12
	back.fill = Paper.CREAM
	back.fill_hover = Paper.INK
	back.fg = Paper.INK
	back.fg_hover = Paper.CREAM
	_add(_top, back, Vector2(1136, 16), Vector2(120, 40))
	back.pressed.connect(func(): back_pressed.emit())
	# atalho pra tela SKILLS: etiqueta roxa pequena, inclinada pro outro lado, pendurada embaixo do VOLTAR
	_skills_btn = ShineButton.new()
	_skills_btn.text = "SKILLS"
	_skills_btn.font_px = 13
	_skills_btn.chevron = 1
	_skills_btn.chevron_px = 11
	_skills_btn.skew = -10
	_skills_btn.border = 3
	_skills_btn.shadow = Vector2(4, 5)
	_skills_btn.fill = Color("5B2BB8")
	_skills_btn.fill_hover = Paper.GOLD
	_skills_btn.fg = Paper.CREAM
	_skills_btn.fg_hover = Paper.INK
	_skills_btn.hover_scale = 1.1
	_skills_btn.idle = true
	_skills_btn.idle_every = 5.0
	_add(_top, _skills_btn, Vector2(1158, 66), Vector2(98, 32))
	_skills_btn.rotation = deg_to_rad(-3.0)
	_skills_btn.pressed.connect(func(): skills_pressed.emit(hero))

	# nome, classe e vida, colados sobre a arte
	_name_tag = Control.new()
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_top, _name_tag, Vector2(890, 382), Vector2(196, 58))
	_name_panel = _add(_name_tag, CutPanel.make(Rect2(0, 0, 196, 58), [[0, .08], [1, 0], [.96, 1], [.03, .92]], Paper.CREAM, 4, Vector2(8, 8)))
	_name_label = Paper.label("", 40, Paper.INK, Paper.display())
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_name_tag, _name_label, Vector2.ZERO, Vector2(196, 58))
	_name_label.rotation = deg_to_rad(-2.0)
	_role_tag = Tag.new()
	_role_tag.border = 3
	_role_tag.pad = 12
	_add(_top, _role_tag, Vector2(902, 446))
	_hp = _drawer(_top, _draw_hp, Vector2(1060, 446), Vector2(140, 28))

	# detalhes da carta
	_d_panel = _add(_top, CutPanel.make(Rect2(916, 480, 348, 142), [[.02, 0], [1, .05], [.97, 1], [0, .94]], Paper.CREAM, 5, Vector2(8, 8)))
	_d_tile =_drawer(_top, _draw_tile, Vector2(936, 496), Vector2(44, 44))
	_d_tile.pivot_offset = Vector2(22, 22)
	_d_tile.rotation = deg_to_rad(-6.0)
	_d_name = Paper.label("", 22, Paper.INK, Paper.display())
	_add(_top, _d_name, Vector2(992, 488), Vector2(260, 30))
	_d_kind = Tag.new()
	_d_kind.px = 11
	_add(_top, _d_kind, Vector2(994, 521))
	_d_cat = Tag.new()
	_d_cat.px = 11
	_add(_top, _d_cat, Vector2(1060, 521))
	_d_desc = Paper.label("", 16, Paper.INK, Paper.body(700))
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.add_theme_constant_override("line_spacing", -5)
	_add(_top, _d_desc, Vector2(938, 546), Vector2(306, 56))
	_d_hint = Paper.label("", 12, Color("5B2BB8"), Paper.body(700))
	_d_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_hint.add_theme_constant_override("line_spacing", -4)
	_add(_top, _d_hint, Vector2(938, 563), Vector2(312, 46))

	# READY FOR BATTLE
	var ready_shape := [[.03, .06], [1, 0], [.97, .92], [0, 1]]
	_ready_shadow = _drawer(_top, func(d: Draw): d.draw_colored_polygon(Paper.poly(d.size, ready_shape), Paper.INK), Vector2(942, 628), Vector2(330, 84))
	_ready_btn = ShineButton.new()
	_ready_btn.text = "READY FOR BATTLE"
	_ready_btn.font_px = 25
	_ready_btn.shape = ready_shape
	_ready_btn.border = 6
	_ready_btn.fill = Paper.GOLD
	_ready_btn.fill_hover = Paper.GOLD_HOVER
	_ready_btn.fg = Paper.INK
	_ready_btn.fg_hover = Paper.RED
	_ready_btn.text_rot = -3
	_ready_btn.idle = true
	_ready_btn.hover_scale = 1.05
	_add(_top, _ready_btn, Vector2(932, 618), Vector2(330, 84))
	_ready_btn.pressed.connect(func(): ready_pressed.emit())


func _arrow(dir: int) -> ShineButton:
	var b := ShineButton.new()
	b.chevron = dir
	return b


func _center() -> void:
	_stage.position = ((size - STAGE) * 0.5).floor()


# ---------------------------------------------------------------- desenho

func _draw_bg(d: Draw) -> void:
	# o fundo passa do palco pros lados, pra janelas mais largas que 16:9
	d.draw_rect(Rect2(-1200, -600, 3680, 1920), _th["bg"])
	var dot: Color = _th["bg2"]
	for iy in 36:
		for ix in 64:
			d.draw_circle(Vector2(ix * 20 + 10, iy * 20 + 10), 5.5, dot)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(760, 420), [[0, 0], [1, 0], [.62, .46], [.78, .62], [.3, 1], [0, .84]]), Vector2(-40, -40)), dot)
	d.draw_colored_polygon(Paper.moved(Paper.poly(Vector2(420, 220), [[0, .3], [.7, 0], [1, .22], [.4, .62], [0, 1]]), Vector2(-30, 300)), Paper.CREAM)
	d.draw_rect(Rect2(1280, -600, 1200, 1920), _th.get("stage", _th["deep"]))


func _disc(d: Draw, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for n in 240:
		pts.append(HUB + Vector2.from_angle(TAU * n / 240.0) * r)
	d.draw_colored_polygon(pts, col)


func _draw_wheel(d: Draw) -> void:
	_disc(d, RIM, Paper.INK)
	# arrastando uma carta equipada: o aro acende, a roleta é onde ela pode ser devolvida
	_disc(d, 666, Paper.GOLD if (_drag != null and _drag["src"] == "slot") else Paper.CREAM)
	_disc(d, 652, Paper.INK)
	_disc(d, 648, Paper.BROWN)
	_disc(d, 470, Paper.INK)
	_disc(d, 464, _th["deep"])


## Um losango por carta da mão, na cor da raridade (apagado = ainda não conquistada); o maior é a
## carta em foco. Mostra quantas cartas existem e onde você está, sem texto.
func _draw_pager(d: Draw) -> void:
	var n := _hand.size()
	if n <= 1:
		return
	var pitch := minf(13.0, 250.0 / (n - 1))
	for k in n:
		var id: String = _hand[k]
		var c := Vector2(HUB.x + (k - (n - 1) * 0.5) * pitch, 655.0)
		var col: Color = Paper.KIND[Knowledge.kind_of(id)]["bg"]
		if not Knowledge.is_owned_by(hero, id):
			col = Color(col.r, col.g, col.b, 0.3)
		var r := 6.5 if k == _focus else 3.5
		if k == _focus:
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r - 2.5), c + Vector2(r + 2.5, 0), c + Vector2(0, r + 2.5), c + Vector2(-r - 2.5, 0)]), Paper.CREAM)
			col.a = 1.0
		d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


func _draw_ticks(d: Draw) -> void:
	for n in range(-14, 70):
		d.draw_set_transform(Vector2.ZERO, deg_to_rad((n + 0.5) * STEP), Vector2.ONE)
		d.draw_rect(Rect2(-3, -666, 6, 14), Paper.INK)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pointer(d: Draw) -> void:
	d.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(44, 0), Vector2(22, 36)]), Paper.INK)
	d.draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(36, 4), Vector2(22, 27)]), Paper.GOLD)


func _draw_boss(d: Draw) -> void:
	var pts := Paper.skew_rect(d.size, 14)
	d.draw_colored_polygon(Paper.moved(pts, Vector2(5, 6)), Paper.INK)
	d.draw_colored_polygon(pts, Paper.INK)
	d.draw_colored_polygon(Paper.inset(pts, 3), Paper.PINK)
	var f := Paper.display()
	var nm: String = ("TREINO LIVRE" if Knowledge.practice else Knowledge.BOSS_INFO[Knowledge.boss]["name"]) if _show_ready else "GEAR"
	var vs := "VS" if _show_ready else ""
	var w1 := f.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var px := 17
	while px > 11 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + w1 + 30 > d.size.x:
		px -= 1
	var w2 := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var gap := 8.0 if vs != "" else 0.0
	var x := (d.size.x - w1 - gap - w2) * 0.5
	if vs != "":
		d.draw_string(f, Vector2(x, 26), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Paper.INK)
	d.draw_string(f, Vector2(x + w1 + gap, 27), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Paper.INK)


func _draw_hp(d: Draw) -> void:
	var h: Dictionary = Knowledge.HEROES[hero]
	var f := Paper.display()
	var num := str(h["hp"])
	var w := 24.0 + f.get_string_size("HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8 + 56 + 8 + f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	d.draw_colored_polygon(Paper.skew_rect(Vector2(w, 28), 12), Paper.INK)
	d.draw_string(f, Vector2(12, 19), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Paper.CREAM)
	var x := 12.0 + f.get_string_size("HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
	d.draw_rect(Rect2(x, 9, 56, 10), Paper.GREEN)
	d.draw_string(f, Vector2(x + 64, 20), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Paper.CREAM)


func _draw_tile(d: Draw) -> void:
	if _detail_id == "":
		return
	var c: Dictionary = Knowledge.CARDS[_detail_id]
	d.draw_rect(Rect2(Vector2.ZERO, d.size), Paper.INK)
	d.draw_rect(Rect2(3, 3, 38, 38), Paper.KIND[c["kind"]]["bg"])
	Paper.draw_suit(d, c["cat"], Vector2(9, 9), 26, Paper.INK)


# ---------------------------------------------------------------- seletor de herói

## Lugares do seletor: 0 é a placa aberta (herói atual), 1 a 4 são os rostos, da esquerda pra direita.
const TILE_X := [512.0, 684.0, 726.0, 768.0, 810.0]
const TILE_ROT := [-2.0, 3.0, -3.0, 2.0, -2.0]


func _tile_pos(slot: int) -> Vector2:
	return Vector2(TILE_X[slot], 12.0 if slot == 0 else 17.0)


## Põe cada herói no lugar dele na fila. Na troca:
##   - a placa do atual retrai e some (fade);
##   - o escolhido vai pra frente já abrindo com o nome, tudo num movimento só;
##   - o antigo reaparece inserido na fila, e os rostos vizinhos são empurrados pra dar lugar.
func _layout_tiles(animate: bool) -> void:
	if _row.is_empty():
		_row = [hero]
		for id in ORDER:
			if id != hero:
				_row.append(id)
	for n in _row.size():
		var id: int = _row[n]
		var t: HeroTile = _tiles[id]
		var was := t.slot
		t.slot = n
		t.dim = false
		# Trocas em sequência rápida interrompem a animação anterior no meio: a peça pode estar em
		# qualquer lugar, meio aberta, pequena ou transparente. Por isso cada caminho abaixo parte do
		# estado em que ela ESTÁ e leva todas as propriedades (posição, giro, escala, alfa, abertura)
		# até o valor final do lugar novo; nenhum deixa algo "como estava".
		if t.tw != null:
			t.tw.kill()
			t.tw = null
		t.stop_hover()
		var pos := _tile_pos(n)
		var rot := deg_to_rad(TILE_ROT[n])
		var settled: bool = was == n and t.position.is_equal_approx(pos) and is_equal_approx(t.k, 1.0 if n == 0 else 0.0) \
				and t.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(t.modulate.a, 1.0)
		if not animate or was < 0 or settled:
			t.position = pos
			t.rotation = rot
			t.scale = Vector2.ONE
			t.modulate.a = 1.0
			t.z_index = 0
			t.k = 1.0 if n == 0 else 0.0
			continue
		var tw := t.create_tween()
		t.tw = tw
		if n == 0:
			# escolhido: corre pra frente e abre no caminho
			t.z_index = 3
			tw.set_parallel(true)
			tw.tween_property(t, "position", pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "rotation", rot, 0.3)
			tw.tween_property(t, "scale", Vector2.ONE, 0.12)
			tw.tween_property(t, "modulate:a", 1.0, 0.1)
			tw.tween_property(t, "k", 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_callback(_tile_done.bind(t, n))
		elif was == 0 and t.modulate.a > 0.05:
			# antigo: retrai e some onde está; reaparece crescendo no lugar novo da fila
			t.z_index = 1
			tw.tween_property(t, "k", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(t, "modulate:a", 0.0, 0.14)
			tw.tween_callback(func():
				t.position = pos
				t.rotation = rot
				t.k = 0.0
				t.scale = Vector2.ONE * 0.4)
			tw.tween_interval(0.06)
			tw.tween_property(t, "modulate:a", 1.0, 0.14)
			tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_tile_done.bind(t, n))
		elif t.modulate.a <= 0.05:
			# estava invisível (interrompida no meio do sumiço): só reaparece no lugar certo
			t.z_index = 0
			t.position = pos
			t.rotation = rot
			t.k = 0.0
			t.scale = Vector2.ONE * 0.4
			tw.tween_property(t, "modulate:a", 1.0, 0.14)
			tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_tile_done.bind(t, n))
		else:
			# vizinhos: empurrados pelo antigo entrando, um depois do outro a partir de onde ele entrou.
			# Se a peça ficou meio aberta, pequena ou apagada de uma troca interrompida, conserta já.
			t.z_index = 0
			tw.set_parallel(true)
			tw.tween_property(t, "k", 0.0, 0.12)
			tw.tween_property(t, "scale", Vector2.ONE, 0.12)
			tw.tween_property(t, "modulate:a", 1.0, 0.1)
			var wait := 0.2 + absi(n - _push_at) * 0.04
			tw.tween_property(t, "position", pos, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(wait)
			tw.tween_property(t, "rotation", rot, 0.26).set_delay(wait)
			tw.chain().tween_callback(_tile_done.bind(t, n))


## Fim da animação de uma peça: crava o estado final, pra nenhum resto de arredondamento ou de
## animação interrompida sobrar.
func _tile_done(t: HeroTile, n: int) -> void:
	t.position = _tile_pos(n)
	t.rotation = deg_to_rad(TILE_ROT[n])
	t.scale = Vector2.ONE
	t.modulate.a = 1.0
	t.k = 1.0 if n == 0 else 0.0
	t.z_index = 0
	t.tw = null


# ---------------------------------------------------------------- cartas

## Mostra na carta o papel dela: APRENDIZADO tem a barrinha (o quanto este herói já aprendeu);
## CRITÉRIO tem a etiqueta, e nunca vira passiva.
func _mark_role(cv: CardView, id: String) -> void:
	if id == "" or not Knowledge.CARDS.has(id):
		return
	match Knowledge.role(id):
		"learn": cv.learn = Knowledge.learn_progress(hero, id)
		"pref": cv.tag = "CRITÉRIO"


## Cartas do herói que não estão equipadas, e depois as que ele ainda não tem (de verso, com a maestria).
func _hand_list() -> Array:
	var out: Array = []
	for id in Knowledge.inventory(hero):
		out.append(id)
	if not tutor.is_empty():
		return out  # aula: só o que o jogador já ganhou, sem as cartas "?"
	for kind in Knowledge.KINDS:
		for id in Knowledge.CARDS:
			if Knowledge.CARDS[id]["kind"] == kind and not Knowledge.GEAR_IDS.has(id) and Knowledge.usable(hero, id) and not Knowledge.is_owned_by(hero, id):
				out.append(id)
	return out


## Depois de mexer nos slots: mantém a ordem da roleta, tira o que foi equipado e põe no fim o que faltar.
func _sync_hand() -> void:
	var want := _hand_list()
	var out: Array = []
	for id in _hand:
		if want.has(id) and not out.has(id):
			out.append(id)
	for id in want:
		if not out.has(id):
			out.append(id)
	_hand = out
	_focus = clampi(_focus, 0, maxi(0, _hand.size() - 1))


func _build_cards(deal := false, drop := "") -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_slots.clear()
	_spokes.clear()
	_peek = null
	var deck := Knowledge.deck(hero)
	for kind in Knowledge.KINDS:
		for n in Knowledge.SLOTS[kind]:
			var id: String = deck[kind][n]
			var cv := CardView.make(id) if id != "" else CardView.empty(kind)
			_mark_role(cv, id)
			cv.position = SLOT_AT[kind][n]
			_cards.add_child(cv)
			var idx := _slots.size()
			var info := {"cv": cv, "src": "slot", "idx": idx, "n": n, "id": id, "kind": kind, "home": cv.position,
				"rot0": 3.0 if kind == "item" else 0.0, "hover": false, "press": false, "drag_ok": id != "", "alt": idx % 2 == 1, "tw": null, "spoke": null}
			_slots.append(info)
			if id != "":
				_wire(info)
			else:
				cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in _hand.size():
		var id: String = _hand[k]
		var mine := Knowledge.is_owned_by(hero, id)
		var spoke := Control.new()
		spoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spoke.position = HUB
		spoke.rotation = deg_to_rad((k - _focus) * STEP)
		_cards.add_child(spoke)
		var cv := CardView.make(id, "face" if mine else "back")
		if mine:
			_mark_role(cv, id)
		cv.fresh = mine and Knowledge.is_new(hero, id)
		if not mine:
			var key := Knowledge.mastery_key(id)
			if key != "":
				cv.progress = Knowledge.mastery_of(key)
		elif Knowledge.is_unique(id):
			# cópia única (item ou carta da loja): o selo mostra com quem está; arrastar pra cá tira de lá
			var holder := Knowledge.holder(id)
			if holder >= 0 and holder != hero:
				cv.badge = load("res://assets/portraits/%s_face.png" % Knowledge.HEROES[holder]["key"])
		cv.position = Vector2(-CARD_HALF.x, -RADIUS - CARD_HALF.y)
		spoke.add_child(cv)
		var info := {"cv": cv, "src": "hand", "idx": k, "n": k, "id": id, "kind": Knowledge.kind_of(id), "home": cv.position,
			"rot0": 0.0, "hover": false, "press": false, "drag_ok": mine, "alt": k % 2 == 1, "tw": null, "spoke": spoke}
		_spokes.append(info)
		_wire(info)
	for info in _slots + _spokes:
		_settle(info, true)
	if deal:
		for info in _slots:
			if info["id"] != "":
				_deal(info, info["idx"] * 0.045)
		for info in _spokes:
			# só as que aparecem na tela, abrindo a partir da carta em foco
			var far := absi(info["idx"] - _focus)
			if far <= 4:
				_deal(info, 0.16 + far * 0.045)
	if drop != "":
		# a carta que acabou de encaixar chega maior e inclinada e assenta
		var list: Array = _slots if drop.begins_with("s") else _spokes
		var at := int(drop.substr(1))
		if at < list.size():
			var cv: CardView = list[at]["cv"]
			cv.scale *= 1.35
			cv.rotation += deg_to_rad(8.0)
			_settle(list[at], false, 0.35)
	_update_details()


func _wire(info: Dictionary) -> void:
	var cv: CardView = info["cv"]
	cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if info["drag_ok"] else Control.CURSOR_ARROW
	cv.mouse_entered.connect(func():
		if cv.fresh:
			# o jogador achou a carta nova: o selo some dela e, se era a última, do rosto do herói
			Knowledge.see_new(hero, info["id"])
			cv.fresh = false
			_mark_new()
		info["hover"] = true
		_peek = info
		_settle(info)
		_update_details())
	cv.mouse_exited.connect(func():
		info["hover"] = false
		if _peek != null and is_same(_peek, info):
			_peek = null
			_update_details()
		_settle(info))
	cv.gui_input.connect(func(e: InputEvent):
		if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed):
			return
		if e.double_click:
			_quick(info)
			return
		_pend = {"info": info, "start": _mouse_at, "shook": false}
		info["press"] = true
		_settle(info))


## Liga ou desliga o aviso de carta nova no rosto de cada herói do seletor.
func _mark_new() -> void:
	for id in _tiles:
		_tiles[id].fresh = tutor.is_empty() and Knowledge.has_new(id)


## Duplo clique, o atalho do arrasto: carta da roleta vai pro primeiro slot livre do tipo dela;
## carta equipada volta pra roleta.
func _quick(info: Dictionary) -> void:
	_cancel_drag()
	if not tutor.is_empty():
		_shake(info)  # na aula a carta vai arrastada, que é o gesto sendo ensinado
		return
	var drop := ""
	if info["src"] == "slot":
		drop = _unequip_to_hand(info["id"])
	elif info["drag_ok"]:
		for s in _slots:
			if s["kind"] == info["kind"] and s["id"] == "":
				drop = _equip_from_hand(info["idx"], s["idx"])
				break
	if drop == "":
		_shake(info)
		return
	_sel = -1
	Knowledge.save()
	_sync_hand()
	_build_cards(false, drop)


func _unequip_to_hand(id: String) -> String:
	Knowledge.unequip(hero, id)
	_hand.insert(mini(_focus, _hand.size()), id)
	return "h%d" % _focus


## "Não dá": a carta balança no lugar (sem slot livre, ou carta que ainda não é sua).
func _shake(info: Dictionary) -> void:
	var cv: CardView = info["cv"]
	if info["tw"] != null:
		info["tw"].kill()
	var home: Vector2 = info["home"]
	var tw := cv.create_tween()
	for dx in [7.0, -7.0, 4.0, -4.0, 0.0]:
		tw.tween_property(cv, "position:x", home.x + dx, 0.04)
	tw.tween_callback(func(): _settle(info))
	info["tw"] = tw


## Escala, giro (graus) e deslocamento vertical que a carta deve ter agora.
func _pose(info: Dictionary) -> Array:
	var sc := 1.0
	var rot := 0.0
	var dy := 0.0
	var focus: bool = info["src"] == "hand" and info["idx"] == _focus and _sel < 0
	if focus:
		sc = 1.15
		dy = -14.0
	if info["src"] == "slot" and info["idx"] == _sel:
		sc = 1.06
	if info["hover"] and _drag == null and info["id"] != "":
		if focus:
			sc = 1.2
			rot = 2.0
			dy = -18.0
		else:
			sc = 1.09
			rot = 3.0 if info["alt"] else -3.0
			dy = -12.0
	if info["press"] and _drag == null:
		sc = 1.02
	if info["src"] == "slot" and info["idx"] == _over:
		sc = 1.1
	return [sc, rot, dy]


## Leva a carta pra pose dela e atualiza moldura, contorno e ordem de desenho.
func _settle(info: Dictionary, snap := false, time := 0.22) -> void:
	var cv: CardView = info["cv"]
	if not is_instance_valid(cv):
		return
	var p := _pose(info)
	var sc := Vector2.ONE * float(p[0])
	var rot := deg_to_rad(float(info["rot0"]) + float(p[1]))
	var pos: Vector2 = info["home"] + Vector2(0, p[2])
	var lifted: bool = (_drag != null and is_same(_drag, info)) or info.get("away", false)
	var hand: bool = info["src"] == "hand"
	cv.halo = hand and info["idx"] == _focus and _sel < 0
	if info["src"] == "slot":
		if _drag != null and not lifted and info["kind"] == _drag["kind"]:
			var on: bool = info["idx"] == _over
			cv.ring = Paper.GOLD if on else Paper.CREAM
			cv.ring_w = 6.0 if on else 4.0
			if on:
				cv.ring_gap = 4.0
		elif info["idx"] == _sel and _drag == null:
			cv.ring = Paper.GOLD
			cv.ring_w = 5.0
			cv.ring_gap = 3.0
		else:
			cv.ring = Color(0, 0, 0, 0)
	var z := 9 if (info["hover"] and _drag == null) else (5 if cv.halo or (hand and info["idx"] == _focus) else (2 if hand else 0))
	if hand:
		info["spoke"].z_index = z
	else:
		cv.z_index = z
	if info["tw"] != null:
		info["tw"].kill()
		info["tw"] = null
	if snap:
		cv.scale = sc
		cv.rotation = rot
		cv.position = pos
		cv.modulate.a = 0.25 if lifted else 1.0
		return
	var tw := cv.create_tween().set_parallel(true)
	tw.tween_property(cv, "scale", sc, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation", rot, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "position", pos, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "modulate:a", 0.25 if lifted else 1.0, 0.15)
	info["tw"] = tw


## Entrada: a carta sobe de baixo, pequena e transparente, e assenta. Cada uma com seu atraso.
func _deal(info: Dictionary, delay: float) -> void:
	var cv: CardView = info["cv"]
	var sc := cv.scale
	var pos := cv.position
	cv.scale = sc * 0.7
	cv.position = pos + Vector2(0, 40)
	cv.modulate.a = 0.0
	var tw := cv.create_tween().set_parallel(true)
	tw.tween_property(cv, "scale", sc, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(cv, "position", pos, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(cv, "modulate:a", 1.0, 0.2).set_delay(delay)
	info["tw"] = tw


func _settle_all() -> void:
	for info in _slots + _spokes:
		_settle(info)


# ---------------------------------------------------------------- roleta

func _spin(dir: int) -> void:
	_set_focus(_focus + dir)


func _set_focus(k: int) -> void:
	_focus = clampi(k, 0, maxi(0, _hand.size() - 1))
	_sel = -1
	for info in _spokes:
		var sp: Control = info["spoke"]
		# girar de novo antes de parar: o giro anterior é cancelado, senão os dois brigam pelo mesmo raio
		if info.get("spin") != null:
			info["spin"].kill()
		var tw := sp.create_tween()
		info["spin"] = tw
		# passa um pouco do ponto e volta, como roleta parando
		tw.tween_property(sp, "rotation", deg_to_rad((info["idx"] - _focus) * STEP), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _ticks_tw != null:
		_ticks_tw.kill()
	_ticks_tw = _ticks.create_tween()
	_ticks_tw.tween_property(_ticks, "rotation", deg_to_rad(-_focus * STEP), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_settle_all()
	_update_details()


# ---------------------------------------------------------------- arrastar e soltar

func _slot_at(p: Vector2) -> int:
	for info in _slots:
		if Rect2(info["home"] - Vector2(8, 8), Vector2(CardView.W + 16, CardView.H + 16)).has_point(p):
			return info["idx"]
	return -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouse:
		# posição do ponteiro em coordenadas do palco 1280x720
		_mouse_at = _stage.get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseButton and event.pressed and _pend == null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_spin(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_spin(1)
	if _pend == null:
		return
	var info: Dictionary = _pend["info"]
	if event is InputEventMouseMotion:
		var p := _mouse_at
		if _drag == null and p.distance_to(_pend["start"]) > 6.0:
			if info["drag_ok"]:
				_start_drag(info)
			elif not _pend["shook"]:
				_pend["shook"] = true
				_shake(info)
		if _drag != null:
			_ghost.position = p - CARD_HALF
			var si := _slot_at(p)
			var ok: bool = si >= 0 and _slots[si]["kind"] == info["kind"] and not is_same(_slots[si], info)
			var over := si if ok else -1
			if over != _over:
				_over = over
				for s in _slots:
					_settle(s)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish()


func _start_drag(info: Dictionary) -> void:
	_drag = info
	info["hover"] = false
	_ghost = CardView.make(info["id"])
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.scale = Vector2.ONE * 1.15
	_ghost.rotation = deg_to_rad(7.0)
	_ghost.z_index = 50
	_top.add_child(_ghost)
	_ghost.position = _mouse_at - CARD_HALF
	_wheel.queue_redraw()
	_settle_all()
	_update_details()


func _cancel_drag() -> void:
	if _pend != null:
		_pend["info"]["press"] = false
	_pend = null
	_drag = null
	_over = -1
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_wheel.queue_redraw()


func _finish() -> void:
	var info: Dictionary = _pend["info"]
	var dragged: bool = _drag != null
	var p := _mouse_at
	# o fantasma sobrevive ao fim do arrasto: se a carta não encaixou, é ele que voa de volta
	var ghost := _ghost
	_ghost = null
	_cancel_drag()
	if not dragged:
		# clique simples: carta da roleta vem pro foco; carta equipada mostra os detalhes
		if info["src"] == "hand":
			_set_focus(info["idx"])
		else:
			_sel = info["idx"]
			_settle_all()
			_update_details()
		return
	var id: String = info["id"]
	var si := _slot_at(p)
	var drop := ""
	if si >= 0 and _slots[si]["kind"] == info["kind"]:
		if info["src"] == "hand":
			drop = _equip_from_hand(info["idx"], si)
		elif si != info["idx"]:
			var arr: Array = Knowledge.deck(hero)[info["kind"]]
			var a: int = info["n"]
			var b: int = _slots[si]["n"]
			arr[a] = arr[b]
			arr[b] = id
			drop = "s%d" % si
	elif info["src"] == "slot" and p.distance_to(HUB) < RIM:
		# de volta pra roleta: a carta entra na mão já em foco
		drop = _unequip_to_hand(id)
	_sel = -1
	if drop == "":
		_fly_back(ghost, info)
		return
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	Knowledge.save()
	_sync_hand()
	_build_cards(false, drop)
	deck_changed.emit()


## Soltou num lugar que não vale: a carta volta voando pra onde estava, em vez de sumir.
func _fly_back(ghost: CardView, info: Dictionary) -> void:
	var cv: CardView = info["cv"]
	if ghost == null or not is_instance_valid(ghost) or not is_instance_valid(cv):
		_settle_all()
		return
	info["away"] = true
	_settle_all()
	var to_stage := _stage.get_global_transform().affine_inverse()
	var center: Vector2 = to_stage * (cv.get_global_transform() * CARD_HALF)
	var rot: float = cv.rotation
	if info["spoke"] != null:
		rot += float(info["spoke"].rotation)
	var tw := ghost.create_tween().set_parallel(true)
	tw.tween_property(ghost, "position", center - CARD_HALF, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "rotation", rot, 0.2)
	tw.tween_property(ghost, "scale", cv.scale, 0.2)
	tw.chain().tween_callback(func():
		ghost.queue_free()
		info["away"] = false
		if is_instance_valid(cv):
			_settle(info))


## Roleta -> slot. Se o slot estava ocupado, a carta antiga volta pro mesmo lugar da mão.
func _equip_from_hand(k: int, si: int) -> String:
	var id: String = _hand[k]
	var old: String = _slots[si]["id"]
	if not Knowledge.equip(hero, id, _slots[si]["n"]):
		return ""
	if old != "":
		_hand[k] = old
		_focus = k
	else:
		_hand.remove_at(k)
		if _focus > k:
			_focus -= 1
	return "s%d" % si


## Atalhos usados pelos testes (ui/tests/shot.gd): o mesmo efeito de soltar a carta.
func _drop_slot(kind: String, n: int, data) -> void:
	var id: String = data["card"]
	var arr: Array = Knowledge.deck(hero)[kind]
	if data["from"] == "slot":
		var src := arr.find(id)
		if src >= 0 and src != n:
			arr[src] = arr[n]
			arr[n] = id
	else:
		Knowledge.equip(hero, id, n)
	Knowledge.save()
	_sync_hand()
	_build_cards()


func _drop_hand(_at: Vector2, data) -> void:
	Knowledge.unequip(hero, data["card"])
	Knowledge.save()
	_sync_hand()
	_build_cards()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and _drag != null:
		_cancel_drag()
		_build_cards()


# ---------------------------------------------------------------- detalhes

func _update_details() -> void:
	var id := ""
	var mine := true
	if _peek != null and _drag == null and _peek["id"] != "":
		id = _peek["id"]
		mine = _peek["src"] == "slot" or Knowledge.is_owned_by(hero, id)
	elif _sel >= 0 and _sel < _slots.size() and _slots[_sel]["id"] != "":
		id = _slots[_sel]["id"]
	elif _focus < _hand.size():
		id = _hand[_focus]
		mine = Knowledge.is_owned_by(hero, id)
	_detail_id = id
	_d_tile.queue_redraw()
	_pager.queue_redraw()
	# setas da roleta apagadas nas pontas
	for pair in [[_spin_prev, _focus > 0], [_spin_next, _focus < _hand.size() - 1]]:
		pair[0].disabled = not pair[1]
		pair[0].modulate.a = 1.0 if pair[1] else 0.35
	_d_kind.visible = id != ""
	_d_cat.visible = id != ""
	if not tutor.is_empty():
		# aula: sem carta pra mostrar (todas já foram pro baralho), o painel de detalhes some
		for n in [_d_panel, _d_tile, _d_name, _d_desc]:
			n.visible = id != ""
	_d_hint.text = ""
	if id == "":
		_d_name.text = ""
		_d_desc.text = ""
		return
	var c: Dictionary = Knowledge.CARDS[id]
	var k: Dictionary = Paper.KIND[c["kind"]]
	var nm := String(c["name"]).to_upper() if mine else "???"
	var px := 22
	while px > 13 and Paper.display().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 258.0:
		px -= 1
	_d_name.text = nm
	_d_name.add_theme_font_size_override("font_size", px)
	_d_kind.text = String(Knowledge.KIND_NAME[c["kind"]]).to_upper()
	_d_kind.bg = k["chip"]
	_d_kind.fg = k["chip_t"]
	_d_kind.fit(20)
	var key := Knowledge.mastery_key(id)
	if mine or key == "":
		_d_cat.text = String(Knowledge.CAT_NAME[c["cat"]]).to_upper()
	else:
		_d_cat.text = "MAESTRIA %d/%d" % [Knowledge.mastery_of(key), Knowledge.MASTERY_NEED]
	_d_cat.fit(20)
	_d_cat.position.x = _d_kind.position.x + _d_kind.size.x + 8.0
	if mine:
		_d_desc.text = c["desc"]
	else:
		# carta desconhecida: o nome fica "???"; no lugar da descrição, um mistério e uma pista
		_d_desc.text = Knowledge.mystery(id)
		_d_hint.text = Knowledge.hint(id)
	_d_desc.add_theme_font_size_override("font_size", 16 if mine else 14)


# ---------------------------------------------------------------- movimento parado

func _wave(period: float) -> float:
	return 0.5 - 0.5 * cos(TAU * _t / period)


func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree():
		return
	_t += delta
	# arte: sobe e desce 20 px com um balanço leve, girando a partir da base
	var k := _wave(3.6)
	_art.position.y = _art_home.y + lerpf(6.0, -14.0, k)
	_art.rotation = deg_to_rad(lerpf(-1.0, 1.4, k))
	k = _wave(3.4)
	_bubble.position.y = 62.0 - 5.0 * k
	_bubble.rotation = deg_to_rad(-1.5 * k)
	k = _wave(5.2)
	_name_tag.position.y = 382.0 - 5.0 * k
	_name_tag.rotation = deg_to_rad(-1.5 * k)
	# faixas do palco deslizando, cada uma no seu ritmo
	var periods := [14.0, 18.0, 11.0]
	for i in _stripes.size():
		var s: CutPanel = _stripes[i]
		s.position = s.get_meta("home") + Vector2(-10, 4).lerp(Vector2(12, -5), _wave(periods[i]))
	_pointer.position.y = 398.0 + 5.0 * _wave(1.0)
	if _focus < _spokes.size():
		_spokes[_focus]["cv"].halo_grow = 3.0 * _wave(1.1)
	if _drag != null:
		# slots válidos: o contorno respira
		for s in _slots:
			if not is_same(s, _drag) and s["kind"] == _drag["kind"] and s["idx"] != _over:
				s["cv"].ring_gap = 4.0 + 5.0 * _wave(0.7)
	if not tutor.is_empty():
		_tutor_fx()


## Aula: a carta em destaque brilha e saltita na roleta; arrastando ela, os slots que servem acendem.
func _tutor_fx() -> void:
	var want: String = tutor.get("card", "")
	var held: bool = _drag != null and _drag["id"] == want
	for info in _spokes:
		if info["id"] != want:
			continue
		var cv: CardView = info["cv"]
		cv.halo = true
		cv.halo_grow = 4.0 + 5.0 * _wave(0.6)
		var busy: bool = info["tw"] != null and info["tw"].is_running()
		if not held and not busy and not info["hover"] and not info["press"] and not info.get("away", false):
			var hop := absf(sin(_t * 5.0)) * 14.0
			cv.position.y = float(info["home"].y) + float(_pose(info)[2]) - hop
			cv.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.0), _wave(0.6))
	for s in _slots:
		var lit: bool = held and s["kind"] == _drag["kind"] and s["id"] == ""
		s["cv"].modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.7, 1.6, 1.1), _wave(0.5)) if lit else Color(1, 1, 1)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not tutor.is_empty():
		# aula: só gira a roleta; trocar de herói, sair e lutar ficam com quem ensina
		match event.physical_keycode:
			KEY_Q: _spin(-1)
			KEY_E: _spin(1)
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT: _switch(-1)
		KEY_D, KEY_RIGHT: _switch(1)
		KEY_Q: _spin(-1)
		KEY_E: _spin(1)
		KEY_ENTER, KEY_KP_ENTER:
			if _show_ready:
				ready_pressed.emit()
		KEY_ESCAPE: back_pressed.emit()
