@tool
class_name InkPanel
extends Control
## Painel de formato irregular: sombra dura deslocada, preenchimento e contorno grosso.

@export var fill := Color(0.13, 0.13, 0.3): set = _set_fill
@export var outline := Color(0.05, 0.045, 0.1): set = _set_outline
@export var width := 4.0: set = _set_width
## Muda o recorte do painel: cada número dá um formato diferente.
@export var shape_seed := 1: set = _set_seed
@export var jag := 6.0: set = _set_jag
@export var shadow := Vector2(5, 6): set = _set_shadow
@export var shadow_col := Color(0, 0, 0, 0.45)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_fill(c: Color) -> void:
	fill = c
	queue_redraw()


func _set_outline(c: Color) -> void:
	outline = c
	queue_redraw()


func _set_width(v: float) -> void:
	width = v
	queue_redraw()


func _set_seed(v: int) -> void:
	shape_seed = v
	queue_redraw()


func _set_jag(v: float) -> void:
	jag = v
	queue_redraw()


func _set_shadow(v: Vector2) -> void:
	shadow = v
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var pts := Ink.blob(size, shape_seed, jag)
	if shadow != Vector2.ZERO:
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + shadow)
		draw_colored_polygon(sh, shadow_col)
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, outline, width, true)
