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
uniform float u_beatCount; // Integer beat counter from JS

uniform sampler2D u_backgroundTexture;

// --- TWEAKABLE PARAMETERS ---
#define ZOOM_BEAT_INTERVAL 16.0 // Zoom will trigger on beats that are a multiple of this number.
#define ZOOM_DURATION 4.0       // How many beats the zoom effect lasts.
#define ZOOM_MAGNITUDE 15.0     // How far the zoom goes. Higher is more extreme.
#define BARREL_DISTORTION 0.2
#define BASS_GLOW_INTENSITY 0.2
#define TREBLE_JITTER_INTENSITY 0.002
#define SCANLINE_INTENSITY 0.2

// Category: Post-Processing & Sci-Fi
// Name: The Monolith CRT Matrix
// --- Utility Functions ---
float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    
    // --- 1. The "Matrix Zoom" Effect ---
    // This is the core cinematic event of the shader.
    float zoom_trigger = 0.0;
    // Check if the current beat is on our desired interval (e.g., every 16th beat).
    if (mod(floor(u_beatCount / ZOOM_BEAT_INTERVAL), 2.0) == 1.0) {
        // Create a smooth curve that lasts for ZOOM_DURATION beats.
        float beat_phase = fract(u_beatCount / ZOOM_DURATION);
        zoom_trigger = smoothstep(0.0, 0.2, beat_phase) * smoothstep(1.0, 0.8, beat_phase);
    }

    // Apply the zoom to the UV coordinates, centered on the screen.
    vec2 centered_uv = uv - 0.5;
    float zoom_level = 1.0 + zoom_trigger * ZOOM_MAGNITUDE;
    vec2 final_uv = centered_uv / zoom_level + 0.5;

    // --- 2. CRT Geometry & Audio-Reactive Instability ---
    // Barrel distortion for the curved screen effect
    vec2 barrel_uv = final_uv - 0.5;
    barrel_uv *= 1.0 + dot(barrel_uv, barrel_uv) * BARREL_DISTORTION;
    final_uv = barrel_uv + 0.5;

    // Subtle signal jitter driven by treble
    final_uv.x += (hash1(uv * u_time) - 0.5) * u_trebleLevel * TREBLE_JITTER_INTENSITY;
    
    // --- 3. Image Sampling & Phosphor Grid Reveal ---
    vec3 finalColor = texture(u_backgroundTexture, final_uv).rgb;

    // Fallback if no image is loaded
    if (dot(finalColor, vec3(1.0)) < 0.01) {
        finalColor = vec3(0.05);
    }
    
    // The Phosphor Grid is only visible during the zoom.
    // We get the coordinates of the individual phosphor "cell" we're in.
    vec2 phosphor_uv = fract(final_uv * u_resolution.y * 0.1 * zoom_level);
    float phosphor_dist = length(phosphor_uv - 0.5);
    // Create a grid of glowing dots.
    float phosphor_grid = smoothstep(0.4, 0.3, phosphor_dist);
    // The grid is only visible when the zoom is active.
    finalColor *= 1.0 + phosphor_grid * zoom_trigger * 2.0;

    // --- 4. Bluish Color Grading & Audio Reactivity ---
    // The core of the "Matrix" aesthetic.
    
    // Convert to grayscale to control the color precisely.
    float luminance = dot(finalColor, vec3(0.299, 0.587, 0.114));
    
    // Define our "Monolith" blue/green palette.
    vec3 base_tint = vec3(0.3, 0.9, 1.0); // Cyan
    vec3 highlight_tint = vec3(0.8, 1.0, 0.9); // Mint Green
    
    // The spectral centroid shifts the color between the base and highlight tints.
    vec3 harmonic_tint = mix(base_tint, highlight_tint, smoothstep(0.4, 0.7, u_spectralCentroid));
    
    finalColor = luminance * harmonic_tint;

    // Bass causes the entire monitor to glow, simulating power surges.
    finalColor += u_bassLevel * BASS_GLOW_INTENSITY * base_tint;

    // A beat triggers a sharp, bright flash.
    finalColor += u_beatDetected * 0.5;

    // --- 5. Final CRT Overlay Effects ---
    // Scanlines
    finalColor *= 0.8 + SCANLINE_INTENSITY * sin(gl_FragCoord.y * 2.0);

    // Subtle Vignette
    finalColor *= 1.0 - length(centered_uv) * 0.5;

    // Clamp the final color to prevent over-exposure
    finalColor = clamp(finalColor, 0.0, 1.0);
    
    outColor = vec4(finalColor, 1.0);
}