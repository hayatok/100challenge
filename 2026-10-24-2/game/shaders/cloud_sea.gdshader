shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform float drift_time = 0.0;
uniform float billow_height = 2.4;
uniform vec3 shadow_color : source_color = vec3(0.40, 0.59, 0.67);
uniform vec3 body_color : source_color = vec3(0.72, 0.82, 0.83);
uniform vec3 sunlight_color : source_color = vec3(0.98, 0.95, 0.86);
uniform vec3 haze_color : source_color = vec3(0.82, 0.90, 0.92);

varying vec3 cloud_world;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), blend.x), blend.y);
}

float cloud_noise(vec2 p) {
	float result = soft_noise(p) * 0.57;
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(17.3, 8.1);
	result += soft_noise(p) * 0.28;
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(9.2, 31.7);
	return result + soft_noise(p) * 0.15;
}

vec2 soft_billow(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 blended = vec2(0.0);
	float total_weight = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = vec2(hash21(cell + neighbor), hash21(cell + neighbor + vec2(57.2, 13.7)));
			vec2 delta = neighbor + 0.2 + point * 0.6 - local;
			float weight = max(0.0, 1.0 - dot(delta, delta));
			weight *= weight;
			weight *= weight;
			blended += delta * weight;
			total_weight += weight;
		}
	}
	return blended / max(0.001, total_weight) * 1.8;
}

void vertex() {
	cloud_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 flow = vec2(drift_time * 0.007, drift_time * -0.004);
	float billow = cloud_noise(cloud_world.xz * 0.018 + flow);
	VERTEX.y += smoothstep(0.23, 0.78, billow) * billow_height;
	cloud_world.y += smoothstep(0.23, 0.78, billow) * billow_height;
}

void fragment() {
	vec2 flow = vec2(drift_time * 0.007, drift_time * -0.004);
	vec2 p = cloud_world.xz * 0.018 + flow;
	float wisps = cloud_noise(p * 2.2 + vec2(5.7, 21.3) - flow * 0.4);
	vec2 billow = soft_billow(p * 0.72 + (wisps - 0.5) * 0.22);
	float dome = sqrt(max(0.04, 1.0 - dot(billow, billow) * 1.65));
	vec3 cloud_normal = normalize(vec3(-billow.x * 1.4, dome, -billow.y * 1.4));
	float light = dot(cloud_normal, normalize(vec3(-0.55, 0.76, -0.35)));
	float body = smoothstep(0.24, 0.80, dome);
	vec3 color = mix(shadow_color, body_color, body * 0.72);
	color = mix(color, sunlight_color, smoothstep(0.48, 0.95, light) * body * 0.88);
	// Fine, slow wisps soften the boundaries of the larger rounded billows.
	color = mix(color, sunlight_color, smoothstep(0.60, 0.79, wisps) * 0.18);
	float distance_to_eye = length(cloud_world.xz - CAMERA_POSITION_WORLD.xz);
	float haze = smoothstep(160.0, 1000.0, distance_to_eye);
	ALBEDO = mix(color, haze_color, haze * 0.94);
	ROUGHNESS = 1.0;
}
