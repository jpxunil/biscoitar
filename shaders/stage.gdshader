shader_type spatial;
// Palco da MEL-CHAN: chão de favo de mel, com raios saindo do centro e um aro escuro em volta.
// Os uniforms de alcance e de vazio são os mesmos do floor.gdshader (o jogo ajusta os dois igual).

uniform vec3 tile_a : source_color = vec3(0.2, 0.115, 0.2);
uniform vec3 tile_b : source_color = vec3(0.155, 0.095, 0.185);
uniform vec3 line_col : source_color = vec3(1.0, 0.8, 0.55);
uniform vec3 honey_col : source_color = vec3(1.0, 0.7, 0.2);
uniform vec3 rim_col : source_color = vec3(1.0, 0.45, 0.72);
uniform float arena_r = 9.0;
uniform float hex_size = 2.5;
uniform vec2 melee_center = vec2(0.0, -9.0);
uniform float melee_r = 4.8;
uniform float melee_on = 0.0;
uniform float melee_in = 0.0;
uniform float void_warn = 0.0;
uniform float void_on = 0.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// xy = posição dentro do hexágono, zw = qual hexágono
vec4 hex(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 0.5);
}

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.5, 0.8660254)), p.x);
}

void fragment() {
	float r = length(wp.xz);
	vec4 h = hex(wp.xz / hex_size);
	float d = 0.5 - hex_dist(h.xy);           // distância até a borda do hexágono (0 na borda)
	float aa = fwidth(d) * 1.5;
	float seam = 1.0 - smoothstep(0.012, 0.012 + aa, d);
	float inner = (1.0 - smoothstep(0.0, aa, abs(d - 0.13))) * 0.35;
	float pick = fract(sin(dot(h.zw, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 tile = mix(tile_a, tile_b, step(0.5, pick));
	// o meio do palco é mais quente, como mel sob a luz
	float warm = 1.0 - smoothstep(0.0, arena_r * 0.75, r);
	tile = mix(tile, tile + honey_col * 0.05, warm);
	// oito raios saindo do centro
	float ang = atan(wp.z, wp.x);
	float spoke_d = abs(sin(ang * 4.0)) * r;
	float spoke = (1.0 - smoothstep(0.03, 0.03 + fwidth(spoke_d) * 1.5, spoke_d)) * step(0.9, r);
	float on_stage = 1.0 - smoothstep(arena_r - 0.02, arena_r + 0.02, r);
	float band = smoothstep(0.28, 0.0, abs(r - arena_r));
	// fora do palco: aro escuro com um fio de luz
	vec3 pit = vec3(0.03, 0.03, 0.09);
	float wire = smoothstep(0.07, 0.0, abs(r - (arena_r + 1.1))) * 0.6;
	ALBEDO = mix(pit, tile, on_stage);
	ROUGHNESS = 0.55;
	METALLIC = 0.1;
	vec3 em = line_col * (seam * 0.28 + inner * 0.12 + spoke * 0.3) * on_stage;
	em += rim_col * (band * 1.1 + wire * 0.6);
	// arco de alcance corpo a corpo
	float md = distance(wp.xz, melee_center);
	float arc = smoothstep(0.07, 0.0, abs(md - melee_r)) * on_stage;
	float inside = step(md, melee_r) * on_stage * 0.05;
	em += vec3(1.0, 0.95, 0.8) * (arc * mix(0.6, 1.6, melee_in) + inside) * melee_on;
	em *= 1.0 - void_on;
	em += vec3(1.0, 0.15, 0.3) * void_warn * 0.1 * on_stage;
	EMISSION = em;
}
