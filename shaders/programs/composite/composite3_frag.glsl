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
    const bool colortex1MipmapEnabled = true;
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // bloom
uniform sampler2D colortex5; // depth of field

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec3 bloomData;

/*******************************************/
/**** bloom & depth of field : 2nd pass ****/
/*******************************************/
void main() {

    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);

    // -- depth of field : 2nd pass + apply it -- //
    #if DOF_TYPE > 0
        vec4 depthOfFieldData = vec4(0.0);
        vec3 DOF = doDepthOfField(uv, colortex0, colortex5, DOF_RANGE, DOF_RESOLUTION, DOF_STD, DOF_KERNEL == 1, false, depthOfFieldData);
        color = DOF;
    #endif

    // -- bloom : 2nd pass -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = doBlur(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        bloomData = linearToSRGB(bloom);
    #elif BLOOM_TYPE == 2
        vec3 bloom = doBloom(uv, colortex1, BLOOM_RANGE, BLOOM_RESOLUTION, BLOOM_STD, BLOOM_KERNEL == 1, false);
        bloomData = linearToSRGB(bloom);
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
