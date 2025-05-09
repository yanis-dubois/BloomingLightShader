#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/bloom.glsl"
#include "/lib/depth_of_field.glsl"

// mipmap bloom
#if BLOOM_TYPE > 1
    const bool colortex4MipmapEnabled = true;
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex4; // bloom
uniform sampler2D colortex5; // depth of field

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,4,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 bloomData;
layout(location = 2) out vec4 depthOfFieldData;

/*******************************************/
/**** bloom & depth of field : 1st pass ****/
/*******************************************/
void main() {
    // -- depth of field : 1st pass -- //
    #if DOF_TYPE > 0
        vec3 DOF = doDepthOfField(uv, colortex0, colortex5, DOF_RANGE, DOF_RESOLUTION, DOF_STD, DOF_KERNEL == 1, true, depthOfFieldData);
        colorData = vec4(linearToSRGB(DOF), 1.0);
    #else
        colorData = texture2D(colortex0, uv);
    #endif

    // -- bloom : 1st pass -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = doBlur(uv, colortex4, BLOOM_OLD_RANGE, BLOOM_OLD_RESOLUTION, BLOOM_OLD_STD, BLOOM_OLD_KERNEL == 1, true);
        bloomData = vec4(linearToSRGB(bloom.rgb), 0.0);
    #elif BLOOM_TYPE == 2
        vec4 bloom = doBloom(uv, colortex4, true);
        bloomData = vec4(linearToSRGB(bloom.rgb), bloom.a);
    #endif
}
