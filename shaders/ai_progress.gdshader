shader_type canvas_item;

// --- Uniforms ---
// Speed of the blob movement and pulsing
uniform float speed : hint_range(0.1, 5.0) = 0.5;

// Scale of the grid (lower value = fewer, larger blobs)
uniform float density : hint_range(1.0, 20.0) = 4.0;

// How "wobbly" the shapes are (Domain Warping intensity)
uniform float fluidity : hint_range(0.0, 2.0) = 0.5;

// --- Appearance Customization ---
// The size of individual blobs relative to their grid cell (0.0 to 1.0)
uniform float blob_radius : hint_range(0.1, 1.0) = 0.45;

// How soft the edges are. 0.0 is sharp, 0.5 is very blurry.
uniform float edge_softness : hint_range(0.0, 1.0) = 0.05;

// Adds a subtle static noise texture for a "premium" feel
uniform float grain_amount : hint_range(0.0, 0.2) = 0.03;

// Colors matching a "Neural/Gemini" aesthetic
uniform vec4 color_primary : source_color = vec4(0.1, 0.3, 0.9, 1.0); // Deep Blue
uniform vec4 color_secondary : source_color = vec4(0.0, 0.7, 0.7, 1.0); // Cyan
uniform vec4 color_tertiary : source_color = vec4(0.6, 0.1, 0.8, 1.0); // Purple

// Master alpha control for fading via script
uniform float alpha_power : hint_range(0.0, 1.0) = 0.0;

// --- Functions ---

// 2D Random
vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// 2D Noise for warping
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix( mix( dot( random2(i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ),
                     dot( random2(i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                mix( dot( random2(i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ),
                     dot( random2(i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
}

// Voronoi that returns distance (x) and a random "ID" for the closest cell (y)
vec2 voronoi_blobs(vec2 uv, float time) {
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);
    
    float min_dist = 1.0; // Max search radius
    float cell_id = 0.0;
    
    // Check 3x3 neighbor grid
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            
            // Random offset for this grid cell
            vec2 point = random2(i_uv + neighbor);
            
            // Animate the point's position within the cell
            // We add unique timing offsets so they don't move in sync
            vec2 pos_offset = 0.5 + 0.5 * sin(time + 6.2831 * point);
            
            // Vector from current pixel to this point
            vec2 diff = neighbor + pos_offset - f_uv;
            float dist = length(diff);
            
            // --- BLOB FADING LOGIC ---
            // We use a separate sine wave to pulse the "size" of this specific blob.
            float pulse = 0.5 + 0.5 * sin(time * 0.8 + point.x * 10.0);
            
            // Threshold the pulse to make blobs appear/disappear
            float apparent_dist = dist / clamp(pulse, 0.01, 1.0);
            
            if (apparent_dist < min_dist) {
                min_dist = apparent_dist;
                cell_id = point.x; // Save the random ID of this cell
            }
        }
    }
    return vec2(min_dist, cell_id);
}

void fragment() {
	vec2 uv = UV;
	
	// Aspect Ratio Correction
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	uv += vec2(0.2, 0.0); // Center shift
	
	float time = TIME * speed;
	
	// --- Domain Warping ---
	vec2 warped_uv = uv * density;
	warped_uv += vec2(
		noise(uv * 3.0 + time * 0.5),
		noise(uv * 3.0 - time * 0.5)
	) * fluidity;
	
	// --- Generate Blobs ---
	vec2 blob_data = voronoi_blobs(warped_uv, time);
	
	float dist = blob_data.x;
	float id = blob_data.y;
	
	// --- Shape & Softness ---
	// dist increases from 0 (center) to >1 (outside).
	// smoothstep(edge1, edge0, x) creates a fade from 1.0 to 0.0
	// We use 'blob_radius' as the outer limit, and subtract 'edge_softness' for the inner limit.
	float outer_edge = blob_radius;
	float inner_edge = max(0.0, blob_radius - edge_softness);
	
	float shape = smoothstep(outer_edge, inner_edge, dist);
	
	// --- Coloring ---
	vec4 col = mix(color_primary, color_secondary, id);
	col = mix(col, color_tertiary, sin(id * 10.0 + time) * 0.5 + 0.5);
	
	// Slight brightness bump for "alive" feel
	col.rgb *= 1.0 + 0.2 * sin(time * 2.0 + id * 20.0);

	// --- Film Grain ---
	// Generate high frequency noise based on pixel coordinate
	float noise_grain = random2(UV + vec2(TIME * 5.0)).x;
	// Mix it into the color (subtly)
	col.rgb += (noise_grain - 0.5) * grain_amount;

	// --- Final Output ---
	COLOR = col;
	COLOR.a *= shape * alpha_power;
}