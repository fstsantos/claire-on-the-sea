shader_type spatial;

// Troca as cores da paleta do modelo (Kenney Mini Characters, female-f)
// pelas cores da Claire: cabelo castanho, camiseta magenta, calça rosa, pele clara.
// A paleta é uma grade: cada célula (coluna u, faixa v) é uma parte do corpo.

uniform sampler2D palette : source_color, filter_nearest;
uniform bool is_head = false;
uniform vec3 hair : source_color = vec3(0.36, 0.22, 0.14);
uniform vec3 skin : source_color = vec3(0.96, 0.76, 0.62);
uniform vec3 shirt : source_color = vec3(0.78, 0.12, 0.48);
uniform vec3 skirt : source_color = vec3(0.9, 0.45, 0.68);
uniform vec3 shoes : source_color = vec3(0.97, 0.95, 0.96);

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

bool col(float u, float target) {
	return abs(u - target) < 0.03;
}

void fragment() {
	vec3 base = texture(palette, UV).rgb;
	vec3 c = base;
	// ref: cor mais clara da célula original, para manter o degradê de sombra dela
	vec3 ref = base;
	bool swap = true;
	float u = UV.x;
	float v = UV.y;
	if (is_head) {
		if (col(u, 0.094)) { c = hair * 1.12; ref = vec3(0.84, 0.5, 0.35); }
		else if (col(u, 0.219)) { c = hair; ref = vec3(0.57, 0.35, 0.25); }
		else if (col(u, 0.344)) { c = skin; ref = v < 0.5 ? base : vec3(0.82, 0.56, 0.4); }
		else { swap = false; }
	} else {
		if (col(u, 0.094)) {
			if (v < 0.6) { c = skirt; ref = vec3(0.36, 0.4, 0.77); }
			else { c = shirt; ref = vec3(0.91, 0.73, 0.44); }
		}
		else if (col(u, 0.219)) { c = skirt * 0.8; ref = vec3(0.46, 0.45, 0.64); }
		else if (col(u, 0.281)) { c = skin; ref = base; }
		else if (col(u, 0.344)) {
			if (v < 0.5) { c = shoes; ref = vec3(0.44, 0.29, 0.77); }
			else if (v < 0.7) { c = skin; ref = vec3(0.89, 0.67, 0.52); }
			else { c = shirt; ref = vec3(0.65, 0.64, 0.82); }
		}
		else if (col(u, 0.469)) { c = shirt; ref = vec3(0.24, 0.24, 0.27); }
		else { swap = false; }
	}
	if (swap) {
		c *= clamp(lum(base) / max(lum(ref), 0.001), 0.72, 1.08);
	}
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
}
