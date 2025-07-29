shader_type canvas_item;
render_mode world_vertex_coords;
#include "std.gdshaderinc"

uniform vec4 mult_tuning: source_color = vec4(1.0);
instance uniform vec4 tuning: source_color = vec4(1.0);
uniform vec4 color_mult: source_color = vec4(1.0);
instance uniform bool disabled = false;

uniform float corner_radius: hint_range(0.0, 100.0) = 8.0;
uniform bool blurred_background = true;
uniform float outline_width: hint_range(0.0, 50.0) = 0.0;
instance uniform vec4 outline_color: source_color = vec4(1.0);
uniform float blur_level: hint_range(0.0, 7.0) = 2.5;
//global uniform float zoom = 1.0;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;

varying vec2 view_scale;
varying vec2 vert_scale;
varying vec2 vert;


varying vec4 modulate;



void vertex() {
	vert = VERTEX;
	modulate = COLOR;
	view_scale = vec2(
		length(CANVAS_MATRIX[0].xy),
		length(CANVAS_MATRIX[1].xy)
	);
	vert_scale = vec2(
		length(MODEL_MATRIX[0].xy),
		length(MODEL_MATRIX[1].xy)
	);
}

void fragment() {
	if (disabled){discard;}

	vec2 size_px = vec2(1.0 / dFdx(UV).x, 1.0 / dFdy(UV).y);
	vec2 half = size_px * 0.5;
	vec2 p = UV * size_px - half;
	float r = corner_radius * min(view_scale.x, view_scale.y) * vert_scale.x;
	float w = outline_width * min(view_scale.x, view_scale.y) * vert_scale.y;

	vec2 q = abs(p) - (half - vec2(r));
	float sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;

	float mask = smoothstep(1.0, -1.0, sdf);
	float ol = smoothstep(w + 1.0, w - 1.0, abs(sdf));

	vec4 col;
	if (blurred_background) {
		vec4 bg = textureLod(screen, SCREEN_UV, blur_level);
		if (ol < 0.999) {
			col = mix(alpha_blend(bg, tuning*mult_tuning)*color_mult, outline_color, ol);
		} else {
			col = outline_color;
		}
	} else {
		col = mix(tuning*mult_tuning*color_mult, outline_color, ol);
	}

	col.a *= mask;
	COLOR = col;
	COLOR *= modulate;
}
