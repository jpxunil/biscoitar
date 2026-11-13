@tool
class_name InkLabel
extends Label
## Texto de título dos menus: negrito e inclinado. Tamanho e cor ficam no inspetor.

@export var px := 32: set = _set_px
@export var color := Color(0.97, 0.94, 0.84): set = _set_color
@export var slant := 0.2: set = _set_slant


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


func _set_px(v: int) -> void:
	px = v
	_apply()


func _set_color(c: Color) -> void:
	color = c
	_apply()


func _set_slant(v: float) -> void:
	slant = v
	_apply()


func _apply() -> void:
	add_theme_font_override("font", Ink.font(slant))
	add_theme_font_size_override("font_size", px)
	add_theme_color_override("font_color", color)
