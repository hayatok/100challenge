shader_type spatial;
render_mode unshaded;

uniform float swell_time = 0.0;
uniform vec4 lagoon : source_color = vec4(0.046, 0.63, 0.73, 1.0);
uniform vec4 blue_water : source_color = vec4(0.028, 0.42, 0.64, 1.0);
uniform vec4 distant_water : source_color = vec4(0.43, 0.73, 0.88, 1.0);
uniform vec4 crest_color : source_color = vec4(0.74, 0.95, 0.98, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float glint(vec2 p, float t) {
	float a = sin(p.x * 1.22 + p.y * 1.76 + t * 1.35);
	float b = sin(p.x * 0.27 - p.y * 4.60 + sin(p.x * 0.83 - t) + t * 1.1);
	float c = cos(p.x * 2.09 + p.y * 1.41 - t * 0.74);
	float s = a * b + 0.39 * c;
	return smoothstep(0.84, 1.25, s);
}

float foam(float distance_to_edge, vec2 p, float t) {
	float ripple = 0.095 * sin(p.y * 4.8 + p.x * 4.0 + t * 2.1);
	float pattern = 0.54 + 0.46 * sin(p.y * 2.18 - p.x * 3.12 + t * 2.7);
	return (1.0 - smoothstep(0.045, 0.21, abs(distance_to_edge + ripple))) * pattern;
}

void fragment() {
	vec2 p = vec2(world_position.x, -world_position.z);
	float t = swell_time;
	float swell = sin(p.x * 0.53 + p.y * 0.76 + t * 0.9)
		+ 0.42 * sin(p.x * 0.35 - p.y * 1.57 + t);
	float spread = 0.64 + 0.19 * swell + 0.1 * sin(p.y * 0.071 + p.x * 0.12);
	vec3 color = mix(blue_water.rgb, lagoon.rgb, clamp(spread, 0.0, 1.0));
	float distance_to_camera = length(CAMERA_POSITION_WORLD - world_position);
	float glints = 0.0;
	if (distance_to_camera < 49.0) {
		glints = glint(p, t) * (1.0 - smoothstep(11.0, 49.0, distance_to_camera));
	}
	float broad = smoothstep(0.91, 1.34, swell) * 0.10;
	float foam_mask = 0.0;
	if (abs(p.x) < 9.0 && p.y >= -6.0 && p.y <= 158.0) {
		float edge = abs(p.x) - 4.87;
		if (p.y > 52.0 && p.y < 94.0) {
			float drift = 3.5 * sin(3.14159265 * (p.y - 52.0) / 42.0);
			float outside = abs(p.x - (3.0 + drift)) - 2.16;
			float inside = abs(p.x + 2.45) - 2.4;
			edge = abs(outside) < abs(inside) ? outside : inside;
		}
		if (abs(edge) < 0.31) {
			foam_mask = foam(edge, p, t);
		}
	}
	float highlights = clamp(glints * 0.75 + broad + 0.8 * foam_mask, 0.0, 0.93);
	color = mix(color, crest_color.rgb, highlights);
	float haze = smoothstep(20.0, 185.0, distance_to_camera);
	ALBEDO = mix(color, distant_water.rgb, haze * 0.91);
}
