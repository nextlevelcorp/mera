shader_type canvas_item;
// Ground of the top-down world: a CC0 texture set at real size, sampled twice
// (once turned a quarter and offset) and blended by large soft noise, so the
// repeat of the texture does not show; the normal map follows, so the sun and
// the lamps (Light2D) still pick out the stones. Plus patches of wear.

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 size_m = vec2(10.0, 10.0);
uniform float tile_m = 2.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 p = UV * size_m;
	vec2 uv1 = p / tile_m;
	vec2 uv2 = vec2(-p.y, p.x) / (tile_m * 1.13) + vec2(0.37, 0.71);
	float m = smoothstep(0.38, 0.62, texture(noise_tex, p / 17.0).r);
	vec3 c = mix(texture(albedo_tex, uv1).rgb, texture(albedo_tex, uv2).rgb, m);
	vec3 n1 = texture(normal_tex, uv1).rgb;
	vec3 n2 = texture(normal_tex, uv2).rgb;
	vec3 n2r = vec3(n2.y, 1.0 - n2.x, n2.z);   // the normal turns with the quarter turn
	float wear = texture(noise_tex, p / 37.0 + vec2(0.3, 0.6)).r;
	c *= tint.rgb * (0.8 + 0.35 * wear);
	COLOR = vec4(c, 1.0);
	NORMAL_MAP = mix(n1, n2r, m);
}
