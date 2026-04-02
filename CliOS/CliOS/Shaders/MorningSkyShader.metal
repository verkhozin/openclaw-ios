#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Morning Sky: warm sunrise, soft clouds ---

static float ms_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float ms_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = ms_hash(i);
    float b = ms_hash(i + float2(1, 0));
    float c = ms_hash(i + float2(0, 1));
    float d = ms_hash(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float ms_fbm(float2 p) {
    float v = 0.0, a = 0.5, t = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * ms_noise(p);
        t += a;
        p = p * 2.03 + 0.3;
        a *= 0.5;
    }
    return v / t;
}

fragment float4 morningSkyFragment(VertexOut in [[stage_in]],
                                   constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time * 0.03;
    float ar = u.resolution.x / u.resolution.y;

    // Sunrise gradient — warm at bottom, pale blue top
    float3 top = float3(0.45, 0.6, 0.85);
    float3 mid = float3(0.95, 0.75, 0.55);
    float3 bot = float3(1.0, 0.6, 0.35);

    float3 col;
    if (uv.y > 0.5)
        col = mix(mid, top, (uv.y - 0.5) * 2.0);
    else
        col = mix(bot, mid, uv.y * 2.0);

    // Sun at horizon
    float2 sunP = float2(0.5 * ar, 0.32);
    float2 uvAr = float2(uv.x * ar, uv.y);
    float sd = length(uvAr - sunP);
    col += float3(1.0, 0.85, 0.5) * 0.6 * exp(-sd * 4.0);
    col += float3(1.0, 0.95, 0.8) * 0.9 * exp(-sd * 12.0);

    // Soft clouds
    float2 cp = float2(uv.x * ar * 2.5 + t, uv.y * 1.2 + 0.3);
    float n = ms_fbm(cp * 2.0);
    float n2 = ms_fbm(cp * 4.0 + 7.0);
    float cloud = n * 0.65 + n2 * 0.35;

    float mask = smoothstep(0.75, 0.3, uv.y);
    cloud = smoothstep(0.38, 0.62, cloud) * mask;

    // Warm lit clouds
    float3 cloudLit = float3(1.0, 0.9, 0.75);
    float3 cloudShade = float3(0.85, 0.65, 0.5);
    float3 cloudCol = mix(cloudShade, cloudLit, n2);

    col = mix(col, cloudCol, cloud * 0.85);

    return float4(col, 1.0);
}
