shader_type sky;

uniform vec4 horizon : source_color = vec4(0.69, 0.86, 0.96, 1.0);
uniform vec4 zenith : source_color = vec4(0.21, 0.53, 0.88, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.74, 0.87, 0.97, 1.0);
uniform vec4 cloud_sun : source_color = vec4(1.0, 0.99, 0.96, 1.0);

float hash(vec2 p) {
	vec3 n = fract(vec3(p.xyx) * 0.1031);
	n += dot(n, n.yzx + 33.33);
	return fract((n.x + n.y) * n.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), w.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), w.x), w.y);
}

float cloud(vec2 p) {
	float value = 0.56 * noise(p);
	value += 0.26 * noise(p * 2.06 + 13.8);
	value += 0.13 * noise(p * 4.19 + 8.1);
	value += 0.05 * noise(p * 8.32 + 7.2);
	return value;
}

vec3 cloud_sky(vec3 direction) {
	float height = max(direction.y, 0.0);
	vec3 clear = mix(horizon.rgb, zenith.rgb, pow(height, 0.49));
	if (height > 0.018) {
		vec2 p = direction.xz * 2.51 / (height + 0.17) + vec2(12.0, 19.0);
		float density = cloud(p);
		float definition = smoothstep(0.49, 0.66, density - 0.12 * cloud(p + vec2(-0.12, 0.19)));
		vec3 wisps = mix(cloud_shadow.rgb, cloud_sun.rgb, definition);
		float cover = smoothstep(0.52, 0.62, density) * smoothstep(0.018, 0.115, height);
		clear = mix(clear, wisps, cover);
	}
	return clear;
}

void sky() {
	// The sky is stationary. Shade the cubemap once, then sample it on screen.
	if (AT_CUBEMAP_PASS) {
		COLOR = cloud_sky(EYEDIR);
	} else {
		COLOR = textureLod(RADIANCE, EYEDIR, 0.0).rgb;
	}
}
