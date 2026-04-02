#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Sunset Parallax Clouds ---

float sc_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float sc_noise(float2 x) {
    float2 f = fract(x);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float2 p = floor(x);
    float a = sc_hash(p);
    float b = sc_hash(p + float2(1.0, 0.0));
    float c = sc_hash(p + float2(0.0, 1.0));
    float d = sc_hash(p + float2(1.0, 1.0));

    return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

float sc_fbm(float2 x, int detail) {
    float a = 0.0;
    float b = 1.0;
    float t = 0.0;
    for (int i = 0; i < detail; i++) {
        float n = sc_noise(x);
        a += b * n;
        t += b;
        b *= 0.7;
        x *= 2.0;
    }
    return a / t;
}

// Returns float4(color, alpha). Alpha=0 means sky shows through.
float4 sc_foreground(float2 uv, float t) {
    float midlevel, h, disp, dist;
    float2 uv2;

    uv.y -= 0.2;

    // c14
    midlevel = -0.1; disp = 1.7; dist = 1.0;
    uv2 = uv + float2(t / dist + 40.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.12) return float4(0.43, 0.32, 0.31, 1.0);
    if (uv.y < h + midlevel - 0.08) return float4(0.55, 0.42, 0.41, 1.0);
    if (uv.y < h + midlevel - 0.04) return float4(0.66, 0.42, 0.40, 1.0);
    if (uv.y < h + midlevel)        return float4(0.77, 0.48, 0.46, 1.0);

    // c13
    midlevel = 0.05; disp = 1.7; dist = 2.0;
    uv2 = uv + float2(t / dist + 38.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.1)  return float4(0.95, 0.66, 0.48, 1.0);
    if (uv.y < h + midlevel - 0.04) return float4(0.98, 0.76, 0.64, 1.0);
    if (uv.y < h + midlevel)        return float4(0.95, 0.80, 0.77, 1.0);

    return float4(0.95, 0.80, 0.77, 0.0);
}

float4 sc_background(float2 uv, float t) {
    float midlevel, h, disp, dist;
    float2 uv2;

    // c12
    midlevel = 0.3; disp = 0.9; dist = 10.0;
    uv2 = uv + float2(t / dist + 32.5, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.14) return float4(0.48, 0.19, 0.20, 1.0);
    if (uv.y < h + midlevel - 0.1)  return float4(0.68, 0.28, 0.19, 1.0);
    if (uv.y < h + midlevel - 0.07) return float4(0.88, 0.38, 0.24, 1.0);
    if (uv.y < h + midlevel)        return float4(0.95, 0.45, 0.30, 1.0);

    // c11
    midlevel = 0.35; disp = 1.0; dist = 15.0;
    uv2 = uv + float2(t / dist + 30.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.04) return float4(0.98, 0.76, 0.64, 1.0);
    if (uv.y < h + midlevel)        return float4(0.95, 0.80, 0.77, 1.0);

    // c10
    midlevel = 0.35; disp = 3.5; dist = 20.0;
    uv2 = uv + float2(t / dist + 27.5, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.12) return float4(0.43, 0.32, 0.31, 1.0);
    if (uv.y < h + midlevel - 0.08) return float4(0.55, 0.42, 0.41, 1.0);
    if (uv.y < h + midlevel - 0.04) return float4(0.66, 0.42, 0.40, 1.0);
    if (uv.y < h + midlevel)        return float4(0.77, 0.48, 0.46, 1.0);

    // c9
    midlevel = 0.45; disp = 2.0; dist = 25.0;
    uv2 = uv + float2(t / dist + 23.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.04) return float4(0.98, 0.57, 0.36, 1.0);
    if (uv.y < h + midlevel)        return float4(1.0, 0.62, 0.44, 1.0);

    // c8
    midlevel = 0.5; disp = 2.3; dist = 30.0;
    uv2 = uv + float2(t / dist + 20.5, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.12) return float4(0.41, 0.27, 0.27, 1.0);
    if (uv.y < h + midlevel - 0.08) return float4(0.53, 0.35, 0.32, 1.0);
    if (uv.y < h + midlevel - 0.04) return float4(0.80, 0.24, 0.17, 1.0);
    if (uv.y < h + midlevel)        return float4(0.99, 0.29, 0.20, 1.0);

    // c7
    midlevel = 0.5; disp = 2.5; dist = 35.0;
    uv2 = uv + float2(t / dist + 18.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.1)  return float4(0.88, 0.38, 0.24, 1.0);
    if (uv.y < h + midlevel - 0.05) return float4(0.98, 0.42, 0.28, 1.0);
    if (uv.y < h + midlevel)        return float4(1.0, 0.48, 0.35, 1.0);

    // c6
    midlevel = 0.6; disp = 2.0; dist = 40.0;
    uv2 = uv + float2(t / dist + 18.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.1)  return float4(0.95, 0.66, 0.48, 1.0);
    if (uv.y < h + midlevel)        return float4(1.0, 0.76, 0.60, 1.0);

    // c5
    midlevel = 0.75; disp = 3.5; dist = 45.0;
    uv2 = uv + float2(t / dist + 15.5, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.2)  return float4(1.0, 0.55, 0.33, 1.0);
    if (uv.y < h + midlevel - 0.15) return float4(0.98, 0.50, 0.24, 1.0);
    if (uv.y < h + midlevel - 0.1)  return float4(0.90, 0.55, 0.40, 1.0);
    if (uv.y < h + midlevel)        return float4(1.0, 0.62, 0.44, 1.0);

    // c4
    midlevel = 0.7; disp = 2.7; dist = 50.0;
    uv2 = uv + float2(t / dist + 12.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.04) return float4(0.73, 0.36, 0.30, 1.0);
    if (uv.y < h + midlevel)        return float4(0.80, 0.40, 0.34, 1.0);

    // c3
    midlevel = 0.8; disp = 2.7; dist = 60.0;
    uv2 = uv + float2(t / dist + 9.5, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.1)  return float4(0.93, 0.58, 0.35, 1.0);
    if (uv.y < h + midlevel)        return float4(1.0, 0.76, 0.60, 1.0);

    // c2
    midlevel = 0.9; disp = 3.0; dist = 70.0;
    uv2 = uv + float2(t / dist + 7.0, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.1)  return float4(0.56, 0.25, 0.22, 1.0);
    if (uv.y < h + midlevel - 0.05) return float4(0.60, 0.30, 0.27, 1.0);
    if (uv.y < h + midlevel)        return float4(0.74, 0.35, 0.30, 1.0);

    // c1
    midlevel = 1.0; disp = 5.0; dist = 100.0;
    uv2 = uv + float2(t / dist + 3.5, 0.0);
    h = (sc_fbm(uv2, 6) - 0.5) * disp;
    if (uv.y < h + midlevel - 0.1)  return float4(0.92, 0.85, 0.82, 1.0);
    if (uv.y < h + midlevel)        return float4(1.0, 0.94, 0.91, 1.0);

    // Sky
    return float4(0.58, 0.7, 1.0, 1.0);
}

fragment float4 sunsetCloudsFragment(VertexOut in [[stage_in]],
                                     constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = float2(in.uv.x, in.uv.y) * u.resolution / u.resolution.y;
    float t = u.time * 4.0;

    float3 col = sc_background(uv, t).rgb;

    // Foreground clouds (only lower half, single pass — no motion blur to save perf)
    if (uv.y < 0.5) {
        float4 fg = sc_foreground(uv, t);
        col = mix(col, fg.rgb, fg.a);
    }

    return float4(col, 1.0);
}
