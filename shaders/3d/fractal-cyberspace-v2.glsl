#version 300 es
// --- Fractal Cyberspace (v4 - Stabilized Rotation) ---

precision highp float;

out vec4 fragColor;

// Uniforms
uniform float u_time;
uniform vec2  u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

// --- Helper Functions ---
mat3 rotY(float a) { float c=cos(a),s=sin(a); return mat3(c,0,s,0,1,0,-s,0,c); }
mat3 rotX(float a) { float c=cos(a),s=sin(a); return mat3(1,0,0,0,c,-s,0,s,c); }

vec3 hash3(vec3 p) {
    p = vec3(dot(p,vec3(127.1,311.7, 74.7)),
             dot(p,vec3(269.5,183.3,246.1)),
             dot(p,vec3(113.5,271.9,124.6)));
    return -1.0 + 2.0 * fract(sin(p)*43758.5453123);
}

float noise3D(vec3 p) {
    vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
    float n = mix(mix(mix( dot(hash3(i+vec3(0,0,0)),f-vec3(0,0,0)), dot(hash3(i+vec3(1,0,0)),f-vec3(1,0,0)),f.x),
                      mix( dot(hash3(i+vec3(0,1,0)),f-vec3(0,1,0)), dot(hash3(i+vec3(1,1,0)),f-vec3(1,1,0)),f.x),f.y),
                 mix(mix( dot(hash3(i+vec3(0,0,1)),f-vec3(0,0,1)), dot(hash3(i+vec3(1,0,1)),f-vec3(1,0,1)),f.x),
                      mix( dot(hash3(i+vec3(0,1,1)),f-vec3(0,1,1)), dot(hash3(i+vec3(1,1,1)),f-vec3(1,1,1)),f.x),f.y),f.z);
    return n;
}

// --- Scene Definition ---
float sdMenger(vec3 p) {
    float d = length(max(abs(p) - 1.0, 0.0));
    float scale = 3.0;
    for(int i = 0; i < 4; i++) {
        p = abs(p) - 1.0;
        p = p * scale;
        p = p - 1.0;
        d = min(d, length(max(abs(p) - 1.0, 0.0)) / pow(scale, float(i+1)));
    }
    return d;
}

vec2 map(vec3 p) {
    p *= (1.0 - u_bassLevel * 0.2);
    float d_solid = sdMenger(p);
    float sizzle = noise3D(p * 20.0) * u_trebleLevel * 0.05;
    d_solid -= sizzle;
    float cloud_density = smoothstep(0.5, 0.0, d_solid) * 0.1;
    return vec2(d_solid, cloud_density);
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(map(p+e.xyy).x - map(p-e.xyy).x,
                          map(p+e.yxy).x - map(p-e.yxy).x,
                          map(p+e.yyx).x - map(p-e.yyx).x));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // --- Camera ---
    float z_offset = -8.0;
    float z_motion_amplitude = 3.0 + u_bassLevel * 2.0;
    float z_motion = sin(u_time * 0.2) * z_motion_amplitude;
    
    vec3 ro = vec3(0.0, 0.0, z_offset + z_motion);
    vec3 rd = normalize(vec3(uv, 1.0));

    // --- FIX: Rotation speed is now primarily constant ---
    // The base speed is constant, and the audio's influence is now a very
    // small, additive "push" rather than the main driver of the speed.
    float y_rot_speed = 0.1 + u_spectralCentroid * 0.02; // Much smaller multiplier
    float x_rot_speed = 0.04; // Constant gentle tumble
    mat3 cameraRotation = rotY(u_time * y_rot_speed) * rotX(u_time * x_rot_speed);
    
    ro = cameraRotation * ro;
    rd = cameraRotation * rd;

    // Raymarching loop
    vec3 color = vec3(0.0);
    float t = 0.0;
    for(int i=0; i<80; i++) {
        vec3 p = ro + rd * t;
        vec2 res = map(p);
        
        if(res.x < 0.001) {
            vec3 n = getNormal(p);
            vec3 baseColor = 0.5 + 0.5 * cos(3.0 + u_spectralCentroid * 5.0 + vec3(0.0, 2.0, 4.0));
            float diffuse = max(0.2, dot(n, normalize(vec3(1.0, 1.0, -1.0))));
            float emissive = u_beatDetected * 2.0;
            color = baseColor * diffuse + emissive;
            break;
        }

        if(t > 30.0) break;
        t += max(0.02, res.x * 0.7);
    }
    
    fragColor = vec4(color, 1.0);
}