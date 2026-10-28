shader_type canvas_item;
render_mode unshaded;
uniform float motion_time = 0.0;
uniform bool reduced_motion = false;
uniform vec4 water_tint : source_color = vec4(1.0);
uniform vec4 deep_color : source_color = vec4(0.176, 0.494, 0.553, 1.0);
uniform vec2 flow_direction = vec2(0.08, 0.35);
uniform float wave_density = 90.0;
uniform float glint_strength = 0.035;
varying vec2 map_position;

void vertex() {
	map_position = VERTEX;
}

void fragment() {
	float t = motion_time;
	vec4 tex = texture(TEXTURE, UV);
	// Broad continuous bands preserve a calm surface across tile boundaries.
	vec2 p = map_position + flow_direction * t * 13.0;
	float depth = smoothstep(-0.7, 0.85, sin(p.y * 0.025 + sin(p.x * 0.009) * 0.7));
	vec3 sea = mix(tex.rgb * water_tint.rgb, deep_color.rgb, depth * 0.28);
	float wave = sin(p.y * 0.072 + sin(p.x * 0.021) * 0.6);
	float glint = pow(max(wave, 0.0), 38.0) * glint_strength;
	COLOR = vec4(sea + vec3(glint * 0.65, glint, glint), tex.a * COLOR.a);
}
