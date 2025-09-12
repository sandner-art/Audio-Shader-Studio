// --- Audio-Reactive Image Degrader ---
// Description: A modern motion graphics shader that deforms, color-shifts,
// and degrades the background image in response to multiple audio features.

precision mediump float;

// Standard Uniforms
uniform float u_time;
uniform vec2 u_resolution;
uniform sampler2D u_backgroundTexture;

// Audio Uniforms
uniform float u_audioLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_energyLevel;
uniform float u_beatDetected; // Perfect for sharp, sudden effects

// --- Tweakable Parameters ---
// Feel free to change these values to alter the effect's intensity!
#define BASS_WAVE_INTENSITY 0.03
#define BEAT_ZOOM_INTENSITY 0.05
#define CHROMATIC_ABERRATION_INTENSITY 0.015
#define TREBLE_GRAIN_INTENSITY 0.15

// A simple pseudo-random number generator
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void main() {
    // --- 1. UV COORDINATE SETUP ---
    // Get normalized screen coordinates (0.0 to 1.0)
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    // Get coordinates centered on the screen (-0.5 to 0.5) for radial effects
    vec2 centered_uv = uv - 0.5;

    
    // --- 2. UV DISTORTION EFFECTS ---
    // These effects manipulate the coordinates BEFORE we sample the image texture.
    
    vec2 distorted_uv = uv;

    // Effect A: Gentle, continuous ambient warping using time
    // This gives the image a slow, fluid, or heat-haze-like motion.
    distorted_uv.x += sin(uv.y * 10.0 + u_time * 0.5) * 0.005;
    distorted_uv.y += cos(uv.x * 12.0 + u_time * 0.3) * 0.005;

    // Effect B: Bass-reactive radial shockwave
    // This creates a "thump" that expands from the center, driven by low-end frequencies.
    float distanceFromCenter = length(centered_uv);
    float bassWave = sin(distanceFromCenter * 20.0 - u_time * 4.0) * u_bassLevel * BASS_WAVE_INTENSITY;
    distorted_uv += normalize(centered_uv) * bassWave;
    
    // Effect C: Beat-reactive "punch" or zoom
    // When a beat is detected, the image quickly zooms in and out from the center.
    distorted_uv -= normalize(centered_uv) * u_beatDetected * BEAT_ZOOM_INTENSITY;


    // --- 3. TEXTURE SAMPLING & COLOR EFFECTS ---
    // Now we get the color from the image using our distorted coordinates.

    // Effect D: Chromatic Aberration on Beat
    // Splits the RGB channels slightly for a glitchy, high-impact effect on beats.
    float R = texture2D(u_backgroundTexture, distorted_uv + vec2(CHROMATIC_ABERRATION_INTENSITY, 0.0) * u_beatDetected).r;
    float G = texture2D(u_backgroundTexture, distorted_uv).g;
    float B = texture2D(u_backgroundTexture, distorted_uv - vec2(CHROMATIC_ABERRATION_INTENSITY, 0.0) * u_beatDetected).b;
    vec3 texColor = vec3(R, G, B);

    
    // --- 4. COLOR GRADING & DEGRADATION ---
    // These effects modify the final color.

    // Effect E: Energy-based Saturation
    // As the overall energy of the track increases, the colors become more vibrant.
    vec3 finalColor = texColor;
    float grayscale = dot(finalColor, vec3(0.299, 0.587, 0.114));
    float saturationAmount = 1.0 + u_energyLevel * 0.5; // From normal (1.0) to more saturated
    finalColor = mix(vec3(grayscale), finalColor, saturationAmount);

    // Effect F: Treble-reactive Film Grain
    // Adds a layer of noise that "fizzes" with high-frequency sounds like cymbals.
    float grain = random(uv + u_time) * u_trebleLevel * TREBLE_GRAIN_INTENSITY;
    finalColor += grain;


    // --- 5. FINAL OUTPUT ---
    gl_FragColor = vec4(finalColor, 1.0);
}