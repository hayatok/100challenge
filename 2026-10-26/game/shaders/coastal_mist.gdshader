shader_type canvas_item;
render_mode unshaded;
uniform float motion_time = 0.0;
varying vec2 map_position;
void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float clouds = sin(map_position.x * 0.017 + motion_time * 0.04) * sin(map_position.y * 0.023 - motion_time * 0.025);
	clouds += sin((map_position.x + map_position.y) * 0.008 + motion_time * 0.02) * 0.5;
	COLOR = vec4(COLOR.rgb + clouds * 0.022, COLOR.a);
}
