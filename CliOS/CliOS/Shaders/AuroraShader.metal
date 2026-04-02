#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

float2x2 mm2(float a) {
    float c = cos(a), s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

constant float2x2 m2 = float2x2(float2(0.95534, 0.29552), float2(-0.29552, 0.95534));
constant float2x2 neg_m2 = float2x2(float2(-0.95534, -0.29552), float2(0.29552, -0.95534));

float tri(float x) {
    return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

float2 tri2(float2 p) {
    return float2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
}

float triNoise2d(float2 p, float spd, float time) {
    float z = 1.8;
    float z2 = 2.5;
    float rz = 0.0;
    p = mm2(p.x * 0.06) * p;
    float2 bp = p;
    for (float i = 0.0; i < 4.0; i++) {
        float2 dg = tri2(bp * 1.85) * 0.75;
        dg = mm2(time * spd) * dg;
        p -= dg / z2;
        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;
        p *= 1.21 + (rz - 1.0) * 0.02;
        rz += tri(p.x + tri(p.y)) * z;
        p = neg_m2 * p;
    }
    return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}

float hash21(float2 n) {
    return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

float4 aurora_fn(float3 ro, float3 rd, float2 fragCoord, float time) {
    float4 col = float4(0.0);
    float4 avgCol = float4(0.0);
    for (float i = 0.0; i < 30.0; i++) {
        float of = 0.006 * hash21(fragCoord) * smoothstep(0.0, 15.0, i);
        float pt = ((0.8 + pow(i, 1.4) * 0.002) - ro.y) / (rd.y * 2.0 + 0.4);
        pt -= of;
        float3 bpos = ro + pt * rd;
        float2 p = bpos.zx;
        float rzt = triNoise2d(p, 0.06, time);
        float4 col2 = float4(0.0, 0.0, 0.0, rzt);
        col2.rgb = (sin(1.0 - float3(2.15, -0.5, 1.2) + i * 0.043) * 0.5 + 0.5) * rzt;
        avgCol = mix(avgCol, col2, 0.5);
        col += avgCol * exp2(-i * 0.065 - 2.5) * smoothstep(0.0, 5.0, i);
    }
    col *= clamp(rd.y * 15.0 + 0.4, 0.0, 1.0);
    return col * 1.8;
}

float3 nmzHash33(float3 q) {
    uint3 p = uint3(int3(q));
    p = p * uint3(374761393U, 1103515245U, 668265263U) + p.zxy + p.yzx;
    p = p.yzx * (p.zxy ^ (p >> 3U));
    return float3(p ^ (p >> 16U)) * (1.0 / float(0xffffffffU));
}

float3 stars(float3 p, float res) {
    float3 c = float3(0.0);
    for (float i = 0.0; i < 3.0; i++) {
        float3 q = fract(p * (0.15 * res)) - 0.5;
        float3 id = floor(p * (0.15 * res));
        float2 rn = nmzHash33(id).xy;
        float c2 = 1.0 - smoothstep(0.0, 0.6, length(q));
        c2 *= step(rn.x, 0.0005 + i * i * 0.001);
        c += c2 * (mix(float3(1.0, 0.49, 0.1), float3(0.75, 0.9, 1.0), rn.y) * 0.1 + 0.9);
        p *= 1.3;
    }
    return c * c * 0.8;
}

float3 bg(float3 rd) {
    float sd = dot(normalize(float3(-0.5, -0.6, 0.9)), rd) * 0.5 + 0.5;
    sd = pow(sd, 5.0);
    float3 col = mix(float3(0.05, 0.1, 0.2), float3(0.1, 0.05, 0.2), sd);
    return col * 0.63;
}

fragment float4 auroraFragment(VertexOut in [[stage_in]],
                               constant ShaderUniforms &u [[buffer(0)]]) {
    float2 fragCoord = float2(in.uv.x * u.resolution.x, in.uv.y * u.resolution.y);
    float2 q = fragCoord / u.resolution;
    float2 p = q - 0.5;
    p.x *= u.resolution.x / u.resolution.y;

    float time = u.time;
    float3 ro = float3(0.0, 0.0, -6.7);
    float3 rd = normalize(float3(p, 1.3));

    float2 mo = float2(-0.1, 0.1);
    mo.x *= u.resolution.x / u.resolution.y;
    rd.yz = mm2(mo.y) * rd.yz;
    rd.xz = mm2(mo.x + sin(time * 0.015) * 0.12) * rd.xz;

    float3 col = float3(0.0);
    float3 brd = rd;
    float fade = smoothstep(0.0, 0.01, abs(brd.y)) * 0.1 + 0.9;

    col = bg(rd) * fade;

    if (rd.y > 0.0) {
        float4 aur = smoothstep(float4(0.0), float4(1.5), aurora_fn(ro, rd, fragCoord, time)) * fade;
        col += stars(rd, u.resolution.x);
        col = col * (1.0 - aur.a) + aur.rgb;
    } else {
        rd.y = abs(rd.y);
        col = bg(rd) * fade * 0.6;
        float4 aur = smoothstep(float4(0.0), float4(2.5), aurora_fn(ro, rd, fragCoord, time));
        col += stars(rd, u.resolution.x) * 0.1;
        col = col * (1.0 - aur.a) + aur.rgb;
        float3 pos = ro + ((0.5 - ro.y) / rd.y) * rd;
        float nz2 = triNoise2d(pos.xz * float2(0.5, 0.7), 0.0, time);
        col += mix(float3(0.2, 0.25, 0.5) * 0.08, float3(0.3, 0.3, 0.5) * 0.7, nz2 * 0.4);
    }

    return float4(col, 1.0);
}
