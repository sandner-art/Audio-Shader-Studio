#version 300 es
precision highp float;

out vec4 outColor;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

// Category: 3D & Raymarching
// Name: Generative Crystal Cavern (Smoothed Cinematic Camera)

// --- Utility & Noise ---
mat3 rotY(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s,0,1,0,-s,0,c); }
mat3 rotX(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0,0,c,-s,0,s,c); }
float noise3D(vec3 p) { /* ... Standard noise function ... */
    p = abs(fract(p) - 0.5); return dot(p, p); // Simplified for brevity
}

// --- Smoothing Function ---
float smoothstep_decay(float t) {
    return exp(-t * 5.0);
}

// --- SDFs & Scene Map (Unchanged from previous smoothed version) ---
float sdOctahedron(vec3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

float sdCrystal(vec3 p, float s_bass_size, float s_beat_size) {
    float d = sdOctahedron(p, (1.0 + s_bass_size) + s_beat_size);
    d = max(d, -sdOctahedron(p - vec3(0.6, 0.6, 0.6), 0.5 + s_beat_size * 0.5));
    d = max(d, -sdOctahedron(p - vec3(-0.6, 0.6, -0.6), 0.5 + s_beat_size * 0.5));
    return d;
}

vec2 map(vec3 p, float s_treble, float s_bass, float s_beat) {
    vec3 originalP = p;
    vec3 q = mod(p, 4.0) - 2.0;
    float d = sdCrystal(q, s_bass, s_beat);
    d -= noise3D(originalP * 10.0 + u_time * 0.5) * 0.075 * s_treble;
    return vec2(d, 1.0);
}

vec3 getNormal(vec3 p, float s_treble, float s_bass, float s_beat) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(map(p+e.xyy, s_treble, s_bass, s_beat).x - map(p-e.xyy, s_treble, s_bass, s_beat).x,
                          map(p+e.yxy, s_treble, s_bass, s_beat).x - map(p-e.yxy, s_treble, s_bass, s_beat).x,
                          map(p+e.yyx, s_treble, s_bass, s_beat).x - map(p-e.yyx, s_treble, s_bass, s_beat).x));
}


void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // --- Smoothed Audio Parameters ---
    float s_bass = mix(u_bassLevel, (sin(u_time * 0.5) * 0.5 + 0.5), 0.6) * 0.4;
    float s_treble = u_trebleLevel * 0.8;
    float s_centroid = u_spectralCentroid + sin(u_time * 0.2) * 0.1;
    float beat_time = mod(u_time, 10.0) * (1.0 - u_beatDetected);
    float s_beat = smoothstep_decay(beat_time) * u_beatDetected * 0.3;

    // --- REWORKED CINEMATIC CAMERA ---
    // 1. Slow down the forward speed DRAMATICALLY.
    float forward_speed = -u_time * 0.4; // Changed from 1.0 to 0.3

    // 2. Create a slower, wider, more deliberate drift path.
    float drift_x = sin(u_time * 0.1) * 1.5;
    float drift_y = cos(u_time * 0.15) * 1.0;

    vec3 ro = vec3(drift_x, drift_y, forward_speed);
    vec3 rd = normalize(vec3(uv, 1.0));

    // 3. Define a "look at" point that is slightly ahead of the camera.
    // This makes the rotation feel more natural, like the camera is focusing on the path ahead.
    vec3 look_at = vec3(0.0, 0.0, forward_speed + 2.0);

    // 4. Build the view matrix to correctly orient the camera. (More advanced but better)
    vec3 forward = normalize(look_at - ro);
    vec3 right = normalize(cross(vec3(0,1,0), forward));
    vec3 up = cross(forward, right);
    mat3 viewMatrix = mat3(right, up, forward);

    rd = viewMatrix * rd;


    // --- Raymarching ---
    vec3 color = vec3(0.0);
    float t = 0.0;
    for(int i=0; i<80; i++) {
        vec3 p = ro + rd * t;
        vec2 res = map(p, s_treble, s_bass, s_beat);
        float d = res.x;

        if (d < 0.001) {
            vec3 n = getNormal(p, s_treble, s_bass, s_beat);
            vec3 lightDir = normalize(vec3(0, 1, -1));

            // --- Material & Lighting (using smoothed values) ---
            float diffuse = max(0.1, dot(n, lightDir));
            vec3 reflected = reflect(rd, n);
            float specular = pow(max(0.0, dot(reflected, lightDir)), 32.0);
            float fresnel = pow(1.0 - abs(dot(n, rd)), 3.0);
            vec3 base_color = 0.5 + 0.5 * cos(s_centroid * 5.0 + p.z * 2.0 + vec3(0.0, 1.0, 2.0));

            color = base_color * diffuse;
            color += vec3(1.0) * specular;
            color += fresnel * base_color * 2.0;
            color += base_color * s_beat * 5.0;
            break;
        }
        if (t > 30.0) break;
        t += d * 0.9;
    }

    color += vec3(0.1, 0.2, 0.5) * (0.2 + s_bass);
    outColor = vec4(color, 1.0);
}