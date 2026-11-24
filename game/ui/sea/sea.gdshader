shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
// The sea as a real surface (owner, 2026-11-15: photorealistic graphics).
// Gerstner waves move the vertices near the angler (crests sharpen and lean),
// two scrolling normal maps add the wind ripples, and the colour comes from
// Fresnel reflection of the same sky the background draws, light scattered
// through the wave crests, the sun's glitter, whitecaps, wind slicks, the
// shore lights' broken streaks and haze towards the horizon. Driven by the
// simulation's chop (0..1), visibility (0..1) and light (0..1).

#include "res://ui/sea/sea_sky.gdshaderinc"

uniform float chop = 0.3;
uniform float visibility = 0.5;
uniform vec3 water_deep : source_color = vec3(0.03, 0.2, 0.35);
uniform vec3 water_shallow : source_color = vec3(0.1, 0.45, 0.55);
uniform vec2 wind = vec2(0.3, -1.0);
// 1 adds wind slicks, finer ripples and whitecap texture; the debug menu
// switches it off to measure its cost on the phone.
uniform float detail = 1.0;
// Rings and boils on the surface (x, z in the sea's world, radius, strength)
// and fish seen as shadows under the water (x, z, radius, strength); both
// are filled by WaterView from the splash effects and the fight.
const int MAX_RINGS = 12;
const int MAX_SHADOWS = 8;
uniform int ring_count = 0;
uniform vec4 rings[MAX_RINGS];
uniform int shadow_count = 0;
uniform vec4 fish_shadow[MAX_SHADOWS];
uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 v_world;
varying vec3 v_normal;
varying float v_crest;

const float G = 9.81;

void gerstner(vec2 p, vec2 dir, float wavelength, float a, float q, inout vec3 offset, inout vec3 n) {
	float k = 6.2831853 / wavelength;
	float w = sqrt(G * k);
	vec2 d = normalize(dir);
	float th = k * dot(d, p) - w * TIME;
	float c = cos(th);
	float s = sin(th);
	offset += vec3(q * a * d.x * c, a * s, q * a * d.y * c);
	n += vec3(-d.x * k * a * c, -q * k * a * s, -d.y * k * a * c);
}

void vertex() {
	vec3 p = VERTEX;   // the mesh is built in world metres, at the origin
	float dist = length(p.xz);
	float fade = 1.0 - smoothstep(40.0, 220.0, dist);
	float amp = (0.04 + 0.26 * chop) * fade;
	float q = 0.35 + 0.45 * chop;
	vec2 wd = normalize(wind);
	vec2 side = vec2(-wd.y, wd.x);
	vec3 offset = vec3(0.0);
	vec3 n = vec3(0.0, 1.0, 0.0);
	gerstner(p.xz, wd, 9.0, amp, q, offset, n);
	gerstner(p.xz, wd + side * 0.45, 5.3, amp * 0.55, q, offset, n);
	gerstner(p.xz, wd - side * 0.6, 3.1, amp * 0.33, q, offset, n);
	gerstner(p.xz, wd + side * 1.3, 1.7, amp * 0.18, q * 0.7, offset, n);
	p += offset;
	v_world = p;
	v_normal = n;
	v_crest = amp > 0.0 ? offset.y / (amp * 2.06) : 0.0;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

vec3 ripples(vec2 p, float strength) {
	vec2 wd = normalize(wind);
	vec3 a = texture(ripple_tex, p * 0.11 + wd * TIME * 0.035).rgb * 2.0 - 1.0;
	vec3 b = texture(ripple_tex, p * vec2(0.29, 0.23) + vec2(-wd.y, wd.x) * TIME * 0.05 + 0.5).rgb * 2.0 - 1.0;
	// Tangent space (x, y in the texture, z up) to world (x, z on the water, y up).
	return vec3(a.x + b.x * detail, 0.0, a.y + b.y * detail) * strength;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 to_cam = cam - v_world;
	float dist = length(to_cam.xz);
	vec3 v = normalize(to_cam);
	vec2 p = v_world.xz;

	// Wind slicks: long smooth patches where films damp the ripples.
	float slick = 0.0;
	if (detail > 0.5) {
		slick = smoothstep(0.55, 0.75, texture(cloud_tex, p * vec2(0.0045, 0.0016) + TIME * 0.0012).r) * (1.0 - 0.7 * chop);
	}
	float ripple = (0.16 + 0.34 * chop) * (1.0 - 0.8 * slick) / (1.0 + dist * 0.012);
	// Rings: a narrow raised band pushing the normal outwards, so it catches
	// the sky and the sun like a real ripple, and hides behind whatever is nearer.
	vec3 ring_n = vec3(0.0);
	float ring_glow = 0.0;
	for (int i = 0; i < MAX_RINGS; i++) {
		if (i >= ring_count) {
			break;
		}
		vec2 dv = p - rings[i].xy;
		float d = length(dv);
		float w = 0.04 + 0.05 * rings[i].z;
		float x = (d - rings[i].z) / w;
		float k = exp(-x * x) * rings[i].w / (1.0 + 0.6 * rings[i].z);
		ring_n += vec3(dv.x, 0.0, dv.y) / max(d, 0.001) * k;
		ring_glow += k;
	}
	vec3 n = normalize(normalize(v_normal) + ripples(p, ripple) + ring_n * 0.6);

	float ndv = max(dot(n, v), 0.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 r = reflect(-v, n);
	r.y = abs(r.y);
	// Grazing reflections would pick the thin far shore up as dark dashes
	// (aliasing on a phone screen); lift them above it. The shore lights get
	// their own streaks below.
	// The shore is left out of the reflection: a place's skyline can stand
	// above the clamp, and its hard edges in every wave read as stripes.
	vec3 refl = sky_radiance_k(normalize(vec3(r.x, max(r.y, 0.045), r.z)), 0.0);

	// The water body: darker looking down into it, clearer water a little brighter.
	vec3 body = mix(water_shallow, water_deep, smoothstep(0.15, 0.6, ndv)) * (0.35 + 0.65 * light) * (0.75 + 0.5 * visibility);
	// A fish under the surface: a soft dark body along its spine.
	float shade = 0.0;
	for (int i = 0; i < MAX_SHADOWS; i++) {
		if (i >= shadow_count) {
			break;
		}
		vec2 q = (p - fish_shadow[i].xy) / fish_shadow[i].z;
		shade += exp(-dot(q, q)) * fish_shadow[i].w;
	}
	shade = clamp(shade, 0.0, 1.0);
	body *= 1.0 - 0.8 * shade;
	// Light through the crests: thin water lit from behind when facing the sun.
	vec3 sun = normalize(sun_dir);
	vec2 sun_h = normalize(sun.xz + vec2(1e-4));
	float back = pow(max(dot(normalize(-v.xz + vec2(1e-4)), sun_h), 0.0), 3.0) * (1.0 - sun.y);
	body += water_shallow * sun_color * clamp(v_crest, 0.0, 1.0) * back * 0.9 * light;

	vec3 col = mix(body, refl, fresnel);
	col *= 1.0 - 0.3 * shade;
	col += vec3(0.85, 0.9, 1.0) * (0.1 + 0.25 * light) * clamp(ring_glow, 0.0, 1.0) * 0.3;

	// Sun glitter: a sharp highlight and a broad sheen on the facets.
	float rs = max(dot(r, sun), 0.0);
	col += sun_color * sun_power * (pow(rs, 2400.0) * 70.0 + pow(rs, 500.0) * 1.3) * step(0.0, sun.y);

	// Whitecaps on the crests when it blows, broken up by texture.
	float crest = v_crest + (texture(cloud_tex, p * 0.21 + TIME * 0.01).r - 0.5) * 0.7;
	float foam = smoothstep(0.55, 0.9, crest) * smoothstep(0.35, 1.0, chop);
	if (detail > 0.5) {
		foam *= smoothstep(0.3, 0.6, texture(cloud_tex, p * 0.9).r);
	}
	col = mix(col, vec3(0.92, 0.95, 1.0) * (0.2 + 0.8 * light), foam * 0.8);

	// Shore lights reflected as long vertical streaks broken by the waves.
	float night = smoothstep(0.4, 1.0, city_lights);
	if (night > 0.0) {
		vec3 rr = normalize(vec3(r.x + n.x * 0.04, max(abs(r.y) * 0.15, 0.0005), r.z));
		float streak = far_shore(rr).y * smoothstep(30.0, 140.0, dist);
		float broken = smoothstep(0.4, 0.7, texture(cloud_tex, vec2(p.x * 0.6, p.y * 0.05) + TIME * 0.02).r);
		col += vec3(1.0, 0.75, 0.45) * streak * broken * night * 2.5;
	}

	// Air between the angler and far water.
	vec3 haze = sky_radiance_k(normalize(vec3(-v.x, 0.004, -v.z)), 0.0);
	col = mix(col, haze, 1.0 - exp(-dist * 0.0011));
	ALBEDO = col;
}
