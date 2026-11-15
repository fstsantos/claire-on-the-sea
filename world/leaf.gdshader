shader_type spatial;
render_mode cull_disabled;

// Folha de palmeira: recorta os folíolos em forma de pente e balança com o vento.

uniform vec3 dark_color : source_color = vec3(0.07, 0.2, 0.06);
uniform vec3 light_color : source_color = vec3(0.3, 0.44, 0.13);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = UV.y * UV.y;
	float w = sin(TIME * 1.2 + wp.x * 0.3 + wp.z * 0.2) + 0.4 * sin(TIME * 2.7 + wp.z * 0.9);
	VERTEX.y += w * 0.12 * k;
	VERTEX.x += w * 0.05 * k;
}

void fragment() {
	float u = abs(UV.x * 2.0 - 1.0);
	float teeth = abs(fract(UV.y * 26.0) - 0.5) * 2.0;
	float reach = 0.1 + 0.9 * teeth;
	if (u > reach) {
		discard;
	}
	vec3 col = mix(light_color, dark_color, smoothstep(0.0, 0.9, u));
	col = mix(col, vec3(0.5, 0.5, 0.25), (1.0 - smoothstep(0.03, 0.09, u)) * 0.6);
	ALBEDO = col * (0.75 + 0.25 * teeth);
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.25, 0.35, 0.08);
}
