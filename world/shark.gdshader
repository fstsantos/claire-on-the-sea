shader_type spatial;
render_mode cull_disabled;
// Pele dos tubarões: dorso escuro e barriga clara, listras/pintas por espécie,
// e a ondulação do nado feita no vértice (cresce do focinho para a cauda).
// UV.x = altura no corpo (-1 barriga, 1 dorso), UV.y = posição ao longo do corpo.
// COLOR: r = aceita padrão, g = ponta de nadadeira, a = 0 nos olhos.

uniform vec3 top_color : source_color = vec3(0.35, 0.4, 0.45);
uniform vec3 belly_color : source_color = vec3(0.9, 0.9, 0.88);
uniform vec3 mark_color : source_color = vec3(0.1, 0.1, 0.1);
uniform vec3 tip_color : source_color = vec3(0.05, 0.05, 0.05);
uniform float stripes = 0.0;
uniform float spots = 0.0;
uniform float tips = 0.0;
uniform float body_len = 3.0;
uniform float swim_amp = 0.06;
uniform float swim_rate = 3.0;
instance uniform float phase = 0.0;

void vertex() {
	float t = UV.y;
	float wave = sin(t * 5.5 - TIME * swim_rate + phase);
	VERTEX.x += wave * swim_amp * body_len * (0.05 + t * t);
}

void fragment() {
	float t = UV.y;
	float v = UV.x;
	vec3 col = mix(belly_color, top_color, smoothstep(-0.5, 0.05, v));
	float upper = smoothstep(-0.35, 0.2, v) * COLOR.r;

	float band = sin(t * 105.0 + sin(v * 5.0) * 1.2);
	col = mix(col, mark_color, stripes * upper * smoothstep(0.35, 0.8, band) * 0.6 * (1.0 - 0.6 * smoothstep(0.55, 0.9, t)));

	vec2 p = vec2(t * body_len * 2.6, v * 4.5);
	p.x += 0.5 * floor(p.y);
	float spot = 1.0 - smoothstep(0.12, 0.2, length(fract(p) - 0.5));
	col = mix(col, mark_color, spots * upper * spot);

	col = mix(col, tip_color, tips * smoothstep(0.35, 0.75, COLOR.g));
	ALBEDO = col * COLOR.a;
	ROUGHNESS = 0.45;
	SPECULAR = 0.4;
}
