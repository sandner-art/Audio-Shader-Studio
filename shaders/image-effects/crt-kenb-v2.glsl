#version 300 es
precision highp float;

out vec4 outColor;

// --- Uniforms ---
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

uniform sampler2D u_backgroundTexture;

// --- TWEAKABLE PARAMETERS ---
#define KEN_BURNS_ZOOM_SPEED 0.1
#define KEN_BURNS_ZOOM_AMOUNT 0.2
#define KEN_BURNS_PAN_SPEED 0.08
#define KEN_BURNS_PAN_AMOUNT 0.1

#define GLITCH_ZONE_SCALE 8.0     // Lower numbers = bigger glitch zones.
#define GLITCH_THRESHOLD 0.95     // Likelihood of a zone glitching (0.95 = 5% chance).
#define GLITCH_INTENSITY 0.1      // The strength of the tearing/blockiness.

#define ZOOM_CRT_THRESHOLD 1.15   // At what zoom level the CRT grid appears.

// Category: Post-Processing & Glitch
// Name: CRT Glitch with Ken Burns effect
// --- Utility Functions ---
float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(p*mat2(12.98,78.23,26.67,82.34))*43758.5); }

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    
    // --- 1. The Ken Burns Camera Effect ---
    // A slow, continuous pan and zoom to give the image a cinematic feel.
    float zoom_level = 1.0 + sin(u_time * KEN_BURNS_ZOOM_SPEED) * KEN_BURNS_ZOOM_AMOUNT;
    vec2 pan_offset = vec2(sin(u_time * KEN_BURNS_PAN_SPEED), cos(u_time * KEN_BURNS_PAN_SPEED * 0.7)) * KEN_BURNS_PAN_AMOUNT;
    vec2 ken_burns_uv = (uv - 0.5) / zoom_level + 0.5 + pan_offset;

    // --- 2. Localized Glitch Zones (Voronoi) ---
    // We create invisible zones, and on a beat, some of them will glitch.
    vec2 final_uv = ken_burns_uv;
    if (u_beatDetected > 0.5) {
        vec2 cell_id = floor(ken_burns_uv * GLITCH_ZONE_SCALE);
        // Check if this cell is chosen to glitch
        if (hash1(cell_id) > GLITCH_THRESHOLD) {
            vec2 random_offset = (hash2(cell_id) - 0.5) * GLITCH_INTENSITY;
            // The glitch is a combination of horizontal tearing and block corruption.
            final_uv.x += random_offset.x;
            final_uv = floor(final_uv * 100.0) / 100.0;
        }
    }
    
    // Add a subtle, continuous bass shake on top of everything.
    final_uv += (hash2(vec2(u_time*20.0)) - 0.5) * u_bassLevel * 0.005;

    // --- 3. Texture Sampling & CRT Reveal ---
    // We sample the image using our final, glitched UV coordinates.
    vec3 finalColor = texture(u_backgroundTexture, final_uv).rgb;

    // Fallback if no image is loaded
    if (dot(finalColor, vec3(1.0)) < 0.01) {
        finalColor = vec3(0.05);
    }
    
    // The CRT phosphor grid is only revealed when the Ken Burns camera zooms in close.
    float zoom_reveal = smoothstep(ZOOM_CRT_THRESHOLD, ZOOM_CRT_THRESHOLD + 0.1, zoom_level);
    if (zoom_reveal > 0.0) {
        vec2 phosphor_uv = fract(final_uv * u_resolution.y * 0.2);
        float phosphor_dist = length(phosphor_uv - 0.5);
        float phosphor_grid = smoothstep(0.4, 0.3, phosphor_dist);
        finalColor = mix(finalColor, vec3(0.8, 1.0, 0.9), phosphor_grid * zoom_reveal);
    }
    
    // --- 4. Bluish Color Grading & Audio Reactivity ---
    float luminance = dot(finalColor, vec3(0.299, 0.587, 0.114));
    vec3 base_tint = vec3(0.3, 0.9, 1.0); // Cyan
    vec3 highlight_tint = vec3(0.8, 1.0, 0.9); // Mint Green
    vec3 harmonic_tint = mix(base_tint, highlight_tint, smoothstep(0.4, 0.7, u_spectralCentroid));
    finalColor = luminance * harmonic_tint;

    // A beat triggers a sharp, bright flash.
    finalColor += u_beatDetected * 0.5;

    // --- 5. Final CRT Overlay Effects ---
    // Scanlines and a subtle vignette add to the "monitor" feel.
    finalColor *= 0.8 + 0.2 * sin(gl_FragCoord.y * 1.5);
    finalColor *= 1.0 - length(uv - 0.5) * 0.5;

    // Tonemapping to prevent over-exposure on bright flashes.
    finalColor = finalColor / (finalColor + vec3(1.0));
    finalColor = pow(finalColor, vec3(1.0/2.2));
    
    outColor = vec4(finalColor, 1.0);
}