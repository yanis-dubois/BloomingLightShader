#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex2; // opaque color * emissivness
uniform sampler2D colortex4; // transparent color
uniform sampler2D colortex6; // transparent color * emissivness
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // only opaque depth
uniform sampler2D depthtex2; // only opaque depth and no hand

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 transparentColorData;

vec3 bloom(vec2 uv, sampler2D bloomTexture) {

    // no bloom
    #if BLOOM_TYPE == 0
        return vec3(0);

    // no light leak
    #elif float(BLOOM_RANGE) <= 0.0 || float(BLOOM_RESOLTUION) <= 0.0
        return SRGBtoLinear(texture2D(bloomTexture, uv).rgb);

    // bloom
    #else

        // prepare loop
        float range = BLOOM_RANGE;
        float samples = range * BLOOM_RESOLTUION;
        float step_length = range / samples;
        vec3 color = vec3(0);
        float count = 0;

        // stocastic
        #if BLOOM_TYPE == 1
            for (float i=0; i<samples; ++i) {
                // random offset by sampling disk area
                vec2 seed = uv + i + (frameTimeCounter / 60);
                vec2 offset = sampleDiskArea(seed);
                vec2 coord = uv + range * texelToScreen(offset);

                // box
                #if BLOOM_KERNEL == 0
                    float weight = 1;
                // gaussian
                #elif BLOOM_KERNEL == 1
                    float weight = gaussian(offset.x, offset.y, 0, 0.5);
                #endif

                color += weight * SRGBtoLinear(texture2D(bloomTexture, coord).rgb);
                count += weight;
            }

        // classic
        #elif BLOOM_TYPE == 2
            for (float x=-range; x<=range; x+=step_length) {
                for (float y=-range; y<=range; y+=step_length) {
                    vec2 offset = vec2(x,y);
                    vec2 coord = uv + texelToScreen(offset);

                    // box
                    #if BLOOM_KERNEL == 0
                        float weight = 1;
                    // gaussian
                    #elif BLOOM_KERNEL == 1
                        float weight = gaussian(offset.x / range, offset.y / range, 0, 0.5);
                    #endif

                    color += weight * SRGBtoLinear(texture2D(bloomTexture, coord).rgb);
                    count += weight;
                }
            }

        #endif

        return color / count + SRGBtoLinear(texture2D(bloomTexture, uv).rgb) * 0.75;
    #endif
}

void process(sampler2D colorTexture, sampler2D bloomTexture,
            out vec4 colorData) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(colorTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    /* bloom */
    vec3 bloomColor = bloom(uv, bloomTexture);
    color += bloomColor * BLOOM_FACTOR;

    colorData.rgb = linearToSRGB(color);
}

/******************************************
****************** Bloom ******************
*******************************************/
void main() {
    process(colortex0, colortex2, opaqueColorData);
    process(colortex4, colortex6, transparentColorData);
}
