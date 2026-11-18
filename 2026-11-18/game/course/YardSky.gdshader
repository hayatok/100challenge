shader_type sky;

// Matches the left-of-course key light and the reflection in YardWater.
uniform vec3 sun_direction = vec3(-0.388, 0.105, -0.916);

void sky() {
	vec3 view = normalize(EYEDIR);
	float height = max(view.y, 0.0);
	float toward_sun = dot(view, normalize(sun_direction));
	float warmth = smoothstep(-0.5, 0.95, toward_sun);
	vec3 horizon = mix(vec3(0.76, 0.53, 0.61), vec3(1.0, 0.66, 0.35), warmth);
	vec3 dusk = vec3(0.27, 0.32, 0.54);
	vec3 zenith = vec3(0.12, 0.23, 0.43);
	vec3 gradient = mix(horizon, dusk, smoothstep(0.0, 0.39, height));
	gradient = mix(gradient, zenith, smoothstep(0.37, 1.0, height));
	float longitude = atan(view.x, -view.z);
	float clouds = sin(height * 93.0 + 0.35 * sin(longitude * 9.0));
	clouds += 0.46 * sin(height * 191.0 + longitude * 3.0);
	clouds = smoothstep(0.69, 1.28, clouds);
	clouds *= smoothstep(0.06, 0.16, height) * (1.0 - smoothstep(0.23, 0.46, height));
	clouds *= smoothstep(-0.4, 0.8, sin(longitude * 1.87) + sin(longitude * 4.27) * 0.4);
	gradient = mix(gradient, vec3(0.90, 0.50, 0.46), clouds * 0.48);
	float halo = pow(max(0.0, toward_sun), 20.0);
	float glow = pow(max(0.0, toward_sun), 210.0);
	float disk = smoothstep(0.99915, 0.99926, toward_sun);
	gradient = mix(gradient, vec3(1.0, 0.70, 0.37), halo * 0.40);
	gradient = mix(gradient, vec3(1.0, 0.77, 0.43), glow * 0.58);
	COLOR = mix(gradient, vec3(1.0, 0.92, 0.65), disk);
}
