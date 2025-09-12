// --- Liquid Metal Sphere ---
// Description: A raymarched sphere with a fluid, wave-like surface that
// responds to different audio frequencies for a complex, organic look.

precision mediump float;

// Standard & Audio Uniforms
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_audioLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_beatDetected;
uniform vec3 u_cameraPos;

// Signed Distance Function for a sphere
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

// The core of our effect: the Scene Map
// It returns the shortest distance from a point `p` to any object in the scene.
float map(vec3 p) {
    // 1. Base Sphere with Bass Swell
    // The sphere's fundamental radius grows with the bass.
    float sphere = sdSphere(p, 1.0 + u_bassLevel * 0.2);
    
    // 2. Fluid Wave Interference
    // We sum multiple sine waves moving in different directions and speeds.
    // This creates complex, non-repeating peaks and valleys, like real fluid.
    float wave1 = sin(p.x * 3.0 + p.y * 4.0 + u_time * 1.5) * 0.5;
    float wave2 = sin(p.y * 2.0 - p.z * 5.0 - u_time * 1.1) * 0.5;
    float fluidDeformation = (wave1 + wave2) * 0.5 * u_audioLevel * 0.4;
    
    // 3. Treble-Reactive Ripples
    // A higher-frequency wave that adds fine detail based on treble sounds.
    float ripples = sin(p.z * 15.0 + u_time * 5.0) * sin(p.x * 12.0 - u_time * 7.0);
    ripples *= u_trebleLevel * 0.05;

    // 4. Beat-Reactive Shockwave
    // A very high-frequency, sharp distortion that flashes with the beat.
    float beatShockwave = sin(p.x * 30.0 + p.y * 30.0) * u_beatDetected * 0.05;
    
    // 5. Combine all deformations
    // We subtract the deformations because a positive wave should push the surface
    // outwards, which means the distance from point `p` to the surface decreases.
    return sphere - fluidDeformation - ripples - beatShockwave;
}

// Calculates the surface normal using the gradient of the distance field.
vec3 getNormal(vec3 p) {
    const float h = 0.001;
    return normalize(vec3(
        map(p + vec3(h, 0, 0)) - map(p - vec3(h, 0, 0)),
        map(p + vec3(0, h, 0)) - map(p - vec3(0, h, 0)),
        map(p + vec3(0, 0, h)) - map(p - vec3(0, 0, h))
    ));
}

void main() {
    // --- Raymarching Setup ---
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x);
    vec3 ro = u_cameraPos; // Ray Origin
    vec3 rd = normalize(vec3(uv, -1.0)); // Ray Direction

    // --- Raymarching Loop ---
    float t = 0.0; // Total distance traveled by the ray
    for (int i = 0; i < 80; i++) { // Increased steps for better quality
        vec3 p = ro + rd * t; // Current position along the ray
        float d = map(p); // Distance from p to the surface
        
        // If we're very close, we've hit the surface.
        // If we've traveled too far, we've missed.
        if (d < 0.001 || t > 20.0) break;
        
        // "March" the ray forward by the safe distance `d`.
        t += d;
    }
    
    vec3 color = vec3(0.0);
    
    // If the ray hit something...
    if (t < 20.0) {
        vec3 p = ro + rd * t;
        vec3 normal = getNormal(p);
        
        // --- Advanced Lighting ---
        vec3 lightDir = normalize(vec3(0.8, 1.0, 0.5));
        float lighting = max(0.2, dot(normal, lightDir)); // Basic diffuse light with some ambient fill

        // Fresnel Effect for Metallic Reflections
        // This makes edges and glancing angles appear brighter, like polished metal.
        float fresnel = pow(1.0 - abs(dot(normal, -rd)), 4.0);
        
        // --- Audio-Reactive Coloring ---
        // Base color driven by bass
        vec3 baseColor = vec3(0.1, 0.2, 0.5) + u_bassLevel * vec3(0.6, 0.2, 0.3);
        
        // Reflection color driven by treble
        vec3 reflectionColor = vec3(0.8, 0.9, 1.0) * (0.5 + u_trebleLevel * 0.5);

        // Mix the base and reflection colors based on the fresnel term
        color = mix(baseColor, reflectionColor, fresnel);
        
        // Apply the diffuse lighting
        color *= lighting;
        
        // Add a bright, hot flash on the beat
        color += u_beatDetected * 0.4;
    }
    
    // Final Output
    gl_FragColor = vec4(color, 1.0);
}