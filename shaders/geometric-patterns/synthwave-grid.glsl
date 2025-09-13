precision highp float;

uniform float u_time;
uniform vec2  u_resolution;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_beatDetected;
uniform sampler2D u_frequencyTexture;

// --- Main Scene Map ---
// Returns distance to the grid floor and the spectrum city
float map(vec3 p) {
    // Floor is at y = -1
    float d = p.y + 1.0;
    
    // Spectrum Cityscape
    // Only draw buildings far away
    if(p.z > 5.0) {
        // Map the x position to the frequency texture
        // Use fract to make the city repeat infinitely
        float freq_index = fract(p.x * 0.1);
        float building_height = texture2D(u_frequencyTexture, vec2(freq_index, 0.5)).r * 5.0;
        
        // Simple box distance for the buildings
        vec2 box_p = vec2(abs(fract(p.x - 0.5) - 0.5) - 0.2, p.y + 1.0);
        float building_dist = max(box_p.x, box_p.y);
        
        // Only consider the building if we are below its height
        if (p.y < building_height - 1.0) {
            d = min(d, building_dist);
        }
    }
    return d;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // --- Camera ---
    vec3 ro = vec3(0.0, 0.0, u_time * 2.0); // Fly forward
    vec3 rd = normalize(vec3(uv, 1.0));
    
    // --- Raymarch ---
    float t = 0.0;
    vec3 p = ro;
    for(int i=0; i<80; i++) {
        p = ro + rd * t;
        float d = map(p);
        if(d < 0.001 || t > 50.0) break;
        t += d;
    }

    // --- Shading ---
    vec3 color = vec3(0.0);
    if(t < 50.0) {
        // Hit the floor/buildings
        vec2 grid_uv = p.xz;
        
        // --- FIX: Replaced fwidth with a smoothstep-based grid ---
        // This is universally compatible.
        float line_thickness = 0.02;
        vec2 grid_dist = abs(fract(grid_uv) - 0.5);
        float grid_glow = smoothstep(line_thickness, 0.0, min(grid_dist.x, grid_dist.y));
        
        // Base color is cyan, flashes white on beat
        vec3 grid_color = mix(vec3(0.1, 0.8, 0.9), vec3(1.0), u_beatDetected);
        color = grid_color * grid_glow;
        
    } else {
        // Hit the sky
        // Draw the sun
        float sun = 1.0 - smoothstep(0.0, 0.2, length(uv - vec2(0.0, 0.2)));
        color += vec3(1.0, 0.6, 0.4) * sun * (1.0 + u_beatDetected);
        
        // Add purple horizon glow, driven by bass
        color = mix(color, vec3(0.5, 0.1, 0.8), 1.0 - smoothstep(0.0, 0.4, uv.y)) * (0.5 + u_bassLevel * 1.5);
    }
    
    // Add atmospheric fog
    color = mix(color, vec3(0.0, 0.0, 0.02), 1.0 - exp(-0.05 * t));

    gl_FragColor = vec4(color, 1.0);
}