#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

float S_d(float a, float b, float t) { return smoothstep(a, b, t); }

constant float3 streetLightCol = float3(1.0, 0.7, 0.3);
constant float3 headLightCol = float3(0.8, 0.8, 1.0);
constant float3 tailLightCol = float3(1.0, 0.1, 0.1);

float N_d(float t) {
    return fract(sin(t * 10234.324) * 123423.23512);
}

float3 N31_d(float p) {
    float3 p3 = fract(float3(p) * float3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

float DistLine_d(float3 ro, float3 rd, float3 p) {
    return length(cross(p - ro, rd));
}

float Remap_d(float a, float b, float c, float d, float t) {
    return ((t - a) / (b - a)) * (d - c) + c;
}

float BokehMask_d(float3 ro, float3 rd, float3 p, float size, float blur) {
    float d = DistLine_d(ro, rd, p);
    float m = S_d(size, size * (1.0 - blur), d);
    m *= mix(0.7, 1.0, S_d(0.8 * size, size, d));
    return m;
}

float SawTooth_d(float t) {
    return cos(t + cos(t)) + sin(2.0 * t) * 0.2 + sin(4.0 * t) * 0.02;
}

float DeltaSawTooth_d(float t) {
    return 0.4 * cos(2.0 * t) + 0.08 * cos(4.0 * t) - (1.0 - sin(t)) * sin(t + cos(t));
}

float2 GetDrops_d(float2 uv, float seed, float iTime) {
    float t = iTime;
    uv.y += t * 0.05;
    uv *= float2(10.0, 2.5) * 2.0;
    float2 id = floor(uv);
    float3 n = N31_d(id.x + (id.y + seed) * 546.3524);
    float2 bd = fract(uv) - 0.5;
    bd.y *= 4.0;
    bd.x += (n.x - 0.5) * 0.6;
    t += n.z * 6.28318;
    float slide = SawTooth_d(t);
    float ts = 1.5;
    float2 trailPos = float2(bd.x * ts, (fract(bd.y * ts * 2.0 - t * 2.0) - 0.5) * 0.5);
    bd.y += slide * 2.0;
    bd.y += bd.x * bd.x * DeltaSawTooth_d(t);
    float d = length(bd);
    float trailMask = S_d(-0.2, 0.2, bd.y) * bd.y;
    float td = length(trailPos * max(0.5, trailMask));
    float mainDrop = S_d(0.2, 0.1, d);
    float dropTrail = S_d(0.1, 0.02, td) * trailMask;
    return mix(bd * mainDrop, trailPos, dropTrail);
}

float3 HeadLights_d(float i, float t, float3 ro, float3 rd) {
    float z = fract(-t * 2.0 + i);
    float3 p = float3(-0.3, 0.1, z * 40.0);
    float d = length(p - ro);
    float size = mix(0.03, 0.05, S_d(0.02, 0.07, z)) * d;
    float m = BokehMask_d(ro, rd, p - float3(0.08, 0, 0), size, 0.1)
            + BokehMask_d(ro, rd, p + float3(0.08, 0, 0), size, 0.1)
            + BokehMask_d(ro, rd, p + float3(0.1, 0, 0), size, 0.1)
            + BokehMask_d(ro, rd, p - float3(0.1, 0, 0), size, 0.1);
    float distFade = max(0.01, pow(1.0 - z, 9.0));
    float r = (BokehMask_d(ro, rd, p + float3(-0.09, -0.2, 0), size * 2.5, 0.8)
             + BokehMask_d(ro, rd, p + float3(0.09, -0.2, 0), size * 2.5, 0.8))
             * distFade * distFade;
    return headLightCol * (m + r) * distFade;
}

float3 TailLights_d(float i, float t, float3 ro, float3 rd) {
    t = t * 1.5 + i;
    float id = floor(t) + i;
    float3 n = N31_d(id);
    float laneId = S_d(0.5, 0.51, n.y);
    float ft = fract(t);
    float z = 3.0 - ft * 3.0;
    laneId *= S_d(0.2, 1.5, z);
    float lane = mix(0.6, 0.3, laneId);
    float3 p = float3(lane, 0.1, z);
    float d = length(p - ro);
    float size = 0.05 * d;
    float m = BokehMask_d(ro, rd, p - float3(0.08, 0, 0), size, 0.1)
            + BokehMask_d(ro, rd, p + float3(0.08, 0, 0), size, 0.1);
    float bs = n.z * 3.0;
    float brake = S_d(bs, bs + 0.01, z) * S_d(bs + 0.01, bs, z - 0.5 * n.y);
    m += (BokehMask_d(ro, rd, p + float3(0.1, 0, 0), size, 0.1)
        + BokehMask_d(ro, rd, p - float3(0.1, 0, 0), size, 0.1)) * brake;
    float refSize = size * 2.5;
    m += BokehMask_d(ro, rd, p + float3(-0.09, -0.2, 0), refSize, 0.8);
    m += BokehMask_d(ro, rd, p + float3(0.09, -0.2, 0), refSize, 0.8);
    float3 col = tailLightCol * m * ft;
    float b = BokehMask_d(ro, rd, p + float3(0.12, 0, 0), size, 0.1);
    b += BokehMask_d(ro, rd, p + float3(0.12, -0.2, 0), refSize, 0.8) * 0.2;
    float3 blinker = float3(1.0, 0.7, 0.2) * S_d(1.5, 1.4, z) * S_d(0.2, 0.3, z)
                    * clamp(sin(t * 200.0) * 100.0, 0.0, 1.0) * laneId;
    col += blinker * b;
    return col;
}

float3 StreetLights_d(float i, float t, float3 ro, float3 rd) {
    float side = sign(rd.x);
    float offset = max(side, 0.0) / 16.0;
    float z = fract(i - t + offset);
    float3 p = float3(2.0 * side, 2.0, z * 60.0);
    float d = length(p - ro);
    float distFade = Remap_d(1.0, 0.7, 0.1, 1.5, 1.0 - pow(1.0 - z, 6.0)) * (1.0 - z);
    return BokehMask_d(ro, rd, p, 0.05 * d, 0.1) * distFade * streetLightCol;
}

float3 EnvLights_d(float i, float t, float3 ro, float3 rd) {
    float n = N_d(i + floor(t));
    float side = sign(rd.x);
    float offset = max(side, 0.0) / 16.0;
    float z = fract(i - t + offset + fract(n * 234.0));
    float n2 = fract(n * 100.0);
    float3 p = float3((3.0 + n) * side, n2 * n2 * n2, z * 60.0);
    float d = length(p - ro);
    float distFade = Remap_d(1.0, 0.7, 0.1, 1.5, 1.0 - pow(1.0 - z, 6.0));
    float m = BokehMask_d(ro, rd, p, 0.05 * d, 0.1) * distFade * distFade * 0.5;
    m *= 1.0 - pow(sin(z * 6.28 * 20.0 * n) * 0.5 + 0.5, 20.0);
    float3 col = mix(tailLightCol, streetLightCol, fract(n * -65.42));
    col = mix(col, float3(fract(n * -34.5), fract(n * 4572.0), fract(n * 1264.0)), n);
    return m * col * 0.2;
}

fragment float4 driveHomeFragment(VertexOut in [[stage_in]],
                                  constant ShaderUniforms &u [[buffer(0)]]) {
    float iTime = u.time;
    float2 uv = in.uv - 0.5;
    uv.x *= u.resolution.x / u.resolution.y;

    float3 pos = float3(0.3, 0.15, 0.0);
    float bt = iTime * 5.0;
    float bumps = mix(N_d(floor(bt)), N_d(floor(bt + 1.0)), fract(bt)) * 0.1;
    bumps = bumps * bumps * bumps;
    pos.y += bumps;
    float lookatY = pos.y + bumps;
    float3 lookat = mix(float3(0.3, lookatY, 1.0), float3(0.0, lookatY, 0.7),
                       sin(iTime * 0.1) * 0.5 + 0.5);
    uv.y += bumps * 4.0;

    float3 ro = pos;
    float3 f = normalize(lookat - ro);
    float3 r = cross(float3(0, 1, 0), f);
    float3 up = cross(f, r);

    float rx = (sin(iTime * 0.1) * 0.5 + 0.5) * 0.5;
    rx = -rx * rx;
    float cs = cos(rx), sn = sin(rx);
    float2 dropUv = float2x2(float2(cs, sn), float2(-sn, cs)) * uv;
    dropUv.x -= sin(iTime * 0.1) * 0.5;

    float2 offs = GetDrops_d(dropUv, 1.0, iTime)
                + GetDrops_d(dropUv * 1.4, 10.0, iTime)
                + GetDrops_d(dropUv * 2.4, 25.0, iTime);
    float ripple = sin(iTime + uv.y * 94.248 + uv.x * 124.0) * 0.5 + 0.5;
    ripple *= 0.005;
    offs += float2(ripple * ripple, ripple);

    float3 center = ro + f * 2.0;
    float3 ii = center + (uv.x - offs.x) * r + (uv.y - offs.y) * up;
    float3 rd = normalize(ii - ro);

    float t = iTime * 0.03;
    float3 col = float3(0.0);

    for (float i = 0.0; i < 1.0; i += 0.125)
        col += StreetLights_d(i, t, ro, rd);
    for (float i = 0.0; i < 1.0; i += 0.125) {
        float n = N_d(i + floor(t));
        col += HeadLights_d(i + n * 0.0875, t, ro, rd);
    }
    for (float i = 0.0; i < 1.0; i += 0.03125)
        col += EnvLights_d(i, t, ro, rd);

    col += TailLights_d(0.0, t, ro, rd);
    col += TailLights_d(0.5, t, ro, rd);
    col += clamp(rd.y, 0.0, 1.0) * float3(0.6, 0.5, 0.9);

    return float4(col, 1.0);
}
