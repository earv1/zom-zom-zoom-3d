shader_type spatial;
// Desert ground: sand with tonal variation and wind ripples up close; steep
// slopes turn into red rock with horizontal strata so mesas read as sandstone.

uniform vec3 sand_light : source_color = vec3(0.76, 0.58, 0.38);
uniform vec3 sand_dark : source_color = vec3(0.60, 0.43, 0.27);
uniform vec3 rock_color : source_color = vec3(0.62, 0.33, 0.20);
uniform vec3 rock_band : source_color = vec3(0.80, 0.52, 0.34);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(5.3, 1.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm(world_pos.xz * 0.018);
	vec3 sand = mix(sand_dark, sand_light, smoothstep(0.25, 0.75, n));

	float near = smoothstep(140.0, 15.0, length(VERTEX));
	float warp = fbm(world_pos.xz * 0.12) * 7.0;
	float ripple = sin((world_pos.x * 0.85 + world_pos.z * 0.4) * 2.3 + warp);
	sand *= 1.0 + ripple * 0.045 * near;

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock_mask = smoothstep(0.28, 0.5, slope + (n - 0.5) * 0.25);
	float strata = smoothstep(0.35, 0.65, fract(world_pos.y * 0.085 + fbm(world_pos.xz * 0.008) * 0.8));
	vec3 rock = mix(rock_color, rock_band, strata * 0.7) * (0.85 + 0.3 * n);

	ALBEDO = mix(sand, rock, rock_mask);
	ROUGHNESS = 0.96;
	SPECULAR = 0.2;
}
