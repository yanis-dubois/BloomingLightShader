#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/depth_of_field.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex1; // opaque far plane
uniform sampler2D colortex4; // transparent color
uniform sampler2D colortex5; // transparent far plane

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 transparentColorData;

void process(sampler2D colorTexture, sampler2D DOFTexture,
            out vec4 colorData) {

    // init buffer (keep alpha value for transparent layer)
    colorData = texture2D(colorTexture, uv);

    // -- depth of field -- //
    vec4 DOFData = vec4(0); // useless in second pass
    vec3 DOF = depthOfField(uv, colorTexture, DOFTexture, DOF_RANGE, DOF_SAMPLES, DOF_STD, DOF_KERNEL == 1, false, DOFData);
    colorData.rgb = linearToSRGB(DOF);
}

/*****************************************
************* Depth of field *************
*****************************************/
void main() {
    #if DOF_TYPE == 0
        opaqueColorData = texture2D(colortex0, uv);
        transparentColorData = texture2D(colortex4, uv);
    #else
        process(colortex0, colortex1, opaqueColorData);
        process(colortex4, colortex5, transparentColorData);
    #endif
}
