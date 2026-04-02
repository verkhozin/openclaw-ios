#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- Vector Field Background (nmz/stormoid) ---

static float vf_f(float2 p, float t) {
    return sin(p.x + sin(p.y + t * 0.1)) * sin(p.y * p.x * 0.1 + t * 0.2);
}

static float2 vf_field(float2 p, float t) {
    float2 ep = float2(0.05, 0.0);
    float2 rz = float2(0.0);
    for (int i = 0; i < 7; i++) {
        float t0 = vf_f(p, t);
        float t1 = vf_f(p + ep.xy, t);
        float t2 = vf_f(p + ep.yx, t);
        float2 g = float2(t1 - t0, t2 - t0) / ep.xx;
        float2 tn = float2(-g.y, g.x);
        p += 0.9 * tn + g * 0.3;
        rz = tn;
    }
    return rz;
}

fragment float4 vectorFieldFragment(VertexOut in [[stage_in]],
                                    constant ShaderUniforms &u [[buffer(0)]]) {
    float2 p = in.uv - 0.5;
    p.x *= u.resolution.x / u.resolution.y;
    p *= 10.0;

    float t = u.time;
    float2 fld = vf_field(p, t);

    float3 col = sin(float3(-0.3, 0.1, 0.5) + fld.x - fld.y) * 0.65 + 0.35;
    col = mix(col, float3(fld.x, -fld.x, fld.y), smoothstep(0.75, 1.0, sin(t * 0.4))) * 0.85;

    return float4(col, 1.0);
}
