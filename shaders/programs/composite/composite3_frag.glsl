#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"
#include "/lib/bloom.glsl"
#if TAA_TYPE > 0
    #include "/lib/TAA.glsl"
#endif

// mipmap bloom
#if BLOOM_TYPE > 1
    const bool colortex1MipmapEnabled = true;
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D colortex1; // bloom
uniform sampler2D depthtex0; // depth all
#if TAA_TYPE > 0
    uniform sampler2D colortex3; // TAA - last frame color
#endif
#if TAA_TYPE == 1
    uniform sampler2D colortex4; // TAA - last frame depth
#endif

// attributes
in vec2 uv;

// results
#if TAA_TYPE == 0
    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 colorData;
#elif TAA_TYPE == 1
    /* RENDERTARGETS: 0,3,4 */
    layout(location = 0) out vec4 colorData;
    layout(location = 1) out vec3 taaColorData;
    layout(location = 2) out float taaDepthData;
#else
    /* RENDERTARGETS: 0,3 */
    layout(location = 0) out vec4 colorData;
    layout(location = 1) out vec3 taaColorData;
#endif

/*******************************************/
/*************** bloom + TAA ***************/
/*******************************************/
void main() {

    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);

    // -- temporal anti aliasing -- //
    #if TAA_TYPE > 0
        float depth = texture2D(depthtex0, uv).r;
        #if TAA_TYPE == 1
            color = doTAA(uv, depth, color, colortex0, colortex3, colortex4, taaColorData, taaDepthData);
        #else
            color = doTAA(uv, depth, color, colortex0, colortex3, taaColorData);
        #endif
    #endif
    // wild effect
    // {
    //     vec4 taaData = texture2D(colortex3, uv);
    //     vec3 previousColor = SRGBtoLinear(taaData.rgb);
    //     color = mix(color, previousColor, 0.92);
    // }

    // -- apply bloom -- //
    #if BLOOM_TYPE > 0
        vec3 bloom = SRGBtoLinear(texture2D(colortex1, uv).rgb);
        #if BLOOM_TYPE == 2
            bloom = pow(bloom, 1.0 / vec3(1.75));
        #endif
        color += bloom * BLOOM_FACTOR;
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
