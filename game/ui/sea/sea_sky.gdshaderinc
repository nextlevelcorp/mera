// Shared by the sky and the sea, so the sea reflects exactly the sky that is
// drawn: gradient, sun and its glow, clouds and the far shore with its lights.
// Directions are in world space: x right, y up, -z away from the angler.

uniform vec3 sky_top : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.85, 0.95);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sun_dir = vec3(0.2, 0.75, -0.6);
uniform float sun_power = 1.0;
uniform float cloud_cover = 0.35;
uniform float light = 1.0;
// 0..1: lights of the far shore at dusk and night (generic, not a mapped skyline).
uniform float city_lights = 0.0;
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;

float sea_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_density(vec3 d) {
	if (d.y <= 0.0) {
		return 0.0;
	}
	vec2 cp = d.xz / (d.y + 0.06);
	float f = texture(cloud_tex, cp * 0.11 + vec2(0.31, 0.17)).r * 0.65 + texture(cloud_tex, cp * 0.37 + vec2(0.7, 0.2)).r * 0.35;
	return smoothstep(1.0 - cloud_cover, 1.18 - cloud_cover * 0.6, f) * smoothstep(0.0, 0.1, d.y);
}

// Far shore: a hazy ridge a few hundredths of a radian high on the horizon.
// Returns land cover in x and the shore lights in y.
vec2 far_shore(vec3 d) {
	float az = atan(d.x, -d.z);
	float e = d.y;
	float ridge = 0.009 + 0.020 * texture(cloud_tex, vec2(az * 0.35, 0.37)).r + 0.006 * texture(cloud_tex, vec2(az * 2.9, 0.71)).r;
	// Rooftops and towers: small steps along the ridge.
	float block = floor(az * 180.0);
	ridge += 0.0025 * step(0.5, sea_hash(vec2(block, 1.1))) * sea_hash(vec2(block, 2.3)) + 0.006 * step(0.985, sea_hash(vec2(floor(az * 420.0), 4.4)));
	float land = (1.0 - smoothstep(ridge - 0.0018, ridge, e)) * step(-0.002, e);
	float lights = 0.0;
	if (city_lights > 0.0 && land > 0.0) {
		float x = az * 260.0;
		float cell = floor(x);
		float r = sea_hash(vec2(cell, 3.7));
		float within = abs(fract(x) - 0.5);
		float y = sea_hash(vec2(cell, 5.3)) * ridge * 0.85;
		float cluster = smoothstep(0.35, 0.65, texture(cloud_tex, vec2(az * 1.7, 0.13)).r);
		lights = step(0.55, r) * cluster * smoothstep(0.45, 0.1, within) * smoothstep(0.0016, 0.0, abs(e - y)) * (0.5 + 0.5 * sea_hash(vec2(cell, 9.1)));
	}
	return vec2(land, lights);
}

// Linear-light HDR colour of the sky in direction d (normalised).
vec3 sky_radiance(vec3 d) {
	float up = clamp(d.y, 0.0, 1.0);
	vec3 sun = normalize(sun_dir);
	float s = max(dot(d, sun), 0.0);
	// Sky gradient, warmer and brighter towards the sun near the horizon.
	vec3 c = mix(sky_horizon, sky_top, pow(up, 0.45));
	c += sky_horizon * sun_color * pow(s, 6.0) * 0.35 * (1.0 - up);
	// Clouds: lit from the sun side, a bright rim close to the sun.
	float cloud = cloud_density(d);
	vec3 cloud_lit = mix(sky_horizon * 0.55, mix(sky_horizon, vec3(1.0), 0.55), 0.5 + 0.5 * s) * (0.35 + 0.65 * light);
	cloud_lit += sun_color * pow(s, 24.0) * 1.4;
	c = mix(c, cloud_lit, cloud * 0.9);
	// Sun disc, halo and wide glow (above 1 so the glow pass blooms it).
	float disc = smoothstep(0.99955, 0.99975, s);
	c += sun_color * sun_power * (disc * 14.0 + pow(s, 400.0) * 1.6 + pow(s, 16.0) * 0.22) * (1.0 - 0.85 * cloud);
	// The far shore, hazed by the air between, and its lights.
	vec2 shore = far_shore(d);
	// Land: a cool silhouette, hazier towards its foot.
	vec3 land_col = mix(mix(sky_top, sky_horizon, 0.55) * 0.42, sky_horizon * 0.7, smoothstep(0.012, 0.0, d.y) * 0.6);
	c = mix(c, land_col, shore.x * 0.92);
	c += vec3(1.0, 0.62, 0.32) * city_lights * 0.10 * exp(-max(d.y, 0.0) * 40.0);
	c += vec3(1.0, 0.82, 0.5) * shore.y * city_lights * 3.0;
	return c;
}
