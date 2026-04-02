#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

constant float pi = 3.1415926435;
constant float2 vp = float2(320.0, 200.0);

// Buffer A inlined — generates palette color for parameter i (0..1)
static float3 palette(float i, float iTime, float3 tint) {
    float3 t = iTime / float3(63.0, 78.0, 45.0);
    // tintColor controls the phase offsets (default ~0,1,-0.5 gives original rainbow)
    float3 phase = tint * pi;
    float3 cs = cos(i * pi * 2.0 + phase + t);
    return 0.5 + 0.5 * cs;
}

fragment float4 plasmaFragment(VertexOut in [[stage_in]],
                               constant ShaderUniforms &u [[buffer(0)]]) {
    float iTime = u.time;
    float2 uv = in.uv;
    float t = iTime * 10.0;

    float2 p0 = (uv - 0.5) * vp;
    float2 hvp = vp * 0.5;

    float2 p1d = float2(cos(t / 98.0),   sin(t / 178.0))  * hvp - p0;
    float2 p2d = float2(sin(-t / 124.0), cos(-t / 104.0)) * hvp - p0;
    float2 p3d = float2(cos(-t / 165.0), cos(t / 45.0))   * hvp - p0;

    float sum = 0.5 + 0.5 * (
        cos(length(p1d) / 30.0) +
        cos(length(p2d) / 20.0) +
        sin(length(p3d) / 25.0) * sin(p3d.x / 20.0) * sin(p3d.y / 15.0));

    // Lookup palette (replaces texture(iChannel0, vec2(fract(sum), 0)))
    float3 col = palette(fract(sum), iTime, u.tintColor);

    return float4(col, 1.0);
}
