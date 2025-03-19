
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/animation.glsl"

// textures
uniform sampler2D colortex0; // color
uniform sampler2D depthtex0; // all depth

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
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;

/******************************************/
/************** wild effects **************/
/******************************************/
void main() {
    vec2 UV = uv;

    // -- water refraction -- //
    #if DISTORTION_WATER_REFRACTION > 0
        if (isEyeInWater == 1) {
            float depth = texture2D(depthtex0, uv).r;
            vec3 eyeSpaceDirection = normalize(viewToEye(screenToView(uv, depth)));
            UV = uv + doWaterRefraction(frameTimeCounter, uv, eyeSpaceDirection);
        }
    #endif

    // -- chromatic aberation -- //
    #if CHROMATIC_ABERATION_TYPE > 0
        // direction & amplitude
        vec2 direction = (uv * 2 - 1);
        float dist = length(direction);
        direction = normalize(direction);
        float amplitude = CHROMATIC_ABERATION_AMPLITUDE * dist*dist;

        // respective offets
        vec2 offsetR = - direction * amplitude;
        vec2 offsetG = vec2(0);
        vec2 offsetB = direction * amplitude;

        // get respective values
        float R = texture2D(colortex0, UV + offsetR).r;
        float G = texture2D(colortex0, UV + offsetG).g;
        float B = texture2D(colortex0, UV + offsetB).b;
        vec3 color = SRGBtoLinear(vec3(R,G,B));

    // -- get input buffer values -- //
    #else
        vec3 color = SRGBtoLinear(texture2D(colortex0, UV).rgb);
    #endif

    // -- quantization & dithering -- //
    #if QUANTIZATION_TYPE > 0
        // quantization
        float quantization = QUANTIZATION_AMOUNT;
        vec3 quantizedColor = floor(color * quantization) / quantization; // Reduce to 'quantization' levels per channel
        
        // dithering
        #if QUANTIZATION_TYPE == 2
            // get Bayer matrix value
            ivec2 pixelPos = ivec2(gl_FragCoord.xy) % 4;
            float threshold = (bayerMatrix[pixelPos.x][pixelPos.y] + 0.5) / 16.0;
            // apply it
            quantizedColor = mix(quantizedColor, quantizedColor + 1.0 / quantization, step(threshold, fract(color * quantization)));
        #endif

        color = quantizedColor;
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
