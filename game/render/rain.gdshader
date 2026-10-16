shader_type canvas_item;
// Rain over the game window, drawn in whole game pixels (zoom 2) so it stays pixel art.
// Three layers of slanted drops fall at different speeds and parallax; splashes are anchored
// to the map (camera) so they stay on the ground while you walk. Everything is tinted by the
// world's light, so rain is dim at night and flares with lightning.

uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float storm : hint_range(0.0, 1.0) = 0.0;
// 1 over the frost isles: the same weather falls as snow, slow drifting flakes and no splashes.
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 light = vec3(1.0);
// Map pixel at the top-left corner of the game window, and the window size in game pixels.
uniform vec2 camera = vec2(0.0);
uniform vec2 view_pixels = vec2(480.0, 352.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// One layer of drops: 1-pixel streaks of `len` pixels, `density` share of grid cells filled.
float drops(vec2 p, float speed, float parallax, float density, vec2 cell, float slant) {
	vec2 q = p + camera * parallax;
	q.x += q.y * slant;
	q.y -= TIME * speed;
	vec2 id = floor(q / cell);
	vec2 local = q - id * cell;
	float r = hash(id);
	if (r > density) {
		return 0.0;
	}
	float x = floor(hash(id + 17.0) * (cell.x - 1.0));
	float top = floor(hash(id + 31.0) * (cell.y * 0.5));
	float len = 4.0 + floor(hash(id + 7.0) * 4.0) + storm * 3.0;
	return (local.x >= x && local.x < x + 1.0 && local.y >= top && local.y < top + len) ? 1.0 : 0.0;
}

// Small splashes on the ground: a dot that opens into a squashed ring and fades.
float splashes(vec2 p) {
	vec2 q = p + camera;
	vec2 cell = vec2(14.0, 11.0);
	vec2 id = floor(q / cell);
	if (hash(id + 5.0) > rain * 0.55) {
		return 0.0;
	}
	float t = fract(TIME * (1.1 + hash(id + 9.0) * 0.8) + hash(id + 3.0));
	if (t > 0.45) {
		return 0.0;
	}
	vec2 centre = id * cell + floor(vec2(hash(id + 1.0), hash(id + 2.0)) * (cell - 4.0)) + 2.0;
	vec2 d = q - centre;
	float radius = floor(t * 7.0);
	float ring = abs(length(d * vec2(1.0, 2.0)) - radius);
	return (ring < 0.75 && d.y <= 0.5) ? (1.0 - t / 0.45) : 0.0;
}

// One layer of snowflakes: one- or two-pixel flakes drifting down and swaying side to side.
float flakes(vec2 p, float speed, float parallax, float density, float cell, float big) {
	vec2 q = p + camera * parallax;
	q.y -= TIME * speed;
	q.x += sin(TIME * 0.9 + q.y * 0.045) * 4.0;
	vec2 id = floor(q / cell);
	if (hash(id) > density) {
		return 0.0;
	}
	vec2 local = q - id * cell;
	vec2 at = floor(vec2(hash(id + 13.0), hash(id + 29.0)) * (cell - 2.0));
	vec2 d = local - at;
	float size = hash(id + 41.0) < big ? 2.0 : 1.0;
	return (d.x >= 0.0 && d.y >= 0.0 && d.x < size && d.y < size) ? 1.0 : 0.0;
}

void fragment() {
	vec2 p = floor(UV * view_pixels);
	if (snow > 0.5) {
		float amount = max(rain, 0.0);
		float f = flakes(p, 18.0, 0.5, 0.5 * amount, 9.0, 0.1) * 0.55;
		f = max(f, flakes(p + 51.0, 28.0 + storm * 30.0, 0.8, 0.4 * amount, 12.0, 0.35) * 0.8);
		f = max(f, flakes(p + 97.0, 40.0 + storm * 50.0, 1.0, 0.3 * amount * (0.5 + storm), 16.0, 0.6));
		float haze = 0.05 * amount + 0.1 * storm;
		float a = max(f * 0.85, haze) * step(0.01, amount);
		vec3 white = vec3(0.96, 0.98, 1.0) * light;
		COLOR = vec4(mix(vec3(0.8, 0.86, 0.94) * light, white, step(haze + 0.001, a)), a);
	} else {
		float d = drops(p, 200.0, 0.6, 0.55 * rain, vec2(7.0, 24.0), 0.18 + storm * 0.12) * 0.6;
		d = max(d, drops(p + 37.0, 250.0, 0.8, 0.45 * rain, vec2(9.0, 30.0), 0.2 + storm * 0.14) * 0.8);
		d = max(d, drops(p + 71.0, 310.0, 1.0, 0.35 * rain * (0.5 + storm), vec2(11.0, 36.0), 0.22 + storm * 0.16));
		float s = splashes(p) * 0.6;
		vec3 tint = vec3(0.78, 0.84, 0.92) * light;
		float veil = 0.05 * rain + 0.06 * storm;
		float alpha = max(max(d * 0.62, s * 0.6), veil) * step(0.01, rain);
		vec3 colour = mix(vec3(0.42, 0.47, 0.55) * light, tint, step(veil + 0.001, alpha));
		COLOR = vec4(colour, alpha);
	}
}
