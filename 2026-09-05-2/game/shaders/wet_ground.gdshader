shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
float patch(vec2 p) {
	return sin(p.x*.83+sin(p.y*.73))*sin(p.y*.67+cos(p.x*.42))*.5+.5;
}
void fragment() {
	vec2 uv = UV * vec2(8.6,5.4);
	vec3 tex = texture(asphalt,uv).rgb;
	float damp = smoothstep(.28,.73,patch(UV*vec2(43.,27.)));
	ALBEDO = tex * mix(vec3(.75,.78,.81),vec3(.58,.64,.70),damp);
	ROUGHNESS = mix(.82,.55,damp);
	METALLIC = 0.0;
	SPECULAR = .3;
	float dx = texture(asphalt,uv+vec2(.001,0)).r-texture(asphalt,uv-vec2(.001,0)).r;
	float dy = texture(asphalt,uv+vec2(0,.001)).r-texture(asphalt,uv-vec2(0,.001)).r;
	NORMAL_MAP = normalize(vec3(-dx*.7,-dy*.7,1.))*.5+.5;
	NORMAL_MAP_DEPTH = .025;
}
