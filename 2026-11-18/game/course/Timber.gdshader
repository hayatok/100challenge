shader_type spatial;
render_mode diffuse_burley;

varying vec3 board_position;

void vertex() {
	// Instance axis lengths keep grain consistent across board widths.
	vec3 dimensions = vec3(length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	board_position = VERTEX * dimensions;
}

void fragment() {
	vec3 position = board_position;
	float phase = COLOR.r * 253.24 + COLOR.g * 76.17;
	float across = position.z + position.y * 0.81;
	float curve = sin(position.x * 1.61 + phase) * sin(position.x * 0.71 - phase);
	float grain = across * 103.0 + curve * 2.7;
	float detail = 1.0 - smoothstep(0.35, 4.0, fwidth(grain));
	float streak = sin(grain) * sin(across * 519.0 + position.x * 4.9 + phase);
	float coarse = sin(across * 36.0 + curve * 0.8 + phase);
	float patina = sin(across * 20.0 + phase) * sin(position.x * 0.31 - phase);
	float ends = smoothstep(0.36, 0.497, abs(UV.x));
	float tone = 0.97 + detail * (0.048 * streak + 0.061 * coarse)
		+ 0.061 * patina - ends * 0.032;
	ALBEDO = COLOR.rgb * tone;
	ROUGHNESS = 0.67 + 0.12 * coarse;
	SPECULAR = 0.32;
}
