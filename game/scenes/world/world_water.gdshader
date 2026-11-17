shader_type canvas_item;
// Water of the top-down world: the same ripple normal map as the 3D sea,
// scrolled twice, lit by the sun from the top left, with sun glints, a darker
// colour away from the edges and foam where the water meets stone. Sized in
// metres (size_m), so the ripples keep their scale on every rect.

uniform sampler2D ripple_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 size_m = vec2(10.0, 10.0);
uniform vec4 foam_edges = vec4(0.0);   // left, top, right, bottom: 1 where stone meets water
uniform vec3 deep : source_color = vec3(0.05, 0.16, 0.24);
uniform vec3 shallow : source_color = vec3(0.13, 0.3, 0.37);
uniform float light = 1.0;

void fragment() {
	vec2 p = UV * size_m;
	vec3 a = texture(ripple_tex, p * 0.09 + vec2(TIME * 0.012, TIME * 0.02)).rgb * 2.0 - 1.0;
	vec3 b = texture(ripple_tex, p * 0.23 + vec2(-TIME * 0.025, TIME * 0.01)).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3(a.xy + b.xy, 2.4));
	vec3 l = normalize(vec3(-0.5, -0.6, 0.62));
	float diffuse = clamp(dot(n, l), 0.0, 1.0);
	vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
	float glint = pow(max(dot(n, h), 0.0), 120.0);
	// Distance to the stone edges, in metres.
	float d = 1000.0;
	d = mix(d, min(d, p.x), foam_edges.x);
	d = mix(d, min(d, p.y), foam_edges.y);
	d = mix(d, min(d, size_m.x - p.x), foam_edges.z);
	d = mix(d, min(d, size_m.y - p.y), foam_edges.w);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 4.0, d));
	col *= 0.75 + 0.45 * diffuse;
	col += vec3(1.0, 0.97, 0.9) * glint * 0.9 * light;
	float foam = (1.0 - smoothstep(0.0, 0.55, d)) * smoothstep(0.35, 0.6, texture(ripple_tex, p * 0.4 + TIME * 0.03).b);
	col = mix(col, vec3(0.92, 0.95, 0.97), foam * 0.7);
	COLOR = vec4(col, 1.0);
}
