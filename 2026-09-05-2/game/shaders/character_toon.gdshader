shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool has_texture = false;
uniform bool face_material = false;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 color = base_color.rgb;
	if (has_texture) { color *= texture(albedo_texture, UV).rgb; }
	float light = dot(normalize(world_normal), normalize(vec3(-0.4, 0.8, 0.65)));
	vec3 shade = face_material ? vec3(0.95, 0.91, 0.92) : vec3(0.49, 0.46, 0.57);
	vec3 middle = face_material ? vec3(0.975, 0.96, 0.96) : vec3(0.80, 0.75, 0.81);
	vec3 tint = mix(shade, middle, smoothstep(-0.15, 0.22, light));
	tint = mix(tint, vec3(1.0), smoothstep(0.22, 0.65, light));
	ALBEDO = color * tint;
}
