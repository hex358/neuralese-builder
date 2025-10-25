shader_type canvas_item;

// --- 1. GENERAL BRIGHTNESS ---
// Adjusts the overall lightness/exposure.
// Ranges from -1.0 (darkest) to 1.0 (brightest).
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;

// --- 2. CONTRAST ---
// Scales the color values away from the mid-point (0.5).
// Ranges from 0.0 (flat gray) to 3.0 (high contrast).
uniform float contrast : hint_range(0.0, 3.0) = 1.0;

// --- 3. TUNABLE LUMINOSITY BOOST (Bright Pixel Enhancement) ---
// Pixels with luminosity (l) > lumi_threshold will be pushed towards 1.0 (white).
// -----------------------------------------------------------
// Threshold: The minimum luminosity value for a pixel to start receiving a boost.
// Setting this to 0.0 means almost all non-black pixels are affected.
uniform float lumi_threshold : hint_range(0.0, 1.0) = 0.5;

// Boost Intensity: How aggressively the bright pixels are pushed to white.
uniform float lumi_boost_intensity : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    // Read the current texture color
    vec4 color = texture(TEXTURE, UV);
    vec3 rgb = color.rgb;

    // --- 1. Apply General Brightness ---
    rgb += vec3(brightness);

    // --- 2. Apply Contrast ---
    // Center the color around 0.5, scale, and recenter.
    rgb = (rgb - 0.5) * contrast + 0.5;

    // Clamp after the first two adjustments
    rgb = clamp(rgb, 0.0, 1.0);

    // --- 3. Apply Tunable Luminosity Boost ---
    
    // Calculate the luminosity (luma) using the standard NTSC formula.
    // This value represents the perceived brightness of the color.
    // (0.299 for red, 0.587 for green, 0.114 for blue)
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));

    // Check if the pixel's luminosity is above the user-defined threshold.
    if (l > lumi_threshold) {
        // Calculate the blending factor.
        // We use smoothstep to ensure a smooth transition:
        // - At lumi_threshold, factor is 0.
        // - At 1.0 luminosity, factor is 1.
        float intensity_factor = smoothstep(lumi_threshold, 1.0, l);

        // Determine the actual boost amount based on the factor and user intensity.
        float boost_amount = intensity_factor * lumi_boost_intensity;

        // Apply the boost by adding to the color, scaled by the color itself.
        // This preserves the hue while making the color brighter.
        rgb += rgb * boost_amount;
    }

    // --- Final Output ---
    // Ensure the final color is clamped to the 0.0 - 1.0 range
    COLOR.rgb = clamp(rgb, 0.0, 1.0);
    // Preserve the original alpha channel
    COLOR.a = color.a; 
}
