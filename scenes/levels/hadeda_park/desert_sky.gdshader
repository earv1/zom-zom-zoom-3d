shader_type sky;
// Desert sky: deep blue zenith, pale dusty horizon, warm dust band, sun disc
// with glow and wispy high cirrus. Sun direction comes from the scene's
// first DirectionalLight3D.

uniform vec3 zenith_color : source_color = vec3(0.16, 0.36, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.80, 0.70);
uniform vec3 dust_color : source_color = vec3(0.93, 0.68, 0.45);
uniform vec3 ground_color : source_color = vec3(0.72, 0.56, 0.38);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.62);
uniform float sun_size = 0.9995;          // cosine of the sun disc radius
uniform float cloud_coverage = 0.45;
uniform float cloud_speed = 0.004;

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;

	vec3 col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), 0.45));
	col = mix(col, dust_color, exp(-max(h, 0.0) * 9.0) * 0.55);        // warm dust low on the horizon
	col = mix(col, ground_color, smoothstep(0.0, -0.08, h));            // below the horizon

	// wispy cirrus, stretched along the wind and fading near the horizon
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.18) * vec2(1.0, 2.6) + vec2(TIME * cloud_speed, 0.0);
		float c = fbm(uv * 1.6);
		c = smoothstep(1.0 - cloud_coverage, 1.0, c) * smoothstep(0.0, 0.25, h);
		col = mix(col, vec3(1.0, 0.97, 0.92), c * 0.65);
	}

	// sun disc + glow, warmed toward the horizon
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		float disc = smoothstep(sun_size - 0.0004, sun_size, d);
		float glow = pow(max(d, 0.0), 180.0) * 0.8 + pow(max(d, 0.0), 12.0) * 0.18;
		col += sun_color * (disc * 6.0 + glow) * LIGHT0_ENERGY;
	}

	COLOR = col;
}
