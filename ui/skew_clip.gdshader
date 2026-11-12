shader_type canvas_item;
// Recorta a textura no mesmo paralelogramo das placas inclinadas (StyleBoxFlat.skew),
// mantendo a imagem reta. O nó precisa cobrir a caixa inteira da placa inclinada.

uniform float skew = 0.22;
uniform vec2 rect_size = vec2(86.0, 72.0);
uniform float slab_width = 75.0;
uniform float border = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	float shift = (0.5 - UV.y) * skew * rect_size.y;
	float left = (rect_size.x - slab_width) * 0.5 + shift;
	float d = min(min(p.x - left - border, left + slab_width - border - p.x), min(p.y - border, rect_size.y - border - p.y));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= smoothstep(-0.5, 0.5, d);
}
