shader_type spatial;
render_mode cull_disabled;

// Cauda de sereia: escamas em meia-lua, degradê do quadril até a nadadeira
// e um brilho furta-cor nas bordas. UV.x dá a volta na cauda; UV.y vai do
// quadril (0) até a ponta (1).

uniform vec3 top_color : source_color = vec3(0.1, 0.62, 0.6);
uniform vec3 tip_color : source_color = vec3(0.34, 0.2, 0.7);
uniform vec3 shine_color : source_color = vec3(0.75, 1.0, 0.95);
uniform float scales_around = 14.0;
uniform float scales_along = 16.0;
uniform bool is_fin = false;

void fragment() {
	vec3 base = mix(top_color, tip_color, smoothstep(0.1, 1.0, UV.y));
	float pattern = 1.0;
	if (is_fin) {
		// Nervuras da nadadeira, abrindo em leque.
		float ribs = abs(sin(UV.x * 40.0));
		pattern = mix(0.75, 1.05, ribs);
		base = mix(tip_color, shine_color * 0.8, UV.y * 0.6);
	} else {
		vec2 g = vec2(UV.x * scales_around, UV.y * scales_along);
		g.x += 0.5 * mod(floor(g.y), 2.0);
		vec2 cell = fract(g) - vec2(0.5, 0.0);
		float d = length(cell * vec2(1.0, 1.3));
		pattern = mix(1.15, 0.7, smoothstep(0.35, 0.62, d));
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = base * pattern;
	EMISSION = shine_color * rim * 0.35 + base * 0.06;
	METALLIC = 0.25;
	ROUGHNESS = 0.35;
	SPECULAR = 0.7;
}
