shader_type canvas_item;
// Prototype water, "realistic" variant. A camera ray is cast onto a flat sea,
// a sum of directional waves gives height and slope, and the colour comes
// from Fresnel reflection of the sky, the water body and a sun or moon
// highlight. Driven by the same three simulation values as the basic shader:
// chop (0..1), visibility (0..1) and light (0..1).

uniform float chop = 0.3;
uniform float visibility = 0.5;
uniform float light = 1.0;
uniform float horizon = 0.38;
uniform float aspect = 1.7778;
uniform vec3 sky_top : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.85, 0.95);
uniform vec3 water_deep : source_color = vec3(0.03, 0.2, 0.35);
uniform vec3 water_shallow : source_color = vec3(0.1, 0.45, 0.55);
uniform vec3 bottom_color : source_color = vec3(0.55, 0.5, 0.38);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sun_dir = vec3(0.2, 0.75, 0.6);

const float CAM_HEIGHT = 2.2;
const float FOV = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// One directional wave with sharpened crests. Adds height and slope.
void add_wave(vec2 p, vec2 dir, float k, float speed, float a, float sharp, inout float h, inout vec2 slope) {
	float phase = dot(p, dir) * k + TIME * speed;
	float s = max(0.5 + 0.5 * sin(phase), 0.0001);
	h += a * (pow(s, sharp) * 2.0 - 1.0);
	slope += dir * (a * sharp * pow(s, sharp - 1.0) * cos(phase) * k);
}

vec3 sky_color(vec3 d) {
	float up = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(sky_horizon, sky_top, pow(up, 0.5));
	float s = max(dot(d, sun_dir), 0.0);
	// A small disc, a tight halo and a wide soft glow.
	c += sun_color * (smoothstep(0.9993, 0.9997, s) * 3.0 + pow(s, 300.0) * 0.6 + pow(s, 12.0) * 0.18);
	return c;
}

void fragment() {
	vec2 uv = UV;
	vec3 ray = normalize(vec3((uv.x - 0.5) * aspect * FOV, (horizon - uv.y) * FOV, 1.0));
	if (ray.y >= 0.0) {
		vec3 c = sky_color(ray);
		// A hazy far shore on the horizon (generic, not a real skyline).
		float above = horizon - uv.y;
		float ridge = 0.010 + 0.022 * noise(vec2(uv.x * 5.0, 3.0)) + 0.007 * noise(vec2(uv.x * 37.0, 7.0));
		float land = 1.0 - smoothstep(ridge - 0.003, ridge, above);
		c = mix(c, sky_horizon * 0.62, land * 0.85);
		COLOR = vec4(c, 1.0);
	} else {
		float dist = CAM_HEIGHT / -ray.y;
		vec2 p = ray.xz * dist;

		float amp = 0.05 + 0.30 * chop;
		float sharp = 1.0 + 1.5 * chop;
		float h = 0.0;
		vec2 slope = vec2(0.0);
		add_wave(p, normalize(vec2(0.25, 1.0)), 0.35, 0.9, amp, sharp, h, slope);
		add_wave(p, normalize(vec2(-0.5, 1.0)), 0.62, 1.2, amp * 0.6, sharp, h, slope);
		add_wave(p, normalize(vec2(0.8, 0.6)), 1.1, 1.7, amp * 0.35, sharp, h, slope);
		add_wave(p, normalize(vec2(-0.9, 0.35)), 1.9, 2.3, amp * 0.22, 1.0, h, slope);
		add_wave(p, normalize(vec2(0.1, 1.0)), 3.3, 3.1, amp * 0.12 * (0.3 + chop), 1.0, h, slope);
		// Small wind ripples from noise.
		vec2 q = p * 3.0 + vec2(TIME * 0.6, TIME * 0.4);
		float n0 = noise(q);
		slope += vec2(noise(q + vec2(0.15, 0.0)) - n0, noise(q + vec2(0.0, 0.15)) - n0) / 0.15 * (0.05 + 0.12 * chop);

		// Far water is seen at a grazing angle: flatten the detail there.
		float lod = 1.0 / (1.0 + dist * 0.04);
		vec3 n = normalize(vec3(-slope.x * lod, 1.0, -slope.y * lod));
		vec3 view = -ray;
		float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(n, view), 0.0), 5.0);
		vec3 refl_dir = reflect(ray, n);
		refl_dir.y = abs(refl_dir.y);
		vec3 reflection = sky_color(refl_dir);

		vec3 body = mix(water_shallow, water_deep, smoothstep(2.0, 25.0, dist));
		// Clear, bright water shows the bottom close to the angler.
		float bottom = (1.0 - smoothstep(1.0, 1.5 + 9.0 * visibility, dist)) * visibility;
		body = mix(body, bottom_color * (0.55 + 0.45 * light), bottom * 0.75);
		// Light through the crests.
		body += water_shallow * max(h, 0.0) * 0.6;

		vec3 col = mix(body, reflection, fresnel);

		// Whitecaps on the crests when it blows.
		float crest = h / (2.3 * amp) + (noise(p * 2.5 + TIME * 0.3) - 0.5) * 0.5;
		float foam = smoothstep(0.55, 0.85, crest) * smoothstep(0.4, 1.0, chop);
		col = mix(col, vec3(0.95, 0.97, 1.0) * (0.25 + 0.75 * light), foam * 0.85);

		// Haze towards the horizon.
		col = mix(col, sky_horizon, smoothstep(30.0, 400.0, dist) * 0.6);
		COLOR = vec4(col, 1.0);
	}
}
