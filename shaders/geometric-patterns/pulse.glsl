// Category: Morphogenesis & Generative
// Name: Pulsating Cellular Growth
precision highp float;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_energyLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

const float PI = 3.1415926535;

// Noise function for organic texture
float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // --- 1. Coordinate System Setup ---
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    // --- 2. Audio-Driven Geometric Parameters ---

    // The core growth is driven by time and overall energy
    float growth_speed = u_time * 0.2 * (0.5 + u_energyLevel * 2.0);

    // Bass determines the number of major arms/lobes in the crystal.
    // More bass = more complex base shape.
    float lobes = floor(2.0 + u_bassLevel * 8.0);

    // Treble adds jagged, high-frequency detail to the edges.
    // It modulates the radius based on the angle.
    float jagged_detail = 0.05 * u_trebleLevel * sin(angle * 20.0 * (1.0 + u_spectralCentroid));

    // A beat creates a sharp ring that expands outwards.
    // We use a smoothstep to create a pulse that fades over time.
    float beat_ring = smoothstep(0.0, 0.1, u_beatDetected) *
                      smoothstep(0.05, 0.0, abs(radius - (growth_speed * 0.1)));


    // --- 3. Constructing the Shape (SDF) ---
    // This is the core formula for the shape's boundary.
    float shape_radius = 0.2 + growth_speed * 0.5;
    shape_radius += cos(angle * lobes) * 0.1 * (0.5 + u_energyLevel); // Add lobes
    shape_radius += jagged_detail;

    // Calculate the distance from the current pixel to the shape's boundary
    float dist_to_shape = abs(radius - shape_radius);
    float thickness = 0.01 + u_energyLevel * 0.05;
    float line = smoothstep(thickness, 0.0, dist_to_shape);


    // --- 4. Coloring and Final Composition ---
    vec3 color = vec3(0.0);

    // Color the main line based on spectral centroid
    vec3 line_color = mix(vec3(1.0, 0.3, 0.8), vec3(0.3, 1.0, 0.8), u_spectralCentroid);
    color += line * line_color;

    // Add the beat ring as a bright, hot color
    color += beat_ring * vec3(1.0, 0.9, 0.5);

    // Add an inner glow that pulsates with the bass
    float core_glow = 1.0 / (radius * 100.0 + 1.0) * u_bassLevel * 2.0;
    color += core_glow * vec3(0.2, 0.5, 1.0);

    gl_FragColor = vec4(color, 1.0);
}