shader_type canvas_item;


void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float d = length(UV - center);
	float aa = max(fwidth(d), 0.005);
	float mask = 1.0 - smoothstep(0.495 - aa, 0.495 + aa, d);
	COLOR.a *= mask;
}
