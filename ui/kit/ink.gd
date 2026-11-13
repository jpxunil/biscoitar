@tool
class_name Ink
## Kit visual dos menus (título, bosses, cartas, loja): cara de tinta e papel recortado.
## Painéis de contorno grosso e formato irregular, sombra dura, letra grande inclinada.
## Paleta: roxo, azul-escuro, creme e marrom. As cores de significado continuam as de UiStyle.

const NIGHT := Color(0.075, 0.07, 0.16)
const NAVY := Color(0.13, 0.13, 0.3)
const GRAPE := Color(0.42, 0.22, 0.86)
const VIOLET := Color(0.62, 0.36, 1.0)
const CREAM := Color(0.97, 0.94, 0.84)
const BROWN := Color(0.36, 0.22, 0.16)
const TAN := Color(0.78, 0.6, 0.4)
const OUT := Color(0.05, 0.045, 0.1)
const COIN := Color(1.0, 0.8, 0.25)
const TICKET := Color(0.75, 0.5, 1.0)

static var _fonts := {}


## Letra de título: negrito e inclinada, feita a partir da fonte padrão.
static func font(slant := 0.2, bold := 0.9) -> FontVariation:
	var key := "%.2f_%.2f" % [slant, bold]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = bold
		f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-slant, 1), Vector2.ZERO)
		_fonts[key] = f
	return _fonts[key]


## Texto de título (negrito inclinado). Não recebe clique.
static func title(text: String, size: int, col := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Texto corrido.
static func text(t: String, size: int, col := CREAM) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Painel irregular. Posicione e dimensione como qualquer Control e ponha os filhos dentro.
static func panel(fill: Color, shape_seed := 1, outline := OUT) -> InkPanel:
	var p := InkPanel.new()
	p.fill = fill
	p.outline = outline
	p.shape_seed = shape_seed
	return p


## Botão irregular com texto de título.
static func button(text: String, fill: Color, fg: Color, font_size := 24, shape_seed := 3) -> InkButton:
	var b := InkButton.new()
	b.text = text
	b.fill = fill
	b.fg = fg
	b.shape_seed = shape_seed
	b.font_px = font_size
	return b


## Contorno de um retângulo "recortado à mão": cantos e meios de lado levemente fora do lugar.
static func blob(size: Vector2, shape_seed: int, jag := 5.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 7919 + 13
	var pts := PackedVector2Array()
	var w := size.x
	var h := size.y
	var base := [Vector2(0, 0), Vector2(w * 0.5, 0), Vector2(w, 0), Vector2(w, h * 0.5),
		Vector2(w, h), Vector2(w * 0.5, h), Vector2(0, h), Vector2(0, h * 0.5)]
	for k in base.size():
		var p: Vector2 = base[k]
		var inward := Vector2(1 if p.x < w * 0.5 else (-1 if p.x > w * 0.5 else 0), 1 if p.y < h * 0.5 else (-1 if p.y > h * 0.5 else 0))
		# só puxa pra dentro, pra forma nunca sair da caixa do Control
		pts.append(p + inward * rng.randf_range(0.0, jag) + Vector2(rng.randf_range(-jag, jag) * (1.0 - absf(inward.x)), rng.randf_range(-jag, jag) * (1.0 - absf(inward.y))) * 0.4)
	return pts


## Ícone de moeda, pra desenhar dentro do `draw` de qualquer Control (lado = tamanho do ícone).
static func draw_coin(ci: CanvasItem, side: float) -> void:
	var c := Vector2(side, side) * 0.5
	ci.draw_circle(c, side * 0.5, OUT)
	ci.draw_circle(c, side * 0.5 - 3.0, COIN)
	ci.draw_circle(c, side * 0.5 - 8.0, COIN.darkened(0.18))
	ci.draw_rect(Rect2(c.x - 2.0, c.y - side * 0.2, 4.0, side * 0.4), COIN.lightened(0.35))


## Ícone de ticket roxo (o que o ranking SSS dá).
static func draw_ticket(ci: CanvasItem, side: float) -> void:
	var r := Rect2(1, side * 0.2, side - 2, side * 0.6)
	ci.draw_rect(r.grow(2.5), OUT)
	ci.draw_rect(r, TICKET)
	ci.draw_circle(Vector2(r.position.x, side * 0.5), side * 0.13, OUT)
	ci.draw_circle(Vector2(r.end.x, side * 0.5), side * 0.13, OUT)
	var c := Vector2(side, side) * 0.5
	var d := side * 0.16
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), CREAM)
