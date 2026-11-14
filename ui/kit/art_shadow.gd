class_name ArtShadow
extends TextureRect
## Sombra gráfica de uma sprite de personagem: a mesma silhueta, deslocada pra trás da figura.
## Não é sombra de chão: é o recorte colorido atrás, como papel em duas camadas.
##
## Pra nunca "derreter" no cenário (sombra rosa em cima de faixa rosa), a silhueta tem um contorno
## INK em volta: ele separa a sombra de qualquer cor que esteja atrás. A cor de cada herói (COLORS)
## foi escolhida fora das cores das faixas do tema dele e ligada ao personagem (o fogo da Soulflame
## e do Soulburner, por exemplo). Maga e Ringstar têm sombra arco-íris: sete cores em fatias, girando
## em volta dela.
##
## Use ArtShadow.for_hero(arte, chave) (ou attach, com uma cor qualquer). A sombra vira filha da própria
## arte, desenhada atrás dela, então acompanha troca de textura, movimento, escala e rotação.

const CODE := "shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.07, 0.08, 0.16, 1.0);
uniform vec4 ink : source_color = vec4(0.071, 0.078, 0.161, 1.0);
uniform float outline = 4.0;
uniform bool rainbow = false;
uniform float spin = 0.16;
const vec3 BAND[7] = vec3[](vec3(1.0, 0.25, 0.35), vec3(1.0, 0.6, 0.2), vec3(1.0, 0.88, 0.25), vec3(0.35, 0.9, 0.45), vec3(0.25, 0.85, 1.0), vec3(0.4, 0.5, 1.0), vec3(0.8, 0.4, 1.0));
void fragment() {
	float inner = texture(TEXTURE, UV).a;
	// contorno: a silhueta engordada em 8 direções
	float fat = inner;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		fat = max(fat, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * outline * TEXTURE_PIXEL_SIZE).a);
	}
	vec3 col = tint.rgb;
	if (rainbow) {
		vec2 d = UV - vec2(0.5);
		float turn = fract(atan(d.y, d.x) / 6.2831853 + TIME * spin);
		col = BAND[int(floor(turn * 7.0)) % 7];
	}
	COLOR = vec4(mix(ink.rgb, col, step(0.5, inner)), fat * tint.a);
}
"

## Cor da sombra de cada herói. "rainbow" = arco-íris girando.
const COLORS := {
	"tank": Color("4DE6FF"),        # luz fria, contra o dourado e o azul dela
	"healer": Color("3FF2E0"),      # o fogo e os olhos dela
	"assassina": Color("FFCC40"),   # dourado dos punhais
	"nurse": Color("5566E0"),
	"burner": Color("39C8FF"),      # fogo azul
	"apothecary": Color("9E5CFF"),  # roxo, contra o verde da fumaça
	"sleepwalker": Color("FFE08A"), # luz de abajur
	"valsa": Color("FFCC40"),       # o dourado das rosas
}
const RAINBOW := ["maga", "ringstar"]

static var _shader: Shader


## Sombra padrão do herói `key`.
static func for_hero(art: TextureRect, key: String, offset := Vector2(16, 13)) -> ArtShadow:
	var sh := attach(art, COLORS.get(key, Paper.GOLD), offset)
	(sh.material as ShaderMaterial).set_shader_parameter("rainbow", RAINBOW.has(key))
	return sh


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
	var mat := sh.material as ShaderMaterial
	mat.set_shader_parameter("tint", col)
	mat.set_shader_parameter("rainbow", false)
	# o contorno é medido em pixels da textura: compensa a escala em que a arte está na tela
	var tex_w := float(art.texture.get_width()) if art.texture != null else art.size.x
	mat.set_shader_parameter("outline", 4.0 * tex_w / maxf(art.size.x, 1.0))
	return sh
