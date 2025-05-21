
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

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 colorData;

/******************************************/
/************** wild effects **************/
/******************************************/
void main() {
    vec2 UV = uv;

    // -- light refraction -- //
    // underwater
    #if REFRACTION_UNDERWATER > 0 && !defined NETHER
        if (isEyeInWater == 1) {
            float depth = texture2D(depthtex0, uv).r;
            vec3 eyeSpaceDirection = normalize(viewToEye(screenToView(uv, depth)));
            UV = uv + doWaterRefraction(frameTimeCounter, uv, eyeSpaceDirection);
        }
    // nether
    #elif REFRACTION_NETHER > 0 && defined NETHER
        float depth = texture2D(depthtex0, uv).r;
        vec3 eyeSpaceDirection = normalize(viewToEye(screenToView(uv, depth)));
        UV = uv + doHeatRefraction(frameTimeCounter, uv, eyeSpaceDirection);
    #endif

    // -- dying effect (pulsating chromatic aberation) -- //
    #if STATUS_DYING_TYPE > 0

        // direction
        vec2 direction = (uv * 2 - 1);
        float dist = length(direction);
        direction = normalize(direction);

        // amplitude
        float dyingFactor = pow(1.0 - abs(currentPlayerHealth), 2.0);
        float pulseSpeed = map(1.0 - dyingFactor, 0.0, 1.0, 0.7, 1.0);
        float pulse = mod(frameTimeCounter, pulseSpeed) / pulseSpeed;
        pulse = pulse < 0.33
            ? pow(map(pulse, 0.0, 0.33, 0.0, 1.0), 2.5)
            : pow(1.0 - map(pulse, 0.33, 1.0, 0.0, 1.0), 0.75);
        float pulseFactor = 0.5 + 0.5 * pulse;
        float amplitude = dist * 0.02;
        amplitude *= dyingFactor * pulseFactor;

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

    // -- drowning effect (desaturate & dark pulse) -- //
    #if STATUS_DROWNING_TYPE > 0
        vec3 grayScale = saturate(color, 0.5) + 0.01 * interleavedGradient(uv);
        grayScale = pow(0.5 * grayScale, vec3(1.25));
        float drowningFactor = 1.0 - abs(currentPlayerAir);
        float desaturateFactor = pow(map(drowningFactor, 0.0, 0.9, 0.0, 1.0), 3.0);
        float darkenFactor = pow(map(drowningFactor, 0.9, 1.0, 0.0, 1.0), 1.5);
        color = mix(color, grayScale, desaturateFactor);
        color = mix(color, vec3(0.0), darkenFactor);
    #endif

    colorData = vec4(linearToSRGB(color), 1.0);
}
