#version 440

// NEON RAIN M1: layered GPU rain over the approved city artwork.
//
// The artwork is sampled with an aspect-preserving cover crop (uvScale/uvOffset come
// from lib/geometry.js), then up to four depth layers of procedural rain streaks are
// added on top. The nearest layer slightly refracts the artwork underneath it.
// All rain maths is in output pixels so streaks stay thin at every resolution.
//
// Compile with `scripts/neon-rain-proto compile` (wraps /usr/lib/qt6/bin/qsb).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // seconds, wrapped by QML
    float intensity;   // 0..2 overall rain brightness
    float layers;      // 1..4 depth layers
    float density;     // 0..1 fraction of active rain columns
    float distortion;  // 0..1 refraction strength of the nearest layer
    float speed;       // fall-speed multiplier
    vec2 resolution;   // output size in pixels
    vec2 uvScale;      // cover crop: visible fraction of the artwork
    vec2 uvOffset;     // cover crop: top-left of the visible region
};

layout(binding = 1) uniform sampler2D source;

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// One depth layer of rain streaks. depth 0 = far (thin, slow, dim), 1 = near.
// Returns streak coverage 0..1 at pixel px.
float rainLayer(vec2 px, float depth, float t) {
    float cellW = mix(4.0, 14.0, depth);            // spacing between rain columns (px)
    float lenPx = mix(10.0, 48.0, depth);           // streak length (px)
    float widthPx = mix(0.55, 1.35, depth);         // streak half-width (px)
    float fall = mix(650.0, 1500.0, depth) * speed; // px per second

    // Light wind: shear columns so streaks lean slightly.
    px.x += px.y * 0.10;

    float col = floor(px.x / cellW);
    float rCol = hash21(vec2(col, depth * 91.7 + 3.0));
    if (rCol > density)
        return 0.0;

    // Each column repeats drop slots every `period` pixels, scrolling down over time.
    float period = lenPx * mix(5.0, 14.0, hash21(vec2(col, depth * 13.1 + 7.3)));
    float y = px.y - t * fall * mix(0.85, 1.15, rCol) + rCol * 4000.0;
    float k = floor(y / period);
    float seg = fract(y / period);

    // Not every slot carries a drop; vary horizontal placement per drop.
    float rDrop = hash21(vec2(col * 1.37 + depth, k));
    if (rDrop > 0.55)
        return 0.0;

    float lenFrac = lenPx / period;
    // Tail fades in from the top, brightest at the head (bottom of the streak).
    float streak = seg < lenFrac ? smoothstep(0.0, lenFrac, seg) : 0.0;

    float cx = (0.5 + (rDrop - 0.275) * 0.9) * cellW;
    float dx = abs(fract(px.x / cellW) * cellW - cx);
    float line = 1.0 - smoothstep(0.0, widthPx, dx);

    return streak * line;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * resolution;

    float rain = 0.0;
    float nearest = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        if (fi >= layers)
            break;
        float depth = layers <= 1.0 ? 0.6 : fi / (layers - 1.0);
        float r = rainLayer(px + vec2(fi * 37.0, fi * 53.0), depth, time);
        rain += r * mix(0.16, 0.50, depth);
        nearest = r;
    }

    vec2 imgUv = uv * uvScale + uvOffset;
    imgUv.x += nearest * distortion * 0.0025;
    vec3 base = texture(source, imgUv).rgb;

    // Pale lavender rain, tinted by the neon underneath so it reads as lit by the city.
    vec3 rainColor = mix(vec3(0.80, 0.74, 0.96), base + 0.35, 0.35);
    vec3 col = base + rain * intensity * rainColor;

    fragColor = vec4(min(col, vec3(1.0)), 1.0) * qt_Opacity;
}
