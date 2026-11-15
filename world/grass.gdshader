shader_type spatial;
render_mode cull_disabled;

// Capim: balança com o vento e vai de verde escuro na base a palha na ponta.

uniform vec3 base_color : source_color = vec3(0.12, 0.2, 0.06);
uniform vec3 tip_color : source_color = vec3(0.42, 0.47, 0.18);
uniform vec3 dry_color : source_color = vec3(0.62, 0.55, 0.3);

varying float tone;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = UV.y * UV.y;
	float w = sin(TIME * 1.6 + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(TIME * 3.1 + wp.x * 1.3);
	VERTEX.x += w * 0.07 * k;
	VERTEX.z += w * 0.04 * k;
	tone = fract(sin(dot(floor(MODEL_MATRIX[3].xz * 7.0), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// normal sempre para cima: os dois lados da lâmina recebem a mesma luz
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = mix(base_color, mix(tip_color, dry_color, tone * 0.7), UV.y);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
