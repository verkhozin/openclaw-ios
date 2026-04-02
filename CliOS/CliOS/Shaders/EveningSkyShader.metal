#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Evening Sky: deep sunset, purple-orange gradient ---

static float es_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float es_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(es_hash(i), es_hash(i + float2(1, 0)), f.x),
               mix(es_hash(i + float2(0, 1)), es_hash(i + float2(1, 1)), f.x), f.y);
}

static float es_fbm(float2 p) {
    float v = 0.0, a = 0.5, t = 0.0;
    for (int i = 0; i < 5; i++) {
        v += a * es_noise(p);
        t += a;
        p = p * 2.1 + 0.7;
        a *= 0.48;
    }
    return v / t;
}

fragment float4 eveningSkyFragment(VertexOut in [[stage_in]],
                                   constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time * 0.025;
    float ar = u.resolution.x / u.resolution.y;

    // Deep sunset gradient
    float3 top = float3(0.15, 0.1, 0.3);
    float3 mid = float3(0.6, 0.2, 0.35);
    float3 low = float3(0.95, 0.5, 0.2);
    float3 bot = float3(1.0, 0.65, 0.15);

    float3 col;
    if (uv.y > 0.6)
        col = mix(mid, top, (uv.y - 0.6) / 0.4);
    else if (uv.y > 0.35)
        col = mix(low, mid, (uv.y - 0.35) / 0.25);
    else
        col = mix(bot, low, uv.y / 0.35);

    // Setting sun — low and large
    float2 sunP = float2(0.4 * ar, 0.28);
    float2 uvAr = float2(uv.x * ar, uv.y);
    float sd = length(uvAr - sunP);
    col += float3(1.0, 0.6, 0.15) * 0.5 * exp(-sd * 3.5);
    col += float3(1.0, 0.85, 0.4) * 0.7 * exp(-sd * 10.0);

    // Silhouette clouds — dark against bright sky
    float2 cp = float2(uv.x * ar * 2.0 + t, uv.y * 1.5);
    float n1 = es_fbm(cp * 1.8);
    float n2 = es_fbm(cp * 3.5 + 5.0);
    float cloud = n1 * 0.6 + n2 * 0.4;

    float mask = smoothstep(0.8, 0.25, uv.y);
    cloud = smoothstep(0.4, 0.65, cloud) * mask;

    // Clouds lit from below
    float3 cloudLit = float3(1.0, 0.55, 0.2);
    float3 cloudDark = float3(0.25, 0.1, 0.15);
    float edgeLight = smoothstep(0.4, 0.55, cloud) * (1.0 - smoothstep(0.55, 0.7, cloud));
    float3 cloudCol = mix(cloudDark, cloudLit, n2 * 0.5 + edgeLight * 0.8);

    col = mix(col, cloudCol, cloud * 0.9);

    // Stars peeking through at top
    float2 starUV = floor(uv * u.resolution * 0.5);
    float star = step(0.998, es_hash(starUV));
    star *= smoothstep(0.6, 0.9, uv.y);
    float twinkle = 0.5 + 0.5 * sin(es_hash(starUV + 1.0) * 50.0 + u.time * 2.0);
    col += star * twinkle * float3(0.9, 0.85, 1.0);

    return float4(col, 1.0);
}
