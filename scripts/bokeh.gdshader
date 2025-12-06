shader_type canvas_item;

// --- Controls ---
uniform float intensity       : hint_range(0.0,1.0) = 0.45;
uniform float border_width    : hint_range(0.0,0.6) = 0.22;
uniform float softness        : hint_range(0.01,0.6) = 0.25;
uniform float flow_speed      : hint_range(0.0,2.0) = 0.4;
uniform float flow_scale      : hint_range(0.5,8.0) = 3.0;
uniform float warp_strength   : hint_range(0.0,1.0) = 0.3;
uniform float bokeh_variance  : hint_range(0.0,1.0) = 0.3;
uniform float blur_amount     : hint_range(0.0,3.0) = 1.1;
uniform float blur_speed      : hint_range(0.0,2.0) = 0.4;

uniform vec4 color_a : source_color = vec4(0.10,0.30,0.95,1.0);
uniform vec4 color_b : source_color = vec4(0.65,0.20,0.90,1.0);

// === fbm noise ===
float hash11(float n){ return fract(sin(n)*43758.5453123); }
vec2 hash22(vec2 p){
	vec2 q = vec2(dot(p, vec2(127.1,311.7)), dot(p, vec2(269.5,183.3)));
	return fract(sin(q)*43758.5453123);
}
float noise(vec2 x){
	vec2 i=floor(x), f=fract(x);
	vec2 u=f*f*(3.0-2.0*f);
	return mix(
		mix(dot(hash22(i+vec2(0,0)),f-vec2(0,0)),
		    dot(hash22(i+vec2(1,0)),f-vec2(1,0)),u.x),
		mix(dot(hash22(i+vec2(0,1)),f-vec2(0,1)),
		    dot(hash22(i+vec2(1,1)),f-vec2(1,1)),u.x),
		u.y);
}
float fbm(vec2 p){
	float a=0.0, w=0.6;
	for(int i=0;i<3;i++){ a+=w*noise(p); p*=2.03; w*=0.45; }
	return a;
}

void fragment(){
	vec2 uv = UV;
	float t = TIME * flow_speed;

	// base noise field for breathing blobs
	float n_field = fbm(uv * flow_scale + vec2(t*0.6, -t*0.5));

	// horizontal / vertical edge distances
	float dx = min(uv.x, 1.0 - uv.x);
	float dy = min(uv.y, 1.0 - uv.y);

	// dynamic warping (brings back blobbiness)
	float warp = fbm(uv * (flow_scale * 0.8) + vec2(t, -t*0.7)) - 0.5;
	dx += warp * warp_strength * 0.25;
	dy += warp * warp_strength * 0.25;

	// animate inward/outward breathing
	float local_width = border_width * (1.0 + 0.15 * sin(t + n_field*3.14));

	// per-axis masks (edge bands)
	float mask_x = smoothstep(local_width + softness, local_width, dx);
	float mask_y = smoothstep(local_width + softness, local_width, dy);

	// blend them smoothly (union → no seams)
	float mask = 1.0 - (1.0 - mask_x) * (1.0 - mask_y);
	mask = pow(mask, 1.15);

	// subtle organic modulation (restores “blob” variance)
	float blob_mod = fbm(uv * flow_scale * 1.5 + vec2(t*0.9, -t*1.1));
	mask *= 0.85 + 0.15 * sin(blob_mod * 6.28 + t*0.7);

	// variable transparency flicker (bokeh shimmer)
	float alpha_mod = 1.0 - bokeh_variance * (0.5 + 0.5*sin((blob_mod + t)*3.14159));
	mask *= alpha_mod;

	// direction for blur (inward)
	vec2 dir = normalize(vec2(0.5 - uv.x, 0.5 - uv.y));
	vec3 blurred = vec3(0.0);
	const int steps = 3;
	for (int i = 0; i < steps; i++) {
		float off = (float(i) - float(steps-1)/2.0) * blur_amount / SCREEN_PIXEL_SIZE.x;
		vec2 suv = clamp(uv + dir * off * (0.5 + 0.5*sin(t*blur_speed)), vec2(0.0), vec2(1.0));
		float w = 1.0 - abs(float(i) - float(steps-1)/2.0) / float(steps);
		vec3 c = mix(color_a.rgb, color_b.rgb, 0.5 + 0.5*sin(t*0.4 + blob_mod*2.0));
		blurred += c * w;
	}
	blurred /= float(steps);

	// fade to transparent version of same hue
	vec4 col_edge = vec4(blurred, 1.0);
	vec4 col_trans = vec4(blurred, 0.0);
	vec4 final_col = mix(col_trans, col_edge, mask);

	COLOR *= final_col * intensity;
}
