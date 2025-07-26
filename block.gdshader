shader_type canvas_item;
render_mode world_vertex_coords;

uniform float corner_radius: hint_range(0.0, 100.0) = 8.0;
uniform bool blurred_background = true;
uniform float outline_width: hint_range(0.0, 50.0) = 0.0;
uniform vec4 outline_color: source_color = vec4(1.0);

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;

varying vec2 vs_scale;
varying vec2 vert;

vec4 alpha_blend(vec4 o, vec4 n) {
	float sum = n.a + o.a;
	sum = clamp(sum, 0.0001, 1.0);
	float rate = n.a / sum;
	vec4 res = mix(o, n, rate);
	res.a = clamp(n.a + o.a, 0.0, 1.0);
	return res;
}

void vertex() {
	vert = VERTEX;
	vs_scale = vec2(
		length(CANVAS_MATRIX[0].xy),
		length(CANVAS_MATRIX[1].xy)
	);
}

void fragment() {
	vec2 size_px = vec2(1.0 / dFdx(UV).x, 1.0 / dFdy(UV).y);
	vec2 half = size_px * 0.5;
	vec2 p = UV * size_px - half;
	float r = corner_radius * min(vs_scale.x, vs_scale.y);
	float w = outline_width * min(vs_scale.x, vs_scale.y);

	vec2 q = abs(p) - (half - vec2(r));
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;

	float mask = smoothstep(1.0, -1.0, sdf);
	float ol = smoothstep(w + 1.0, w - 1.0, abs(sdf));

	vec4 col;
	if (blurred_background) {
		vec4 bg = textureLod(screen, SCREEN_UV, 2.5);
		if (ol < 0.999) {
			col = mix(alpha_blend(bg, COLOR), outline_color, ol);
		} else {
			col = outline_color;
		}
	} else {
		col = mix(COLOR, outline_color, ol);
	}

	col.a *= mask;
	COLOR = col;
}
