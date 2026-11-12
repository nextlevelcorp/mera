shader_type canvas_item;
// Prototype water for the first-person view. Drawn in a low-resolution
// SubViewport and scaled up. Driven by three simulation values:
// chop (0..1), visibility (0..1) and light (0..1).

uniform float chop = 0.3;
uniform float visibility = 0.5;
uniform float light = 1.0;
uniform float horizon = 0.38;
uniform vec3 sky_top : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.85, 0.95);
uniform vec3 water_deep : source_color = vec3(0.03, 0.2, 0.35);
uniform vec3 water_shallow : source_color = vec3(0.1, 0.45, 0.55);
uniform vec3 bottom_color : source_color = vec3(0.55, 0.5, 0.38);

float wave(vec2 p, vec2 dir, float freq, float speed) {
	return sin(dot(p, dir) * freq + TIME * speed);
}

void fragment() {
	vec2 uv = UV;
	if (uv.y < horizon) {
		float g = uv.y / horizon;
		COLOR = vec4(mix(sky_top, sky_horizon, g * g), 1.0);
	} else {
		// v: 0 at the horizon, 1 at the angler's feet. dist: far is large.
		float v = (uv.y - horizon) / (1.0 - horizon);
		float dist = 1.0 / (v * 0.9 + 0.03);
		vec2 p = vec2((uv.x - 0.5) * dist * 2.0, dist);

		float amp = 0.15 + chop * 0.85;
		float swell = wave(p, normalize(vec2(0.3, 1.0)), 1.6, 1.1) * 0.5;
		float mid = wave(p, normalize(vec2(-0.6, 1.0)), 3.1, 1.7) * 0.3;
		float ripple = wave(p, normalize(vec2(0.9, 0.4)), 6.3, 2.6) * 0.2 * chop;
		float h = swell + mid + ripple;

		vec3 base = mix(water_shallow, water_deep, smoothstep(0.0, 0.6, 1.0 - v));
		// Clear, bright water shows the bottom close to the angler.
		float near = smoothstep(1.0 - visibility * 0.7 - 0.05, 1.0, v);
		base = mix(base, bottom_color, near * visibility * 0.8);
		// Far water reflects the sky.
		float fresnel = pow(1.0 - v, 3.0);
		vec3 col = mix(base, sky_horizon, fresnel * 0.7);
		// Wave shading, sparkle and whitecaps.
		col += h * amp * 0.10;
		col += smoothstep(0.55, 0.8, h) * light * 0.12 * (1.0 - fresnel);
		// Whitecaps: small crests far out, fading towards the angler's feet.
		float crest = h + wave(p, normalize(vec2(0.5, 0.8)), 11.0, 3.4) * 0.25;
		float foam = smoothstep(0.78, 0.95, crest) * smoothstep(0.45, 1.0, chop) * (1.0 - 0.85 * v);
		col = mix(col, vec3(0.92, 0.95, 0.97) * (0.35 + 0.65 * light), foam * 0.8);
		COLOR = vec4(col, 1.0);
	}
}
