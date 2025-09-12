precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_energyLevel;
uniform float u_spectralCentroid;
uniform sampler2D u_frequencyTexture;
uniform float u_beatDetected;
uniform float u_onsetDetected;

// A pseudo-random number generator
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec3 color = vec3(0.0, 0.05, 0.08); // Dark terminal background

    // --- Data Stream ---
    // The y-position is warped slightly over time to create a scrolling effect
    float y_scan = uv.y + u_time * 0.1;
    // We sample the frequency texture based on the "scanned" y-position
    float spectrum = texture2D(u_frequencyTexture, vec2(fract(y_scan), 0.5)).r;
    
    // Create horizontal lines based on frequency magnitude
    float line = pow(spectrum, 3.0) * 20.0;
    line *= (1.0 + sin(y_scan * 800.0 + u_time) * 0.5); // Add a fine grain scanline effect
    
    // --- Onset Glitch ---
    // Onsets trigger a horizontal displacement "glitch"
    float onset_glitch = (rand(uv + u_time) - 0.5) * u_onsetDetected * 0.5;
    uv.x += onset_glitch;

    // --- Beat Glitch ---
    // Beats trigger a "block corruption" effect
    if (u_beatDetected > 0.5) {
        vec2 block_uv = floor(uv * 8.0) / 8.0;
        uv.x += (rand(block_uv) - 0.5) * 0.1;
    }

    // Combine line with base color, coloring it by spectral centroid
    vec3 streamColor = mix(vec3(0.1, 1.0, 0.8), vec3(1.0, 0.5, 1.0), u_spectralCentroid);
    color += line * streamColor * u_energyLevel * 1.5;

    // Add a classic CRT vignette and scanline effect
    float vignette = length(uv - 0.5) * 1.2;
    color *= (1.0 - vignette);
    color *= (0.8 + fract(gl_FragCoord.y * 0.2) * 0.2);

    gl_FragColor = vec4(color, 1.0);
}