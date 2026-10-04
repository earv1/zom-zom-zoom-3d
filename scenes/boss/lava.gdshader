shader_type spatial;
// Molten lava: slowly churning crust breaking up into bright hot veins.
render_mode unshaded;

uniform vec3 hot : source_color = vec3(1.0, 0.82, 0.3);
uniform vec3 mid : source_color = vec3(0.95, 0.32, 0.05);
uniform vec3 crust : source_color = vec3(0.22, 0.04, 0.02);

varying vec3 world_pos;

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
		p = p * 2.1 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.045;
	float n = fbm(uv + vec2(TIME * 0.04, TIME * 0.025));
	float n2 = fbm(uv * 2.4 - vec2(TIME * 0.07, -TIME * 0.05));
	float heat = n * 0.6 + n2 * 0.5;
	vec3 col = mix(crust, mid, smoothstep(0.42, 0.62, heat));
	col = mix(col, hot, smoothstep(0.66, 0.85, heat));
	ALBEDO = col * (1.0 + 0.15 * sin(TIME * 2.5 + n * 12.0));
}
