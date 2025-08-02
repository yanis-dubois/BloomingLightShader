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
#if TAA_TYPE > 0 || STATUS_STARVING_TYPE > 0
    uniform sampler2D colortex2; // TAA - last frame color
#endif
#if TAA_TYPE > 0
    uniform sampler2D depthtex1; // depth opaque
#endif
#if TAA_TYPE == 1
    uniform sampler2D colortex3; // TAA - last frame depth
#endif

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;   
#if TAA_TYPE > 0 || STATUS_STARVING_TYPE > 0
    /* RENDERTARGETS: 0,2 */
    layout(location = 1) out vec3 taaColorData;
#endif
#if TAA_TYPE == 1
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

    // -- starving effect (constrast & motion blur) -- //
    #if STATUS_STARVING_TYPE > 0
        float starvingFactor = 1.0 - abs(currentPlayerHunger);
        // increase contrast
        float contrastFactor = map(starvingFactor, 0.5, 1.0, 0.0, 1.0);
        color = mix(color, smoothstep(0.0, 0.8, color), contrastFactor);
        // motion blur
        if (starvingFactor >= 0.7) {
            float motionBlurFactor = map(starvingFactor, 0.7, 1.0, 0.5, 0.7);

            vec4 taaData = texture2D(colortex2, uv);
            vec3 previousColor = SRGBtoLinear(taaData.rgb);
            color = mix(color, previousColor, motionBlurFactor);

            taaColorData = linearToSRGB(color);
        }
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
