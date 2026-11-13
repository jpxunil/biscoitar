class_name Chip
extends Control
## Etiqueta do kit de papel: retângulo inclinado com contorno INK, sombra dura e texto em Bowlby One.
## É o "chip" do design (tecla do HUD, etiqueta de nome, selo de seção). O tamanho segue o texto:
## defina px, pad, skew e arrow ANTES de `text`.

var text := "": set = _set_text
var px := 15
var fill := Paper.CREAM
var ink := Paper.INK
var skew := 12.0
var border := 3.0
var pad := 16.0
var shadow := Vector2(-5, 6)
## Triângulo de "continuar" depois do texto.
var arrow := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_text(v: String) -> void:
	text = v
	var w := Paper.display().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	size = Vector2(w + pad * 2.0 + (px * 1.1 if arrow else 0.0), px + 14.0)
	custom_minimum_size = size
	queue_redraw()


func _draw() -> void:
	var pts := Paper.skew_rect(size, skew)
	if shadow != Vector2.ZERO:
		draw_colored_polygon(Paper.moved(pts, shadow), Paper.INK)
	draw_colored_polygon(pts, Paper.INK)
	if border > 0.0:
		draw_colored_polygon(Paper.inset(pts, border), fill)
	else:
		draw_colored_polygon(pts, fill)
	var f := Paper.display()
	var tail := px * 1.1 if arrow else 0.0
	var y := (size.y - f.get_ascent(px) - f.get_descent(px)) * 0.5 + f.get_ascent(px)
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - tail, px, ink)
	if arrow:
		var c := Vector2(size.x - pad - px * 0.25, size.y * 0.5)
		var r := px * 0.42
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, 0), c + Vector2(-r, r)]), ink)
