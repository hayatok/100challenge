shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

// The track still casts shadows. The painted fill keeps the line art legible in them.
uniform sampler2D painted : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 key_direction = vec3(-0.52, 0.77, -0.37);
uniform vec3 shadow_tint = vec3(0.73, 0.75, 0.88);
uniform vec3 sun_tint = vec3(1.02, 1.00, 0.98);
uniform vec3 rim_tint = vec3(0.96, 0.83, 0.74);
uniform bool facial_features = false;
uniform float visibility_from_camera = 1.0;

void fragment() {
	if (visibility_from_camera < 1.0) {
		// Ordered screen-door fade keeps solid hair, eyes and cutouts in the depth buffer.
		const float threshold[16] = {0.5, 8.5, 2.5, 10.5, 12.5, 4.5, 14.5, 6.5, 3.5, 11.5, 1.5, 9.5, 15.5, 7.5, 13.5, 5.5};
		ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
		if (threshold[cell.y * 4 + cell.x] > visibility_from_camera * 16.0) { discard; }
	}
	vec3 paint = texture(painted, UV).rgb;
	vec3 n = normalize(NORMAL);
	vec3 key = normalize(mat3(VIEW_MATRIX) * key_direction);
	float facing_light = dot(n, key);
	float wrap = smoothstep(-0.37, 0.63, facing_light);
	vec3 tone = mix(shadow_tint, sun_tint, wrap);
	if (facial_features) {
		tone = mix(tone, vec3(1.0), 0.70);
	}
	float edge = pow(1.0 - max(dot(n, normalize(VIEW)), 0.0), 3.5);
	float rim = edge * smoothstep(-0.5, 0.18, facing_light);
	float lock = max(1.0 - step(0.3125, UV.y), step(0.848, UV.x) * step(0.566, UV.y) * (1.0 - step(0.795, UV.y)));
	float ribbon = step(0.692, UV.x) * (1.0 - step(0.845, UV.x)) * step(0.545, UV.y) * (1.0 - step(0.801, UV.y));
	float satin = facial_features ? 0.0 : max(lock, ribbon * 0.75);
	float sheen = smoothstep(0.66, 0.94, dot(n, normalize(VIEW + key)));
	vec3 illustrated = paint * tone + rim * rim_tint * (facial_features ? 0.025 : 0.14);
	illustrated += (0.014 + paint * 0.065) * satin * sheen;
	EMISSION = illustrated * 0.93;
	ALBEDO = paint * 0.07;
}

void light() {
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * (0.45 + 0.55 * max(dot(normalize(NORMAL), LIGHT), 0.0)) / PI;
}

