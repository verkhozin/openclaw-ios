#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

constant float cloudscale = 1.1;
constant float cloud_speed = 0.03;
constant float clouddark = 0.5;
constant float cloudlight = 0.3;
constant float cloudcover = 0.2;
constant float cloudalpha = 8.0;
constant float skytint = 0.5;
constant float3 skycolour1 = float3(0.2, 0.4, 0.6);
constant float3 skycolour2 = float3(0.4, 0.7, 1.0);

constant float2x2 cm = float2x2(float2(1.6, 1.2), float2(-1.2, 1.6));

float2 chash(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float cnoise(float2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    float2 i = floor(p + (p.x + p.y) * K1);
    float2 a = p - i + (i.x + i.y) * K2;
    float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;
    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3 n = h * h * h * h * float3(dot(a, chash(i + 0.0)), dot(b, chash(i + o)), dot(c, chash(i + 1.0)));
    return dot(n, float3(70.0));
}

float fbm(float2 n) {
    float total = 0.0, amplitude = 0.1;
    for (int i = 0; i < 6; i++) {
        total += cnoise(n) * amplitude;
        n = cm * n;
        amplitude *= 0.4;
    }
    return total;
}

fragment float4 cloudsFragment(VertexOut in [[stage_in]],
                               constant ShaderUniforms &u [[buffer(0)]]) {
    float2 p = in.uv;
    float2 uv = p * float2(u.resolution.x / u.resolution.y, 1.0);
    float time = u.time * cloud_speed;
    float q = fbm(uv * cloudscale * 0.5);

    float r = 0.0;
    float2 ruv = uv * cloudscale - q + time;
    float weight = 0.8;
    for (int i = 0; i < 7; i++) {
        r += abs(weight * cnoise(ruv));
        ruv = cm * ruv + time;
        weight *= 0.7;
    }

    float f = 0.0;
    float2 fuv = uv * cloudscale - q + time;
    weight = 0.7;
    for (int i = 0; i < 7; i++) {
        f += weight * cnoise(fuv);
        fuv = cm * fuv + time;
        weight *= 0.6;
    }
    f *= r + f;

    float c = 0.0;
    float time2 = u.time * cloud_speed * 2.0;
    float2 cuv = uv * cloudscale * 2.0 - q + time2;
    weight = 0.4;
    for (int i = 0; i < 6; i++) {
        c += weight * cnoise(cuv);
        cuv = cm * cuv + time2;
        weight *= 0.6;
    }

    float c1 = 0.0;
    float time3 = u.time * cloud_speed * 3.0;
    float2 c1uv = uv * cloudscale * 3.0 - q + time3;
    weight = 0.4;
    for (int i = 0; i < 6; i++) {
        c1 += abs(weight * cnoise(c1uv));
        c1uv = cm * c1uv + time3;
        weight *= 0.6;
    }
    c += c1;

    float3 skycolour = mix(skycolour2, skycolour1, p.y);
    float3 cloudcolour = float3(1.1, 1.1, 0.9) * clamp(clouddark + cloudlight * c, 0.0, 1.0);
    f = cloudcover + cloudalpha * f * r;
    float3 result = mix(skycolour, clamp(skytint * skycolour + cloudcolour, 0.0, 1.0), clamp(f + c, 0.0, 1.0));

    return float4(result, 1.0);
}
