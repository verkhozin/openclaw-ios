#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Night Sky: stars, moon, subtle clouds ---

static float ns_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float ns_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(ns_hash(i), ns_hash(i + float2(1, 0)), f.x),
               mix(ns_hash(i + float2(0, 1)), ns_hash(i + float2(1, 1)), f.x), f.y);
}

static float ns_fbm(float2 p) {
    float v = 0.0, a = 0.5, t = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * ns_noise(p);
        t += a;
        p = p * 2.05 + 0.4;
        a *= 0.5;
    }
    return v / t;
}

fragment float4 nightSkyFragment(VertexOut in [[stage_in]],
                                 constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time * 0.015;
    float ar = u.resolution.x / u.resolution.y;

    // Night gradient — deep blue/black
    float3 top = float3(0.02, 0.02, 0.06);
    float3 bot = float3(0.08, 0.1, 0.18);
    float3 col = mix(bot, top, uv.y);

    // Moon
    float2 moonP = float2(0.7 * ar, 0.75);
    float2 uvAr = float2(uv.x * ar, uv.y);
    float md = length(uvAr - moonP);
    float moon = smoothstep(0.08, 0.075, md);
    // Crescent shadow
    float shadow = smoothstep(0.06, 0.075, length(uvAr - moonP - float2(0.03, 0.01)));
    moon *= shadow;
    col += moon * float3(0.95, 0.93, 0.85);
    // Moon glow
    col += float3(0.15, 0.18, 0.3) * 0.3 * exp(-md * 5.0);

    // Stars — multiple layers
    for (float layer = 0.0; layer < 3.0; layer++) {
        float scale = 200.0 + layer * 150.0;
        float2 starGrid = floor(uv * scale + layer * 73.0);
        float h = ns_hash(starGrid + layer * 17.3);
        float brightness = step(0.97 - layer * 0.005, h);
        float twinkle = 0.6 + 0.4 * sin(h * 80.0 + u.time * (1.5 + h * 2.0));
        float size = (1.0 - layer * 0.3);
        float2 starPos = fract(uv * scale + layer * 73.0) - 0.5;
        float starDot = smoothstep(0.04 * size, 0.0, length(starPos));
        float3 starCol = mix(float3(0.8, 0.85, 1.0), float3(1.0, 0.9, 0.7), h);
        col += brightness * twinkle * starDot * starCol * size;
    }

    // Dark purple clouds — two layers for depth
    float2 cp = float2(uv.x * ar * 2.0 + t, uv.y * 0.8 + 0.2);
    float n1 = ns_fbm(cp * 1.8);
    float n2 = ns_fbm(cp * 3.5 + 5.0);
    float cloud = n1 * 0.6 + n2 * 0.4;
    cloud = smoothstep(0.35, 0.65, cloud);
    float cloudMask = smoothstep(0.55, 0.15, uv.y) * smoothstep(0.0, 0.1, uv.y);

    float3 cloudDark = float3(0.06, 0.03, 0.1);
    float3 cloudMid = float3(0.12, 0.06, 0.18);
    float3 cloudCol = mix(cloudDark, cloudMid, n2);
    // Faint purple edge light from moonlight
    float edgeGlow = smoothstep(0.35, 0.5, cloud) * (1.0 - smoothstep(0.5, 0.65, cloud));
    cloudCol += float3(0.15, 0.08, 0.25) * edgeGlow;

    col = mix(col, cloudCol, cloud * cloudMask * 0.85);

    return float4(col, 1.0);
}
