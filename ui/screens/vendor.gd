@tool
class_name Vendor
extends Control
## Quem atende no balcão da loja. `who` escolhe a vendedora: "cards" é a Shopkeeper (loja de cartas),
## "gear" é a vendedora de itens. A arte vem de assets/portraits (recortada por tools/portraits.py) e
## aparece da cintura pra cima, atrás do balcão. `mood` mexe o corpo: ela não tem cara desenhada à mão.

const ART := {
	"cards": "res://assets/portraits/shopkeeper_art.webp",
	"gear": "res://assets/portraits/itemseller_art.webp",
}
## Largura da arte no balcão, em pixels da tela (a altura segue a proporção do arquivo).
const WIDTH := {"cards": 300.0, "gear": 236.0}

@export var who := "cards": set = _set_who
## "idle" parada · "happy" vendeu (pulinho) · "sad" faltou dinheiro (balança) · "wow" carta rara (cresce)
@export var mood := "idle": set = _set_mood

var _t := 0.0
var _hop := 0.0
var _shake := 0.0
var _pop := 0.0
var _slide := 0.0
var _tex := {}


func _set_who(v: String) -> void:
	if v != who:
		_slide = 1.0
	who = v
	queue_redraw()


func _set_mood(v: String) -> void:
	mood = v
	match v:
		"happy": _hop = 1.0
		"sad": _shake = 1.0
		"wow": _pop = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_hop = maxf(0.0, _hop - delta * 2.5)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_pop = maxf(0.0, _pop - delta * 3.0)
	_slide = maxf(0.0, _slide - delta * 4.0)
	queue_redraw()


func _art() -> Texture2D:
	if not _tex.has(who):
		var p: String = ART.get(who, ART["cards"])
		_tex[who] = load(p) if ResourceLoader.exists(p) else null
	return _tex[who]


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Ink.OUT
	var top := h * 0.74
	var tex := _art()
	if tex != null:
		var ts := tex.get_size()
		var aw: float = float(WIDTH.get(who, 280.0)) * (1.0 + sin(_pop * PI) * 0.05)
		var k := aw / ts.x
		# respira devagar; pula quando vende, balança quando falta dinheiro, entra de baixo na troca
		var y := sin(_t * 1.6) * 3.0 - sin(_hop * PI) * 22.0 + _slide * _slide * 220.0
		var x := (w - aw) * 0.5 + sin(_shake * PI * 5.0) * 9.0 * _shake
		# só o pedaço acima do balcão é desenhado (o resto ficaria por cima dele)
		var show_h := minf(top + 14.0 - y, ts.y * k)
		if show_h > 0.0:
			var tint := Color(0.8, 0.8, 0.9) if mood == "sad" else Color.WHITE
			draw_texture_rect_region(tex, Rect2(x, y, aw, show_h), Rect2(0, 0, ts.x, show_h / k), tint)
	# balcão e o que está à venda em cima dele
	_poly(PackedVector2Array([Vector2(0, top), Vector2(w, top - 8), Vector2(w, h), Vector2(0, h)]), Ink.BROWN, ink)
	draw_line(Vector2(0, top + 22), Vector2(w, top + 14), Ink.BROWN.lightened(0.18), 5.0)
	var gear := who == "gear"
	var packs := [[Vector2(8, top - 30), Ink.COIN if gear else Ink.GRAPE, -8.0], [Vector2(w - 62, top - 34), Ink.CREAM, 5.0]]
	for pk in packs:
		draw_set_transform(pk[0] + Vector2(27, 37), deg_to_rad(pk[2]), Vector2.ONE)
		draw_rect(Rect2(-30, -40, 60, 80), ink)
		draw_rect(Rect2(-26, -36, 52, 72), pk[1])
		if gear:
			# caixa de peças: uma engrenagem
			draw_circle(Vector2.ZERO, 13, ink)
			draw_circle(Vector2.ZERO, 5, pk[1])
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(11, 0), Vector2(0, 12), Vector2(-11, 0)]), ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(pts: PackedVector2Array, fill: Color, line: Color) -> void:
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, line, 5.0, true)
