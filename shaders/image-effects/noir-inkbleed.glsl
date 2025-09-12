// --- Noir Inkbleed ---
// Description: Simulates ink spreading on paper, revealing a high-contrast
// version of the background image. Inspired by crime show title sequences.

precision mediump float;

// Standard Uniforms
uniform float u_time;
uniform vec2 u_resolution;
uniform sampler2D u_backgroundTexture;

// Audio Uniforms
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_energyLevel;
uniform float u_beatDetected;

// --- Helper Functions ---

// 2D pseudo-random number generator
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 2D Fractional Brownian Motion (fbm) - for organic, cloudy noise
// This is the core of our ink splotch effect.
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
}

float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}


void main() {
    // --- 1. UV COORDINATE & JITTER SETUP ---
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    
    // EFFECT: Treble-reactive signal jitter
    // Adds horizontal instability for a tense, surveillance-feed vibe.
    uv.x += (random(vec2(uv.y, u_time * 0.1)) - 0.5) * 0.005 * u_trebleLevel;


    // --- 2. INK MASK GENERATION ---
    // Generate a moving, organic noise pattern using fbm.
    // The time component makes the ink patterns evolve slowly.
    float noisePattern = fbm(uv * 3.0 + u_time * 0.1);

    // EFFECT: Bass-controlled ink bleed
    // The threshold determines how much of the noise becomes "ink".
    // High bass lowers the threshold, causing the ink to spread dramatically.
    float inkThreshold = 0.7 - u_bassLevel * 0.4;
    
    // Use smoothstep to create a sharp but anti-aliased edge for the ink.
    float inkMask = smoothstep(inkThreshold - 0.05, inkThreshold, noisePattern);


    // --- 3. BACKGROUND IMAGE PROCESSING ---
    // Sample the original image color.
    vec3 imageColor = texture2D(u_backgroundTexture, uv).rgb;

    // Convert to grayscale for that classic "noir" look.
    float luma = dot(imageColor, vec3(0.299, 0.587, 0.114));
    
    // EFFECT: Energy-based contrast boost
    // This crushes the image towards pure black and white as energy increases.
    float contrast = 1.0 + u_energyLevel * 3.0;
    luma = (luma - 0.5) * contrast + 0.5;

    vec3 noirImage = vec3(luma);


    // --- 4. COMPOSITING ---
    // Define the "paper" color (a slightly warm, off-white).
    vec3 paperColor = vec3(0.9, 0.88, 0.85);

    // Use the inkMask to blend between the paper and the noir-processed image.
    // Where inkMask is 0, we see paper. Where it's 1, we see the image.
    vec3 finalColor = mix(paperColor, noirImage, inkMask);


    // --- 5. ACCENT EFFECTS ---
    // EFFECT: Beat-reactive blood flash
    // On a beat, we mix in a deep red color, but ONLY where the ink is.
    // Multiplying by inkMask is key to this targeted effect.
    vec3 bloodColor = vec3(0.5, 0.0, 0.05);
    finalColor = mix(finalColor, bloodColor, u_beatDetected * inkMask * 0.8);
    

    // --- 6. FINAL OUTPUT ---
    gl_FragColor = vec4(finalColor, 1.0);
}