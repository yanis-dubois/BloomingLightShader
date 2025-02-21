#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/depth_of_field.glsl"

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // bloom
uniform sampler2D colortex2; // depth of field
uniform sampler2D colortex3; // TAA

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 bloomData;
layout(location = 2) out vec4 depthOfFieldData;

/*******************************************/
/**** bloom & depth of field : 1st pass ****/
/*******************************************/
void main() {
    // -- depth of field -- //
    #if DOF_TYPE > 0
        vec3 DOF = depthOfField(uv, colortex0, colortex2, DOF_RANGE, DOF_RESOLUTION, DOF_STD, DOF_KERNEL == 1, true, depthOfFieldData);
        colorData = vec4(linearToSRGB(DOF), 1.0);
    #else
        colorData = texture2D(colortex0, uv);
    #endif

    // -- bloom -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = blur(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, true);
        bloomData = vec4(linearToSRGB(bloom), 1.0);
    #elif BLOOM_TYPE == 2
        bloomData = texture2D(colortex1, uv);
    #endif
}
