shader_type spatial;
// Arena glass: faint blue tint, stronger at glancing angles (fresnel), with thin
// panel lines so the curve reads while you drive on it. Double-sided.
render_mode blend_mix, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.62, 0.84, 1.0, 0.05);
uniform vec3 frame_color : source_color = vec3(0.85, 0.95, 1.0);
uniform float panel = 12.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	vec3 g = abs(fract(world_pos / panel) - 0.5) * panel;
	float frame = 1.0 - smoothstep(0.05, 0.2, min(min(g.x, g.y), g.z));
	ALBEDO = mix(tint.rgb, frame_color, frame);
	ALPHA = clamp(tint.a + fres * 0.22 + frame * 0.17, 0.0, 0.45);
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
}
