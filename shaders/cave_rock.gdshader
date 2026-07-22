shader_type spatial;
// Hand-drawn cave rock, computed per pixel.
//
// Replaces the CPU-baked rock texture. A 320px bitmap stretched over 7.2m of
// wall is 44 px/m — everything read as mush up close, and raising the bitmap
// size cost seconds of load time. Here the stones are evaluated in the
// fragment shader, so ink lines stay crisp at any distance, there is no tiling
// repeat, and dungeon generation no longer pays for texture baking.
//
// Two stone layers (big slabs + small chips) + top-edge rim light + ink
// outlines, all anti-aliased with fwidth so nothing crawls when walking.
//
// UV arrives in WORLD METRES (see _world_uv_scale in dungeon_generator.gd),
// which is what keeps stones the same size on every surface.

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 ink_col : source_color = vec3(0.02, 0.05, 0.07);
uniform vec3 deep_col : source_color = vec3(0.05, 0.13, 0.16);
uniform vec3 mid_col : source_color = vec3(0.09, 0.22, 0.25);
uniform vec3 lite_col : source_color = vec3(0.15, 0.34, 0.34);
uniform vec3 hi_col : source_color = vec3(0.26, 0.52, 0.5);

uniform float big_scale = 2.2;      // stone cells per metre
uniform float small_scale = 6.4;    // chip cells per metre
uniform float ink_width = 0.085;    // thick outline, comic style
uniform float chip_ink = 0.038;
uniform float rim_strength = 0.45;  // lit top edge of each stone
uniform float chip_contrast = 0.16;
uniform float angular = 0.45;       // 0 = round pebbles, 1 = boxy slabs
uniform float rough = 0.85;
uniform float seed_offset = 0.0;


vec2 hash2(vec2 p) {
	p += seed_offset;
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	p += seed_offset;
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 24634.6345);
}

// x = nearest distance, y = second nearest, zw = cell id
vec4 voronoi(vec2 p, float ang) {
	vec2 n = floor(p);
	vec2 f = p - n;
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			vec2 r = g + o - f;
			// Blend euclidean with chebyshev so stones read faceted, not round
			float d = mix(length(r), max(abs(r.x), abs(r.y)), ang);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = n + g;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec4(f1, f2, id);
}

// Ink line at a cell boundary, anti-aliased in screen space
float ink_line(float edge, float width) {
	float aa = max(fwidth(edge), 0.0008) * 1.4;
	return 1.0 - smoothstep(width - aa, width + aa, edge);
}


void fragment() {
	vec2 p = UV;

	// --- big stones -------------------------------------------------------
	vec4 v1 = voronoi(p * big_scale, angular);
	float edge1 = v1.y - v1.x;
	float r1 = hash1(v1.zw);
	float r2 = hash1(v1.zw + 7.31);

	vec3 col = mix(deep_col, mid_col, r1);
	col = mix(col, lite_col, r2 * r2 * 0.65);

	// Lit top edge / shaded bottom edge — reads as carved relief
	vec2 centre = v1.zw + hash2(v1.zw);
	vec2 local = p * big_scale - centre;
	float upness = clamp(local.y * 2.0, -1.0, 1.0);
	float near_edge = 1.0 - smoothstep(ink_width, ink_width * 3.4, edge1);
	col = mix(col, hi_col, rim_strength * near_edge * max(0.0, upness));
	col = mix(col, ink_col, 0.3 * near_edge * max(0.0, -upness));

	// Per-pixel detail has no mip chain, so fine work must be faded out with
	// distance or it sparkles as the player walks. Matches the fog range.
	float dist = length(VERTEX);
	float chip_fade = 1.0 - smoothstep(5.0, 12.0, dist);

	// --- small chips ------------------------------------------------------
	// Offset by the parent cell id so chips never line up across a stone seam
	vec4 v2 = voronoi(p * small_scale + v1.zw * 0.73, angular * 0.7);
	float edge2 = v2.y - v2.x;
	col *= mix(1.0 - chip_contrast * chip_fade, 1.0 + chip_contrast * chip_fade,
		hash1(v2.zw + 3.7));

	// --- ink --------------------------------------------------------------
	float ink = max(ink_line(edge1, ink_width), ink_line(edge2, chip_ink) * 0.7 * chip_fade);
	col = mix(col, ink_col, ink);

	// Vertex colour carries the baked contact AO from the mesh
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
