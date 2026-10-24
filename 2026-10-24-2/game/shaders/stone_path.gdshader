shader_type spatial;
render_mode diffuse_burley;

uniform vec3 stone_color : source_color = vec3(0.64, 0.61, 0.53);
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 tile = world_point.xz / vec2(2.8, 3.5);
	tile.x += mod(floor(tile.y), 2.0) * 0.5;
	vec2 edge = min(fract(tile), 1.0 - fract(tile));
	vec2 feather = max(fwidth(tile), vec2(0.001));
	float seam = min(smoothstep(0.012, 0.012 + feather.x, edge.x),
		smoothstep(0.012, 0.012 + feather.y, edge.y));
	float variation = fract(sin(dot(floor(tile), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(stone_color * 0.69, stone_color * (0.94 + variation * 0.12), seam);
	ROUGHNESS = 0.9;
}
