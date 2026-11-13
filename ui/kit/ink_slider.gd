class_name InkSlider
extends Control
## Slider horizontal no kit de papel: trilho INK inclinado (como as barras do HUD no design),
## preenchimento chapado e um pegador creme com contorno e sombra dura.
## `value` vai de 0 a 1, em passos de 1%. Arrasta com o mouse ou clica em qualquer ponto do trilho.
## (O nome ficou da primeira versão, feita no kit Ink.)

signal changed(value: float)
signal released

@export var fill := Paper.GOLD
var value := 1.0: set = _set_value
var _drag := false
var _hover := false

const KNOB := Vector2(20, 34)
const TRACK_H := 16.0


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
	var at := Vector2(x0, y)
	var track := Paper.moved(Paper.skew_rect(Vector2(span, TRACK_H), 24.0), at)
	draw_colored_polygon(Paper.moved(track, Vector2(4, 4)), Paper.INK)
	draw_colored_polygon(track, Paper.INK)
	if value > 0.01:
		var bar := Paper.moved(Paper.skew_rect(Vector2(maxf(span * value - 6.0, 2.0), TRACK_H - 6.0), 24.0), at + Vector2(3, 3))
		draw_colored_polygon(bar, fill)
	var k := Paper.moved(Paper.skew_rect(KNOB, 8.0), Vector2(x0 + span * value - KNOB.x * 0.5, (size.y - KNOB.y) * 0.5))
	draw_colored_polygon(Paper.moved(k, Vector2(3, 4)), Paper.INK)
	draw_colored_polygon(k, Paper.INK)
	draw_colored_polygon(Paper.inset(k, 3.0), Paper.GOLD_HOVER if (_hover or _drag) else Paper.CREAM)
