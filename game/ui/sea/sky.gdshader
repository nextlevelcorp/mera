shader_type sky;
// Sky of the 3D sea (sea_sky.gdshaderinc). Static: no TIME, so the sky is
// not redrawn into reflections every frame on a phone.

#include "res://ui/sea/sea_sky.gdshaderinc"

void sky() {
	vec3 d = EYEDIR;
	if (d.y < 0.0) {
		// Below the horizon only far water shows, where the sea mesh ends.
		COLOR = sky_horizon * 0.55;
	} else {
		COLOR = sky_radiance(d);
	}
}
