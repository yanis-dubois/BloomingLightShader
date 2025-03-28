#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"

#if REFLECTION_TYPE == 0
    void main() {}

#else
    #include "/lib/utils.glsl"
    #if REFLECTION_TYPE > 1
        #include "/lib/blur.glsl"
    #endif

    // textures
    uniform sampler2D colortex4; // opaque reflection

    in vec2 uv;

    // results
    /* RENDERTARGETS: 4 */
    layout(location = 0) out vec4 reflectionData;

    /**********************************************/
    /* opaque material reflection blur : 1st pass */
    /**********************************************/
    void main() {

        // retrieve data
        vec4 reflection = texture2D(colortex4, uv);

        #if REFLECTION_TYPE > 1
            // blur 1st pass
            reflection.rgb = doBlur(uv, colortex4, REFLECTION_BLUR_RANGE, REFLECTION_BLUR_RESOLUTION, REFLECTION_BLUR_STD, REFLECTION_BLUR_KERNEL==1, true);

            // gamma correct
            reflection.rgb = linearToSRGB(reflection.rgb);
        #endif

        // write buffer
        reflectionData = vec4(reflection);
    }
#endif
