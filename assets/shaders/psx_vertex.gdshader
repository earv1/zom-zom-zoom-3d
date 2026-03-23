shader_type spatial;
render_mode unshaded, vertex_lighting, fog_disabled;

// PSX vertex shader: vertex jitter + affine texture warping

uniform float jitter_strength : hint_range(0.0, 2.0) = 0.5;
uniform float snap_resolution : hint_range(32.0, 512.0) = 160.0;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_triplanar = false;
uniform float triplanar_sharpness = 1.0;

varying float vertex_dist;

void vertex() {
	// Standard MVP
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snap vertices to grid in clip space (PSX vertex jitter)
	float w = clip_pos.w;
	float res = snap_resolution * (1.0 - jitter_strength * 0.5);
	clip_pos.xy = floor(clip_pos.xy / w * res + 0.5) / res * w;

	POSITION = clip_pos;
	vertex_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

vec4 triplanar_sample(sampler2D tex, vec3 world_pos, vec3 normal, float sharpness) {
	vec3 w = pow(abs(normal), vec3(sharpness));
	w /= (w.x + w.y + w.z);
	vec4 x = texture(tex, world_pos.yz);
	vec4 y = texture(tex, world_pos.xz);
	vec4 z = texture(tex, world_pos.xy);
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec4 tex;
	if (use_triplanar) {
		// Use world position for triplanar (need NODE_POSITION_WORLD in spatial)
		vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		tex = triplanar_sample(albedo_texture, world_pos, world_normal, triplanar_sharpness);
	} else {
		tex = texture(albedo_texture, UV);
	}

	ALBEDO = tex.rgb * albedo_color.rgb;

	// Simple distance fog for PSX feel
	float fog = clamp((vertex_dist - 80.0) / 120.0, 0.0, 0.6);
	ALBEDO = mix(ALBEDO, vec3(0.45, 0.5, 0.55), fog);
}
