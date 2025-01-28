#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/blur.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex4; // transparent color

// attributes
in vec2 uv;

// Bayer matrix for dithering (4x4)
const mat4 bayerMatrix = mat4(
    0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
    3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);

// results
/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 transparentColorData;

void process(sampler2D colorTexture,
            out vec4 colorData, bool isTransparent) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(colorTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    // -- dithering -- //

    // get Bayer matrix value
    ivec2 pixelPos = ivec2(gl_FragCoord.xy) % 4;
    float threshold = (bayerMatrix[pixelPos.x][pixelPos.y] + 0.5) / 16.0;

    // color quantization
    float quantization = QUANTIZATION_AMOUNT;
    vec3 quantizedColor = floor(color * quantization) / quantization; // Reduce to 'quantization' levels per channel
    
    // dithering
    #if QUANTIZATION_TYPE == 2
        quantizedColor = mix(quantizedColor, quantizedColor + 1.0 / quantization, step(threshold, fract(color * quantization)));
    #endif

    quantizedColor = linearToSRGB(quantizedColor);
    colorData = vec4(quantizedColor, transparency);
}

/******************************************
**************** Dithering ****************
*******************************************/
void main() {
    #if QUANTIZATION_TYPE > 0
        process(colortex0, opaqueColorData, false);
        process(colortex4, transparentColorData, true);
    #else
        opaqueColorData = texture2D(colortex0, uv);
        transparentColorData = texture2D(colortex4, uv);
    #endif
}
