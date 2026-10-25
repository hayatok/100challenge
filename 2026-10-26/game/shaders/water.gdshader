shader_type canvas_item;
render_mode unshaded;

uniform bool reduced_motion = false;
uniform vec4 water_tint : source_color = vec4(0.42, 0.66, 0.67, 1.0);

void fragment() {
	float t = reduced_motion ? 0.0 : TIME;
	vec2 uv = UV;
	uv.x += sin(uv.y * 25.0 + t * 0.65) * 0.003;
	vec4 tex = texture(TEXTURE, uv);
	float wave = sin(UV.y * 65.0 + UV.x * 13.0 - t * 1.2);
	float glint = pow(max(wave, 0.0), 16.0) * 0.055;
	COLOR = vec4(tex.rgb * water_tint.rgb + glint, tex.a * COLOR.a);
}
