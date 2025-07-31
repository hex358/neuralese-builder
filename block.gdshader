shader_type canvas_item;
render_mode world_vertex_coords;
#include "std.gdshaderinc"

// shape: 0=rect,1=triangle,2=rhombus
uniform int shape: hint_range(0,2) = 0;

uniform vec4 mult_tuning: source_color = vec4(1.0);
instance uniform vec4 tuning: source_color = vec4(1.0);
uniform vec4 color_mult: source_color = vec4(1.0);

uniform float corner_radius: hint_range(0.0, 100.0) = 8.0;
uniform bool blurred_background = true;
uniform float outline_width: hint_range(0.0, 50.0) = 0.0;
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
	// compute pixel coords
	vec2 size_px = vec2(1.0 / dFdx(UV).x, 1.0 / dFdy(UV).y);
	vec2 half = size_px * 0.5;
	vec2 p = UV * size_px - half;
	
	// compute effective radius and outline width in px
	float r = corner_radius * min(view_scale.x, view_scale.y) * vert_scale.x;
	float w = outline_width * min(view_scale.x, view_scale.y) * vert_scale.y;
	
	float sdf;
	if (false) {
		//// right-facing isosceles triangle
		//vec2 u = vec2(p.x + half.x, p.y);
		//float f = half.y * (1.0 - u.x / (2.0 * half.x));
		//float d1 = abs(u.y) - f;
		//float d2 = -u.x;
		//float d3 = u.x - 2.0 * half.x;
		//sdf = max(max(d1, d2), d3);
		//vec2 origin = size_px*vec2(0.5, 0.0)+vec2(-r*2.55,0);
		//float dist = distance(p, origin);
		//sdf *= mix(0.0, 1.0, float(dist < r || p.x < origin.x + 0.33*r));
	//} else if (shape == 2) {
		//// diamond/rhombus inscribed in rect
		//vec2 v = abs(p);
		//float d = (v.x / half.x + v.y / half.y - 1.0);
		//float inv_norm = (half.x * half.y) / length(vec2(half.y, half.x));
		//sdf = d * inv_norm - r;
	} else {
		// rounded rectangle
		vec2 q = abs(p) - (half - vec2(r));
		sdf = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	}
	
	// compute mask and outline alpha
	float mask = smoothstep(1.0, -1.0, sdf);
	float ol = smoothstep(w + 1.0, w - 1.0, abs(sdf));
	
	// compute fill color
	vec4 col;
	if (blurred_background) {
		vec4 bg = textureLod(screen, SCREEN_UV, blur_level);
		if (ol < 0.999) {
			col = mix(alpha_blend(bg, tuning * mult_tuning) * color_mult, outline_color, ol);
		} else {
			col = outline_color;
		}
	} else {
		col = mix(tuning * mult_tuning * color_mult, outline_color, ol);
	}
	
	col.a *= mask;
	COLOR = col * modulate;
}
