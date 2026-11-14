shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A saia da Valsa no chão: uma roseta de renda que gira. A barra recortada marca exatamente até onde
// o bônus alcança; as pregas em espiral giram mais rápido conforme o Embalo sobe.
uniform vec3 col_a : source_color = vec3(0.72, 0.6, 1.0);
uniform vec3 col_b : source_color = vec3(1.0, 0.8, 0.3);
uniform float energy = 0.0;   // 0..1: Embalo
uniform float gold = 0.0;     // 0..1: Crescendo / Grande Baile
uniform float spin = 0.0;     // ângulo acumulado (quem gira é o script)
uniform float alpha = 1.0;
uniform float lobes = 10.0;   // recortes da barra (número par)

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) + spin;
	// barra recortada em pétalas
	float hem = 0.9 + 0.06 * cos(a * lobes);
	float inside = 1.0 - smoothstep(hem - 0.012, hem, r);
	float edge = smoothstep(hem - 0.075, hem - 0.03, r) * inside;
	// pregas em espiral
	float fold = 0.5 + 0.5 * sin(a * lobes * 0.5 + r * 7.5);
	fold = smoothstep(0.5, 0.95, fold) * smoothstep(0.12, 0.85, r);
	// renda: uma fileira de furinhos perto da barra e um anel fino no meio
	float lace = smoothstep(0.55, 0.9, 0.5 + 0.5 * cos(a * lobes * 2.0)) * smoothstep(0.05, 0.0, abs(r - (hem - 0.15)));
	float ring = smoothstep(0.018, 0.0, abs(r - 0.42)) * inside;
	float fill = inside * (0.07 + 0.2 * fold + 0.1 * energy * fold);
	float k = clamp(gold + edge * (0.25 + 0.75 * energy) + lace * 0.8, 0.0, 1.0);
	vec3 c = mix(col_a, col_b, k);
	ALBEDO = c * (1.0 + 0.9 * energy + 0.8 * gold);
	ALPHA = clamp(fill + edge * 0.9 + lace * 0.7 + ring * (0.35 + 0.5 * energy), 0.0, 1.0) * alpha;
}
