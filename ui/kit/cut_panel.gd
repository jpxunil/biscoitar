class_name CutPanel
extends Control
## Painel de papel recortado: um polígono com contorno grosso e sombra dura deslocada.
## `shape` são os pontos em frações (0..1) do tamanho do Control.

var shape: Array = [[0, 0], [1, 0], [1, 1], [0, 1]]: set = _set_shape
var fill := Paper.CREAM: set = _set_fill
var outline := Paper.INK
var border := 5.0
var shadow := Vector2(7, 7)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func make(rect: Rect2, pts: Array, col: Color, border_px := 5.0, shadow_off := Vector2(7, 7)) -> CutPanel:
	var p := CutPanel.new()
	p.position = rect.position
	p.size = rect.size
	p.shape = pts
	p.fill = col
	p.border = border_px
	p.shadow = shadow_off
	return p


func _set_shape(v: Array) -> void:
	shape = v
	queue_redraw()


func _set_fill(v: Color) -> void:
	fill = v
	queue_redraw()


func _draw() -> void:
	var pts := Paper.poly(size, shape)
	if shadow != Vector2.ZERO:
		draw_colored_polygon(Paper.moved(pts, shadow), Paper.INK)
	if border > 0.0:
		draw_colored_polygon(pts, outline)
	draw_colored_polygon(Paper.inset(pts, border), fill)
