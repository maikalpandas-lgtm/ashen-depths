shader_type spatial;
// Soft heat shimmer on flame only (upper UV). No mesh stretch.
render_mode unshaded, cull_disabled, depth_prepass_alpha, blend_mix, ambient_light_disabled, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float time_scale : hint_range(0.05, 3.0) = 0.7;
uniform float warp_strength : hint_range(0.0, 0.08) = 0.018;
uniform float blur_strength : hint_range(0.0, 0.04) = 0.009;
/// UV.y: 0 = top (flame), 1 = bottom (hand/stick).
uniform float flame_start : hint_range(0.0, 1.0) = 0.5;
uniform float flame_soft : hint_range(0.01, 0.5) = 0.2;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.08;
uniform float emission_strength : hint_range(0.0, 4.0) = 1.6;


void fragment() {
	float flame_mask = 1.0 - smoothstep(flame_start - flame_soft, flame_start + flame_soft * 0.2, UV.y);
	flame_mask = clamp(flame_mask, 0.0, 1.0);
	float tip = flame_mask * flame_mask;

	float t = TIME * time_scale;
	float w = warp_strength * tip;

	vec2 warp = vec2(
		sin(t * 1.3 + UV.y * 12.0 + UV.x * 3.5) * 0.5
			+ sin(t * 0.65 + UV.y * 5.5) * 0.35
			+ sin(t * 2.0 + UV.x * 8.0) * 0.15,
		cos(t * 1.0 + UV.x * 7.0) * 0.35
			+ sin(t * 0.5 + UV.y * 6.5) * 0.45
	) * w;
	warp.y += sin(t * 1.5 + UV.x * 4.5) * w * 0.7;

	vec2 uv = UV + warp;
	vec4 col = texture(albedo_tex, uv);

	float b = blur_strength * tip;
	if (b > 0.00005) {
		vec4 acc = col;
		acc += texture(albedo_tex, uv + vec2(b, 0.0));
		acc += texture(albedo_tex, uv - vec2(b, 0.0));
		acc += texture(albedo_tex, uv + vec2(0.0, b * 1.2));
		acc += texture(albedo_tex, uv - vec2(0.0, b * 0.8));
		col = acc * 0.2;
	}

	if (col.a < alpha_scissor) {
		discard;
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
	EMISSION = col.rgb * tip * emission_strength;
}
