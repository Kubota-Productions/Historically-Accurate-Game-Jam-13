shader_type spatial;

uniform vec4 floor_color : source_color = vec4(0.307, 0.307, 0.307, 1.0);
uniform vec4 line_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform bool show_grid = true;
uniform float cell_size : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform float line_width : hint_range(0.001, 0.1, 0.001) = 0.016;

varying vec2 floor_position;
varying float top_face;

void vertex() {
	floor_position = VERTEX.xz;
	top_face = step(0.5, NORMAL.y);
}

void fragment() {
	vec2 grid_position = floor_position / cell_size;
	vec2 distance_to_line = abs(fract(grid_position + 0.5) - 0.5);
	vec2 antialias = max(fwidth(grid_position), vec2(0.0001));
	float half_width = 0.5 * line_width / cell_size;
	vec2 lines = 1.0 - smoothstep(vec2(half_width) - antialias * 0.5, vec2(half_width) + antialias * 0.5, distance_to_line);
	float grid = max(lines.x, lines.y) * top_face * float(show_grid);
	ALBEDO = mix(floor_color.rgb, line_color.rgb, grid);
	ROUGHNESS = 0.85;
}
