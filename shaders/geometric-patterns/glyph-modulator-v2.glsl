#version 300 es
// --- Glyph Modulator (WebGL 2.0 Version) ---
// This version uses modern GLSL 3.00 es syntax.

precision highp float;

// Declare the output variable
out vec4 fragColor;

uniform float u_time;
uniform vec2  u_resolution;
uniform float u_audioLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_beatDetected;

// Polygon SDF (now with the original, clean for-loop)
float sdPolygon(vec2 p, vec2 v[4], int N) {
    float d = dot(p-v[0], p-v[0]);
    float s = 1.0;
    // This complex loop initializer is now VALID in GLSL 3.00 es!
    for(int i=0, j=N-1; i<N; j=i, i++) {
        vec2 e = v[j] - v[i];
        vec2 w = p - v[i];
        vec2 b = w - e*clamp(dot(w,e)/dot(e,e), 0.0, 1.0);
        d = min(d, dot(b,b));
        bvec3 c = bvec3(p.y>=v[i].y, p.y<v[j].y, e.x*w.y>e.y*w.x);
        if(all(c) || all(not(c))) s*=-1.0;
    }
    return s * sqrt(d);
}

// Rounded Box SDF
float sdBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p)-b+r;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r;
}


void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.x, u_resolution.y);
    uv *= 1.5;

    // --- Shape Definition ---
    float d_circle = length(uv) - 0.5;
    float d_box = sdBox(uv, vec2(0.4), 0.5 - u_audioLevel * 0.5);
    vec2 tri_v[4];
    tri_v[0] = vec2( 0.0,  0.6);
    tri_v[1] = vec2(-0.6, -0.4);
    tri_v[2] = vec2( 0.6, -0.4);
    float d_tri = sdPolygon(uv, tri_v, 3) - 0.05;

    // --- Audio-Reactive Morphosis ---
    float d1 = mix(d_circle, d_box, u_bassLevel);
    float d2 = mix(d1, d_tri, u_trebleLevel);
    float final_dist = d2;

    // --- Beat Glitch Effect ---
    float beat_pulse = u_beatDetected * 0.2;
    float r = smoothstep(0.01, 0.0, abs(final_dist - beat_pulse * 0.5) - 0.01);
    float g = smoothstep(0.01, 0.0, abs(final_dist) - 0.01);
    float b = smoothstep(0.01, 0.0, abs(final_dist + beat_pulse * 0.5) - 0.01);
    vec3 color = vec3(r, g, b);

    color += vec3(1.0) * (1.0 - smoothstep(0.0, 0.02, length(uv)));

    // Use the new output variable
    fragColor = vec4(color, 1.0);
}