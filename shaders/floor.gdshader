shader_type spatial;

uniform vec3 base_col : source_color = vec3(0.045, 0.045, 0.085);
uniform vec3 line_col : source_color = vec3(0.3, 0.45, 1.0);
uniform float arena_r = 9.0;
uniform vec2 melee_center = vec2(0.0, -9.0);
uniform float melee_r = 4.8;
uniform float melee_on = 0.0;
uniform float melee_in = 0.0;

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
	EMISSION = line_col * (grid * 0.22 * fade + edge * 2.2 + inner) + melee;
}
