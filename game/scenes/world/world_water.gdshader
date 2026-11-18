shader_type canvas_item;
// Water of the top-down world in pixel art (owner, 2026-11-18: Stardew Valley
// style): flat colour bands, short light dashes that drift with the current,
// a darker band in the bridge's shade and a one-pixel foam line where the
// water meets stone. Worked out per art pixel (px_per_m pixels a metre), so
// it stays crisp when the camera scales it up. Sized in metres (size_m).

uniform vec2 size_m = vec2(10.0, 10.0);
uniform float px_per_m = 16.0;
uniform vec4 foam_edges = vec4(0.0);   // left, top, right, bottom: 1 where stone meets water
uniform vec3 deep : source_color = vec3(0.16, 0.38, 0.55);
uniform vec3 shallow : source_color = vec3(0.24, 0.5, 0.64);
uniform vec3 shade : source_color = vec3(0.12, 0.27, 0.42);
uniform vec3 glint : source_color = vec3(0.72, 0.88, 0.95);
uniform float light = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * size_m * px_per_m);   // the art pixel
	vec2 p = cell / px_per_m;                     // metres
	float d = 1000.0;
	d = mix(d, min(d, p.x), foam_edges.x);
	d = mix(d, min(d, p.y), foam_edges.y);
	d = mix(d, min(d, size_m.x - p.x - 1.0 / px_per_m), foam_edges.z);
	d = mix(d, min(d, size_m.y - p.y - 1.0 / px_per_m), foam_edges.w);
	vec3 col = d < 2.5 ? shallow : deep;
	// Slow broad swell: alternate two tones in wavy bands.
	float band = sin(p.y * 0.9 + sin(p.x * 0.35 + TIME * 0.4) * 1.6 + TIME * 0.3);
	col = band > 0.75 ? mix(col, shallow, 0.5) : col;
	// Light dashes: one pixel thin, a few pixels long, drifting along rows.
	float drift = TIME * 4.0;
	vec2 row = vec2(floor((cell.x + drift) / 24.0), floor(cell.y / 12.0));
	float r = hash(row);
	float x_in = mod(cell.x + drift, 24.0);
	float on = step(0.6, r) * step(x_in, 2.0 + floor(r * 4.0)) * (mod(cell.y, 12.0) < 1.0 ? 1.0 : 0.0);
	col = mix(col, glint, on * (0.4 + 0.6 * light));
	// The bridge's shade and the foam line along stone.
	col = d < 0.75 ? shade : col;
	col = d < 1.0 / px_per_m ? vec3(0.9, 0.95, 0.97) : col;
	COLOR = vec4(col, 1.0);
}
