precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_energyLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform sampler2D u_frequencyTexture;
uniform float u_beatDetected;
uniform float u_onsetDetected;

// Pseudo-random function for noise/snow
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 original_uv = uv; // Keep a copy for sampling
    
    // --- CRT Barrel Distortion ---
    // The screen warps outwards, pulsing with the bass.
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    float barrel_amount = 1.0 + pow(dist, 2.0) * (0.2 + u_bassLevel * 0.3);
    uv = center + (uv - center) / barrel_amount;

    // --- Bass Sync Roll ---
    // Heavy bass causes the vertical hold to fail, making the screen roll.
    float roll_speed = u_bassLevel * u_bassLevel * 2.0;
    uv.y += sin(u_time * 0.5 + uv.x * 3.0) * roll_speed * 0.1;
    uv.y = fract(uv.y);

    // --- Onset Tracking Error ---
    // Onsets cause a sharp horizontal shear and chromatic aberration.
    float onset_shear = (sin(uv.y * 20.0 + u_time * 10.0) * 0.05) * u_onsetDetected;
    
    // Sample color channels separately for chromatic aberration
    float r_channel_x = uv.x + onset_shear * 2.0;
    float g_channel_x = uv.x;
    float b_channel_x = uv.x - onset_shear * 2.0;

    // --- Waveform/Signal Display ---
    // Use the frequency texture as the core signal visualization
    float signal_r = texture2D(u_frequencyTexture, vec2(r_channel_x, 0.5)).r;
    float signal_g = texture2D(u_frequencyTexture, vec2(g_channel_x, 0.5)).r;
    float signal_b = texture2D(u_frequencyTexture, vec2(b_channel_x, 0.5)).r;

    // The signal becomes a glowing line on the screen
    float line_r = smoothstep(0.01, 0.0, abs(uv.y - 0.5 - (signal_r - 0.5) * 0.8));
    float line_g = smoothstep(0.01, 0.0, abs(uv.y - 0.5 - (signal_g - 0.5) * 0.8));
    float line_b = smoothstep(0.01, 0.0, abs(uv.y - 0.5 - (signal_b - 0.5) * 0.8));
    
    vec3 color = vec3(line_r, line_g, line_b);

    // --- Beat Power Surge ---
    // Beats cause a bright flash, intense screen shake, and scanline jitter.
    float beat_shake = (rand(vec2(u_time)) - 0.5) * 0.1 * u_beatDetected;
    uv.y += beat_shake;
    color += u_beatDetected * 2.0;

    // --- Treble Signal Noise (Snow) ---
    // High treble introduces analog "snow" as if the signal is weak.
    float snow = rand(uv + mod(u_time, 1.0)) * u_trebleLevel * 0.8;
    color += snow;

    // --- Phosphor Ghosting & Fading ---
    // A faint, persistent "burn-in" of the waveform, brighter with high energy.
    float ghost_signal = texture2D(u_frequencyTexture, vec2(original_uv.x, 0.5)).r;
    float ghost_line = smoothstep(0.1, 0.0, abs(original_uv.y - 0.5 - (ghost_signal - 0.5) * 0.8));
    color += ghost_line * vec3(0.1, 0.2, 0.15) * u_energyLevel;

    // Final CRT effect: vignette and faint scanlines
    color *= 1.0 - pow(dist * 1.1, 2.5);
    color *= 0.8 + fract(gl_FragCoord.y * 0.3) * 0.4;
    
    gl_FragColor = vec4(color, 1.0);
}