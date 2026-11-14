extends Control
## Fundo da loja (kit de papel): faixas diagonais grandes, retícula no canto e um recorte claro
## atrás da vendedora. Cada balcão tem as suas cores; `show_theme` troca de um pro outro com uma
## cortina diagonal (todo desenho é polígono, então a cortina é só uma interseção).
## colors: bg · bg2 · deep · deep2 · slab (atrás da vendedora) · acc

var themes := {}
var key := ""
var _old := ""
var _t := 1.0: set = _set_t
var _clip := PackedVector2Array()
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


func show_theme(k: String, animate := true) -> void:
	if k == key:
		return
	_old = key
	key = k
	if _tw != null:
		_tw.kill()
	if animate and _old != "" and is_inside_tree():
		_t = 0.0
		_tw = create_tween()
		_tw.tween_property(self, "_t", 1.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_t = 1.0
	queue_redraw()


func _draw() -> void:
	if not themes.has(key):
		return
	var w := size.x
	var h := size.y
	if _t < 1.0 and themes.has(_old):
		_clip = PackedVector2Array()
		_paint(themes[_old])
		# a cortina entra da esquerda, inclinada, com uma faixa INK na borda
		var edge := lerpf(-0.25 * w, 1.25 * w, _t)
		var d := 0.11 * w
		_clip = PackedVector2Array([Vector2(-w, 0), Vector2(edge + d, 0), Vector2(edge - d, h), Vector2(-w, h)])
		_paint(themes[key])
		_clip = PackedVector2Array()
		draw_colored_polygon(PackedVector2Array([Vector2(edge + d, 0), Vector2(edge + d + 46.0, 0), Vector2(edge - d + 46.0, h), Vector2(edge - d, h)]), Paper.INK)
	else:
		_clip = PackedVector2Array()
		_paint(themes[key])


func _shape(pts: PackedVector2Array, col: Color) -> void:
	if _clip.is_empty():
		draw_colored_polygon(pts, col)
		return
	for piece in Geometry2D.intersect_polygons(pts, _clip):
		if piece.size() >= 3:
			draw_colored_polygon(piece, col)


func _paint(c: Dictionary) -> void:
	var w := size.x
	var h := size.y
	_shape(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), c["bg"])
	# duas faixas diagonais que cortam a tela inteira
	_shape(PackedVector2Array([Vector2(w * 0.30, 0), Vector2(w * 0.60, 0), Vector2(w * 0.36, h), Vector2(w * 0.06, h)]), c["bg2"])
	_shape(PackedVector2Array([Vector2(w * 0.655, 0), Vector2(w * 0.685, 0), Vector2(w * 0.445, h), Vector2(w * 0.415, h)]), c["deep2"])
	# canto de baixo, escuro
	_shape(PackedVector2Array([Vector2(w * 0.58, h), Vector2(w, h * 0.70), Vector2(w, h)]), c["deep"])
	_shape(PackedVector2Array([Vector2(w * 0.66, h), Vector2(w, h * 0.80), Vector2(w, h)]), c["deep2"])
	# retícula no canto de cima, à direita
	for row in 7:
		for col in 16:
			var r := 7.0 - row * 0.9
			var p := Vector2(w - 26.0 - col * 26.0 - (13.0 if row % 2 == 1 else 0.0), 14.0 + row * 22.0)
			if r > 1.0 and (_clip.is_empty() or Geometry2D.is_point_in_polygon(p, _clip)):
				draw_circle(p, r * (1.0 - col / 18.0), c["bg2"])
	# recorte atrás da vendedora: ela nunca fica solta em cima das faixas
	var slab := PackedVector2Array([Vector2(-20, 236), Vector2(96, 170), Vector2(150, 204), Vector2(322, 128), Vector2(418, 300), Vector2(380, 330), Vector2(436, 560), Vector2(360, h + 20), Vector2(-20, h + 20)])
	_shape(Paper.moved(slab, Vector2(12, 12)), Paper.INK)
	_shape(slab, Paper.INK)
	_shape(Paper.inset(slab, 6.0), c["slab"])
	var inner := PackedVector2Array([Vector2(-20, 400), Vector2(400, 250), Vector2(412, 300), Vector2(-20, 452)])
	for piece in Geometry2D.intersect_polygons(inner, Paper.inset(slab, 6.0)):
		_shape(piece, c["slab2"])
