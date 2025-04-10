#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#if TAA_TYPE > 0
    #include "/lib/TAA.glsl"
#endif

// textures
uniform sampler2D colortex0; // color
#if TAA_TYPE > 0
    uniform sampler2D depthtex1; // depth opaque
    uniform sampler2D colortex2; // TAA - last frame color
#endif
#if TAA_TYPE == 1
    uniform sampler2D colortex3; // TAA - last frame depth
#endif

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;   
#if TAA_TYPE == 2
    /* RENDERTARGETS: 0,2 */
    layout(location = 1) out vec3 taaColorData;
#else
    /* RENDERTARGETS: 0,2,3 */
    layout(location = 2) out float taaDepthData;
#endif

/*******************************************/
/******************* TAA *******************/
/*******************************************/
void main() {

    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);

    // -- temporal anti aliasing -- //
    #if TAA_TYPE > 0
        float depth = texture2D(depthtex1, uv).r;
        #if TAA_TYPE == 1
            color = doTAA(uv, depth, color, colortex0, colortex2, colortex3, taaColorData, taaDepthData);
        #else
            color = doTAA(uv, depth, color, colortex0, colortex2, taaColorData);
        #endif
    #endif
    // wild effect
    // {
    //     vec4 taaData = texture2D(colortex2, uv);
    //     vec3 previousColor = SRGBtoLinear(taaData.rgb);
    //     color = mix(color, previousColor, 0.7);
    //     taaColorData = linearToSRGB(color);
    // }

    colorData = vec4(linearToSRGB(color), 1.0);
}
