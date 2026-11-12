class_name UiStyle
## Linguagem visual única da interface. Regras:
## 1. Texto nunca fica direto sobre a cena 3D: sempre em cima de uma placa INK ou PAPER.
## 2. Só dois fundos de texto: INK (escuro, texto PAPER) e PAPER (claro, texto INK).
## 3. Cor tem significado fixo e não é reutilizada pra enfeite:
##    DANGER = perigo/pouca vida · CYAN = seguindo carta · YELLOW = confuso/atenção
##    PURPLE = carta roxa · BOSS = tudo que é do boss.
## 4. Formas chapadas e inclinadas (skew), sem cantos arredondados, sem gradiente.

const INK := Color(0.07, 0.08, 0.16)
const INK_SOFT := Color(0.14, 0.15, 0.27)
const PAPER := Color(0.97, 0.96, 0.9)
const DIM := Color(0.66, 0.69, 0.84)
const CYAN := Color(0.3, 0.9, 1.0)
const YELLOW := Color(1.0, 0.8, 0.25)
const DANGER := Color(1.0, 0.33, 0.36)
const GREEN := Color(0.33, 0.87, 0.52)
const PURPLE := Color(0.62, 0.36, 1.0)
const BOSS := Color(1.0, 0.35, 0.6)

const SKEW := 0.22


static func box(col: Color, skew := 0.0, margin_h := 0, margin_v := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.skew = Vector2(skew, 0)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


## Placa com conteúdo. Com skew, use margem horizontal folgada pro texto não encostar na borda inclinada.
static func slab(col: Color, skew := SKEW, margin_h := 22, margin_v := 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(col, skew, margin_h, margin_v))
	return p


static func text(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Barra chapada. Mude o preenchimento com set_bar(barra, 0..1).
static func bar(col: Color, height: int, skew := 0.5) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Panel.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.6), skew))
	c.add_child(back)
	var fill := Panel.new()
	fill.name = "Fill"
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", box(col, skew))
	c.add_child(fill)
	return c


static func set_bar(b: Control, ratio: float) -> void:
	var fill: Panel = b.get_node("Fill")
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_right = 0
	fill.visible = ratio > 0.001


static func chip(col: Color, size: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size + 6, size + 6)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# contorno claro: garante leitura da cor em qualquer fundo
	var edge := ColorRect.new()
	edge.color = PAPER
	edge.position = Vector2(1, 1)
	edge.size = Vector2(size + 4, size + 4)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(edge)
	var c := ColorRect.new()
	c.color = col
	c.position = Vector2(3, 3)
	c.size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(c)
	return holder
