@tool
class_name Vendor
extends Control
## Quem atende no balcão da loja. `who` escolhe a vendedora: "cards" é a Shopkeeper (loja de cartas),
## "gear" é a vendedora de itens. A arte vem de assets/portraits (recortada por tools/portraits.py) e
## aparece da cintura pra cima, atrás do balcão. `mood` mexe o corpo: ela não tem cara desenhada à mão.
## Parada, cada uma tem o seu jeito: a Shopkeeper vai cochilando e acorda num tranco; a vendedora de
## itens fica reta e só inclina a cabeça de vez em quando.

const ART := {
	"cards": "res://assets/portraits/shopkeeper_art.webp",
	"gear": "res://assets/portraits/itemseller_art.webp",
}
## Largura da arte no balcão, em pixels da tela (a altura segue a proporção do arquivo).
const WIDTH := {"cards": 400.0, "gear": 310.0}
## Altura do tampo do balcão dentro do Control (a arte é cortada um pouco abaixo dele).
const TOP := 350.0
const CLOTH := {"cards": Color("5b2bb8"), "gear": Color("1e2a6e")}

@export var who := "cards": set = _set_who
## "idle" parada · "happy" vendeu (pulinho) · "sad" faltou dinheiro (balança) · "wow" carta rara (cresce)
## · "nod" reparou em alguma coisa (aceno curto)
@export var mood := "idle": set = _set_mood

var _t := 0.0
var _hop := 0.0
var _shake := 0.0
var _pop := 0.0
var _slide := 0.0
var _nod := 0.0
var _tex := {}


func _set_who(v: String) -> void:
	if v != who:
		_slide = 1.0
		_t = 0.0
	who = v
	queue_redraw()


func _set_mood(v: String) -> void:
	mood = v
	match v:
		"happy": _hop = 1.0
		"sad": _shake = 1.0
		"wow": _pop = 1.0
		"nod": _nod = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_hop = maxf(0.0, _hop - delta * 2.5)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_pop = maxf(0.0, _pop - delta * 3.0)
	_slide = maxf(0.0, _slide - delta * 4.0)
	_nod = maxf(0.0, _nod - delta * 4.0)
	queue_redraw()


func _art() -> Texture2D:
	if not _tex.has(who):
		var p: String = ART.get(who, ART["cards"])
		_tex[who] = load(p) if ResourceLoader.exists(p) else null
	return _tex[who]


## O jeito de cada uma ficar parada: devolve [descida em px, inclinação em graus].
func _idle_pose() -> Array:
	if who == "gear":
		# reta, e a cada 6 s inclina a cabeça pra olhar o cliente
		var p := fmod(_t, 6.0)
		var look := 0.0
		if p > 4.2 and p < 5.6:
			look = sin((p - 4.2) / 1.4 * PI)
		return [sin(_t * 1.4) * 1.5, look * 1.6]
	# cochila: vai afundando devagar e acorda num tranco
	var q := fmod(_t + 3.0, 7.0)
	var drop := 0.0
	if q < 2.2:
		drop = (q / 2.2) * (q / 2.2) * 13.0
	elif q < 2.5:
		drop = 13.0 - (q - 2.2) / 0.3 * 18.0
	elif q < 3.0:
		drop = -5.0 * (1.0 - (q - 2.5) / 0.5)
	return [drop + sin(_t * 1.6) * 2.5, -drop * 0.14 + sin(_t * 0.8) * 0.5]


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Paper.INK
	var tex := _art()
	if tex != null:
		var ts := tex.get_size()
		var aw: float = float(WIDTH.get(who, 300.0)) * (1.0 + sin(_pop * PI) * 0.05)
		var k := aw / ts.x
		var pose := _idle_pose()
		# pula quando vende, balança quando falta dinheiro, acena no hover, entra de baixo na troca
		var y: float = float(pose[0]) - sin(_hop * PI) * 24.0 + sin(_nod * PI) * 7.0 + _slide * _slide * 300.0
		var x := (w - aw) * 0.5 + sin(_shake * PI * 5.0) * 10.0 * _shake
		# só o pedaço acima do balcão é desenhado (o resto ficaria por cima dele)
		var show_h := minf(TOP + 22.0 - y, ts.y * k)
		if show_h > 0.0:
			var tint := Color(0.8, 0.8, 0.9) if mood == "sad" else Color.WHITE
			var pivot := Vector2(w * 0.5, TOP)
			var breath := 1.0 + sin(_t * 1.6) * 0.006
			var xf := Transform2D(deg_to_rad(float(pose[1])), Vector2(1.0, breath), 0.0, pivot) * Transform2D(0.0, -pivot)
			draw_set_transform_matrix(xf)
			var dst := Rect2(x, y, aw, show_h)
			var src := Rect2(0, 0, ts.x, show_h / k)
			# sombra dura: a mesma arte, em INK, deslocada
			draw_texture_rect_region(tex, Rect2(dst.position + Vector2(10, 8), dst.size), src, Color(ink.r * 0.4, ink.g * 0.4, ink.b * 0.4))
			draw_texture_rect_region(tex, dst, src, tint)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	# balcão: tampo de madeira, frente com o pano da loja
	var gear := who == "gear"
	_poly(PackedVector2Array([Vector2(-10, TOP + 6), Vector2(w + 14, TOP - 6), Vector2(w + 14, h), Vector2(-10, h)]), Paper.BROWN, ink, Vector2(10, 0))
	var cloth := PackedVector2Array([Vector2(16, TOP + 52), Vector2(w - 12, TOP + 42), Vector2(w - 12, h), Vector2(16, h)])
	_poly(cloth, CLOTH.get(who, CLOTH["cards"]), ink)
	var mark := Vector2(w - 86.0, TOP + 118.0)
	if gear:
		_cog(mark, 30.0, Paper.GOLD, CLOTH["gear"])
	else:
		Paper.draw_suit(self, "special", mark - Vector2(34, 34), 68.0, Paper.PINK)
	_poly(PackedVector2Array([Vector2(-18, TOP), Vector2(w + 22, TOP - 12), Vector2(w + 22, TOP + 16), Vector2(-18, TOP + 28)]), Color("a8693a"), ink, Vector2(0, 8))
	draw_line(Vector2(-10, TOP + 9), Vector2(w + 14, TOP - 3), Color("c98a52"), 3.0)
	# o que está em cima do balcão
	if gear:
		_pack(Vector2(34, TOP - 34), Paper.GOLD, -7.0, true)
		# frasco de poção
		var f := Vector2(w - 44.0, TOP - 26.0)
		draw_circle(f + Vector2(0, 4), 23.0, ink)
		draw_rect(Rect2(f.x - 10, f.y - 38, 20, 24), ink)
		draw_circle(f + Vector2(0, 4), 18.0, Paper.CYAN)
		draw_rect(Rect2(f.x - 6, f.y - 34, 12, 20), Paper.CREAM)
		draw_rect(Rect2(f.x - 12, f.y - 42, 24, 8), ink)
		draw_circle(f + Vector2(-6, -2), 4.0, Paper.CREAM)
	else:
		_pack(Vector2(30, TOP - 36), Paper.KIND["purple"]["bg"], -9.0, false)
		_pack(Vector2(w - 52, TOP - 40), Paper.CREAM, 6.0, false)
		_pack(Vector2(w - 34, TOP - 34), Paper.GOLD, 15.0, false)


## Maço de cartas (ou caixa de peças) em pé no balcão.
func _pack(at: Vector2, col: Color, deg: float, cog: bool) -> void:
	var ink := Paper.INK
	draw_set_transform(at, deg_to_rad(deg), Vector2.ONE)
	draw_rect(Rect2(-28, -40, 66, 88), ink)
	draw_rect(Rect2(-32, -44, 64, 88), ink)
	draw_rect(Rect2(-28, -40, 56, 80), col)
	if cog:
		_cog(Vector2.ZERO, 17.0, ink, col)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(13, 0), Vector2(0, 15), Vector2(-13, 0)]), ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cog(c: Vector2, r: float, col: Color, hole: Color) -> void:
	for n in 8:
		var a := TAU * n / 8.0
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x) * r * 0.2
		draw_colored_polygon(PackedVector2Array([c + d * r * 0.6 - s, c + d * r * 1.22 - s * 0.8, c + d * r * 1.22 + s * 0.8, c + d * r * 0.6 + s]), col)
	draw_circle(c, r * 0.86, col)
	draw_circle(c, r * 0.36, hole)


func _poly(pts: PackedVector2Array, fill: Color, line: Color, shadow := Vector2.ZERO) -> void:
	if shadow != Vector2.ZERO:
		draw_colored_polygon(Paper.moved(pts, shadow), line)
	draw_colored_polygon(pts, line)
	draw_colored_polygon(Paper.inset(pts, 5.0), fill)
