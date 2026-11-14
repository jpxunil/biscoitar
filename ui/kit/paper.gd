class_name Paper
## Kit da tela de cartas (design em design/tela-cartas-v2): papel recortado, contorno grosso,
## sombra dura e tema de cor por herói. As cores de raridade são fixas; só cenário e painéis mudam.

const INK := Color(0.071, 0.078, 0.161)
const NAVY := Color(0.118, 0.141, 0.376)
const CREAM := Color(0.969, 0.945, 0.863)
const CREAM2 := Color(0.902, 0.851, 0.706)
const GOLD := Color(1.0, 0.8, 0.251)
const GOLD_HOVER := Color(1.0, 0.894, 0.541)
const BROWN := Color(0.42, 0.247, 0.133)
const CYAN := Color(0.302, 0.902, 1.0)
const PINK := Color(1.0, 0.349, 0.6)
const GREEN := Color(0.329, 0.871, 0.522)
const RED := Color(0.69, 0.094, 0.094)

## Tema por herói: bg/bg2 = fundo e recortes · deep/deep2 = painéis · acc = destaque (acc_t = texto em cima).
## Opcionais: stage = fundo atrás da arte (padrão: deep) · stripe3 = terceira faixa do palco (padrão: creme).
static var THEMES := {
	"tank": {"bg": Color("2b4fbf"), "bg2": Color("4d80ff"), "deep": Color("121a4a"), "deep2": Color("1e2a6e"), "acc": Color("ffcc40"), "acc_t": Color("121429")},
	"healer": {"bg": Color("1f8a4c"), "bg2": Color("3fb86b"), "deep": Color("0e3320"), "deep2": Color("175030"), "acc": Color("ffcc40"), "acc_t": Color("121429")},
	"assassina": {"bg": Color("5b2bb8"), "bg2": Color("7a3fe0"), "deep": Color("1e2460"), "deep2": Color("2b3384"), "acc": Color("ff5999"), "acc_t": Color("121429")},
	"maga": {"bg": Color("e08a14"), "bg2": Color("ffc233"), "deep": Color("2b1509"), "deep2": Color("4a2612"), "acc": Color("c4201c"), "acc_t": Color("f7f1dc")},
	"burner": {"bg": Color("d9622a"), "bg2": Color("ff9a4d"), "deep": Color("2b1206"), "deep2": Color("4a2010"), "acc": Color("3ff2e0"), "acc_t": Color("121429")},
	"ringstar": {"bg": Color("d9408f"), "bg2": Color("ff73be"), "deep": Color("2a0f3a"), "deep2": Color("45195c"), "acc": Color("4fb8ff"), "acc_t": Color("121429")},
	"apothecary": {"bg": Color("2f7a5c"), "bg2": Color("46a082"), "deep": Color("0c2018"), "deep2": Color("163a2c"), "acc": Color("4cff5a"), "acc_t": Color("121429")},
	"sleepwalker": {"bg": Color("5a5fc8"), "bg2": Color("8a8ff0"), "deep": Color("191a45"), "deep2": Color("2a2c6b"), "acc": Color("ffc8e6"), "acc_t": Color("121429")},
	# Gothic Nurse: azul-marinho, preto e branco, com o vermelho do sangue como destaque.
	# `stage` (fundo atrás da arte) é claro porque a personagem é escura; `stripe3` é a terceira faixa.
	"nurse": {"bg": Color("3a46b8"), "bg2": Color("5566e0"), "deep": Color("0e1030"), "deep2": Color("1a1e52"), "acc": Color("c0183a"), "acc_t": Color("f7f1dc"), "stage": Color("d9dcf5"), "stripe3": Color("0e1030")},
}

## Cores da carta por raridade: bg = corpo · art/st = janela e faixas · eb/eg = slot vazio · chip = etiqueta.
static var KIND := {
	"purple": {"bg": Color("9e5cff"), "art": Color("7a3fe0"), "st": Color("5b2bb8"), "eb": Color("2e1766"), "eg": Color("5b2bb8"), "chip": Color("5b2bb8"), "chip_t": Color("f7f1dc")},
	"gold": {"bg": Color("ffcc40"), "art": Color("f2a91e"), "st": Color("c9871a"), "eb": Color("4a2e12"), "eg": Color("8a5a1e"), "chip": Color("ffcc40"), "chip_t": Color("121429")},
	"white": {"bg": Color("f7f1dc"), "art": Color("e6d9b4"), "st": Color("cdbb8a"), "eb": Color("4d4636"), "eg": Color("8c7f5c"), "chip": Color("4d4636"), "chip_t": Color("f7f1dc")},
	"item": {"bg": Color("4de6ff"), "art": Color("35c4e6"), "st": Color("1e9fc0"), "eb": Color("123a4a"), "eg": Color("1e9fc0"), "chip": Color("4de6ff"), "chip_t": Color("121429")},
}

const FONT_DISPLAY := "res://assets/fonts/BowlbyOne-Regular.ttf"
const FONT_BODY := "res://assets/fonts/Baloo2.ttf"

static var _fonts := {}


## Letra de título (Bowlby One). Sem o arquivo da fonte, cai na fonte padrão engrossada.
static func display(slant := 0.18) -> Font:
	var key := "d%.2f" % slant
	if not _fonts.has(key):
		var f := FontVariation.new()
		if ResourceLoader.exists(FONT_DISPLAY):
			f.base_font = load(FONT_DISPLAY)
		else:
			f.base_font = ThemeDB.fallback_font
			f.variation_embolden = 1.0
		f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-slant, 1), Vector2.ZERO)
		_fonts[key] = f
	return _fonts[key]


## Letra de corpo (Baloo 2, peso 500 a 800).
static func body(weight := 700) -> Font:
	var key := "b%d" % weight
	if not _fonts.has(key):
		var f := FontVariation.new()
		if ResourceLoader.exists(FONT_BODY):
			f.base_font = load(FONT_BODY)
			f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		else:
			f.base_font = ThemeDB.fallback_font
			f.variation_embolden = clampf((weight - 400) / 500.0, 0.0, 0.8)
		_fonts[key] = f
	return _fonts[key]


static func label(text: String, px: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Polígono a partir de frações (0..1) do tamanho. Ex.: [[0, .04], [1, 0], [.98, 1], [.02, .96]].
static func poly(size: Vector2, fr: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in fr:
		pts.append(Vector2(p[0] * size.x, p[1] * size.y))
	return pts


## Retângulo inclinado (o topo vai pra direita), como o skewX(-deg) do mockup.
static func skew_rect(size: Vector2, deg: float) -> PackedVector2Array:
	var d := tan(deg_to_rad(deg)) * size.y * 0.5
	return PackedVector2Array([Vector2(d, 0), Vector2(size.x + d, 0), Vector2(size.x - d, size.y), Vector2(-d, size.y)])


## O mesmo polígono, encolhido px pra dentro (pra desenhar contorno + miolo).
static func inset(pts: PackedVector2Array, px: float) -> PackedVector2Array:
	if px <= 0.0:
		return pts
	var out := Geometry2D.offset_polygon(pts, -px, Geometry2D.JOIN_MITER)
	return out[0] if out.size() > 0 else pts


static func moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


## Naipe da categoria, desenhado numa caixa de lado `side` com o canto em `at`.
static func draw_suit(ci: CanvasItem, cat: String, at: Vector2, side: float, col: Color) -> void:
	var k := side / 24.0
	var raw: Array
	match cat:
		"attack":
			raw = [[12, 1], [16, 7], [16, 15], [20, 15], [20, 18], [14, 18], [14, 23], [10, 23], [10, 18], [4, 18], [4, 15], [8, 15], [8, 7]]
		"defense":
			raw = [[3, 3], [21, 3], [21, 12], [20, 16.5], [17, 20], [12, 23], [7, 20], [4, 16.5], [3, 12]]
		"utility":
			ci.draw_arc(at + Vector2(12, 12) * k, 7.0 * k, 0.0, TAU, 40, col, 6.0 * k, true)
			return
		_:
			raw = [[12, 1], [15, 9], [23, 12], [15, 15], [12, 23], [9, 15], [1, 12], [9, 9]]
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(at + Vector2(p[0], p[1]) * k)
	ci.draw_colored_polygon(pts, col)
