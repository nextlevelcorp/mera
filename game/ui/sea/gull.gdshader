shader_type spatial;
render_mode cull_disabled;
// A gull: body and two wings in one mesh; the wings flap in the vertex
// shader from a phase per instance (MultiMesh custom data x), so all the
// gulls are one draw call and the flock costs no CPU per vertex.

uniform vec3 body_color : source_color = vec3(0.93, 0.94, 0.96);
uniform vec3 tip_color : source_color = vec3(0.3, 0.32, 0.36);

varying float v_out;

void vertex() {
	float f = abs(VERTEX.x);
	v_out = f;
	// Flap about the body: the tips move most.
	VERTEX.y += sin(INSTANCE_CUSTOM.x) * f * f * 0.55;
	// And sweep back a little on the down stroke.
	VERTEX.z += cos(INSTANCE_CUSTOM.x) * f * 0.08;
}

void fragment() {
	ALBEDO = mix(body_color, tip_color, smoothstep(0.65, 1.0, v_out));
	ROUGHNESS = 0.8;
}
