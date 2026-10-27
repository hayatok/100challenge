shader_type canvas_item;
render_mode unshaded;
uniform float motion_time = 0.0;
uniform bool reduced_motion = false;
uniform vec4 water_tint : source_color = vec4(0.97, 1.05, 1.03, 1.0);

void fragment() {
	float t = motion_time;
	vec2 uv = UV;
	uv.x += sin(uv.y * 32.0 + t * 0.7) * 0.0018;
	uv.y += cos(uv.x * 25.0 - t * 0.45) * 0.0011;
	vec4 tex = texture(TEXTURE, uv);
	float wave = sin(UV.y * 90.0 + UV.x * 19.0 - t * 0.8);
	float glint = pow(max(wave, 0.0), 22.0) * 0.08;
	COLOR = vec4(tex.rgb * water_tint.rgb + vec3(glint * 0.65, glint, glint), tex.a * COLOR.a);
}
