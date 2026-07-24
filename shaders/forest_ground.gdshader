shader_type spatial;
// Hand-painted forest soil — dirt, moss flecks, leaf-litter mottling.
//
// Same contract as cave_rock.gdshader: UV in WORLD METRES so patches keep a
// physical size; distance-faded fine detail so nothing sparkles when walking.
// Softer organic cells (low angular) — earth clumps, not stone slabs. No heavy
// ink outlines: a forest floor should read soft, not comic-carved rock.

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 ink_col : source_color = vec3(0.04, 0.06, 0.03);
uniform vec3 deep_col : source_color = vec3(0.08, 0.10, 0.05);
uniform vec3 mid_col : source_color = vec3(0.14, 0.16, 0.07);
uniform vec3 lite_col : source_color = vec3(0.22, 0.24, 0.10);
uniform vec3 hi_col : source_color = vec3(0.18, 0.28, 0.12);
uniform vec3 moss_col : source_color = vec3(0.10, 0.22, 0.09);
uniform vec3 litter_col : source_color = vec3(0.28, 0.18, 0.07);

uniform float big_scale = 1.35;     // soil clump cells per metre
uniform float small_scale = 4.8;    // litter / grit per metre
uniform float ink_width = 0.035;    // soft seam, not thick stone ink
uniform float chip_ink = 0.02;
uniform float rim_strength = 0.18;
uniform float chip_contrast = 0.12;
uniform float angular = 0.18;       // round / organic
uniform float rough = 0.95;
uniform float seed_offset = 0.0;
uniform float moss_amount = 0.42;
uniform float litter_amount = 0.28;


vec2 hash2(vec2 p) {
	p += seed_offset;
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	p += seed_offset;
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 24634.6345);
}

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

float ink_line(float edge, float width) {
	float aa = max(fwidth(edge), 0.0008) * 1.4;
	return 1.0 - smoothstep(width - aa, width + aa, edge);
}

// Cheap value noise for large moss patches / soft mottling
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void fragment() {
	vec2 p = UV;

	vec4 v1 = voronoi(p * big_scale, angular);
	float edge1 = v1.y - v1.x;
	float r1 = hash1(v1.zw);
	float r2 = hash1(v1.zw + 7.31);

	// Base soil — brown/olive dirt
	vec3 col = mix(deep_col, mid_col, r1);
	col = mix(col, lite_col, r2 * r2 * 0.55);

	// Soft height cue on clump tops
	vec2 centre = v1.zw + hash2(v1.zw);
	vec2 local = p * big_scale - centre;
	float upness = clamp(local.y * 2.0, -1.0, 1.0);
	float near_edge = 1.0 - smoothstep(ink_width, ink_width * 3.4, edge1);
	col = mix(col, hi_col, rim_strength * near_edge * max(0.0, upness));
	col = mix(col, ink_col, 0.18 * near_edge * max(0.0, -upness));

	float dist = length(VERTEX);
	float chip_fade = 1.0 - smoothstep(6.0, 16.0, dist);

	// Fine grit / leaf litter flecks
	vec4 v2 = voronoi(p * small_scale + v1.zw * 0.73, angular * 0.5);
	float edge2 = v2.y - v2.x;
	col *= mix(1.0 - chip_contrast * chip_fade, 1.0 + chip_contrast * chip_fade,
		hash1(v2.zw + 3.7));

	// Large soft moss patches (distance-stable)
	float moss_n = vnoise(p * 0.55 + seed_offset * 0.01);
	float moss_m = smoothstep(1.0 - moss_amount, 1.0 - moss_amount + 0.22, moss_n);
	col = mix(col, moss_col, moss_m * 0.55);

	// Sparse dry-leaf / needle litter (warmer flecks)
	float lit_n = vnoise(p * 1.7 + 13.7);
	float lit_m = smoothstep(1.0 - litter_amount, 1.0 - litter_amount + 0.12, lit_n) * chip_fade;
	col = mix(col, litter_col, lit_m * 0.4);

	// Very soft seams — almost no comic ink
	float ink = max(ink_line(edge1, ink_width) * 0.45,
		ink_line(edge2, chip_ink) * 0.35 * chip_fade);
	col = mix(col, ink_col, ink);

	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
