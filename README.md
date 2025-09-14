# Audio Shader Studio

A real-time audio-reactive shader visualization platform for creative audio analysis and generative visual art. This application combines advanced digital signal processing with GPU-accelerated fragment shaders to create responsive visual experiences driven by audio features.

## Author & License

**Author:** Daniel Sandner  
**Code License:** [MIT License](LICENSE)  
**Scientific Paper & Documentation:** [CC-BY-SA 4.0](LICENSE-papers.txt)

## Overview

Audio Shader Studio implements real-time audio feature extraction and maps these features to GPU shader uniforms, enabling the creation of sophisticated audio-reactive visualizations. The platform supports multiple audio input sources, advanced spectral analysis, and provides a comprehensive set of audio-derived parameters for shader programming.

## Features

- **Real-time Audio Analysis:** Extracts a rich set of audio features, from broad strokes like bass and treble to nuanced data like spectral centroid and beat detection.
- **Live GLSL Editor:** Write and compile fragment shaders directly in the browser with instant visual feedback.
- **WebGL 1.0 & 2.0 Support:** The app automatically detects and utilizes the best available WebGL version, supporting both GLSL ES 1.00 and 3.00.
- **Multi-Source Input:** Load local audio files, use your microphone for live input, or engage with the built-in audio simulator.
- **Extensive Uniform Library:** A comprehensive set of pre-calculated audio features are passed directly to your shaders, ready to use.
- **Built-in Shader Library:** Get started immediately with a curated collection of generative and post-processing shaders.
- **Presentation Mode:** A clean, fullscreen view perfect for VJing, live performances, or installations.

## Technical Architecture

### Audio Processing Pipeline

The application utilizes the Web Audio API for real-time audio analysis:

1.  **Input Stage**: Audio file loading (`<input type="file">`) or microphone capture (`getUserMedia`).
2.  **Analysis Stage**: FFT analysis using `AnalyserNode` with a 512-point FFT size.
3.  **Feature Extraction**: On each animation frame, a suite of audio features are computed from the raw frequency and time-domain data.
4.  **GPU Mapping**: The extracted features are passed as uniforms to the active fragment shader program.

### Shader Environment

- **Core:** WebGL 1.0 and WebGL 2.0. The application will attempt to initialize a WebGL 2.0 context and gracefully fall back to WebGL 1.0 if it's unavailable.
- **Language:** GLSL ES 1.00 and GLSL ES 3.00.
- **Rendering:** A full-screen quad is rendered every frame, with the fragment shader determining the color of each pixel based on the audio-derived uniforms.

## Shader Creation Guide

For a detailed guide on how to create shaders for this platform, including tips, tricks, and best practices, please see our **[Shader Creation Guide](docs/SHADER_GUIDE.md)**.

---

## Implemented Audio Uniforms

### Basic Audio Parameters

| Uniform | Type | Range | Description |
|---------|------|-------|-------------|
| `u_time` | `float` | 0.0+ | Application runtime in seconds |
| `u_resolution` | `vec2` | Canvas dimensions | Screen resolution (width, height) in pixels |
| `u_audioLevel` | `float` | 0.0-1.0 | Root mean square (RMS) amplitude of audio signal |

### Frequency Domain Analysis

| Uniform | Type | Range | Description |
|---------|------|-------|-------------|
| `u_bassLevel` | `float` | 0.0-1.0 | Low frequency energy (20-250 Hz) |
| `u_trebleLevel` | `float` | 0.0-1.0 | High frequency energy (2-20 kHz) |
| `u_spectralCentroid` | `float` | 0.0-1.0 | Spectral centroid (brightness/timbre measure) |
| `u_frequencyTexture` | `sampler2D` | 256×1 | Complete frequency spectrum as 1D texture |

### Advanced Audio Features

| Uniform | Type | Range | Description |
|---------|------|-------|-------------|
| `u_energyLevel` | `float` | 0.0-1.0 | Instantaneous energy level (spectral power) |
| `u_beatDetected` | `float` | 0.0/1.0 | Binary beat detection using energy flux analysis |
| `u_onsetDetected` | `float` | 0.0/1.0 | Audio onset detection via spectral flux (detects sharp transient sounds like snares or claps) |
| `u_beatDetected`| `float` | 0.0 or 1.0 | A binary flag that is `1.0` for a single frame when a beat is detected. Ideal for triggering sharp events. |
| `u_beatCount`| `float` | 0.0+ | **(New)** An integer that increments on every detected beat. Essential for triggering events on specific beat intervals (e.g., every 4th or 8th beat). |
| `u_frequencyTexture`| `sampler2D`| 256x1 Texture| The entire frequency spectrum, available for detailed analysis and visualization. |
| `u_timeDomainTexture`| `sampler2D`| 512x1 Texture| The raw audio waveform data for the current buffer. Essential for oscilloscope effects. |
| `u_backgroundTexture`|`sampler2D`| Image dimensions | The user-loaded background image. Defaults to black if no image is loaded. |

### Audio Mode Processing

The system implements three specialized processing modes:

- **Normal Mode**: Balanced frequency analysis across full spectrum
- **Music Mode**: Optimized for bass-treble separation with enhanced beat detection
- **Voice Mode**: Mid-range focused (300-3400 Hz) for speech and vocal content

## Supported Shader Formats

### Fragment Shader Specification

**Language:** GLSL ES 1.0 (OpenGL ES Shading Language), GLSL ES 3.00. 
**Precision:** `mediump float` recommended for mobile compatibility  
**Entry Point:** `void main()`  
**Output:** `gl_FragColor` (vec4)

### Required Shader Structure

```glsl
precision mediump float;

// Standard uniforms (always available)
uniform float u_time;
uniform vec2 u_resolution;

// Audio uniforms (conditional availability)
uniform float u_audioLevel;
uniform float u_bassLevel;
uniform float u_trebleLevel;

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    // Shader implementation
    gl_FragColor = vec4(color, 1.0);
}
```

### Coordinate System

- **Fragment Coordinates**: `gl_FragCoord.xy` in pixel space
- **Normalized Coordinates**: `uv = gl_FragCoord.xy / u_resolution.xy` (0.0-1.0)
- **Centered Coordinates**: `(gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.y, u_resolution.x)`

## Audio Feature Extraction Methods

### Spectral Centroid Calculation

The spectral centroid represents the "center of mass" of the frequency spectrum:

```
Centroid = Σ(f[i] × magnitude[i]) / Σ(magnitude[i])
```

Where `f[i]` is the frequency bin and `magnitude[i]` is the corresponding amplitude.

### Beat Detection Algorithm

Implements energy-based beat detection using statistical analysis:

1. Compute instantaneous energy: `E(t) = Σ(x[n]²)`
2. Maintain energy history buffer (10 frames)
3. Beat detected when: `E(t) > mean(E_history) × 1.3`

### Onset Detection

Uses spectral flux for onset detection:

```
Flux(t) = Σ(H(X(t)[k] - X(t-1)[k]))
```

Where `H()` is the half-wave rectifier and `X(t)[k]` is the magnitude spectrum at time `t` and frequency bin `k`.

## Import/Export Functionality

### Supported File Formats

**Audio Input:**
- WAV (uncompressed)
- MP3 (MPEG-1/2 Audio Layer III)
- OGG Vorbis
- AAC/M4A
- FLAC (browser dependent)

**Shader Import/Export:**
- `.glsl` - Standard GLSL format
- `.frag` - Fragment shader files
- `.txt` - Plain text shader code
- Clipboard integration for rapid prototyping

### Shader Library

The application includes algorithmic generative patterns:

1. **Basic Wave** - Sine wave modulation with audio reactivity
2. **Audio Spectrum Bars** - Frequency domain visualization
3. **Circular Waveform** - Polar coordinate frequency mapping
4. **Spiral Spectrum** - Archimedean spiral with frequency data
5. **Reactive Crystals** - Geometric patterns with beat synchronization
6. **Flowing Lines** - Multi-layered sine wave composition

## Technical References

### WebGL & GLSL Documentation

- [OpenGL ES Shading Language Specification](https://registry.khronos.org/OpenGL/specs/es/2.0/GLSL_ES_Specification_2.0.25.pdf) - Khronos Group
- [WebGL Specification](https://registry.khronos.org/webgl/specs/latest/1.0/) - W3C/Khronos Group
- [GLSL Reference Guide](https://registry.khronos.org/OpenGL/index_es.php#specs) - Official Khronos Registry

### Web Audio API Standards

- [Web Audio API Specification](https://webaudio.github.io/web-audio-api/) - W3C Working Draft
- [AnalyserNode Documentation](https://developer.mozilla.org/en-US/docs/Web/API/AnalyserNode) - Mozilla Developer Network

### Audio Analysis Literature

- Lerch, A. (2012). *An Introduction to Audio Content Analysis*. Wiley-IEEE Press.
- Müller, M. (2015). *Fundamentals of Music Processing*. Springer.
- Peeters, G. (2004). "A large set of audio features for sound description." CUIDADO I.S.T. Project Report.

## Browser Compatibility

**Minimum Requirements:**
- WebGL 1.0 support
- Web Audio API support
- ES6 JavaScript features

**Tested Browsers:**
- Chrome 90+ (desktop/mobile)
- Firefox 88+ (desktop/mobile)  
- Safari 14+ (desktop/mobile)
- Edge 90+ (desktop)

## Performance Considerations

### Optimization Guidelines

- Use `mediump` precision for mobile compatibility
- Minimize texture lookups in fragment shaders
- Avoid complex branching in shader code
- Consider frame rate implications of complex mathematical operations
    - Be mindful of expensive operations like `pow()`, `sin()`, and `cos()` inside loops.
    - Raymarching and multi-pass shaders are computationally intensive and may not run smoothly on integrated graphics.

### Mobile Device Limitations

- iOS requires user interaction to initiate audio context
- Some Android devices may have reduced FFT resolution
- Battery optimization may throttle audio processing

## Development Setup

### Prerequisites

- Modern web browser with WebGL support
- Local web server (for file system access)
- Audio input source (microphone or audio files)

### Usage Instructions

1. **Audio Setup**: Load audio file or enable microphone access
2. **Shader Selection**: Choose from library or load custom shader
3. **Real-time Editing**: Modify shader code with live preview
4. **Presentation Mode**: Fullscreen visualization with gesture controls

## Contributing

Contributions are welcome under the MIT license for code and CC-BY-SA 4.0 for documentation. Please ensure shader contributions are compatible with GLSL ES 1.0 and include proper attribution for any derived algorithms.

## Acknowledgments

This work builds upon established techniques in computer graphics, digital signal processing, and creative coding. Special recognition to the Khronos Group for WebGL/OpenGL standards and the W3C for Web Audio API specifications.

---

*For questions regarding the scientific methodology or technical implementation, please refer to the academic literature cited above or contact the author.*
