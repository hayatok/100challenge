shader_type spatial;
render_mode unshaded, cull_front;

void vertex() { VERTEX += NORMAL * 0.00055; }
void fragment() { ALBEDO = vec3(0.055, 0.037, 0.060); }
