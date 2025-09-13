precision highp float;

uniform float u_time;
uniform vec2  u_resolution;
uniform float u_audioLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_onsetDetected;
uniform float u_beatDetected;
uniform sampler2D u_frequencyTexture;

// --- Helper Functions ---
mat3 rotY(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s,0,1,0,-s,0,c); }
mat3 rotX(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0,0,c,-s,0,s,c); }
vec2 toSpherical(vec3 p) { return vec2(acos(p.y/length(p)), atan(p.z, p.x)); }
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }

// SDF for a Torus (a ring)
float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

// --- Scene Map ---
float map(vec3 p) {
    // --- Element 1: The Core Sphere ---
    vec2 spherical = toSpherical(p);
    float freq_index = spherical.x / 3.14159;
    float freq = texture2D(u_frequencyTexture, vec2(freq_index, 0.5)).r;
    float displacement = freq * 0.15;
    float sphere_radius = 0.8 + u_audioLevel * 0.1;
    float d_sphere = length(p) - sphere_radius - displacement;

    // --- Element 2: Bass Containment Rings ---
    float ring_radius = 1.4 + u_bassLevel * 0.3;
    float ring_thick = 0.02 + u_bassLevel * 0.03;
    float d_rings = sdTorus(rotX(1.57) * p, vec2(ring_radius, ring_thick));
    d_rings = min(d_rings, sdTorus(p, vec2(ring_radius * 0.8, ring_thick)));
    d_rings = min(d_rings, sdTorus(rotX(u_time*0.5)*rotY(u_time*0.3)*p, vec2(ring_radius*1.2, ring_thick*0.5)));

    // --- Element 3: Treble Particle Swarm ---
    float d_particles = 100.0;
    for(int i=0; i<8; i++) {
        float fi = float(i);
        // Spectral Centroid makes orbits more complex
        float phase = fi * 0.8 + u_time * 2.0;
        float complexity = 1.0 + u_spectralCentroid * 4.0;
        vec3 part_pos = vec3(cos(phase), sin(phase*complexity), sin(phase)) * 1.1;
        d_particles = min(d_particles, length(p - part_pos) - 0.02);
    }
    
    // Combine all elements
    return min(d_sphere, min(d_rings, d_particles));
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(map(p+e.xyy)-map(p-e.xyy), map(p+e.yxy)-map(p-e.yxy), map(p+e.yyx)-map(p-e.yyx)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    
    // --- Camera ---
    vec3 ro = vec3(0.0, 0.0, -3.5);
    vec3 rd = normalize(vec3(uv, 1.0));
    ro = rotY(u_time * 0.1) * ro;
    rd = rotY(u_time * 0.1) * rd;

    // --- Raymarch ---
    float t = 0.0;
    for(int i=0; i<80; i++) {
        vec3 p = ro + rd * t;
        // Onset Detected causes a spatial glitch
        p.xz += (hash(uv + u_time) - 0.5) * u_onsetDetected * 0.2;
        float d = map(p);
        if(d < 0.001 || t > 20.0) break;
        t += d * 0.7;
    }

    // --- Shading ---
    vec3 color = vec3(0.0);
    if(t < 20.0) {
        vec3 p = ro + rd * t;
        vec3 n = getNormal(p);
        
        // --- Determine which object was hit for coloring ---
        float sphere_check = length(p) - (0.8 + u_audioLevel*0.1); // Approx sphere radius
        float ring_check = abs(length(p.xz) - (1.4 + u_bassLevel*0.3)); // Approx ring radius
        
        if (sphere_check < 0.2) { // Hit the sphere
            vec2 spherical = toSpherical(p);
            float freq = texture2D(u_frequencyTexture, vec2(spherical.x/3.14, 0.5)).r;
            color = vec3(freq, 1.0-freq, 1.0) * (0.8 + freq * 1.2);

            // Beat Detected triggers solar flares from the surface
            float flare = pow(1.0 - abs(dot(n, -rd)), 10.0);
            color += vec3(1.0, 0.8, 0.6) * flare * u_beatDetected * 3.0;
            
        } else if (ring_check < 0.5) { // Hit a ring
            color = vec3(1.0, 0.2, 0.2) * (1.0 + u_bassLevel);
        } else { // Hit a particle
            color = vec3(0.8, 0.9, 1.0) * (1.0 + u_trebleLevel);
        }
        
        // Basic lighting
        float diffuse = max(0.2, dot(n, normalize(vec3(1,1,1))));
        color *= diffuse;
    }
    
    gl_FragColor = vec4(color, 1.0);
}