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
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;

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

    // -- bloom : 2nd pass + apply it -- //
    #if BLOOM_TYPE == 1
        vec3 bloom = doBlur(uv, colortex4, BLOOM_OLD_RANGE, BLOOM_OLD_RESOLUTION, BLOOM_OLD_STD, BLOOM_OLD_KERNEL == 1, false);
    #elif BLOOM_TYPE == 2
        vec4 bloom = doBloom(uv, colortex4, false);
        // classic bloom
        bloom.rgb = pow(bloom.rgb, 1.0 / vec3(1.75));
        // sun bloom
        bloom.rgb += vec3(1.0, 0.5, 0.125) * pow(bloom.a, 1.0 / 1.5);
    #endif
    #if BLOOM_TYPE > 0
        color += bloom.rgb * BLOOM_FACTOR;
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
