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

uniform sampler2D u_backgroundTexture;
// Recommended for best effect: a texture of the raw waveform
uniform sampler2D u_timeDomainTexture;

// --- TWEAKABLE GLITCH PARAMETERS ---
#define BARREL_DISTORTION 0.15      // How curved the CRT screen is.
#define EMP_INTENSITY 0.2           // The strength of the main beat discharge.
#define BASS_WOBBLE_INTENSITY 0.01  // How much bass warps the scanlines.
#define TREBLE_JITTER_INTENSITY 0.005 // How much treble causes pixel jitter.
#define BLOCK_GLITCH_THRESHOLD 0.9  // At what treble level data corruption starts.

// --- Utility Functions ---
float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    
    // --- 1. CRT Geometry Simulation ---
    // Apply barrel distortion to simulate a curved glass screen.
    vec2 centered_uv = uv - 0.5;
    centered_uv *= 1.0 + dot(centered_uv, centered_uv) * BARREL_DISTORTION;
    vec2 distorted_uv = centered_uv + 0.5;

    // --- 2. Audio-Reactive Glitches (UV Manipulation) ---
    // A smoothed beat value that decays over time, for animating the EMP hit.
    float s_beat_decay = pow(1.0 - fract(u_time * 2.0), 4.0) * u_beatDetected;

    // A. The EMP Discharge (triggered by Beat)
    // Creates a massive, violent horizontal tearing wave.
    float emp_wave = sin(distorted_uv.y * 30.0 + u_time * 10.0) * s_beat_decay * EMP_INTENSITY;
    // The wave's shape is modulated by the raw waveform for a more chaotic feel.
    emp_wave *= texture(u_timeDomainTexture, vec2(fract(distorted_uv.y), 0.5)).r * 2.0;
    distorted_uv.x += emp_wave;

    // B. Magnetic Flux Wobble (driven by Bass)
    // Simulates the magnetic field warping, causing scanlines to wobble.
    distorted_uv.x += sin(distorted_uv.y * 80.0 + u_time * 2.0) * u_bassLevel * BASS_WOBBLE_INTENSITY;

    // C. Data Jitter (driven by Treble)
    // High-frequency sounds cause the signal to lose sync, jittering pixels.
    distorted_uv.x += (hash1(distorted_uv * u_time) - 0.5) * u_trebleLevel * TREBLE_JITTER_INTENSITY;

    // D. Block Corruption (driven by Treble)
    // At high treble, the decoder fails, showing large blocks of corrupted data.
    if (u_trebleLevel > BLOCK_GLITCH_THRESHOLD) {
        distorted_uv = floor(distorted_uv * 100.0) / 100.0;
    }

    // --- 3. Texture Sampling & Chromatic Aberration ---
    // The glitches are amplified by splitting the RGB channels.
    vec2 r_offset = vec2(s_beat_decay * 0.05, 0.0);
    vec2 b_offset = vec2(s_beat_decay * 0.03, 0.0);
    float r = texture(u_backgroundTexture, distorted_uv + r_offset).r;
    float g = texture(u_backgroundTexture, distorted_uv).g;
    float b = texture(u_backgroundTexture, distorted_uv - b_offset).b;
    vec3 finalColor = vec3(r, g, b);

    // Fallback for when no image is loaded
    if (dot(finalColor, vec3(1.0)) < 0.01) {
        finalColor = vec3(0.05); // Use a very dark grey for CRTs
    }

    // --- 4. CRT Display Simulation (Post-Processing) ---

    // A. Scanlines
    finalColor *= 0.8 + 0.2 * sin(gl_FragCoord.y * 1.5);

    // B. Phosphor Dot Mask
    // Dims alternate color channels to simulate a real CRT's RGB phosphors.
    float phosphor_mask = mod(gl_FragCoord.x, 2.0);
    if (phosphor_mask < 1.0) { finalColor.r *= 0.8; }
    else { finalColor.gb *= 0.8; }

    // C. Audio-Reactive Color Grading
    // Shifts from a healthy green to a damaged, dying red based on audio.
    vec3 healthy_tint = vec3(0.5, 1.0, 0.6);
    vec3 damaged_tint = vec3(1.0, 0.3, 0.1);
    // Centroid controls the base tint, but a beat forces it into the "damaged" state.
    float damage_level = smoothstep(0.4, 0.7, u_spectralCentroid) + s_beat_decay;
    finalColor *= mix(healthy_tint, damaged_tint, clamp(damage_level, 0.0, 1.0));

    // D. Signal Noise & Flicker
    finalColor += (hash1(uv + u_time) - 0.5) * u_trebleLevel * 0.2; // Treble static
    finalColor *= 0.9 + hash1(vec2(u_time * 30.0)) * 0.1; // General flicker

    outColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}