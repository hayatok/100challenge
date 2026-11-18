shader_type spatial;
render_mode unshaded;

uniform float race_time = 0.0;
uniform vec2 roof_center = vec2(-2.65, 113.75);
uniform vec2 roof_half_extent = vec2(1.45, 4.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_position.x, -world_position.z);
	vec2 from_camera = world_position.xz - CAMERA_POSITION_WORLD.xz;
	float distance_to_camera = length(from_camera);
	float t = race_time;
	float long_wave = sin(p.x * 0.57 + p.y * 1.6 - t * 1.1);
	float fine_wave = sin(p.x * 3.7 - p.y * 6.4 + t * 2.5 + long_wave);
	float water_tone = 0.50 + 0.20 * long_wave + 0.14 * fine_wave;
	vec3 water = mix(vec3(0.14, 0.32, 0.43), vec3(0.29, 0.56, 0.58), water_tone);
	float ripples = sin(p.y * 9.0 + sin(p.x * 1.7) * 1.2 - t * 2.0);
	float crest = smoothstep(0.84, 1.0, ripples) * smoothstep(0.20, 0.92, fine_wave);
	water = mix(water, vec3(0.55, 0.72, 0.70), crest * (1.0 - smoothstep(17.0, 64.0, distance_to_camera)) * 0.22);
	float glare = max(0.0, dot(normalize(from_camera + vec2(0.0001)), vec2(-0.39, -0.92)));
	float reflection = pow(glare, 34.0) * (0.22 + 0.66 * smoothstep(0.66, 1.0, ripples)) * smoothstep(4.0, 32.0, distance_to_camera);
	water = mix(water, vec3(0.98, 0.67, 0.43), reflection);
	float haze = smoothstep(23.0, 172.0, distance_to_camera);
	water = mix(water, vec3(0.64, 0.52, 0.58), haze * 0.82);

	// Deliberately keep this projection centered under the moving load.
	vec2 edge = abs(p - roof_center) - roof_half_extent;
	float load_shadow = 1.0 - smoothstep(-0.14, 0.5, max(edge.x, edge.y));
	ALBEDO = mix(water, vec3(0.13, 0.18, 0.30), load_shadow * 0.62);
}
