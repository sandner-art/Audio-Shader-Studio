#version 300 es
precision highp float;

out vec4 outColor;

// Added u_beatDetected for more powerful, punchy reactions
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

// --- High-Quality 3D Noise (replaces simple plasma) ---
// This creates organic, cloud-like structures instead of repetitive sin waves.
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

// Layered noise for rich detail
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * snoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// HSV to RGB for vibrant color control
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    float time = u_time * 0.2;

    // --- Audio-Reactive Space Warping ---
    // The audio doesn't just add color, it physically distorts the space we sample.
    vec2 bass_warp = vec2(sin(time), cos(time)) * u_bassLevel * 0.5;
    float treble_jitter = snoise(vec3(uv * 10.0, u_time * 20.0)) * u_trebleLevel * 0.1;
    vec2 final_uv = uv + bass_warp + treble_jitter;

    // --- Volumetric Noise Sampling ---
    // We sample the noise field three times with offsets to simulate depth and volume.
    // The third dimension of the noise is animated with time, making the nebula evolve.
    float r = fbm(vec3(final_uv * 1.5, time));
    float g = fbm(vec3(final_uv * 1.5 + 0.1, time));
    float b = fbm(vec3(final_uv * 1.5 + 0.2, time));
    float noise_value = (r + g + b) / 3.0;

    // --- Dynamic Energy Cores ---
    // A beat collapses the plasma into a super-dense, bright core.
    float beat_pulse = pow(1.0 - fract(u_time * 2.0), 4.0) * u_beatDetected;
    // The core's "gravity" gets stronger with the beat, pulling the visuals inward.
    float core_gravity = 1.0 + beat_pulse * 10.0;
    float core_glow = 0.02 / pow(length(uv), 1.5 * core_gravity);

    // --- Powerful Color Mapping ---
    // We use the noise value and audio data to create a vibrant, high-contrast color palette.
    // Spectral centroid controls the hue, shifting between a "cold" and "hot" state.
    float hue = 0.6 + u_spectralCentroid * 0.3;
    float saturation = 0.8 + noise_value * 0.2;
    // Brightness is a combination of noise, glows, and audio levels.
    float value = pow(noise_value, 2.0) * 1.5 + core_glow * 2.0;
    
    vec3 finalColor = hsv2rgb(vec3(hue, saturation, value));
    
    // Add the raw noise channels back in for a colorful, chaotic effect.
    finalColor += vec3(r, g, b) * 0.3;

    // A beat triggers a system-wide flash.
    finalColor += beat_pulse * 0.5;

    // --- Post-Processing: Contrast & Tonemapping ---
    // This final step increases contrast and prevents bright spots from "burning out".
    finalColor = pow(finalColor, vec3(1.5)); // Increase contrast
    finalColor = finalColor / (finalColor + vec3(1.0)); // Tonemapping
    
    outColor = vec4(finalColor, 1.0);
}