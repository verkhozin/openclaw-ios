#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

float wrand(float2 n) {
    return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

float wnoise(float2 p, float iTime) {
    float2 ip = floor(p);
    float2 u = fract(p);
    u = u * u * (3.0 - 2.0 * u);
    float res = mix(
        mix(wrand(ip), wrand(ip + float2(1.0, 0.0)), u.x),
        mix(wrand(ip + float2(0.0, 1.0)), wrand(ip + float2(1.0, 1.0)), u.x), u.y);
    return res * res;
}

constant float2x2 wmtx = float2x2(float2(0.80, 0.60), float2(-0.60, 0.80));

float wfbm(float2 p, float iTime) {
    float f = 0.0;
    f += 0.500000 * wnoise(p + iTime, iTime); p = wmtx * p * 2.02;
    f += 0.031250 * wnoise(p, iTime);          p = wmtx * p * 2.01;
    f += 0.250000 * wnoise(p, iTime);          p = wmtx * p * 2.03;
    f += 0.125000 * wnoise(p, iTime);          p = wmtx * p * 2.01;
    f += 0.062500 * wnoise(p, iTime);          p = wmtx * p * 2.04;
    f += 0.015625 * wnoise(p + sin(iTime), iTime);
    return f / 0.96875;
}

float wpattern(float2 p, float iTime) {
    return wfbm(p + wfbm(p + wfbm(p, iTime), iTime), iTime);
}

fragment float4 warpFBMFragment(VertexOut in [[stage_in]],
                                constant ShaderUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv * float2(u.resolution.x / u.resolution.y, 1.0);
    float shade = wpattern(uv * 3.0, u.time);

    float3 tint = u.tintColor;
    float3 dark = tint * 0.12;
    float3 mid = tint;
    float3 bright = mix(tint, float3(1.0), 0.6);

    float3 col;
    if (shade < 0.4) {
        col = mix(dark, mid, shade / 0.4);
    } else if (shade < 0.7) {
        col = mix(mid, bright, (shade - 0.4) / 0.3);
    } else {
        col = mix(bright, float3(1.0), (shade - 0.7) / 0.3);
    }

    return float4(col, 1.0);
}
