#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// --- ASCII Plasma (VT220 bitmap font + plasma wave) ---

constant float2 AP_FONT = float2(10.0, 20.0);
constant float2 AP_GRID = float2(80.0, 24.0);
constant float4 AP_GREEN = float4(0.2, 1.0, 0.2, 1.0);

static float ap_rand(float2 co) {
    return fract(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
}

static float ap_plasma(float2 uv, float2 res, float t) {
    uv /= res;
    uv *= AP_GRID;
    uv = ceil(uv);
    uv /= AP_GRID;

    float c = 0.0;
    c += 0.7  * sin(0.5  * uv.x + t / 5.0);
    c += 3.0  * sin(1.6  * uv.y + t / 5.0);
    c += 1.0  * sin(10.0 * (uv.y * sin(t / 2.0) + uv.x * cos(t / 5.0)) + t / 2.0);
    float cx = uv.x + 0.5 * sin(t / 2.0);
    float cy = uv.y + 0.5 * cos(t / 4.0);
    c += 0.4  * sin(sqrt(100.0 * cx * cx + 100.0 * cy * cy + 1.0) + t);
    c += 0.9  * sin(sqrt( 75.0 * cx * cx +  25.0 * cy * cy + 1.0) + t);
    c += -1.4 * sin(sqrt(256.0 * cx * cx +  25.0 * cy * cy + 1.0) + t);
    c += 0.3  * sin(0.5 * uv.y + uv.x + sin(t));
    return 17.0 * (0.5 + 0.499 * sin(c)) * (0.7 + sin(t) * 0.3);
}

// Line segment distance for font rendering
static float ap_line(float2 p, float2 a, float2 b) {
    b -= a + float2(1.0, 0.0);
    p -= a;
    float f = length(p - clamp(dot(p, b) / dot(b, b), 0.0, 1.0) * b);
    return smoothstep(0.75, 0.5, f);
}

#define AL(y,a,b) ap_line(p, float2(float(a), float(y)), float2(float(b), float(y)))

static float ap_font(float2 p, float c) {
    if (c < 1.0) return 0.0;
    if (p.y > 16.0) {
        if (c > 2.0) return 0.0;
        if (c > 1.0) return AL(17,1,9);
    }
    if (p.y > 14.0) {
        if (c > 16.0) return AL(15,3,8);
        if (c > 15.0) return AL(15,1,8);
        if (c > 14.0) return AL(15,1,3) + AL(15,7,9);
        if (c > 13.0) return AL(15,2,8);
        if (c > 12.0) return AL(15,1,9);
        if (c > 11.0) return AL(15,2,8);
        if (c > 10.0) return AL(15,1,3) + AL(15,6,8);
        if (c >  9.0) return AL(15,4,6);
        if (c >  8.0) return AL(15,2,4) + AL(15,5,7);
        if (c >  7.0) return AL(15,2,8);
        if (c >  6.0) return AL(15,2,8);
        if (c >  5.0) return AL(15,2,8);
        if (c >  4.0) return AL(15,2,9);
        if (c >  3.0) return AL(15,1,8);
        if (c >  2.0) return AL(15,2,9);
    }
    if (p.y > 12.0) {
        if (c > 16.0) return AL(13,2,4) + AL(13,7,9);
        if (c > 15.0) return AL(13,2,4) + AL(13,7,9);
        if (c > 14.0) return AL(13,1,3) + AL(13,7,9);
        if (c > 13.0) return AL(13,1,3) + AL(13,7,9);
        if (c > 12.0) return AL(13,1,3);
        if (c > 11.0) return AL(13,4,6);
        if (c > 10.0) return AL(13,2,4) + AL(13,5,9);
        if (c >  9.0) return AL(13,2,8);
        if (c >  8.0) return AL(13,2,4) + AL(13,5,7);
        if (c >  7.0) return AL(13,1,3) + AL(13,7,9);
        if (c >  6.0) return AL(13,1,3) + AL(13,7,9);
        if (c >  5.0) return AL(13,1,3) + AL(13,7,9);
        if (c >  4.0) return AL(13,1,3) + AL(15,2,9);
        if (c >  3.0) return AL(13,1,4) + AL(13,7,9);
        if (c >  2.0) return AL(13,1,3) + AL(13,6,9);
    }
    if (p.y > 10.0) {
        if (c > 16.0) return AL(11,1,3);
        if (c > 15.0) return AL(11,2,4) + AL(11,7,9);
        if (c > 14.0) return AL(11,1,9);
        if (c > 13.0) return AL(11,7,9);
        if (c > 12.0) return AL(11,2,5);
        if (c > 11.0) return AL(11,4,6);
        if (c > 10.0) return AL(11,3,5) + AL(11,6,8);
        if (c >  9.0) return AL(11,4,6) + AL(11,7,9);
        if (c >  8.0) return AL(11,1,8);
        if (c >  7.0) return AL(11,1,3) + AL(11,7,9);
        if (c >  6.0) return AL(11,1,3) + AL(11,7,9);
        if (c >  5.0) return AL(11,1,3) + AL(11,7,9);
        if (c >  4.0) return AL(11,1,3);
        if (c >  3.0) return AL(11,1,3) + AL(11,7,9);
        if (c >  2.0) return AL(11,2,9);
    }
    if (p.y > 8.0) {
        if (c > 16.0) return AL(9,1,3);
        if (c > 15.0) return AL(9,2,8);
        if (c > 14.0) return AL(9,1,3) + AL(9,7,9);
        if (c > 13.0) return AL(9,4,8);
        if (c > 12.0) return AL(9,4,8);
        if (c > 11.0) return AL(9,4,6);
        if (c > 10.0) return AL(9,4,6);
        if (c >  9.0) return AL(9,2,8);
        if (c >  8.0) return AL(9,2,4) + AL(9,5,7);
        if (c >  7.0) return AL(9,1,3) + AL(9,7,9);
        if (c >  6.0) return AL(9,1,3) + AL(9,7,9);
        if (c >  5.0) return AL(9,1,3) + AL(9,7,9);
        if (c >  4.0) return AL(9,1,3) + AL(9,7,9);
        if (c >  3.0) return AL(9,1,4) + AL(9,7,9);
        if (c >  2.0) return AL(9,7,9);
    }
    if (p.y > 6.0) {
        if (c > 16.0) return AL(7,1,3);
        if (c > 15.0) return AL(7,2,4) + AL(7,7,9);
        if (c > 14.0) return AL(7,2,4) + AL(7,6,8);
        if (c > 13.0) return AL(7,5,7);
        if (c > 12.0) return AL(7,7,9);
        if (c > 11.0) return AL(7,2,6);
        if (c > 10.0) return AL(7,2,4) + AL(7,5,7);
        if (c >  9.0) return AL(7,1,3) + AL(7,4,6);
        if (c >  8.0) return AL(7,1,8);
        if (c >  7.0) return AL(7,2,8);
        if (c >  6.0) return AL(7,2,8);
        if (c >  5.0) return AL(7,2,8);
        if (c >  4.0) return AL(7,2,8);
        if (c >  3.0) return AL(7,1,8);
        if (c >  2.0) return AL(7,2,8);
    }
    if (p.y > 4.0) {
        if (c > 16.0) return AL(5,2,4) + AL(5,7,9);
        if (c > 15.0) return AL(5,2,4) + AL(5,7,9);
        if (c > 14.0) return AL(5,3,7);
        if (c > 13.0) return AL(5,6,8);
        if (c > 12.0) return AL(5,1,3) + AL(5,7,9);
        if (c > 11.0) return AL(5,3,6);
        if (c > 10.0) return AL(5,1,5) + AL(5,6,8);
        if (c >  9.0) return AL(5,2,8);
        if (c >  8.0) return AL(5,2,4) + AL(5,5,7);
        if (c >  7.0) return 0.0;
        if (c >  6.0) return 0.0;
        if (c >  5.0) return 0.0;
        if (c >  4.0) return 0.0;
        if (c >  3.0) return AL(5,1,3);
        if (c >  2.0) return 0.0;
    }
    if (p.y > 2.0) {
        if (c > 16.0) return AL(3,3,8);
        if (c > 15.0) return AL(3,1,8);
        if (c > 14.0) return AL(3,4,6);
        if (c > 13.0) return AL(3,1,9);
        if (c > 12.0) return AL(3,2,8);
        if (c > 11.0) return AL(3,4,6);
        if (c > 10.0) return AL(3,2,4) + AL(3,7,9);
        if (c >  9.0) return AL(3,4,6);
        if (c >  8.0) return AL(3,2,4) + AL(3,5,7);
        if (c >  7.0) return AL(3,2,4) + AL(3,6,8);
        if (c >  6.0) return AL(3,1,3) + AL(3,4,7);
        if (c >  5.0) return AL(3,2,4) + AL(3,6,8);
        if (c >  4.0) return 0.0;
        if (c >  3.0) return AL(3,1,3);
        if (c >  2.0) return 0.0;
    } else {
        if (c > 7.0) return 0.0;
        if (c > 6.0) return AL(1,2,5) + AL(1,6,8);
    }
    return 0.0;
}

fragment float4 asciiPlasmaFragment(VertexOut in [[stage_in]],
                                    constant ShaderUniforms &u [[buffer(0)]]) {
    float iTime = u.time;
    float2 res = u.resolution;
    float2 fragCoord = float2(in.uv.x * res.x, (1.0 - in.uv.y) * res.y);

    float2 uv = float2(fragCoord.x, res.y - fragCoord.y);
    float2 uvT = AP_GRID * AP_FONT * uv / res;
    float2 uvG = floor(AP_GRID * uv / res);

    float val = ap_plasma(fragCoord, res, iTime);
    float glyph = ap_font(uvT - uvG * AP_FONT, val);
    return glyph * AP_GREEN;
}
