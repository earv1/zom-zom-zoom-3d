shader_type spatial;
// Ground target circle for the eye laser. Drawn on a flat quad: rotating dashed
// rim, a fill that grows from the centre while charging, and a hot pulsing core
// once the beam is live.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.12, 0.05, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;   // charge fill
uniform float firing : hint_range(0.0, 1.0) = 0.0;     // beam live
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float heat = max(progress, firing);
	float pulse = 0.5 + 0.5 * sin(TIME * mix(5.0, 22.0, heat));

	float rim = smoothstep(0.84, 0.91, r) * (1.0 - smoothstep(0.96, 1.0, r));
	float ang = atan(p.y, p.x) / 6.2831853;
	float dash = step(0.45, fract(ang * 10.0 + TIME * mix(0.3, 1.5, heat)));
	rim *= mix(0.55, 1.0, dash);

	float fill = (1.0 - smoothstep(progress - 0.04, progress, r)) * (0.18 + 0.12 * pulse);
	float cross_hair = (1.0 - smoothstep(0.0, 0.025, min(abs(p.x), abs(p.y)))) * (1.0 - smoothstep(0.15, 0.35, r));
	float core = firing * (1.0 - r) * (0.45 + 0.35 * pulse);

	ALBEDO = mix(color.rgb, vec3(1.0, 0.85, 0.7), firing * (1.0 - r) * 0.6);
	ALPHA = clamp((rim + fill + cross_hair * 0.8 + core) * fade, 0.0, 1.0);
}
