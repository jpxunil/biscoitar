class_name ArtShadow
extends TextureRect
## Sombra gráfica de uma sprite de personagem: a mesma silhueta, numa cor só, deslocada pra trás.
## Não é sombra de chão: é o recorte colorido atrás da figura, como papel em duas camadas.
## Use ArtShadow.attach(arte, cor): a sombra vira filha da própria arte (desenhada atrás dela), então
## acompanha troca de textura, movimento, escala e rotação sem mais nenhum código.

const CODE := "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.07, 0.08, 0.16, 1.0);\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);\n}\n"

static var _shader: Shader


## Cria (ou atualiza) a sombra de `art`. Chame de novo depois de trocar a textura ou o tamanho da arte.
static func attach(art: TextureRect, col: Color, offset := Vector2(16, 13)) -> ArtShadow:
	var sh: ArtShadow = art.get_node_or_null("Shadow")
	if sh == null:
		sh = ArtShadow.new()
		sh.name = "Shadow"
		sh.show_behind_parent = true
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _shader == null:
			_shader = Shader.new()
			_shader.code = CODE
		var m := ShaderMaterial.new()
		m.shader = _shader
		sh.material = m
		art.add_child(sh)
	sh.texture = art.texture
	sh.expand_mode = art.expand_mode
	sh.stretch_mode = art.stretch_mode
	sh.size = art.size
	sh.position = offset
	(sh.material as ShaderMaterial).set_shader_parameter("tint", col)
	return sh
