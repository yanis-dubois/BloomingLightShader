#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/bloom.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex2; // opaque color * emissivness
uniform sampler2D colortex4; // transparent color
uniform sampler2D colortex6; // transparent color * emissivness
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth
uniform sampler2D depthtex2; // only opaque depth and no hand

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 transparentColorData;

void process(sampler2D colorTexture, sampler2D bloomTexture,
            out vec4 colorData, bool isTransparent) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(colorTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    vec4 bloomData  = vec4(0);

    #if BLOOM_TYPE == 3
        // 2nd pass blur to bloom texture
        bloomData = blur(uv, bloomTexture, BLOOM_RANGE, BLOOM_SAMPLES, BLOOM_STD, BLOOM_KERNEL == 1, false);
    #endif

    /* bloom */
    bloomData = bloom(uv, bloomTexture, bloomData);
    color += bloomData.rgb * BLOOM_FACTOR;

    if (isTransparent && length(bloomData.rgb) > 0.001 && transparency < 0.1)
        opaqueColorData.rgb = linearToSRGB(SRGBtoLinear(opaqueColorData.rgb) + bloomData.rgb * BLOOM_FACTOR);
    else
        colorData.rgb = linearToSRGB(color);
}

/******************************************
****************** Bloom ******************
*******************************************/
void main() {
    process(colortex0, colortex2, opaqueColorData, false);
    process(colortex4, colortex6, transparentColorData, true);

    //opaqueColorData = texture2D(colortex2, uv);
}
