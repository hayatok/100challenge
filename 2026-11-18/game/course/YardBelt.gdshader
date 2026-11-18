shader_type spatial;

uniform float race_time = 0.0;
uniform float speed_mps = -1.55;
uniform vec2 dimensions = vec2(5.0, 8.0);
uniform vec4 rubber : source_color = vec4(0.16, 0.23, 0.27, 1.0);
uniform vec4 arrow : source_color = vec4(0.52, 0.91, 0.80, 1.0);
varying vec3 surface_position;

void vertex() {
	surface_position = VERTEX;
}

void fragment() {
	// The plane's local X axis is world X; arrows translate at the transport speed.
	vec2 local = surface_position.xz;
	float movement = local.x - speed_mps * race_time;
	float z = abs(mod(local.y + 0.53, 1.06) - 0.53);
	float x = mod(movement + 0.61, 1.22) - 0.61;
	float head = abs(x - (z * 1.05 - 0.24));
	float thickness = 1.0 - smoothstep(0.067, 0.086 + fwidth(head), head);
	float chevron = thickness * (1.0 - smoothstep(0.31, 0.345, z));
	float edge_x = dimensions.x * 0.5 - abs(local.x);
	float edge_z = dimensions.y * 0.5 - abs(local.y);
	float inside = smoothstep(0.08, 0.25, min(edge_x, edge_z));
	float seam = abs(fract(movement * 4.2) - 0.5);
	float rib = smoothstep(0.35, 0.48, seam);
	vec3 deck = rubber.rgb * (0.90 + 0.13 * rib);
	ALBEDO = mix(deck, arrow.rgb, chevron * inside);
	EMISSION = arrow.rgb * chevron * inside * 0.20;
	ROUGHNESS = 0.76;
}
