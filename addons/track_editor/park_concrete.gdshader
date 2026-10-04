shader_type spatial;
// Park surface styled like the track's road: dark asphalt with subtle wear and
// faint lane lines every 8 m, so speed and scale read at a glance. Double-sided.
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.24, 0.24, 0.25);
uniform vec3 stain_color : source_color = vec3(0.17, 0.17, 0.18);
uniform vec3 line_color : source_color = vec3(0.92, 0.92, 0.9);
uniform float joint_spacing = 8.0;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz + vec2(world_pos.y * 0.7);
	float mottle = vnoise(uv * 0.35) * 0.6 + vnoise(uv * 1.7) * 0.4;
	vec2 g = abs(fract(uv / joint_spacing) - 0.5) * joint_spacing;
	float joint = 1.0 - smoothstep(0.06, 0.12, min(g.x, g.y));
	ALBEDO = mix(mix(base_color, stain_color, mottle * 0.6), line_color, joint * 0.35);
	ROUGHNESS = 0.85;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
