extends Control
## O expositor da loja (kit de papel). "cards": um quadro com varais (barbante e tachinhas) onde
## as cartas ficam penduradas. "gear": um painel de oficina com prateleiras de madeira.
## `rows` são as alturas (y, no espaço deste Control) de cada barbante ou tábua.

const SAG := 12.0
const MARGIN := 26.0

var style := "cards": set = _set_style
var deep := Paper.NAVY
var deep2 := Paper.NAVY
var rows: Array = []: set = _set_rows


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_style(v: String) -> void:
	style = v
	queue_redraw()


func _set_rows(v: Array) -> void:
	rows = v
	queue_redraw()


## Altura do barbante da fileira `row` no ponto x (ele faz uma barriga no meio).
func string_y(row: int, x: float) -> float:
	var t := clampf((x - MARGIN) / (size.x - MARGIN * 2.0), 0.0, 1.0)
	return float(rows[row]) + SAG * 4.0 * t * (1.0 - t)


func _draw() -> void:
	var ink := Paper.INK
	var pts := Paper.poly(size, [[.012, 0], [1, .016], [.988, 1], [0, .984]])
	draw_colored_polygon(Paper.moved(pts, Vector2(10, 10)), ink)
	draw_colored_polygon(pts, ink)
	var inner := Paper.inset(pts, 6.0)
	draw_colored_polygon(inner, deep)
	if style == "cards":
		# listras diagonais discretas no quadro
		for n in 4:
			var x := -60.0 + n * 190.0
			var band := PackedVector2Array([Vector2(x + 170, 0), Vector2(x + 230, 0), Vector2(x + 60, size.y), Vector2(x, size.y)])
			for piece in Geometry2D.intersect_polygons(band, inner):
				draw_colored_polygon(piece, deep2)
		for r in rows.size():
			var line := PackedVector2Array()
			for s in 25:
				var x := MARGIN + (size.x - MARGIN * 2.0) * s / 24.0
				line.append(Vector2(x, string_y(r, x)))
			draw_polyline(line, ink, 7.0, true)
			draw_polyline(line, Paper.CREAM, 3.0, true)
			for e in [line[0], line[line.size() - 1]]:
				var p: Vector2 = e
				draw_circle(p + Vector2(2, 3), 10.0, ink)
				draw_circle(p, 10.0, ink)
				draw_circle(p, 6.5, Paper.GOLD)
	else:
		# painel perfurado da oficina
		var y := 24.0
		while y < size.y - 16.0:
			var x := 26.0
			while x < size.x - 16.0:
				draw_circle(Vector2(x, y), 3.0, deep2)
				x += 30.0
			y += 30.0
		if rows.size() == 1:
			# uma prateleira só: ferramentas penduradas no painel, em silhueta
			_cog(Vector2(size.x * 0.20, 78), 30.0)
			_cog(Vector2(size.x * 0.20 + 46, 112), 18.0)
			_cog(Vector2(size.x * 0.82, 70), 22.0)
			var wr := PackedVector2Array([Vector2(-7, -44), Vector2(7, -44), Vector2(7, 30), Vector2(16, 40), Vector2(16, 58), Vector2(6, 50), Vector2(-6, 50), Vector2(-16, 58), Vector2(-16, 40), Vector2(-7, 30)])
			draw_set_transform(Vector2(size.x * 0.52, 76), deg_to_rad(64.0), Vector2.ONE)
			draw_colored_polygon(wr, deep2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for r in rows.size():
			var py := float(rows[r])
			var plank := PackedVector2Array([Vector2(12, py), Vector2(size.x - 12, py - 3), Vector2(size.x - 12, py + 15), Vector2(12, py + 18)])
			draw_colored_polygon(Paper.moved(plank, Vector2(5, 7)), ink)
			draw_colored_polygon(plank, ink)
			draw_colored_polygon(Paper.inset(plank, 3.0), Color("a8693a"))
			draw_line(Vector2(18, py + 6), Vector2(size.x - 18, py + 3), Color("c98a52"), 3.0)
			for bx in [40.0, size.x - 40.0]:
				var b: float = bx
				draw_colored_polygon(PackedVector2Array([Vector2(b - 9, py + 17), Vector2(b + 9, py + 17), Vector2(b, py + 38)]), ink)


func _cog(c: Vector2, r: float) -> void:
	for n in 8:
		var a := TAU * n / 8.0
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x) * r * 0.2
		draw_colored_polygon(PackedVector2Array([c + d * r * 0.6 - s, c + d * r * 1.22 - s * 0.8, c + d * r * 1.22 + s * 0.8, c + d * r * 0.6 + s]), deep2)
	draw_circle(c, r * 0.86, deep2)
	draw_circle(c, r * 0.36, deep)
