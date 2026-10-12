shader_type canvas_item;
// A soft dark edge around the game window; the centre is untouched.

uniform float strength = 0.32;
uniform float inner = 0.72;

void fragment() {
	vec2 offset = (UV - 0.5) * vec2(1.0, 0.75) * 2.0;
	float edge = smoothstep(inner, 1.25, length(offset));
	COLOR = vec4(0.0, 0.0, 0.02, edge * strength);
}
