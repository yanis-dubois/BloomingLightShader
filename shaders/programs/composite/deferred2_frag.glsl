#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#if REFLECTION_TYPE > 1
    #include "/lib/blur.glsl"
#endif

// textures
uniform sampler2D colortex0; // color
uniform sampler2D depthtex0; // all depth
#if REFLECTION_TYPE > 0
    uniform sampler2D colortex4; // opaque reflection
#endif

in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;

#if REFLECTION_TYPE > 0
    /* RENDERTARGETS: 0,4 */
    layout(location = 1) out vec4 colorDeferredData;
#endif

/**********************************************/
/* opaque material reflection blur : 2nd pass */
/**********************************************/
void main() {

    // retrieve data
    vec3 color = SRGBtoLinear(texture2D(colortex0, uv).rgb);
    float depth = texture2D(depthtex0, uv).r;

    // -- reflection -- //
    #if REFLECTION_TYPE > 0
        vec4 reflection = texture2D(colortex4, uv);
        reflection.rgb = SRGBtoLinear(reflection.rgb);

        // blur 2nd pass
        #if REFLECTION_TYPE > 1 && REFLECTION_BLUR_TYPE > 0
            reflection.rgb = doBlur(uv, colortex4, REFLECTION_BLUR_RANGE, REFLECTION_BLUR_RESOLUTION, REFLECTION_BLUR_STD, REFLECTION_BLUR_KERNEL==1, REFLECTION_BLUR_DITHERING_TYPE, false);
        #endif

        // apply fog on reflection visibility
        vec3 worldSpacePosition = screenToWorld(uv, depth);
        reflection.a = min(reflection.a, 1.0 - getFogFactor(worldSpacePosition));

        // apply reflection
        color = mix(color, reflection.rgb, reflection.a);
    #endif

    #ifdef NETHER
        if (depth == 1.0) {
            #if REFLECTION_TYPE == 0
                vec3 worldSpacePosition = screenToWorld(uv, depthAll);
            #endif
            float _;
            foggify(worldSpacePosition, color, _);
        }
    #endif

    // gamma correct
    color = linearToSRGB(color);

    // write buffer
    colorData = vec4(color, 1.0);
    #if REFLECTION_TYPE > 0
        colorDeferredData = vec4(color, 0.0);
    #endif
}
