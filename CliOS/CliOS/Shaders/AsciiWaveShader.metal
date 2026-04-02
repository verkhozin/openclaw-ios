#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

static float aw_noise(float2 p, float time) {
    return sin(p.x * 10.0) * sin(p.y * (3.0 + sin(time / 11.0))) + 0.2;
}

static float2x2 aw_rotate(float angle) {
    float c = cos(angle), s = sin(angle);
    return float2x2(float2(c, -s), float2(s, c));
}

static float aw_fbm(float2 p, float time) {
    p *= 1.1;
    float f = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        float2x2 modify = aw_rotate(time / 50.0 * float(i * i));
        f += amp * aw_noise(p, time);
        p = modify * p;
        p *= 2.0;
        amp /= 2.2;
    }
    return f;
}

static float aw_pattern(float2 p, float time, thread float2 &q, thread float2 &r) {
    q = float2(aw_fbm(p + float2(1.0), time),
               aw_fbm(aw_rotate(0.1 * time) * p + float2(1.0), time));
    r = float2(aw_fbm(aw_rotate(0.1) * q + float2(0.0), time),
               aw_fbm(q + float2(0.0), time));
    return aw_fbm(p + 1.0 * r, time);
}

static float aw_digit(float2 p, float time) {
    float2 grid = float2(3.0, 1.0) * 15.0;
    float2 s = floor(p * grid) / grid;
    p = p * grid;
    float2 q, r;
    float intensity = aw_pattern(s / 10.0, time, q, r) * 1.3 - 0.03;
    p = fract(p);
    p *= float2(1.2, 1.2);
    float x = fract(p.x * 5.0);
    float y = fract((1.0 - p.y) * 5.0);
    int i = int(floor((1.0 - p.y) * 5.0));
    int j = int(floor(p.x * 5.0));
    int n = (i - 2) * (i - 2) + (j - 2) * (j - 2);
    float f = float(n) / 16.0;
    float isOn = intensity - f > 0.1 ? 1.0 : 0.0;
    return (p.x <= 1.0 && p.y <= 1.0) ? isOn * (0.2 + y * 4.0 / 5.0) * (0.75 + x / 4.0) : 0.0;
}

static float aw_onOff(float a, float b, float c, float iTime) {
    return step(c, sin(iTime + a * cos(iTime * b)));
}

static float aw_displace(float2 look, float iTime) {
    float y = (look.y - fmod(iTime / 4.0, 1.0));
    float window = 1.0 / (1.0 + 50.0 * y * y);
    return sin(look.y * 20.0 + iTime) / 80.0 * aw_onOff(4.0, 2.0, 0.8, iTime) * (1.0 + cos(iTime * 60.0)) * window;
}

static float3 aw_getColor(float2 p, float time, float iTime) {
    float bar = fmod(p.y + time * 20.0, 1.0) < 0.2 ? 1.4 : 1.0;
    p.x += aw_displace(p, iTime);
    float middle = aw_digit(p, time);
    float off = 0.002;
    float sum = 0.0;
    for (float i = -1.0; i < 2.0; i += 1.0) {
        for (float j = -1.0; j < 2.0; j += 1.0) {
            sum += aw_digit(p + float2(off * i, off * j), time);
        }
    }
    return float3(0.9) * middle + sum / 10.0 * float3(0.0, 1.0, 0.0) * bar;
}

fragment float4 asciiWaveFragment(VertexOut in [[stage_in]],
                                  constant ShaderUniforms &u [[buffer(0)]]) {
    float iTime = u.time;
    float time = iTime / 3.0;
    float2 p = in.uv;
    float3 col = aw_getColor(p, time, iTime);
    return float4(col, 1.0);
}
