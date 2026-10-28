shader_type canvas_item;
render_mode unshaded;

uniform sampler2D route_mask : filter_nearest, repeat_disable;
uniform vec2 map_center = vec2(0.0);
uniform float map_scale = 1.0;
uniform vec2 map_dimensions = vec2(25.0);
uniform vec2 player_feet = vec2(-1000.0);
varying vec2 map_position;

void vertex() {
	map_position = map_center + VERTEX * map_scale;
}
void fragment() {
	vec4 painted = COLOR;
	vec2 cell = floor(map_position / 64.0);
	float inside = step(0.0, cell.x) * step(0.0, cell.y) * step(cell.x, map_dimensions.x - 1.0) * step(cell.y, map_dimensions.y - 1.0);
	float route = texture(route_mask, (cell + vec2(0.5)) / map_dimensions).r * inside;
	// The known path remains visible through architecture that projects over it.
	float path_alpha = mix(1.0, 0.58, route);
	vec2 to_player = (map_position - player_feet) * vec2(1.0, 0.8);
	float near_player = 1.0 - smoothstep(42.0, 86.0, length(to_player));
	float clearance = mix(path_alpha, min(path_alpha, 0.14), near_player);
	COLOR = vec4(painted.rgb, painted.a * clearance);
}
