#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/animation.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex4; // transparent color
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth
uniform sampler2D depthtex2; // only opaque depth and no hand

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
    
    vec2 UV = uv;

    // -- distortion -- //
    #if UNDERWATER_DISTORTION > 0
        if (isEyeInWater == 1) {
            float depth = texture2D(depthtex0, uv).r;
            vec3 eyeSpaceDirection = normalize(viewToEye(screenToView(uv, depth)));
            UV = uv + doScreenDistortion(frameTimeCounter, uv, eyeSpaceDirection);
        }
    #endif

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(colorTexture, UV);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    // -- chromatic aberation -- //
    #if CHROMATIC_ABERATION_TYPE > 0
        float dist = distance(uv * 2 - 1, vec2(0));
        float amplitude = CHROMATIC_ABERATION_AMPLITUDE * dist * dist;
        vec2 offsetR = vec2(0.1, 0.0) * amplitude;
        vec2 offsetG = vec2(-0.05, -0.05) * amplitude;
        vec2 offsetB = vec2(-0.05, 0.05) * amplitude;
        float R = texture2D(colorTexture, UV + offsetR).r;
        float G = texture2D(colorTexture, UV + offsetG).g;
        float B = texture2D(colorTexture, UV + offsetB).b;
        color = vec3(R,G,B);
        color = SRGBtoLinear(color);
    #endif

    // -- quantization & dithering -- //
    #if QUANTIZATION_TYPE > 0
        // get Bayer matrix value
        ivec2 pixelPos = ivec2(gl_FragCoord.xy) % 4;
        float threshold = (bayerMatrix[pixelPos.x][pixelPos.y] + 0.5) / 16.0;

        // quantization
        float quantization = QUANTIZATION_AMOUNT;
        vec3 quantizedColor = floor(color * quantization) / quantization; // Reduce to 'quantization' levels per channel
        
        // dithering
        #if QUANTIZATION_TYPE == 2
            quantizedColor = mix(quantizedColor, quantizedColor + 1.0 / quantization, step(threshold, fract(color * quantization)));
        #endif

        color = quantizedColor;
    #endif

    color = linearToSRGB(color);
    colorData = vec4(color, transparency);
}

/******************************************
*************** Wild effect ***************
*******************************************/
void main() {
    process(colortex0, opaqueColorData, false);
    process(colortex4, transparentColorData, true);
}
