#version 300 es
precision highp float;

out vec4 outColor;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;
uniform sampler2D u_frequencyTexture;

const float PI = 3.1415926535;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // --- TUNING KNOBS: Audio Parameters ---
    float s_bass = u_bassLevel;
    float s_treble = u_trebleLevel;
    float s_beat = pow(1.0 - fract(u_time * 2.0), 4.0) * u_beatDetected;

    // --- Coordinate System Setup ---
    // Convert to 3D polar-like coordinates
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    // --- Constructing the Shape (SDF) ---
    // 1. Get the spectral data for this angle.
    // We map the angle (-PI to PI) to the texture coordinate (0 to 1).
    float freq_index = (angle / (2.0 * PI)) + 0.5;
    float spectral_radius = texture(u_frequencyTexture, vec2(freq_index, 0.5)).r;

    // 2. Define the main shape boundary. Treble makes it sharper and spikier.
    float shape_boundary = 0.2 + spectral_radius * (0.3 + s_treble);

    // 3. Add bass-driven twisting motion.
    // This gives the 2D shape a dynamic, 3D quality.
    shape_boundary += sin(radius * 10.0 + angle * 3.0 - u_time * 0.8) * 0.05 * s_bass;

    // 4. Calculate the distance to the shape and draw a glowing line.
    float dist_to_shape = abs(radius - shape_boundary);
    float line_width = 0.005 + spectral_radius * 0.02;
    float line = smoothstep(line_width, 0.0, dist_to_shape);
    float glow = smoothstep(line_width + 0.1, 0.0, dist_to_shape);

    // --- Coloring and Final Composition ---
    vec3 color = vec3(0.0);

    // Color the line based on its frequency (angle).
    vec3 line_color = 0.5 + 0.5 * cos(freq_index * 2.0 * PI * 2.0 + vec3(0.0, 0.8, 1.5));
    color += line * line_color * 2.0; // Make the core line bright
    color += glow * line_color * 0.5; // Add a softer glow

    // A central core that pulses with the beat.
    float core_glow = (0.01 / (radius + 0.001)) * (s_bass + s_beat * 2.0);
    color += core_glow * vec3(0.8, 0.9, 1.0);

    // A beat creates a radial shockwave that travels outwards.
    float shockwave = smoothstep(0.01, 0.0, abs(radius - s_beat * 0.8)) * s_beat;
    color += shockwave * 2.0;

    outColor = vec4(color, 1.0);
}