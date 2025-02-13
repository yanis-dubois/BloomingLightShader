#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/depth_of_field.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex1; // opaque color * emissivness
uniform sampler2D colortex2; // opaque DOF
uniform sampler2D colortex4; // transparent color
uniform sampler2D colortex5; // transparent color * emissivness
uniform sampler2D colortex6; // transparent DOF

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 transparentColorData;

void process(sampler2D colorTexture, sampler2D bloomTexture, sampler2D DOFTexture,
            out vec4 colorData, bool isTransparent) {

    // -- get input buffer values & init output buffers -- //
    colorData = texture2D(colorTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    // -- depth of field -- //
    #if DOF_TYPE == 1
        vec4 DOFData = vec4(0); // useless in second pass
        vec3 DOF = depthOfField(uv, colorTexture, DOFTexture, DOF_RANGE, DOF_RESOLUTION, DOF_STD, DOF_KERNEL == 1, false, DOFData);
        color = DOF;
        colorData.rgb = linearToSRGB(color);
    #endif

    // -- bloom -- //
    #if BLOOM_TYPE == 1
        // 2nd pass blur for bloom texture
        vec4 bloomData = blur(uv, bloomTexture, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        // apply bloom
        color += clamp(bloomData.rgb * BLOOM_FACTOR, 0.0, 1.0);
        if (isTransparent && length(bloomData.rgb) > 0.001 && transparency < 0.1)
            opaqueColorData.rgb = linearToSRGB(SRGBtoLinear(opaqueColorData.rgb) + bloomData.rgb * BLOOM_FACTOR);
        else
            colorData.rgb = linearToSRGB(color);
    #endif
}

/*******************************************
********** Bloom & Depth of field **********
*******************************************/
void main() {
    process(colortex0, colortex1, colortex2, opaqueColorData, false);
    process(colortex4, colortex5, colortex6, transparentColorData, true);
}
