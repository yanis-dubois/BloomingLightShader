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

vec3 bloom(vec2 uv, float depth, sampler2D bloomTexture, sampler2D depthTexture) {
    vec3 worldSpacePosition = screenToWorld(uv, depth);
    float fragDistance = distance(cameraPosition, worldSpacePosition);

    float radius = 20;
    float samples = 10.0;
    float step_length = radius/samples;
    vec3 color = vec3(0);
    float count = 0;
    for (float x=-radius; x<=radius; x+=step_length) {
        for (float y=-radius; y<=radius; y+=step_length) {
            vec2 coord = vec2(x,y);
            coord = uv + texelToScreen(coord);

            float sampleDepth = texture2D(depthTexture, coord).r;
            vec3 sampleWorldSpacePosition = screenToWorld(coord, sampleDepth);
            float sampleDistance = distance(viewToWorld(vec3(0)), sampleWorldSpacePosition);
            //if (abs(sampleDistance - fragDistance) < 15) continue;

            float weight = gaussian(x, y, 0, radius/3);
            color += weight * SRGBtoLinear(texture2D(bloomTexture, coord).rgb);
            count += weight;
        }
    }

    return color / count;
}

void process(sampler2D colorTexture, sampler2D bloomTexture, sampler2D depthTexture,
            out vec4 colorData) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    colorData = texture2D(colorTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);
    // depth
    vec4 depthData = texture2D(depthTexture, uv);
    float depth = 0;
    getDepthData(depthData, depth);

    // apply only on opaque !!!!!!!!!!!!!!!
    if (BLOOM_TYPE == 1) {
        vec3 bloomColor = bloom(uv, depth, bloomTexture, depthTexture);
        bloomColor = linearToSRGB(bloomColor);
        colorData.rgb += BLOOM_FACTOR * bloomColor;
        // colorData.rgb = bloomColor;
    }
}

/******************************************
****************** Bloom ******************
*******************************************/
void main() {
    process(colortex0, colortex2, depthtex1, opaqueColorData);
    process(colortex4, colortex6, depthtex0, transparentColorData);
}
