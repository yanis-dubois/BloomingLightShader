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

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,1,4,5 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueDOFData;
layout(location = 2) out vec4 transparentColorData;
layout(location = 3) out vec4 transparentDOFData;

void process(sampler2D colorTexture, sampler2D bloomTexture, sampler2D depthTexture,
            out vec4 colorData, out vec4 DOFData, bool isTransparent) {

    // -- get input buffer values & init output buffers -- //
    colorData = texture2D(colorTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    vec4 bloomData  = vec4(0);
    // 2nd pass blur to bloom texture
    #if BLOOM_TYPE == 3
        bloomData = blur(uv, bloomTexture, BLOOM_RANGE, BLOOM_SAMPLES, BLOOM_STD, BLOOM_KERNEL == 1, false);
    #endif

    // -- bloom -- //
    bloomData = bloom(uv, bloomTexture, bloomData);
    color += bloomData.rgb * BLOOM_FACTOR;

    if (isTransparent && length(bloomData.rgb) > 0.001 && transparency < 0.1)
        opaqueColorData.rgb = linearToSRGB(SRGBtoLinear(opaqueColorData.rgb) + bloomData.rgb * BLOOM_FACTOR);
    else
        colorData.rgb = linearToSRGB(color);

    // -- prepare depth of field -- //
    // focal plane distance
    float focusDepth = texture2D(depthtex1, vec2(0.5)).r;
    vec3 playerSpaceFocusPosition = screenToPlayer(vec2(0.5), focusDepth);
    float focusDistance = length(playerSpaceFocusPosition);
    focusDistance = min(focusDistance, far);
    // actual distance
    float depth = texture2D(depthTexture, uv).r;
    vec3 playerSpacePosition = screenToPlayer(uv, depth);
    float linearDepth = length(playerSpacePosition);
    // blur amount
    float blurFactor = 0;
    if (focusDepth == 1.0) {
        blurFactor = depth < 1.0 ? 1.0 : 0.0;
    }
    else if (depth == 1.0) {
        blurFactor = 1.0;
    }
    else {
        float diff = abs(linearDepth - focusDistance);
        blurFactor = diff < DOF_FOCAL_PLANE_LENGTH ? 0.0 : 1.0;
        blurFactor *= map(diff, DOF_FOCAL_PLANE_LENGTH, 2*DOF_FOCAL_PLANE_LENGTH, 0.0, 1.0);
    }
    // write buffer
    DOFData = vec4(vec3(0.0), 1.0);
    if (blurFactor > 0.0) {
        // near plane
        if (linearDepth < focusDistance) {
            DOFData.rgb = vec3(1.0, 0.0, blurFactor);
        }
        // far plane
        else if (linearDepth > focusDistance) {
            DOFData.rgb = vec3(0.0, 1.0, blurFactor);
        }
    }
}

/******************************************
****************** Bloom ******************
*******************************************/
void main() {
    process(colortex0, colortex2, depthtex1, opaqueColorData, opaqueDOFData, false);
    process(colortex4, colortex6, depthtex0, transparentColorData, transparentDOFData, true);
}
