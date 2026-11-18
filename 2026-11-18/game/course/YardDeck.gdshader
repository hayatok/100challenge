shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.48, 0.53, 0.58, 1.0);
uniform bool timber = false;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_position;
	if (timber) {
		float row = floor(-p.z / 0.54);
		float grain = p.z * 92.0 + sin(p.x * 1.17 + row * 0.46) * 2.4;
		float clarity = 1.0 - smoothstep(0.55, 4.8, fwidth(grain));
		float variation = 0.88 + 0.12 * fract(sin(row * 135.6) * 4375.3);
		float seam = smoothstep(0.0, 0.05 + fwidth(p.z), fract(-p.z / 0.54));
		ALBEDO = base_color.rgb * (variation + 0.081 * sin(grain) * clarity) * mix(0.68, 1.0, seam);
	} else {
		float speckle = sin(p.x * 24.6 + p.z * 29.5) * sin(p.x * 26.7 - p.z * 38.1);
		float panel = smoothstep(0.0, 0.018 + fwidth(p.z), abs(fract(p.z / 5.0) - 0.5));
		float wear = 0.93 + 0.028 * sin(p.z * 2.77 + p.x * 0.83) + 0.036 * sin(p.x * 2.65 + p.z * 0.44);
		ALBEDO = base_color.rgb * mix(0.73, 1.0, panel) * (wear + speckle * 0.025);
	}
	ROUGHNESS = 0.84;
}
