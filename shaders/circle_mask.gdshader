shader_type canvas_item;
// Circular crop for portraits.
//
// Control.clip_contents only ever clips to the node's RECTANGLE — a round
// StyleBox behind the image is just paint, so hair and shoulders spilled past
// the ring. This discards everything outside the inscribed circle instead.

uniform float radius : hint_range(0.0, 0.5) = 0.5;
uniform float feather : hint_range(0.0, 0.1) = 0.006;

void fragment() {
	float d = length(UV - vec2(0.5));
	// Soft edge, or the crop reads as a jagged staircase at small sizes
	float a = 1.0 - smoothstep(radius - feather, radius, d);
	if (a <= 0.001) {
		discard;
	}
	COLOR.a *= a;
}
