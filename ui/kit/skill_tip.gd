class_name SkillTip
extends Control
## Ficha de habilidade (tooltip): ícone, nome, tipo, recarga / conjuração / custo, tecla e descrição.
## O texto vem todo do SkillInfo. Aparece ao passar o mouse num slot da barra da luta.
## `show_for` monta e posiciona acima de um retângulo (o slot); `hide_tip` esconde.

const W := 380.0
const DIM := Color("B9BEEA")

var _box: PanelContainer
var _icon: TextureRect
var _name: Label
var _type: Chip
var _meta: Label
var _desc: Label
var _type_holder: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 20


func _ready() -> void:
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Paper.NAVY
	sb.border_color = Paper.INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	_box.add_theme_stylebox_override("panel", sb)
	_box.custom_minimum_size.x = W
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.custom_minimum_size = Vector2(56, 56)
	head.add_child(_icon)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_name = Paper.label("", 20, Paper.CREAM, Paper.display())
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_constant_override("line_spacing", -4)
	hv.add_child(_name)
	_type_holder = Control.new()
	_type_holder.custom_minimum_size = Vector2(120, 26)
	hv.add_child(_type_holder)
	_meta = Paper.label("", 14, Paper.GOLD, Paper.body(800))
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_meta)
	_desc = Paper.label("", 15, Paper.CREAM, Paper.body(600))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_constant_override("line_spacing", -3)
	v.add_child(_desc)
	# texto com quebra de linha precisa de largura conhecida pra calcular a própria altura
	_name.custom_minimum_size.x = W - 28.0 - 68.0
	_meta.custom_minimum_size.x = W - 28.0
	_desc.custom_minimum_size.x = W - 28.0
	_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _draw() -> void:
	# sombra dura do kit de papel
	if _box != null:
		draw_rect(Rect2(_box.position + Vector2(7, 8), _box.size), Paper.INK)


## Linha "RECARGA 15 s  ·  CONJURAÇÃO 1,25 s  ·  CUSTO 10 de Torpor" (só o que a habilidade tem).
static func meta_line(info: Dictionary) -> String:
	var parts: Array = []
	if float(info["cd"]) > 0.0:
		parts.append("RECARGA %s s" % SkillInfo._n(info["cd"]))
	parts.append("CONJURAÇÃO %s s" % SkillInfo._n(info["cast"]) if float(info["cast"]) > 0.0 else "INSTANTÂNEA")
	if String(info["cost"]) != "":
		parts.append("CUSTO %s" % info["cost"])
	return "  ·  ".join(parts)


func show_for(key: String, slot: int, asleep: bool, key_text: String, above: Rect2) -> void:
	var info := SkillInfo.info(key, slot, asleep)
	_icon.texture = SkillInfo.icon(key, slot, asleep)
	_name.text = String(info["name"]).to_upper()
	if _type != null:
		_type.queue_free()
	_type = Chip.new()
	_type.px = 11
	_type.pad = 9.0
	_type.skew = 8.0
	_type.border = 2.0
	_type.shadow = Vector2.ZERO
	_type.fill = SkillInfo.TYPE_COL.get(info["type"], Paper.CREAM)
	_type.text = String(info["type"]).to_upper()
	_type_holder.add_child(_type)
	_meta.text = meta_line(info) + ("  ·  TECLA %s" % key_text if key_text != "" else "")
	_desc.text = info["desc"]
	visible = true
	# o painel calcula a própria altura; posiciona depois que o layout assenta
	_box.size = Vector2(W, 0)
	_place.call_deferred(above)


func _place(above: Rect2) -> void:
	_box.reset_size()
	var sz := _box.get_combined_minimum_size()
	_box.size = sz
	var view := get_viewport_rect().size
	var at := Vector2(above.get_center().x - sz.x * 0.5, above.position.y - sz.y - 18.0)
	at.x = clampf(at.x, 12.0, view.x - sz.x - 20.0)
	at.y = maxf(at.y, 12.0)
	_box.position = at - global_position
	queue_redraw()


func hide_tip() -> void:
	visible = false
