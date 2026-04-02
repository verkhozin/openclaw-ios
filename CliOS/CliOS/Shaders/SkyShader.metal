#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Sky & Clouds (procedural 2D) ---

static float sky_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float sky_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = sky_hash(i);
    float b = sky_hash(i + float2(1.0, 0.0));
    float c = sky_hash(i + float2(0.0, 1.0));
    float d = sky_hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float sky_fbm(float2 p, int oct) {
    float v = 0.0, a = 0.5, t = 0.0;
    for (int i = 0; i < oct; i++) {
        v += a * sky_noise(p);
        t += a;
        p = p * 2.03 + 0.5;
        a *= 0.5;
    }
    return v / t;
}

fragment float4 skyFragment(VertexOut in [[stage_in]],
                            constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time * 0.04;
    float ar = u.resolution.x / u.resolution.y;

    // Sky gradient — deep blue top, lighter at horizon
    float3 skyTop = float3(0.15, 0.33, 0.65);
    float3 skyBot = float3(0.55, 0.75, 0.95);
    float3 col = mix(skyBot, skyTop, uv.y);

    // Sun glow near horizon
    float2 sunPos = float2(0.6 * ar, 0.38);
    float2 uvAr = float2(uv.x * ar, uv.y);
    float sunDist = length(uvAr - sunPos);
    col += float3(1.0, 0.9, 0.7) * 0.3 * exp(-sunDist * 3.0);

    // Cloud layer — scrolling fbm
    float cloudLine = 0.45; // horizon line
    float2 cp = float2(uv.x * ar * 2.0 + t, uv.y * 1.5);

    // Two octave layers for depth
    float n1 = sky_fbm(cp * 1.5, 6);
    float n2 = sky_fbm(cp * 3.0 + 10.0, 5);
    float cloud = n1 * 0.7 + n2 * 0.3;

    // Shape clouds — denser near horizon, fade toward top
    float horizon = smoothstep(0.7, 0.35, uv.y);
    cloud = smoothstep(0.35, 0.65, cloud) * horizon;

    // Cloud color — bright tops, darker bottoms
    float3 cloudBright = float3(1.0, 1.0, 1.0);
    float3 cloudDark = float3(0.7, 0.75, 0.85);
    float3 cloudCol = mix(cloudDark, cloudBright, n2);

    // Blend clouds onto sky
    col = mix(col, cloudCol, cloud * 0.9);

    // Subtle lower haze
    float haze = smoothstep(0.4, 0.0, uv.y) * 0.25;
    col = mix(col, float3(0.8, 0.85, 0.95), haze);

    return float4(col, 1.0);
}
