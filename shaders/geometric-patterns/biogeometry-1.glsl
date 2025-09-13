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

// Category: Morphogenesis & HUD
// Name: Bio-Mechanical HUD

// --- Utility & Noise Functions ---
float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(p*mat2(12.98,78.23,26.67,82.34))*43758.5); }

// --- FIX: Full, correct snoise implementation with all helper functions ---
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x*34.0)+1.0)*x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0); const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i  = floor(v + dot(v, C.yyy)); vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g = step(x0.yzx, x0.xyz); vec3 l = 1.0 - g; vec3 i1 = min( g.xyz, l.zxy ); vec3 i2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - i1 + C.xxx; vec3 x2 = x0 - i2 + C.yyy; vec3 x3 = x0 - D.yyy;
    i = mod289(i);
    vec4 p = permute( permute( permute( i.z + vec4(0.0, i1.z, i2.z, 1.0 )) + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));
    float n_ = 0.142857142857; vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z); vec4 y_ = floor(j - 7.0 * x_ );
    vec4 x = x_ *ns.x + ns.yyyy; vec4 y = y_ *ns.x + ns.yyyy; vec4 h = 1.0 - abs(x) - abs(y);
    vec4 b0 = vec4( x.xy, y.xy ); vec4 b1 = vec4( x.zw, y.zw );
    vec4 s0 = floor(b0)*2.0 + 1.0; vec4 s1 = floor(b1)*2.0 + 1.0; vec4 sh = -step(h, vec4(0.0));
    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy; vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;
    vec3 p0 = vec3(a0.xy,h.x); vec3 p1 = vec3(a0.zw,h.y); vec3 p2 = vec3(a1.xy,h.z); vec3 p3 = vec3(a1.zw,h.w);
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m; return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3) ) );
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    vec3 finalColor = vec3(0.0);
    float time = u_time * 0.2;

    float s_bass = u_bassLevel;
    float s_treble = u_trebleLevel;
    float s_beat = pow(1.0 - fract(u_time * 2.0), 4.0) * u_beatDetected;
    float s_centroid = u_spectralCentroid;

    vec2 p = uv * 4.0;
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float d1 = 10.0, d2 = 10.0;
    vec2 id1;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor_i = vec2(float(x), float(y));
            vec2 point_pos = hash2(i + neighbor_i);
            point_pos += sin(time + hash1(i + neighbor_i) * PI * 2.0) * 0.5 * (0.2 + s_bass);
            point_pos += (hash2(i + neighbor_i) - 0.5) * s_treble * 0.2;
            
            float d = length(f - (neighbor_i + point_pos));
            if(d < d1) { d2 = d1; d1 = d; id1 = i + neighbor_i; }
            else if(d < d2) { d2 = d; }
        }
    }

    float cell_wall = smoothstep(0.01, 0.08, d2 - d1);
    float freq_index = hash1(id1);
    float spectral_amp = texture(u_frequencyTexture, vec2(freq_index, 0.5)).r;
    
    float cytoplasm = snoise(vec3(uv * 8.0, time + hash1(id1))) * 0.5 + 0.5;
    float cytoplasm_intensity = (1.0 - d1) * cytoplasm;

    float core_glow = (0.1 / (d1 + 0.01)) * spectral_amp * (1.0 + s_treble);

    float hue = 0.5 + s_centroid * 0.4;
    vec3 base_color = hsv2rgb(vec3(hue, 0.8, 1.0));
    vec3 core_color = hsv2rgb(vec3(hue + 0.5, 0.5, 1.0));
    
    finalColor += cell_wall * base_color * 2.0;
    finalColor += cytoplasm_intensity * base_color * 0.3;
    finalColor += core_glow * core_color;

    vec2 ca_offset = vec2(s_beat * 0.01, 0.0);
    // This logic is a bit odd, let's simplify for clarity and effect
    if(s_beat > 0.0) {
        finalColor.r += cell_wall * s_beat * 0.5;
        finalColor.b += cell_wall * s_beat * 0.5;
    }
    
    finalColor += (0.01 / (length(uv) + 0.01)) * 0.1;
    outColor = vec4(finalColor, 1.0);
}