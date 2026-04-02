#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Rainy Sky: overcast clouds + falling rain streaks ---

static float rn_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float rn_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(rn_hash(i), rn_hash(i + float2(1, 0)), f.x),
               mix(rn_hash(i + float2(0, 1)), rn_hash(i + float2(1, 1)), f.x), f.y);
}

static float rn_fbm(float2 p) {
    float v = 0.0, a = 0.5, t = 0.0;
    for (int i = 0; i < 6; i++) {
        v += a * rn_noise(p);
        t += a;
        p = p * 2.05 + 0.3;
        a *= 0.5;
    }
    return v / t;
}

// Rain drop layer
static float rn_drops(float2 uv, float t, float layer) {
    float speed = 8.0 + layer * 3.0;
    float density = 80.0 + layer * 40.0;
    float streakLen = 0.06 - layer * 0.015;

    // Tile into columns
    float2 grid = float2(density, 1.0);
    float2 id = floor(uv * grid + layer * 37.0);
    float h = rn_hash(id + layer * 13.7);

    // Random x offset within cell
    float x = fract(uv.x * grid.x + layer * 37.0) - 0.5;
    x += (h - 0.5) * 0.3;

    // Falling y
    float y = fract(uv.y + t * speed * (0.5 + h * 0.5) + h * 100.0);

    // Streak shape — thin vertical line
    float streak = smoothstep(0.008, 0.0, abs(x)) *
                   smoothstep(streakLen, 0.0, y) *
                   smoothstep(0.0, 0.01, y);

    // Not all columns have rain
    streak *= step(0.3, h);

    return streak * (0.4 + layer * 0.3);
}

fragment float4 rainFragment(VertexOut in [[stage_in]],
                             constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time;
    float ar = u.resolution.x / u.resolution.y;

    // Overcast gradient — grey, oppressive
    float3 top = float3(0.25, 0.27, 0.3);
    float3 bot = float3(0.4, 0.42, 0.45);
    float3 col = mix(bot, top, uv.y);

    // Heavy cloud layer
    float2 cp = float2(uv.x * ar * 1.5 + t * 0.02, uv.y * 0.8 + 0.5);
    float n1 = rn_fbm(cp * 2.0);
    float n2 = rn_fbm(cp * 4.0 + 3.0);
    float cloud = n1 * 0.6 + n2 * 0.4;

    float cloudMask = smoothstep(0.2, 0.6, uv.y);
    cloud = smoothstep(0.3, 0.6, cloud) * cloudMask;

    float3 cloudDark = float3(0.2, 0.22, 0.25);
    float3 cloudLight = float3(0.5, 0.52, 0.55);
    col = mix(col, mix(cloudDark, cloudLight, n2), cloud * 0.7);

    // Darker at bottom — wet atmosphere
    col *= 0.85 + 0.15 * uv.y;

    // Rain layers (3 layers for depth)
    float2 rainUV = float2(uv.x * ar, uv.y);
    float rain = 0.0;
    rain += rn_drops(rainUV, t, 0.0);
    rain += rn_drops(rainUV * 1.3 + 0.5, t, 1.0);
    rain += rn_drops(rainUV * 0.7 + 1.3, t, 2.0);

    col += rain * float3(0.6, 0.65, 0.7);

    // Slight fog at bottom
    float fog = smoothstep(0.3, 0.0, uv.y) * 0.15;
    col = mix(col, float3(0.4, 0.42, 0.45), fog);

    return float4(col, 1.0);
}
