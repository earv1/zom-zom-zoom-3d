shader_type canvas_item;

// PSX post-process: resolution downscale, color banding, dithering

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform int color_depth : hint_range(2, 32) = 15;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.4;
uniform ivec2 target_resolution = ivec2(320, 240);

// 4x4 Bayer dithering matrix
float bayer4x4(ivec2 p) {
	int x = p.x % 4;
	int y = p.y % 4;
	int index = x + y * 4;
	float values[16] = float[16](
		0.0,  8.0,  2.0, 10.0,
		12.0, 4.0, 14.0,  6.0,
		3.0, 11.0,  1.0,  9.0,
		15.0, 7.0, 13.0,  5.0
	);
	return values[index] / 16.0 - 0.5;
}

void fragment() {
	// Pixelate to target resolution
	vec2 snapped_uv = floor(SCREEN_UV * vec2(target_resolution)) / vec2(target_resolution);
	snapped_uv += 0.5 / vec2(target_resolution);

	vec3 col = texture(screen_texture, snapped_uv).rgb;

	// Dithering
	ivec2 dither_coord = ivec2(SCREEN_UV * vec2(target_resolution));
	float dither = bayer4x4(dither_coord) * dither_strength;

	// Color depth reduction
	float levels = float(color_depth);
	col = floor((col + dither / levels) * levels) / levels;

	COLOR = vec4(col, 1.0);
}
