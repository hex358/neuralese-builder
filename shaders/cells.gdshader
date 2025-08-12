shader_type canvas_item;
render_mode world_vertex_coords;

uniform float width   = 2.0;   // line thickness in *world* units
uniform float spacing = 10.0;  // grid spacing in *world* units
uniform vec4 grid_color : source_color;
uniform vec4 bg_color   : source_color;

uniform float aa_pixels = 1.0;

varying vec2 vert;
void vertex() { vert = VERTEX; }

void fragment() {
	vec2 m = mod(vert, spacing);
	vec2 d = min(m, spacing - m);
	float dist = min(d.x, d.y);

	float half_w = 0.5 * width;

	vec2 fw = fwidth(vert);
	float px_world = aa_pixels * max(fw.x, fw.y);

	float a = 1.0 - smoothstep(half_w - px_world, half_w + px_world, dist);

	COLOR = mix(bg_color, grid_color, a);
}
