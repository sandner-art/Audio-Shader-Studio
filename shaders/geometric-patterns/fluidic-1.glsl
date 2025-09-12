precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_energyLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;
uniform float u_spectralCentroid;
uniform float u_beatDetected;

// Simplex noise for organic patterns
vec3 mod289(vec3 x){return x-floor(x*(1./289.))*289.;}
vec4 mod289(vec4 x){return x-floor(x*(1./289.))*289.;}
vec4 permute(vec4 x){return mod289(((x*34.)+1.)*x);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159-0.85373472095314*r;}

float snoise(vec3 v){
    const vec2 C=vec2(1./6.,1./3.);
    const vec4 D=vec4(0.,.5,1.,2.);
    vec3 i=floor(v+dot(v,C.yyy));
    vec3 x0=v-i+dot(i,C.xxx);
    vec3 g=step(x0.yzx,x0.xyz);
    vec3 l=1.-g;
    vec3 i1=min(g.xyz,l.zxy);
    vec3 i2=max(g.xyz,l.zxy);
    vec3 x1=x0-i1+C.xxx;
    vec3 x2=x0-i2+C.yyy;
    vec3 x3=x0-D.yyy;
    i=mod289(i);
    vec4 p=permute(permute(permute(
        i.z+vec4(0.,i1.z,i2.z,1.))
        +i.y+vec4(0.,i1.y,i2.y,1.))
        +i.x+vec4(0.,i1.x,i2.x,1.));
    float n_=.142857142857;
    vec3 ns=n_*D.wyz-D.xzx;
    vec4 j=p-49.*floor(p*ns.z*ns.z);
    vec4 x_=floor(j*ns.z);
    vec4 y_=floor(j-7.*x_);
    vec4 x=x_*ns.x+ns.yyyy;
    vec4 y=y_*ns.x+ns.yyyy;
    vec4 h=1.-abs(x)-abs(y);
    vec4 b0=vec4(x.xy,y.xy);
    vec4 b1=vec4(x.zw,y.zw);
    vec4 s0=floor(b0)*2.+1.;
    vec4 s1=floor(b1)*2.+1.;
    vec4 sh=-step(h,vec4(0.));
    vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy;
    vec4 a1=b1.xzyw+s1.xzyw*sh.zzww;
    vec3 p0=vec3(a0.xy,h.x);
    vec3 p1=vec3(a0.zw,h.y);
    vec3 p2=vec3(a1.xy,h.z);
    vec3 p3=vec3(a1.zw,h.w);
    vec4 norm=taylorInvSqrt(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3)));
    p0*=norm.x;p1*=norm.y;p2*=norm.z;p3*=norm.w;
    vec4 m=max(.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.);
    m=m*m;
    return 42.*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    
    // --- Domain Warping for fluid motion ---
    // The bass controls large, slow warping of the coordinate space
    float time = u_time * 0.1;
    vec2 warp_uv = uv * (1.5 + u_bassLevel * 0.5);
    vec2 q = vec2(snoise(vec3(warp_uv, time)),
                  snoise(vec3(warp_uv.x, warp_uv.y + 2.0, time)));

    // Treble adds fine, high-frequency distortion
    vec2 r = vec2(snoise(vec3(warp_uv * (2.0 + u_trebleLevel * 3.0) + q * u_energyLevel, time)),
                  snoise(vec3(warp_uv * 2.0 + q, time + 5.0)));

    // --- Noise Calculation ---
    // Combine noise layers for the final nebula pattern
    float noise = snoise(vec3(warp_uv + r * 0.5, time * 0.5));
    noise = (noise + 1.0) * 0.5; // Map from -1..1 to 0..1
    noise = pow(noise, 2.5);

    // --- Coloring ---
    // The spectral centroid smoothly shifts the nebula's color palette
    vec3 color1 = vec3(0.8, 0.1, 0.4); // Magenta
    vec3 color2 = vec3(0.1, 0.2, 0.9); // Blue
    vec3 color3 = vec3(1.0, 0.8, 0.2); // Gold
    
    vec3 palette = mix(mix(color2, color1, u_spectralCentroid), color3, u_spectralCentroid - 0.5);
    vec3 color = noise * palette;

    // --- Beat Reaction ---
    // A detected beat injects a bright bloom from the center
    float beat_bloom = 1.0 - smoothstep(0.0, 0.5, length(uv));
    color += beat_bloom * u_beatDetected * vec3(1.0, 1.0, 0.8) * 2.0;
    
    gl_FragColor = vec4(color, 1.0);
}