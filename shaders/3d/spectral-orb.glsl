precision highp float;

uniform float u_time;
uniform vec2  u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_beatDetected;
uniform sampler2D u_frequencyTexture;

// --- Helper Functions ---
// FIX: Added the missing rotY function
mat3 rotY(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s,0,1,0,-s,0,c); }

// Convert a 3D point to spherical coordinates (latitude, longitude)
vec2 toSpherical(vec3 p) {
    return vec2(
        acos(p.y), // Latitude (theta)
        atan(p.z, p.x)  // Longitude (phi)
    );
}

// --- Scene Map ---
float map(vec3 p) {
    float sphere_dist = length(p);

    // Convert the point on the sphere to spherical coords to sample the texture
    vec2 spherical = toSpherical(normalize(p));
    
    // Map latitude (0..PI) to our frequency texture's x-coord (0..1)
    float freq_index = spherical.x / 3.14159;
    float freq = texture2D(u_frequencyTexture, vec2(freq_index, 0.5)).r;

    // The base radius swells with bass
    float base_radius = 0.8 + u_bassLevel * 0.2;
    
    // The frequency displaces the surface, creating the topography
    float displacement = freq * 0.15;

    return sphere_dist - base_radius - displacement;
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p+e.xyy) - map(p-e.xyy),
        map(p+e.yxy) - map(p-e.yxy),
        map(p+e.yyx) - map(p-e.yyx)
    ));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // --- Camera ---
    vec3 ro = vec3(0.0, 0.0, -3.0);
    vec3 rd = normalize(vec3(uv, 1.0));
    ro = rotY(u_time * 0.1) * ro;
    rd = rotY(u_time * 0.1) * rd;

    // --- Raymarch ---
    float t = 0.0;
    for(int i=0; i<64; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if(d < 0.001 || t > 20.0) break;
        t += d * 0.8;
    }

    // --- Shading ---
    vec3 color = vec3(0.0);
    if(t < 20.0) {
        vec3 p = ro + rd * t;
        vec3 n = getNormal(p);
        
        // Use the frequency at the hit point to determine the color
        vec2 spherical = toSpherical(normalize(p));
        float freq_index = spherical.x / 3.14159;
        float freq = texture2D(u_frequencyTexture, vec2(freq_index, 0.5)).r;

        // Color palette based on frequency (low=blue, mid=green, high=red)
        vec3 base_color = vec3(freq, 1.0 - freq, 0.2);
        
        // Lighting
        float fresnel = pow(1.0 - abs(dot(n, -rd)), 3.0);
        color = base_color * (0.5 + freq * 0.8);
        color += vec3(1.0) * fresnel * 0.5;

    }

    // --- Post-Processing Effects ---
    // Treble creates a shimmering corona
    float corona = 1.0 - smoothstep(0.8, 1.0, length(uv));
    color += vec3(0.4, 0.7, 1.0) * corona * u_trebleLevel;

    // Beat triggers a "nova" flash with rays
    float rays = sin(atan(uv.y, uv.x) * 10.0) * 0.5 + 0.5;
    color += vec3(1.0, 0.8, 0.6) * u_beatDetected * corona * rays * 2.0;
    
    gl_FragColor = vec4(color, 1.0);
}