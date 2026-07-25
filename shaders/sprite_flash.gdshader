shader_type spatial;
// Hit flash: fills the sprite's SILHOUETTE with white, keeping its alpha.
//
// The reference does exactly this (video frame 15.0s) and it is not the same as
// brightening: modulate at 3x keeps the hue, so a green ghost stays a green
// ghost and the hit reads as "it got lighter". A silhouette fill reads as
// impact because the shape, not the colour, is what changes.
//
// Also handles the TARGET RIM, so a monster needs one material instead of two
// (a second Sprite3D for the rim doubled the draw and made the flash and the
// rim fight over which one sits in front).
render_mode unshaded, cull_disabled, depth_prepass_alpha, blend_mix,
	ambient_light_disabled, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
/// 0 = normal, 1 = fully white.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
/// Sprite3D.billboard is ignored under material_override (AGENTS.md).
uniform float billboard_y : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.2;


void vertex() {
	if (billboard_y > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}


void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < alpha_cut) {
		discard;
	}
	// COLOR carries Sprite3D.modulate, so hover tint and death fade still work
	vec3 base = c.rgb * COLOR.rgb;
	ALBEDO = mix(base, vec3(1.0), flash);
	// Glow while flashing so it blooms like the reference
	EMISSION = vec3(1.0) * flash * 1.6;
	ALPHA = c.a * COLOR.a;
}
