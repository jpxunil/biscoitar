@tool
class_name InkButton
extends Button
## Botão de formato irregular. Cresce um pouco no hover e afunda no clique.

@export var fill := Color(0.97, 0.94, 0.84): set = _set_fill
@export var fg := Color(0.05, 0.045, 0.1): set = _set_fg
@export var outline := Color(0.05, 0.045, 0.1)
@export var shape_seed := 3: set = _set_seed
@export var font_px := 24: set = _set_px
var _hover := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_font_override("font", Ink.font())
	add_theme_font_size_override("font_size", font_px)
	# o texto é desenhado em _draw, por cima do formato; o do próprio Button fica invisível
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		_hover = true
		_pop(1.05))
	mouse_exited.connect(func():
		_hover = false
		_pop(1.0))
	button_down.connect(func(): _pop(0.96))
	button_up.connect(func(): _pop(1.05 if _hover else 1.0))


func _set_fill(c: Color) -> void:
	fill = c
	queue_redraw()


func _set_fg(c: Color) -> void:
	fg = c
	queue_redraw()


func _set_seed(v: int) -> void:
	shape_seed = v
	queue_redraw()


func _set_px(v: int) -> void:
	font_px = v
	queue_redraw()


func _pop(to: float) -> void:
	if disabled or Engine.is_editor_hint():
		return
	pivot_offset = size * 0.5
	create_tween().tween_property(self, "scale", Vector2.ONE * to, 0.08)
	queue_redraw()


func _draw() -> void:
	var pts := Ink.blob(size, shape_seed, 5.0)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(4, 5))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
	var col := fill
	if disabled:
		col = fill.darkened(0.45)
	elif _hover:
		col = fill.lightened(0.12)
	draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, outline, 4.0, true)
	var f := Ink.font()
	var asc := f.get_ascent(font_px)
	var desc := f.get_descent(font_px)
	var ty := (size.y - asc - desc) * 0.5 + asc
	draw_string(f, Vector2(0, ty), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_px, Color(fg.r, fg.g, fg.b, 0.45) if disabled else fg)
