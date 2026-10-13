shader_type canvas_item;
// Water that moves without redrawing: glints and a slow swell computed from the map pixel,
// quantised to whole pixels so it stays pixel art.

varying vec2 map_pixel;

void vertex() {
	map_pixel = VERTEX;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	vec2 p = floor(map_pixel);
	float wave = sin(p.x * 0.21 + TIME * 1.7) * sin(p.y * 0.17 - TIME * 1.2 + p.x * 0.03);
	float glint = step(0.93, wave);
	float swell = 0.96 + 0.04 * sin((p.x + p.y) * 0.045 + TIME * 0.8);
	color.rgb = color.rgb * swell + vec3(0.07, 0.10, 0.10) * glint;
	COLOR = color;
}
