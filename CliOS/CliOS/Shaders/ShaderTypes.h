#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

struct ShaderUniforms {
    float time;
    simd_float2 resolution;
    simd_float3 tintColor;
};

#endif
