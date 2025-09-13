#version 300 es
precision highp float;

out vec4 outColor;

// --- Uniforms for time, resolution, and audio data ---
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_beatDetected;
uniform sampler2D u_frequencyTexture;
uniform sampler2D u_timeDomainTexture;

const float PI = 3.1415926535;

// --- 2D SDF & Helper Functions ---
// Signed distance function for a line segment
float sdLine(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}
// Signed distance function for an arc
float sdArc(vec2 p, float radius, float angle_start, float angle_end, float thickness) {
    float angle = atan(p.y, p.x);
    if (angle < angle_start || angle > angle_end) return 1000.0;
    return abs(length(p) - radius) - thickness * 0.5;
}


void main() {
    // --- Setup: UVs, Time, and Color Palette ---
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    vec3 finalColor = vec3(0.0);
    float time = u_time * 0.5;

    // --- Audio-Reactive Parameters & Color ---
    float s_beat = pow(1.0 - fract(u_time * 2.0), 4.0) * u_beatDetected;
    vec3 base_color = vec3(1.0, 0.4, 0.0); // Primary orange
    vec3 lockon_color = vec3(0.0, 1.0, 1.0); // Cyan for beat flash
    vec3 hud_color = mix(base_color, lockon_color, s_beat);

    // --- 1. Central Spectrogram - DIVIDED DISPLAY ---

    // --- Part A: Upper Half - Multi-Ring Spectrogram (from Shader 1) ---
    // Provides a textured, granular view of the upper frequency range.
    const int num_rings = 4;
    const int num_segments_upper = 18;
    for (int i = 0; i < num_rings; i++) {
        float ring_radius = 0.15 + float(i) * 0.06;
        for (int j = 0; j < num_segments_upper; j++) {
            float seg_angle = (float(j) / float(num_segments_upper)) * PI; // Only 0 to PI
            if(atan(uv.y, uv.x) < 0.0) continue; // Only draw in upper half

            float freq_index = (seg_angle / (2.0 * PI));
            freq_index = mix(freq_index, 0.1, float(num_rings - i) / float(num_rings));
            float spectral_amp = texture(u_frequencyTexture, vec2(freq_index, 0.5)).r;

            float seg_thickness = 0.04 + spectral_amp * 0.04 * (1.0 + u_trebleLevel);
            float seg_dist = sdArc(uv, ring_radius, seg_angle, seg_angle + 0.15, seg_thickness);

            float intensity = smoothstep(0.005, 0.0, seg_dist);
            vec3 seg_color = mix(hud_color, vec3(1.0, 1.0, 0.5), spectral_amp);
            finalColor += intensity * seg_color * (0.5 + spectral_amp);
        }
    }

    // --- Part B: Lower Half - Polar Waveform Spectrogram (from Shader 2) ---
    // The requested prime design element, showing clear amplitude spikes.
    const int num_segments_lower = 64;
    float base_radius = 0.25; // Placed between the center and the upper rings
    for (int i = 0; i < num_segments_lower; i++) {
        // Map segments to the lower half circle
        float seg_angle = PI + (float(i) / float(num_segments_lower)) * PI;
        float freq_index = float(i) / float(num_segments_lower);
        float spectral_amp = texture(u_frequencyTexture, vec2(freq_index, 0.5)).r;
        
        // Calculate the start and end points of the line
        float seg_length = 0.02 + spectral_amp * (0.2 + u_trebleLevel * 0.2);
        vec2 p1 = vec2(cos(seg_angle), sin(seg_angle)) * base_radius;
        vec2 p2 = p1 * (1.0 + seg_length);
        
        // Draw the line and color it based on amplitude
        float seg_dist = sdLine(uv, p1, p2);
        finalColor += smoothstep(0.005, 0.0, seg_dist) * hud_color * (0.8 + spectral_amp);
    }


    // --- 2. Rotating Scanner & Static Rings (from Shader 1) ---
    float scan_angle = fract(time * 0.2) * 2.0 * PI;
    float scan_dist = sdArc(uv, 0.38, scan_angle, scan_angle + 0.02, 0.76);
    finalColor += smoothstep(0.005, 0.0, scan_dist) * hud_color * 0.5;
    finalColor += smoothstep(0.1, 0.0, scan_dist) * hud_color * 0.1;

    float center_ring = abs(length(uv) - 0.08) - 0.003;
    finalColor += smoothstep(0.001, 0.0, center_ring) * hud_color;
    float outer_ring1 = abs(length(uv) - 0.4) - 0.002;
    finalColor += smoothstep(0.001, 0.0, outer_ring1) * hud_color * 0.5;


    // --- 3. Waveform Oscilloscope (from Shader 2) ---
    if (uv.x > 0.3 && uv.y < -0.4 && uv.y > -0.6) {
        vec2 scope_uv = vec2((uv.x - 0.5) * 4.0, (uv.y + 0.5) * 5.0);
        float wave_amp = texture(u_timeDomainTexture, vec2(scope_uv.x * 0.5 + 0.5, 0.5)).r * 2.0 - 1.0;
        float line_dist = abs(scope_uv.y - wave_amp * 0.5);
        finalColor += smoothstep(0.03, 0.0, line_dist) * hud_color * 0.7;
    }

    // --- 4. Stereo Vectorscope (from Shader 2) ---
    if (length(uv - vec2(-0.5, -0.5)) < 0.15) {
        vec2 vector_uv = (uv - vec2(-0.5, -0.5)) * 10.0;
        float min_dist = 100.0;
        for(int i=0; i<64; i++){
            float t = float(i)/64.0;
            float l = texture(u_timeDomainTexture, vec2(t, 0.5)).r * 2.0 - 1.0;
            float r = texture(u_timeDomainTexture, vec2(t + 0.01, 0.5)).r * 2.0 - 1.0;
            min_dist = min(min_dist, length(vector_uv - vec2(l+r, l-r)*0.5));
        }
        finalColor += smoothstep(0.05, 0.0, min_dist) * hud_color;
    }

    // --- 5. Bass-Reactive Brackets (from Shader 2) ---
    vec2 bracket_uv = abs(uv);
    float bracket_size = 0.42 + u_bassLevel * 0.08;
    float h_line = abs(bracket_uv.x - bracket_size) - 0.002;
    float v_line = abs(bracket_uv.y - bracket_size) - 0.002;
    float bracket_shape = min(h_line, v_line);
    if(bracket_uv.x < bracket_size-0.1 || bracket_uv.y < bracket_size-0.1) bracket_shape=1e9;
    finalColor += smoothstep(0.001, 0.0, bracket_shape) * hud_color * 0.7;

    // --- Final Output ---
    outColor = vec4(finalColor, 1.0);
}