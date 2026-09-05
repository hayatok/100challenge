shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(.4,.4,.4,1.);
uniform float course_height = .24;
uniform float block_width = .52;
varying vec3 position_world;
varying vec3 normal_world;
void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float random_cell(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
void fragment() {
	vec2 p = abs(normal_world.y)>.7 ? position_world.xz : (abs(normal_world.z)>.5 ? position_world.xy : position_world.zy);
	p /= vec2(block_width,course_height);
	p.x += mod(floor(p.y),2.)*.5;
	vec2 f = fract(p);
	vec2 edge = min(f,1.-f);
	float brick = smoothstep(.009,.027,edge.x)*smoothstep(.016,.045,edge.y);
	float variation = mix(.84,1.10,random_cell(floor(p)));
	float weather = sin(position_world.y*1.1+position_world.x*.37)*.025;
	ALBEDO = base_color.rgb * mix(.68,variation+weather,brick);
	ROUGHNESS = mix(.97,.8,brick);
	SPECULAR = .25;
}
