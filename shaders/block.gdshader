shader_type canvas_item;
#include "res://shaders/std.gdshaderinc"
render_mode world_vertex_coords;

// shape: 0=rect,1=triangle,2=rhombus, 3=circle
uniform int shape: hint_range(0,2) = 0;

uniform vec4 mult_tuning: source_color = vec4(1.0);
instance uniform vec4 tuning: source_color = vec4(1.0);

uniform vec4 color_mult: source_color = vec4(1.0);
#include "res://shaders/smooth_extents.gdshaderinc"
global uniform float _view_scale = 1.0;
instance uniform float corner_radius_add = 0.0;
instance uniform float corner_width_add = 0.0;
uniform float corner_radius: hint_range(0.0, 100.0) = 8.0;
uniform bool blurred_background = true;
uniform float outline_width: hint_range(0.0, 50.0) = 0.0;
uniform float mult = 2.0;
instance uniform vec4 outline_color: source_color = vec4(1.0);
uniform float blur_level: hint_range(0.0, 7.0) = 2.5;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;

varying vec2 view_scale;
varying vec2 vert_scale;
varying vec2 vert;
varying vec4 modulate;

void vertex() {
	vert = VERTEX;
	modulate = COLOR;
	view_scale = vec2(length(CANVAS_MATRIX[0].xy), length(CANVAS_MATRIX[1].xy));
	vert_scale = vec2(length(MODEL_MATRIX[0].xy), length(MODEL_MATRIX[1].xy));
}

void fragment() {
	vec2 size_px = vec2(1.0 / dFdx(UV).x, 1.0 / dFdy(UV).y);
	vec2 half = size_px * 0.5;
	vec2 p = UV * size_px - half;

	float radius_added = corner_radius_add + corner_radius;
	float r = radius_added * min(view_scale.x, view_scale.y) * vert_scale.x;
	float w = (outline_width+corner_width_add) * min(view_scale.x, view_scale.y) * vert_scale.y;

	float sdf;
	if (false) { // if shape == 1 (triangle) or 2 (rombic) or 3
	} else {
		// rounded rectangle
		vec2 q = abs(p) - (half - vec2(r));
		sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	}

	float mask = smoothstep(1.0, -1.0, sdf);
	float ol = smoothstep(w + 1.0, w - 1.0, abs(sdf));

	// compute fill color
	vec4 col;
	vec4 out_col = outline_color;
	if (outline_width+corner_width_add < 0.01){out_col = tuning * mult_tuning;}
	if (blurred_background) {
		vec4 bg = textureLod(screen, SCREEN_UV, blur_level*_view_scale)*mult;
		if (ol < 0.999) {
			col = mix(alpha_blend(bg, tuning * mult_tuning) * color_mult, out_col, ol);
		} else {
			col = out_col;
		}
	} else {
		col = mix(tuning * mult_tuning * color_mult, outline_color, ol);
	}

	col.a *= mask;
	COLOR = col * modulate;

	COLOR.a *= alphamult(vert);
}
