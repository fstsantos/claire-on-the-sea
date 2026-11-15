shader_type sky;

// Céu com atmosfera, sol com halo e duas camadas de nuvens procedurais
// (cúmulos iluminados pelo sol + cirros altos), que se movem com o vento.

uniform vec3 top_color : source_color = vec3(0.1, 0.25, 0.52);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.76, 0.78);
uniform vec3 ground_color : source_color = vec3(0.2, 0.26, 0.28);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.8, 0.55);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.96, 0.9);
uniform vec3 cloud_shade : source_color = vec3(0.36, 0.39, 0.44);
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform float coverage = 0.5;
uniform float cloud_speed = 0.006;

float density(vec2 uv, float t) {
	float n = texture(noise_a, uv * 0.6 + t * vec2(1.0, 0.3)).r * 0.52;
	n += texture(noise_b, uv * 1.7 + t * vec2(1.6, 0.7)).r * 0.3;
	n += texture(noise_a, uv * 4.3 - t * vec2(0.8, 2.0)).r * 0.12;
	n += texture(noise_b, uv * 9.1 + t * vec2(2.0, -1.0)).r * 0.06;
	return n;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float sd = max(dot(dir, sun), 0.0);

	// Atmosfera: azul no alto, bruma clara no horizonte, mais quente perto do sol.
	float t = pow(1.0 - max(h, 0.0), 3.5);
	vec3 col = mix(top_color, horizon_color, t);
	col = mix(col, sun_tint, pow(sd, 5.0) * 0.35 * (0.4 + 0.6 * t));
	col += sun_tint * pow(sd, 90.0) * 0.6;

	if (h > -0.02) {
		float hh = max(h, 0.0);
		float ang = acos(clamp(dot(dir, sun), -1.0, 1.0));
		col += vec3(1.0, 0.93, 0.8) * 9.0 * (1.0 - smoothstep(0.017, 0.024, ang));

		vec2 uv = dir.xz / (hh + 0.11) * 0.42;
		float tt = TIME * cloud_speed;
		float fade = smoothstep(0.0, 0.16, hh);

		// Cirros: faixas finas e esticadas bem no alto.
		float ci = texture(noise_b, uv * vec2(0.25, 0.9) + tt * 0.4).r;
		ci *= texture(noise_a, uv * vec2(1.1, 3.0) - tt * 0.3).r * 1.8;
		col = mix(col, cloud_lit, smoothstep(0.3, 0.6, ci) * 0.4 * fade);

		// Cúmulos: a densidade na direção do sol decide o lado claro e o lado escuro.
		float d = density(uv, tt);
		float c = smoothstep(coverage, coverage + 0.1, d);
		vec2 sdir = normalize(sun.xz + vec2(0.0001));
		float d2 = density(uv + sdir * 0.09, tt);
		float lit = clamp(0.6 + (d - d2) * 7.0, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit * (0.9 + 0.5 * pow(sd, 3.0)), lit);
		cc = mix(cc, cloud_shade * 0.75, smoothstep(coverage + 0.1, coverage + 0.3, d) * 0.6);
		cc += sun_tint * pow(sd, 14.0) * (1.0 - c) * 1.2;
		cc = mix(horizon_color, cc, 0.25 + 0.75 * fade);
		col = mix(col, cc, c * smoothstep(0.0, 0.07, hh));
	}
	if (h < 0.0) {
		col = mix(col, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	COLOR = col;
}
