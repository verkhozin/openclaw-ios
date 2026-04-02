#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

float3 sp_fn(float t) {
    return float3(0.26, 0.76, 0.77) + float3(1.0, 0.3, 1.0) * cos(6.28318 * (float3(0.8, 0.4, 0.7) * t + float3(0.0, 0.12, 0.54)));
}

float4 hue_fn(float v) {
    return 0.6 + 0.76 * cos(6.3 * v + float4(0.0, 23.0, 21.0, 0.0));
}

float hash12(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float2 rotate2D(float2 st, float a) {
    float c = cos(a), s = sin(a);
    return float2x2(float2(c, -s), float2(s, c)) * st;
}

float st_fn(float a, float b, float s) {
    return smoothstep(a - s, a + s, b);
}

float gnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(dot(hash22(i + float2(0, 0)), f - float2(0, 0)),
            dot(hash22(i + float2(1, 0)), f - float2(1, 0)), u.x),
        mix(dot(hash22(i + float2(0, 1)), f - float2(0, 1)),
            dot(hash22(i + float2(1, 1)), f - float2(1, 1)), u.x),
        u.y);
}

fragment float4 coastalFragment(VertexOut in [[stage_in]],
                                constant ShaderUniforms &uniforms [[buffer(0)]]) {
    float2 fragCoord = in.uv * uniforms.resolution;
    float2 r = uniforms.resolution;
    float iTime = uniforms.time;

    float2 uv = (2.0 * fragCoord - r) / r.y;
    float2 sun_pos = float2(r.x / r.y * 0.42, -0.53);
    float2 tree_pos = float2(-r.x / r.y * 0.42, -0.2);

    float2 sh = float2(0.0), u = float2(0.0), id = float2(0.0), lc = float2(0.0), t = float2(0.0);
    float3 f = float3(0.0);
    float xd = 0.0, yd = 0.0, h = 0.0, a = 0.0, l = 0.0;
    float4 C = float4(0.0);
    float4 O = float4(0.0, 0.0, 0.0, 1.0);
    float sm = 3.0 / r.y;

    sh = rotate2D(sun_pos, gnoise(uv + iTime * 0.25) * 0.3);

    if (uv.y > -0.4) {
        u = uv + sh;
        yd = 60.0;
        id = float2((length(u) + 0.01) * yd, 0.0);
        xd = floor(id.x) * 0.09;
        h = (hash12(floor(id.xx)) * 0.5 + 0.25) * (iTime + 10.0) * 0.25;
        t = rotate2D(u, h);
        id.y = atan2(t.y, t.x) * xd;
        lc = fract(id);
        id -= lc;
        t = float2(cos((id.y + 0.5) / xd) * (id.x + 0.5) / yd,
                    sin((id.y + 0.5) / xd) * (id.x + 0.5) / yd);
        t = rotate2D(t, -h) - sh;
        h = gnoise(t * float2(0.5, 1.0) - float2(iTime * 0.2, 0.0)) * step(-0.25, t.y);
        h = smoothstep(0.052, 0.055, h);
        lc += gnoise(lc * float2(1.0, 4.0) + id) * float2(0.7, 0.2);
        f = mix(sp_fn(sin(length(u) - 0.1)) * 0.35,
                mix(sp_fn(sin(length(u) - 0.1) + (hash12(id) - 0.5) * 0.15), float3(1.0), h),
                st_fn(abs(lc.x - 0.5), 0.4, sm * yd) * st_fn(abs(lc.y - 0.5), 0.48, sm * xd));
    }

    if (uv.y < -0.35) {
        float cld = gnoise(-sh * float2(0.5, 1.0) - float2(iTime * 0.2, 0.0));
        cld = 1.0 - smoothstep(0.0, 0.15, cld) * 0.5;
        u = uv * float2(1.0, 15.0);
        id = floor(u);
        for (float wi = 1.0; wi > -1.0; wi--) {
            if (id.y + wi < -5.0) {
                lc = fract(u) - 0.5;
                lc.y = (lc.y + sin(uv.x * 12.0 - iTime * 3.0 + id.y + wi) * 0.25 - wi) * 4.0;
                h = hash12(float2(id.y + wi, floor(lc.y)));
                xd = 6.0 + h * 4.0;
                yd = 30.0;
                lc.x = uv.x * xd + sh.x * 9.0;
                lc.x += sin(iTime * (0.5 + h * 2.0)) * 0.5;
                h = 0.8 * smoothstep(5.0, 0.0, abs(floor(lc.x))) * cld + 0.1;
                f = mix(f, mix(float3(0.0, 0.1, 0.5), float3(0.35, 0.35, 0.0), h), st_fn(lc.y, 0.0, sm * yd));
                lc += gnoise(lc * float2(3.0, 0.5)) * float2(0.1, 0.6);
                f = mix(f,
                    mix(hue_fn(hash12(floor(lc)) * 0.1 + 0.56).rgb * (1.2 + floor(lc.y) * 0.17), float3(1.0, 1.0, 0.0), h),
                    st_fn(lc.y, 0.0, sm * xd)
                    * st_fn(abs(fract(lc.x) - 0.5), 0.48, sm * xd) * st_fn(abs(fract(lc.y) - 0.5), 0.3, sm * yd));
            }
        }
    }

    O = float4(f, 1.0);

    a = 0.0;
    u = uv + gnoise(uv * 2.0) * 0.1 + float2(0.0, sin(uv.x + 3.0) * 0.4 + 0.8);
    f = mix(float3(0.7, 0.6, 0.2), float3(0.0, 1.0, 0.0), sin(iTime * 0.2) * 0.5 + 0.5);
    O = mix(O, float4(f * 0.4, 1.0), step(u.y, 0.0));
    xd = 60.0;
    u = u * float2(xd, xd / 3.5);

    if (u.y < 1.2) {
        for (float y = 0.0; y > -3.0; y--) {
            for (float x = -2.0; x < 3.0; x++) {
                id = floor(u) + float2(x, y);
                lc = (fract(u) + float2(1.0 - x, -y)) / float2(5.0, 3.0);
                h = (hash12(id) - 0.5) * 0.25 + 0.5;
                lc -= float2(0.3, 0.5 - h * 0.4);
                lc.x += sin(((iTime * 1.7 + h * 2.0 - id.x * 0.05 - id.y * 0.05) * 1.1 + id.y * 0.5) * 2.0) * (lc.y + 0.5) * 0.5;
                t = abs(lc) - float2(0.02, 0.5 - h * 0.5);
                l = length(max(t, 0.0)) + min(max(t.x, t.y), 0.0);
                l -= gnoise(lc * 7.0 + id) * 0.1;
                C = float4(f * 0.25, st_fn(l, 0.1, sm * xd * 0.09));
                C = mix(C, float4(f * (1.2 + lc.y * 2.0) * (1.8 - h * 2.5), 1.0), st_fn(l, 0.04, sm * xd * 0.09));
                O = mix(O, C, C.a * step(id.y, -1.0));
                a = max(a, C.a * step(id.y, -5.0));
            }
        }
    }

    float T = sin(iTime * 0.5);

    if (abs(uv.x + tree_pos.x - 0.1 - T * 0.1) < 0.6) {
        u = uv + tree_pos;
        u.x -= sin(u.y + 1.0) * 0.2 * (T + 0.75);
        u += gnoise(u * 4.5 - 7.0) * 0.25;
        xd = 10.0; yd = 60.0;
        t = u * float2(1.0, yd);
        h = hash12(floor(t.yy));
        t.x += h * 0.01;
        t.x *= xd;
        lc = fract(t);
        float m = st_fn(abs(t.x - 0.5), 0.5, sm * xd) * step(abs(t.y + 20.0), 45.0);
        C = mix(float4(0.07),
                float4(float3(0.5, 0.3, 0.0) * (0.4 + h * 0.4), 1.0),
                st_fn(abs(lc.y - 0.5), 0.4, sm * yd) * st_fn(abs(lc.x - 0.5), 0.45, sm * xd));
        C.a = m;
        xd = 30.0; yd = 15.0;

        for (float xs = 0.0; xs < 4.0; xs++) {
            u = uv + tree_pos + float2(xs / xd * 0.5 - (T + 0.75) * 0.15, -0.7);
            u += gnoise(u * float2(2.0, 1.0) + float2(-iTime + xs * 0.05, 0.0))
                 * float2(-0.25, 0.1) * smoothstep(0.5, -1.0, u.y + 0.7) * 0.75;
            t = u * float2(xd, 1.0);
            h = hash12(floor(t.xx) + xs * 1.4);
            yd = 5.0 + h * 7.0;
            t.y *= yd;
            float2 sht = t;
            lc = fract(t);
            h = hash12(t - lc);
            t = (t - lc) / float2(xd, yd) + float2(0.0, 0.7);
            m = (step(0.0, t.y) * step(length(t), 0.45)
                + step(t.y, 0.0) * step(-0.7 + sin((floor(u.x) + xs * 0.5) * 15.0) * 0.2, t.y))
                * step(abs(t.x), 0.5)
                * st_fn(abs(lc.x - 0.5), 0.35, sm * xd * 0.5);
            lc += gnoise(sht * float2(1.0, 3.0)) * float2(0.3, 0.3);
            f = hue_fn((h + (sin(iTime * 0.2) * 0.5 + 0.5)) * 0.2).rgb - t.x;
            C = mix(C,
                    float4(mix(f * 0.15, f * 0.6 * (0.7 + xs * 0.2),
                        st_fn(abs(lc.y - 0.5), 0.47, sm * yd) * st_fn(abs(lc.x - 0.5), 0.2, sm * xd)), m),
                    m);
        }
        O = mix(O, C, C.a * (1.0 - a));
    }

    return O;
}
