#version 300 es
precision highp float;

out vec4 outColor;

// --- Standard & Audio Uniforms ---
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;
// --- NEW UNIFORM ---
uniform float u_beatCount; // An integer counter passed from JS

uniform sampler2D u_backgroundTexture;

// --- TWEAKABLE PARAMETERS ---
#define SHAKE_INTENSITY 0.01
#define BLUR_INTENSITY 0.005
#define CONTRAST_INTENSITY 0.5
#define GRAIN_INTENSITY 0.1
#define VIGNETTE_INTENSITY 0.8
#define SCRATCH_INTENSITY 0.5
#define Cinching_INTENSITY 0.8

// --- Utility Functions ---
float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    
    // --- 1. Audio-Reactive Image Destabilization ---
    vec2 final_uv = uv;

    // A. Film Jump on 8th Beat
    // This requires the new u_beatCount uniform from JavaScript.
    if (mod(u_beatCount, 8.0) == 0.0 && u_beatDetected > 0.5) {
        float slip_amount = hash1(vec2(u_beatCount)) * 0.1 - 0.05;
        final_uv.y += slip_amount;
    }

    // B. Gate Weave (subtle vertical shake driven by treble)
    final_uv.y += sin(u_time * 15.0) * 0.001 * u_trebleLevel;

    // C. Projector Shake (driven by bass)
    vec2 shake_offset = vec2(hash1(vec2(u_time * 20.0)) - 0.5, hash1(vec2(u_time * 20.0 + 1.0)) - 0.5);
    final_uv += shake_offset * u_bassLevel * SHAKE_INTENSITY;

    // --- 2. Base Image Sampling (with Blur) ---
    vec3 finalColor;

    // D. Radial Blur (driven by total energy)
    float total_energy = u_bassLevel + u_trebleLevel;
    vec2 blur_dir = normalize(uv - 0.5);
    // We take multiple samples of the image along the blur direction.
    finalColor = texture(u_backgroundTexture, final_uv).rgb * 0.5; // Center sample
    for(int i=1; i<=4; i++) {
        float fi = float(i);
        vec2 offset = blur_dir * fi * total_energy * BLUR_INTENSITY;
        finalColor += texture(u_backgroundTexture, final_uv + offset).rgb * 0.125;
        finalColor += texture(u_backgroundTexture, final_uv - offset).rgb * 0.125;
    }

    // Fallback if no image is loaded
    if (dot(finalColor, vec3(1.0)) < 0.01) {
        finalColor = vec3(0.1);
    }
    
    // --- 3. Audio-Reactive Color Grading ---
    float contrast = 1.0 + u_bassLevel * CONTRAST_INTENSITY;
    finalColor = (finalColor - 0.5) * contrast + 0.5;
    float luminance = dot(finalColor, vec3(0.299, 0.587, 0.114));
    vec3 hot_tint = vec3(1.0, 0.8, 0.6);
    vec3 cold_tint = vec3(0.7, 0.8, 1.0);
    vec3 harmonic_tint = mix(hot_tint, cold_tint, smoothstep(0.4, 0.6, u_spectralCentroid));
    float sepia_amount = 1.0 - smoothstep(0.3, 0.8, u_spectralCentroid);
    finalColor = mix(finalColor, harmonic_tint * luminance, sepia_amount);

    // --- 4. ENHANCED Physical Film Artifacts & Grit ---
    float film_jump_seed = floor(u_time * 2.0);
    if (u_beatDetected > 0.5) { film_jump_seed += u_beatDetected * 100.0; }

    float artifacts = 0.0;

    // A. Corrected Vertical Scratches (now straight lines that jitter)
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float scratch_seed = film_jump_seed + fi * 10.0;
        float scratch_pos = hash1(vec2(scratch_seed));
        // FIX: The wobble is now constant for the whole line, not a per-pixel sine wave.
        scratch_pos += (hash1(vec2(scratch_seed + u_time)) - 0.5) * 0.02;
        float scratch_width = 0.0005 + hash1(vec2(scratch_seed + 1.0)) * 0.002;
        artifacts += smoothstep(scratch_width, 0.0, abs(uv.x - scratch_pos));
    }

    // B. Cinching Marks / Edge Damage (new grit)
    float cinch_check = hash1(floor(uv * vec2(10.0, 200.0)) + film_jump_seed);
    if (cinch_check > 0.99) {
        float cinch_dist = length(fract(uv * vec2(10.0, 200.0)) - 0.5);
        // Confine marks to the left and right edges of the film.
        float edge_mask = smoothstep(0.4, 0.45, abs(uv.x - 0.5));
        artifacts += smoothstep(0.2, 0.0, cinch_dist) * edge_mask * Cinching_INTENSITY;
    }

    // C. Dust motes
    artifacts += smoothstep(0.9995, 1.0, hash1(floor(uv * 300.0) + film_jump_seed)) * 0.5;
    finalColor -= artifacts * SCRATCH_INTENSITY;

    // D. Film Grain
    float grain_energy = (u_bassLevel + u_trebleLevel);
    finalColor += (hash1(uv + fract(u_time * 10.0)) - 0.5) * grain_energy * GRAIN_INTENSITY;

    // --- 5. Projector Simulation ---
    float vignette = 1.0 - length((uv - 0.5) * vec2(1.0, 1.2)) * VIGNETTE_INTENSITY;
    finalColor *= vignette;

    outColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}