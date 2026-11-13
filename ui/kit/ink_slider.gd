class_name InkSlider
extends Control
## Slider horizontal no estilo de tinta: trilho escuro, preenchimento chapado e um pegador recortado.
## `value` vai de 0 a 1, em passos de 1%. Arrasta com o mouse ou clica em qualquer ponto do trilho.

signal changed(value: float)
signal released

@export var fill := Color(1.0, 0.8, 0.25)
var value := 1.0: set = _set_value
var _drag := false
var _hover := false

const KNOB := Vector2(22, 34)
const TRACK_H := 14.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 40)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())


func _set_value(v: float) -> void:
	value = clampf(snappedf(v, 0.01), 0.0, 1.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		if event.pressed:
			_take(event.position.x)
		else:
			released.emit()
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_take(event.position.x)
		accept_event()


func _take(x: float) -> void:
	var span := size.x - KNOB.x
	var v := clampf(snappedf((x - KNOB.x * 0.5) / maxf(span, 1.0), 0.01), 0.0, 1.0)
	if not is_equal_approx(v, value):
		value = v
		changed.emit(value)


func _draw() -> void:
	var y := (size.y - TRACK_H) * 0.5
	var x0 := KNOB.x * 0.5
	var span := size.x - KNOB.x
	draw_rect(Rect2(x0 + 3, y + 4, span, TRACK_H), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(x0, y, span, TRACK_H), Ink.NIGHT)
	draw_rect(Rect2(x0, y, span * value, TRACK_H), fill)
	draw_rect(Rect2(x0, y, span, TRACK_H), Ink.OUT, false, 3.0)
	var at := Vector2(x0 + span * value - KNOB.x * 0.5, (size.y - KNOB.y) * 0.5)
	var pts := Ink.blob(KNOB, 4, 2.5)
	var sh := PackedVector2Array()
	var body := PackedVector2Array()
	for p in pts:
		sh.append(p + at + Vector2(3, 4))
		body.append(p + at)
	draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
	draw_colored_polygon(body, Ink.CREAM.lightened(0.3) if (_hover or _drag) else Ink.CREAM)
	body.append(body[0])
	draw_polyline(body, Ink.OUT, 3.0, true)
