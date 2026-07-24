shader_type spatial;
// Glowing rim around a sprite's silhouette — the reference marks the targeted
// monster with a bright contour, not with a brighter monster.
//
// This draws the RIM ONLY: every fragment that is inside the silhouette is
// discarded, so the outline sprite and the real sprite never cover the same
// pixel. That is deliberate — it means there is no depth fight and no draw
// order to get right, which is what sank the "scaled-up copy behind it"
// approach (a copy overlaps, so it has to win or lose the depth test, and
// ALPHA_CUT_DISCARD puts the two in different render passes).
render_mode unshaded, cull_disabled, blend_mix, ambient_light_disabled,
	specular_disabled, depth_draw_never;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 rim_color : source_color = vec4(1.0, 0.62, 0.18, 1.0);
/// Rim thickness in UV units. Scaled by the sprite's own pixel size at build
/// time so a small enemy does not get a fat crayon border.
uniform float thickness : hint_range(0.0005, 0.06) = 0.012;
/// Alpha above this counts as "inside the monster".
uniform float alpha_cut : hint_range(0.01, 0.9) = 0.2;
/// Breathing, so the target reads as live and not as a static sticker.
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
/// Sprite3D.billboard is ignored under material_override (see AGENTS.md), so
/// the rim has to spin around Y here or it stays flat to the corridor.
uniform float billboard_y : hint_range(0.0, 1.0) = 1.0;


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
	float own = texture(albedo_tex, UV).a;
	// Inside the monster: the monster's own sprite draws here, not us.
	if (own > alpha_cut) {
		discard;
	}

	// Eight taps around the fragment. Any of them landing inside the silhouette
	// means this pixel sits just outside the edge — that is the rim.
	float t = thickness;
	float d = t * 0.7071;  // diagonal taps, same distance from centre
	float hit = 0.0;
	hit = max(hit, texture(albedo_tex, UV + vec2( t, 0.0)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2(-t, 0.0)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2(0.0,  t)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2(0.0, -t)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2( d,  d)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2( d, -d)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2(-d,  d)).a);
	hit = max(hit, texture(albedo_tex, UV + vec2(-d, -d)).a);

	if (hit <= alpha_cut) {
		discard;
	}

	// Fade the outer edge of the rim so it reads as a glow, not as a sticker cut
	float edge = smoothstep(alpha_cut, 1.0, hit);
	ALBEDO = rim_color.rgb;
	ALPHA = rim_color.a * edge * (0.72 + 0.28 * pulse);
}
