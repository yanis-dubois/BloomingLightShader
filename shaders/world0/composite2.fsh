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
/* RENDERTARGETS: 0,1,2,4,5,6 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueBloomData;
layout(location = 2) out vec4 opaqueDOFData;
layout(location = 3) out vec4 transparentColorData;
layout(location = 4) out vec4 transparentBloomData;
layout(location = 5) out vec4 transparentDOFData;

void process(sampler2D colorTexture, sampler2D bloomTexture, sampler2D DOFTexture,
            out vec4 colorData, out vec4 bloomData, out vec4 DOFData) {

    // init buffer (keep alpha value for transparent layer)
    colorData = texture2D(colorTexture, uv);

    // -- depth of field -- //
    // apply dof
    #if DOF_TYPE == 1
        vec3 DOF = depthOfField(uv, colorTexture, DOFTexture, DOF_RANGE, DOF_RESOLUTION, DOF_STD, DOF_KERNEL == 1, true, DOFData);
        colorData.rgb = linearToSRGB(DOF);
    #endif

    // -- bloom -- //
    #if BLOOM_TYPE > 0
        bloomData = texture2D(bloomTexture, uv);
        #if BLOOM_TYPE < 3
            return;
        #else
            // 1st pass blur to bloom texture
            bloomData = blur(uv, bloomTexture, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, true);
            bloomData.rgb = linearToSRGB(bloomData.rgb);
        #endif
    #endif
}

/*******************************************
********** Bloom & Depth of field **********
*******************************************/
void main() {
    process(colortex0, colortex1, colortex2, opaqueColorData, opaqueBloomData, opaqueDOFData);
    process(colortex4, colortex5, colortex6, transparentColorData, transparentBloomData, transparentDOFData);
}
