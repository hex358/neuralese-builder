shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 100.0) = 8.0;

/* OUTLINE */
uniform float outline_width : hint_range(0.0, 20.0) = 2.0; // screen px
uniform vec4 outline_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);

/* BACKGROUND (outside) */
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.12, 1.0);

varying vec2 view_scale;
varying vec2 vert_scale;

void vertex() {
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
	/* Local pixel size */
	vec2 size_px = vec2(
		1.0 / dFdx(UV).x,
		1.0 / dFdy(UV).y
	);

	vec2 half = size_px * 0.5;
	vec2 p = UV * size_px - half;

	/* Screen px → local px */
	float px_scale = min(view_scale.x, view_scale.y) * vert_scale.x;
	float r  = corner_radius * px_scale;
	float ow = outline_width * px_scale;

	/* Rounded rect SDF */
	vec2 q = abs(p) - (half - vec2(r));
	float sdf = length(max(q, vec2(0.0)))
	          + min(max(q.x, q.y), 0.0)
	          - r;

	float aa = fwidth(sdf);

	/* ===== REGIONS ===== */

	/* Fill: sdf < -ow */
	float fill_alpha = smoothstep(-ow - aa, -ow + aa, sdf);

	/* Outline: -ow ≤ sdf ≤ 0 */
	float outline_alpha =
		smoothstep(-ow - aa, -ow + aa, sdf) *
		(1.0 - smoothstep(-aa, aa, sdf));

	/* Background: sdf > 0 */
	float bg_alpha = smoothstep(0.0 - aa, 0.0 + aa, sdf);

	/* ===== COMPOSITION ===== */

	vec4 col = vec4(0.0);

	/* Background */
	col.rgb = background_color.rgb;
	col.a   = background_color.a * bg_alpha;

	/* Outline */
	col.rgb = mix(col.rgb, outline_color.rgb, outline_alpha * outline_color.a);
	col.a   = max(col.a, outline_alpha * outline_color.a);

	/* Fill */
	col.rgb = mix(col.rgb, COLOR.rgb, fill_alpha * COLOR.a);
	col.a   = max(col.a, fill_alpha * COLOR.a);

	COLOR = col;
}
