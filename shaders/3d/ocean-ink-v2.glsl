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

// Category: Liquid & Fluid Dynamics
// Name: Liquid Spectrometer V2 (Optimized)
// --- Standard Simplex Noise (snoise) function ---
// (The full snoise implementation is kept as it is a high-quality noise source)
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


// --- OPTIMIZED Water Height Function ---
float getWaterHeight(vec2 pos, float s_bass, float s_treble, float s_beat_decay) {
    // 1. Base Swells & Ripples: We combine large and small waves with just two noise calls.
    float waves = snoise(vec3(pos * 0.2, u_time * 0.1)) * 0.8 * s_bass;
    waves += snoise(vec3(pos * 1.2, u_time * 0.4)) * 0.15 * (0.5 + s_treble);

    // 2. Spectral Lanes: Simplified to one texture lookup modulated by a sine wave.
    float freq_index = fract(pos.x * 0.1);
    float spectral_energy = texture(u_frequencyTexture, vec2(freq_index, 0.5)).r;
    waves += sin(pos.y * 2.0 + u_time) * spectral_energy * 0.3;

    // 3. Beat Shockwave: Simplified to a single, clean circular wave.
    float dist_from_center = length(pos);
    float beat_radius = s_beat_decay * 10.0;
    float shockwave = exp(-abs(dist_from_center - beat_radius) * 0.8) * 0.5 * s_beat_decay;

    return waves + shockwave;
}

float map(vec3 p, float s_bass, float s_treble, float s_beat_decay) {
    return p.y - getWaterHeight(p.xz, s_bass, s_treble, s_beat_decay);
}

vec3 getNormal(vec3 p, float s_bass, float s_treble, float s_beat_decay) {
    vec2 e = vec2(0.005, 0.0); // Slightly larger epsilon can be faster
    return normalize(vec3(
        map(p - e.xyy, s_bass, s_treble, s_beat_decay) - map(p + e.xyy, s_bass, s_treble, s_beat_decay),
        2.0 * e.x,
        map(p - e.yxy, s_bass, s_treble, s_beat_decay) - map(p + e.yxy, s_bass, s_treble, s_beat_decay)
    ));
}

vec3 getSkyColor(vec3 rd, float s_centroid) {
    float sun_glow = pow(max(0.0, dot(rd, normalize(vec3(0.5, 0.2, 0.5)))), 10.0);
    vec3 sky_gradient = mix(vec3(0.1, 0.2, 0.4), vec3(0.5, 0.7, 1.0), max(0.0, rd.y));
    vec3 sun_color = mix(vec3(1.0, 0.2, 0.5), vec3(1.0, 0.8, 0.2), s_centroid);
    return sky_gradient + sun_color * sun_glow;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float s_bass = u_bassLevel;
    float s_treble = u_trebleLevel;
    float s_centroid = u_spectralCentroid;
    float s_beat_decay = pow(1.0 - fract(u_time * 0.5), 8.0) * u_beatDetected;

    // --- Cinematic Camera ---
    vec3 ro = vec3(u_time * 0.2, 1.0, 0.0);
    vec3 look_at = ro + vec3(0.0, -0.2, -1.0);
    vec3 forward = normalize(look_at - ro);
    vec3 right = normalize(cross(vec3(0,1,0), forward));
    vec3 up = cross(forward, right);
    mat3 viewMatrix = mat3(right, up, forward);
    vec3 rd = viewMatrix * normalize(vec3(uv, 1.8));

    // --- Raymarching Loop ---
    vec3 color = vec3(0.0);
    float t = 0.0;
    for(int i=0; i < 60; i++) { // Reduced max steps from 80 to 60
        vec3 p = ro + rd * t;
        float d = map(p, s_bass, s_treble, s_beat_decay);

        if (d < 0.005) {
            vec3 n = getNormal(p, s_bass, s_treble, s_beat_decay);

            // --- OPTIMIZED Water Shading ---
            // Single reflection call, which is much cheaper.
            vec3 reflected_dir = reflect(rd, n);
            vec3 reflection_color = getSkyColor(reflected_dir, s_centroid);

            // Simplified deep water color.
            vec3 deep_color = mix(vec3(0.0, 0.1, 0.2), vec3(0.3, 0.1, 0.0), s_centroid);
            float fresnel = 0.05 + 0.95 * pow(1.0 - max(0.0, dot(-rd, n)), 5.0);
            color = mix(deep_color, reflection_color, fresnel);

            // Simplified specular highlight.
            float specular = pow(max(0.0, dot(reflected_dir, normalize(vec3(0.5, 0.5, 0.5)))), 64.0);
            color += vec3(1.0) * specular * (1.0 + s_treble);

            // OPTIMIZED Foam: Calculated here based on normal, not in geometry.
            // Steeper waves (where the normal points sideways) get more foam.
            float foam_amount = pow(1.0 - n.y, 4.0) * (0.5 + s_treble);
            color = mix(color, vec3(1.0), foam_amount);
            
            break;
        }
        if (t > 30.0) {
             color = getSkyColor(rd, s_centroid);
             break;
        }
        t += d * 0.9; // Slightly more aggressive march step
    }

    // Post-processing
    color = pow(color, vec3(0.4545));
    outColor = vec4(color, 1.0);
}