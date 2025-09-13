// Category: Post-Processing & Vintage
// Name: Cine-Luxe Projector
precision highp float;

// --- Standard Uniforms (Matches app's structure) ---
uniform float u_time;
uniform vec2 u_resolution;
uniform sampler2D u_backgroundTexture;

// --- Audio Uniforms (Matches app's structure) ---
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

// --- TWEAKABLE PARAMETERS ---
// Adjust these values to customize the "feel" of the projector.
#define CONTRAST_INTENSITY 0.5      // How much bass adds punchiness.
#define BRIGHTNESS_INTENSITY 0.1    // How much treble adds a bright shimmer.
#define GRAIN_INTENSITY 0.1         // The overall amount of film grain.
#define VIGNETTE_INTENSITY 0.8      // How dark the corners are.
#define FLICKER_INTENSITY 0.1       // The strength of the lamp flicker.
#define SCRATCH_JUMP_SPEED 2.0      // How often new scratches appear (higher is faster).

// --- Utility Functions ---
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void main() {
    // --- 1. Get Base Image & Handle Fallback ---
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec3 finalColor = texture2D(u_backgroundTexture, uv).rgb;

    // In-shader fallback for when no image is loaded.
    // If the texture is pure black (the default), we use a dark grey instead.
    if (dot(finalColor, vec3(1.0)) < 0.01) {
        finalColor = vec3(0.1);
    }

    // --- 2. Audio-Reactive Color Grading & Levels ---

    // A. Contrast (driven by Bass)
    float contrast = 1.0 + u_bassLevel * CONTRAST_INTENSITY;
    finalColor = (finalColor - 0.5) * contrast + 0.5;

    // B. Brightness (driven by Treble)
    float brightness = u_trebleLevel * BRIGHTNESS_INTENSITY;
    finalColor += brightness;

    // C. Harmonic Sepia Tones (driven by Spectral Centroid)
    float luminance = dot(finalColor, vec3(0.299, 0.587, 0.114));
    vec3 hot_tint = vec3(1.0, 0.8, 0.6); // Warm Sepia
    vec3 cold_tint = vec3(0.7, 0.8, 1.0); // Cool Cyan
    vec3 harmonic_tint = mix(hot_tint, cold_tint, smoothstep(0.4, 0.6, u_spectralCentroid));
    float sepia_amount = 1.0 - smoothstep(0.3, 0.8, u_spectralCentroid);
    finalColor = mix(finalColor, harmonic_tint * luminance, sepia_amount);


    // --- 3. Physical Film Artifacts ---

    // A. Film Grain
    float grain_energy = (u_bassLevel + u_trebleLevel);
    finalColor += (random(uv + u_time) - 0.5) * grain_energy * GRAIN_INTENSITY;

    // B. Scratches & Dust (triggered by Beat)
    float film_jump_seed = floor(u_time * SCRATCH_JUMP_SPEED);
    if (u_beatDetected > 0.5) {
        film_jump_seed += u_beatDetected * 100.0;
    }
    float scratch_pos = random(vec2(film_jump_seed));
    float scratch_width = 0.001 + random(vec2(film_jump_seed + 1.0)) * 0.002;
    float scratches = smoothstep(scratch_width, 0.0, abs(uv.x - scratch_pos)) * 0.8;
    float dust = smoothstep(0.9995, 1.0, random(floor(uv * 300.0) + film_jump_seed));

    finalColor -= (scratches + dust) * 0.5;


    // --- 4. Projector Simulation ---

    // A. Lens Vignette
    float vignette = 1.0 - length((uv - 0.5) * vec2(1.0, 1.2)) * VIGNETTE_INTENSITY;
    finalColor *= vignette;

    // B. Lamp Flicker
    float flicker_speed = 20.0 + (u_bassLevel + u_trebleLevel) * 20.0;
    float flicker = 0.95 + random(vec2(u_time * flicker_speed)) * FLICKER_INTENSITY;
    finalColor *= flicker;


    // --- 5. FINAL OUTPUT ---
    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}