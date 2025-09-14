# Audio Shader Studio: A Guide to Creating Audio-Reactive Shaders

This guide will walk you through the core concepts, tips, and best practices for creating powerful, expressive, and efficient shaders in Audio Shader Studio.

## The Core Philosophy: Sound as a Sculpting Force 

The best audio-reactive shaders treat sound not just as a trigger, but as a force that shapes the visual world. Think like a physicist creating a universe where the laws of nature are dictated by music.

- **Bass (`u_bassLevel`)** is **Gravity & Mass**. It should control the scale, size, and slow, powerful movements of your largest visual elements.
- **Treble (`u_trebleLevel`)** is **Energy & Detail**. It should control fine details, high-frequency noise, sharpness, and chaotic, energetic jitters.
- **Timbre (`u_spectralCentroid`)** is the **Atmosphere & Mood**. It's the "brightness" of the sound and is perfect for controlling the color palette, shifting between warm (low centroid) and cool (high centroid) tones.
- **The Beat (`u_beatDetected`)** is a **Cataclysmic Event**. A beat is a moment of maximum impact. Use it to trigger sharp, dramatic events: a flash of light, a shockwave, a glitch, a "film jump."

## Your First Shader: The Template

Every shader starts here. This simple template gives you access to the screen coordinates and time.

```glsl
// Use highp for best quality on desktop, mediump for mobile
precision highp float;

// These uniforms are always available
uniform float u_time;
uniform vec2 u_resolution;

// Let's add our first audio uniform
uniform float u_bassLevel;

void main() {
    // Get normalized coordinates (0.0 to 1.0)
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    
    // Let's make the screen glow with the bass
    vec3 color = vec3(1.0, 0.4, 0.0) * u_bassLevel;
    
    // The final output must be a vec4
    gl_FragColor = vec4(color, 1.0);
}
```
*(For WebGL 2.0, replace `gl_FragColor` with a custom `out vec4 outColor;`)*

## Tips for Powerful Visuals

### 1. The Art of Smoothing: Don't Be Too Literal

Raw audio data is "twitchy." A direct `* u_bassLevel` will look shaky. The key to cinematic visuals is **smoothing**.

**Bad (Twitchy):**
`float size = 0.5 * u_bassLevel;`

**Good (Smooth & Breathing):**
- **In JS (Recommended):** Apply a smoothing algorithm (like exponential smoothing) to the audio values before passing them as uniforms.
- **In Shader (Simple):** Use `sin(u_time)` to create a base animation and modulate it with audio.
  `float size = 0.5 + sin(u_time) * 0.1 + u_bassLevel * 0.2;`

### 2. Make the Beat Count

A simple flash on `u_beatDetected` is good. A major event every 4th or 8th beat is great. Use the `u_beatCount` uniform for this.

```glsl
// A value that is 1.0 only on the 4th beat
float is_fourth_beat = (mod(u_beatCount, 4.0) == 0.0) ? 1.0 : 0.0;
float flash = u_beatDetected * is_fourth_beat;
```

### 3. Use the Full Spectrum

Don't just rely on bass and treble. The `u_frequencyTexture` is your most powerful tool for detailed visuals. It contains the amplitude of all frequencies.

**Example: A detailed, wobbly line.**
```glsl
// Get the frequency data based on the pixel's X position
float spectral_amp = texture(u_frequencyTexture, vec2(uv.x, 0.5)).r;
// Use that data to offset a line
float line = abs(uv.y - 0.5 - spectral_amp * 0.2);
```

### 4. Create Depth and Contrast

A flat image is boring. Create a sense of space.
- **Vignette:** Darken the corners to focus the eye.
  `color *= 1.0 - length(uv - 0.5);`
- **Fog:** Make distant objects fade to a background color, essential for 3D scenes.
  `color = mix(fog_color, color, exp(-distance * 0.1));`
- **Tonemapping:** The most important trick for avoiding "burnout." When colors get too bright, they clip to pure white. Tonemapping gracefully compresses them, preserving detail.
  `color = color / (color + 1.0);`

## Performance is a Creative Tool

- **Start with `mediump`:** If your shader is simple, `mediump float` is faster, especially on mobile. Switch to `highp` only if you see visual artifacts.
- **Avoid Loops if Possible:** A `for` loop that runs many times can be slow. Try to find mathematical ("analytic") solutions where you can.
- **Raymarching is Expensive:** Creating 3D fractals and scenes is amazing, but it's the most computationally demanding technique. Use a reasonable number of steps in your raymarching loop (e.g., 60-80) and be aware that it may not run well on older hardware.

Happy creating! We can't wait to see what you build.
```
