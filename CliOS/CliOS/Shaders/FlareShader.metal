#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

static float flare_eq(float2 p, float t) {
    float x = sin(p.y + cos(t + p.x * 0.2)) * cos(p.x - t);
    x *= acos(clamp(x, -1.0, 1.0));
    return -x * abs(x - 0.5) * p.x / p.y;
}

fragment float4 flareFragment(VertexOut in [[stage_in]],
                              constant ShaderUniforms &u [[buffer(0)]]) {
    float4 O = float4(0.0);
    float2 p = 20.0 * (in.uv + 0.5);
    float t = u.time;

    float hs = 20.0 * (0.7 + cos(t) * 0.1);
    float x = flare_eq(p, t);
    float y = p.y - x;

    float4 X = float4(0.0);
    for (float i = 0.0; i < 2.0; i++) {
        p.x *= 2.0;
        float eq1 = flare_eq(p, t + i + 1.0);
        float eq2 = flare_eq(p, t + i + 2.0);
        X = x + float4(0.0, eq1, eq2, 0.0);
        X.z += X.y;
        x = X.z;
        float3 tone = u.tintColor;
        O += float4(tone, 0.0) / abs(y - X - hs);
    }

    return float4(O.rgb, 1.0);
}
