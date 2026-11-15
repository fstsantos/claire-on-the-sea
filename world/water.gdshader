shader_type spatial;
render_mode cull_disabled;

// Mar: a profundidade vem de uma textura com as alturas do terreno,
// então a cor, a transparência e a espuma da arrebentação seguem a costa.

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float height_origin = -240.0;
uniform float height_step = 2.0;
uniform float height_n = 241.0;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.2, 0.6, 0.55);
uniform vec3 deep_color : source_color = vec3(0.02, 0.13, 0.22);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 huv = ((wpos.xz - vec2(height_origin)) / height_step + 0.5) / height_n;
	float h = texture(height_tex, huv).r;
	float depth = max(wpos.y - h, 0.0);

	float n = texture(foam_tex, wpos.xz * 0.06 + vec2(TIME * 0.012, TIME * 0.007)).r;

	vec3 col = mix(shallow_color, deep_color, 1.0 - exp(-depth * 0.28));

	vec2 uv1 = wpos.xz * 0.09 + vec2(TIME * 0.022, TIME * 0.013);
	vec2 uv2 = wpos.xz * 0.05 + vec2(-TIME * 0.016, TIME * 0.019);
	vec3 nm = mix(texture(normal_tex, uv1).rgb, texture(normal_tex, uv2).rgb, 0.5);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.1;

	// Espuma: uma borda na linha d'água e faixas que andam em direção à areia.
	float shore = 1.0 - smoothstep(0.0, 0.9, depth);
	float wave = sin(depth * 7.0 + TIME * 1.3 + n * 4.0);
	float band = smoothstep(0.55, 0.95, wave) * shore * smoothstep(0.3, 0.6, n);
	float edge = 1.0 - smoothstep(0.0, 0.06 + n * 0.1, depth);
	float foam = clamp(max(edge, band * 0.85), 0.0, 1.0);

	ALBEDO = mix(col, vec3(0.92, 0.94, 0.9), foam);
	ROUGHNESS = mix(0.05, 0.7, foam);
	SPECULAR = 0.6;
	float a = clamp(0.38 + depth * 0.13, 0.0, 1.0);
	ALPHA = mix(a, 0.95, foam) * smoothstep(0.0, 0.03, depth);
}
