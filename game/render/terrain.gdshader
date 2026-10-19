shader_type canvas_item;
// Floors on the GPU (game/render/floor_layer.gd). TEXTURE is a chunk's data image, one texel per
// cell plus a one-cell border (SpriteArt.floor_texel): R floor tile, G overlay tile, B overlay
// quarters (low bits) and kerb sides (high bits), A blend. Tiles come from tiles.png. Natural ground
// of a higher priority spills over its lower neighbour in a ragged, shadowed edge; water animates
// and foams along the shore; grass sways in passing gusts. Everything stays on whole pixels.

uniform sampler2D tiles : filter_nearest, repeat_disable;
uniform int curb_tile = 59;
uniform int water_tile = 8;
// How far a neighbour's ground reaches over the edge, in pixels, and how much that wanders.
uniform float edge_reach = 6.0;
uniform float edge_wander = 5.0;

varying vec2 map_pixel;

const int NO_TILE = 255;
const int TILE = 32;

void vertex() {
	map_pixel = VERTEX;
}

ivec4 cell_data(sampler2D data, ivec2 texel) {
	return ivec4(round(texelFetch(data, texel, 0) * 255.0));
}

vec4 tile_pixel(int index, ivec2 p) {
	return texelFetch(tiles, ivec2(index % 4, index / 4) * TILE + (p & ivec2(31)), 0);
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Smooth noise along an edge in steps of whole pixels, two octaves, 0..1.
float edge_noise(float along, float seed) {
	float a = floor(along);
	float n = 0.0;
	for (int octave = 0; octave < 2; octave++) {
		float period = octave == 0 ? 7.0 : 3.0;
		float x = a / period;
		float i = floor(x);
		float f = smoothstep(0.0, 1.0, fract(x));
		n += mix(hash(i + seed * 17.0 + float(octave) * 91.0), hash(i + 1.0 + seed * 17.0 + float(octave) * 91.0), f)
			* (octave == 0 ? 0.65 : 0.35);
	}
	return n;
}

int priority(ivec4 d) {
	return d.r == NO_TILE ? 0 : d.a & 15;
}

bool is_water(ivec4 d) {
	return d.r != NO_TILE && (d.a & 16) != 0;
}

void fragment() {
	ivec2 cells = textureSize(TEXTURE, 0) - 2;
	ivec2 px = ivec2(floor(UV * vec2(cells * TILE)));
	ivec2 cell = px / TILE;
	ivec2 p = px - cell * TILE;
	ivec2 here = cell + 1;
	ivec4 me = cell_data(TEXTURE, here);
	if (me.r == NO_TILE) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		ivec2 world = ivec2(floor(map_pixel));
		ivec2 world_cell = world / TILE;
		ivec2 side = ivec2(p.x < 16 ? -1 : 1, p.y < 16 ? -1 : 1);
		// Distances to the near vertical and horizontal edges, and the near corner.
		float dx = side.x < 0 ? float(p.x) + 0.5 : 31.5 - float(p.x);
		float dy = side.y < 0 ? float(p.y) + 0.5 : 31.5 - float(p.y);
		ivec4 nx = cell_data(TEXTURE, here + ivec2(side.x, 0));
		ivec4 ny = cell_data(TEXTURE, here + ivec2(0, side.y));
		ivec4 nd = cell_data(TEXTURE, here + side);
		// Each grid line wanders along its whole length, so a long edge stays one ragged line.
		float seed_x = float(world_cell.x + (side.x > 0 ? 1 : 0)) * 0.37;
		float seed_y = float(world_cell.y + (side.y > 0 ? 1 : 0)) * 0.53 + 0.29;
		float reach_x = edge_reach + (edge_noise(float(world.y), seed_x) - 0.5) * edge_wander;
		float reach_y = edge_reach + (edge_noise(float(world.x), seed_y) - 0.5) * edge_wander;
		float gap_x = dx - reach_x;
		float gap_y = dy - reach_y;
		float gap_d = length(vec2(dx, dy)) - (reach_x + reach_y) * 0.55;
		int mine = priority(me);
		int best = mine;
		int chosen = me.r;
		bool chosen_sway = (me.a & 32) != 0;
		float lip = 99.0;
		// A higher natural neighbour covers this pixel if it reaches past it, else may cast a lip.
		if (mine > 0) {
			ivec4 near[3] = ivec4[3](nx, ny, nd);
			float gaps[3] = float[3](gap_x, gap_y, gap_d);
			for (int i = 0; i < 3; i++) {
				int theirs = priority(near[i]);
				if (theirs > mine) {
					// Where a higher ground meets this cell on two sides, round the inside corner.
					if (i == 2 && priority(nx) == theirs && priority(ny) == theirs) {
						vec2 fillet = vec2(reach_x, reach_y) + vec2(edge_reach) - vec2(dx, dy);
						if (fillet.x > 0.0 && fillet.y > 0.0) {
							gaps[i] = edge_reach - length(fillet);
						}
					}
					if (gaps[i] < 0.0 && theirs > best) {
						best = theirs;
						chosen = near[i].r;
						chosen_sway = (near[i].a & 32) != 0;
					} else if (gaps[i] >= 0.0) {
						lip = min(lip, gaps[i]);
					}
				}
			}
		}
		ivec2 q = p;
		if (chosen_sway) {
			// Gusts roll across the grass as bands that lean the blades one pixel.
			float gust = sin((float(world.x) * 0.55 + float(world.y)) * 0.045 - TIME * 1.6)
				* sin(float(world.x) * 0.013 + TIME * 0.37);
			if (gust > 0.72) {
				q.x -= 1;
			}
		}
		vec4 color;
		if (chosen == me.r && is_water(me)) {
			int frame = (me.r - water_tile + int(TIME * 2.5)) % 4;
			color = tile_pixel(water_tile + frame, q);
			vec2 w = vec2(world);
			float wave = sin(w.x * 0.21 + TIME * 1.7) * sin(w.y * 0.17 - TIME * 1.2 + w.x * 0.03);
			float swell = 0.96 + 0.04 * sin((w.x + w.y) * 0.045 + TIME * 0.8);
			color.rgb = color.rgb * swell + vec3(0.07, 0.10, 0.10) * step(0.93, wave);
			// Foam where the water meets anything that is not water: a broken white line that
			// breathes in and out with the swell.
			float shore = 99.0;
			ivec4 near[3] = ivec4[3](nx, ny, nd);
			float gaps[3] = float[3](gap_x, gap_y, gap_d);
			float flat_gaps[3] = float[3](dx, dy, length(vec2(dx, dy)));
			for (int i = 0; i < 3; i++) {
				if (near[i].r != NO_TILE && !is_water(near[i])) {
					shore = min(shore, priority(near[i]) > 0 ? gaps[i] : flat_gaps[i]);
				}
			}
			float breath = 1.6 + 1.2 * sin(TIME * 1.3 + float(world_cell.x + world_cell.y) * 0.7);
			if (shore < breath && hash(float(world.x * 7 + world.y * 13) + floor(TIME * 2.0)) > 0.25) {
				color.rgb = mix(color.rgb, vec3(0.82, 0.88, 0.86), shore < 1.0 ? 0.75 : 0.45);
			} else if (shore < breath + 2.0) {
				color.rgb *= 0.86;
			}
		} else {
			color = tile_pixel(chosen, q);
			if (chosen == me.r && lip < 1.5) {
				// The lower ground darkens under the edge of the ground spilling over it.
				color.rgb *= lip < 0.75 ? 0.72 : 0.86;
			}
		}
		// Overlay quarters: a pier's planks or a building's floor beside its wall.
		if (me.g != NO_TILE) {
			int quarter = (p.x >= 16 ? 1 : 0) + (p.y >= 16 ? 2 : 0);
			if ((me.b & (1 << quarter)) != 0) {
				vec4 top = tile_pixel(me.g, p);
				color.rgb = mix(color.rgb, top.rgb, top.a);
			}
		}
		// Kerb stones on a cobbled street, by side (north, east, south, west).
		for (int s = 0; s < 4; s++) {
			if ((me.b & (16 << s)) != 0) {
				vec4 kerb = tile_pixel(curb_tile + s, p);
				color.rgb = mix(color.rgb, kerb.rgb, kerb.a);
			}
		}
		color.a = 1.0;
		COLOR = color;
	}
}
