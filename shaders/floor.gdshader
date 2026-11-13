shader_type spatial;

uniform vec3 base_col : source_color = vec3(0.045, 0.045, 0.085);
uniform vec3 line_col : source_color = vec3(0.3, 0.45, 1.0);
uniform float arena_r = 9.0;
uniform vec2 melee_center = vec2(0.0, -9.0);
uniform float melee_r = 4.8;
uniform float melee_on = 0.0;
uniform float melee_in = 0.0;
// Final da MINI-CHAN: a arena desaba e sobram dois quadrados. warn = só a marca; on = o resto vira vazio.
uniform float void_warn = 0.0;
uniform float void_on = 0.0;
uniform vec2 sq_a = vec2(-3.6, -4.4);
uniform vec2 sq_b = vec2(3.6, -4.4);
uniform float sq_half = 2.4;

float sd_square(vec2 p, vec2 c) {
	vec2 d = abs(p - c) - vec2(sq_half);
	return max(d.x, d.y);
}

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = wp.xz / 1.5;
	vec2 g = abs(fract(c - 0.5) - 0.5) / fwidth(c);
	float grid = 1.0 - min(min(g.x, g.y), 1.0);
	float r = length(wp.xz);
	float edge = smoothstep(0.22, 0.0, abs(r - arena_r));
	float inner = smoothstep(0.06, 0.0, abs(r - arena_r * 0.5)) * 0.4;
	float fade = 1.0 - smoothstep(0.0, arena_r, r) * 0.6;
	ALBEDO = base_col;
	ROUGHNESS = 0.45;
	METALLIC = 0.2;
	// arco de alcance corpo a corpo: linha fina, mais forte quando você está dentro
	float md = distance(wp.xz, melee_center);
	float arc = smoothstep(0.07, 0.0, abs(md - melee_r)) * step(r, arena_r);
	float inside = step(md, melee_r) * step(r, arena_r) * 0.05;
	vec3 melee = vec3(1.0, 0.95, 0.8) * (arc * mix(0.6, 1.6, melee_in) + inside) * melee_on;
	vec3 em = line_col * (grid * 0.22 * fade + edge * 2.2 + inner) + melee;
	float sd = min(sd_square(wp.xz, sq_a), sd_square(wp.xz, sq_b));
	float outside = step(0.0, sd);
	float sq_edge = smoothstep(0.14, 0.0, abs(sd));
	// vazio: fora dos quadrados some o chão; no aviso, fora fica avermelhado
	em *= 1.0 - outside * void_on;
	ALBEDO = mix(ALBEDO, vec3(0.0), outside * void_on);
	em += vec3(1.0, 0.15, 0.3) * outside * void_warn * 0.16 * step(r, arena_r);
	em += vec3(0.55, 0.9, 1.0) * sq_edge * (void_warn * 2.4 + void_on * 2.8);
	em += vec3(0.25, 0.45, 0.6) * (1.0 - outside) * (void_warn + void_on) * 0.12;
	EMISSION = em;
}
