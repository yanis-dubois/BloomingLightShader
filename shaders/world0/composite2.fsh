#version 140
#extension GL_ARB_explicit_attrib_location : enable

#define BLOOM_FIRST_PASS

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/atmospheric.glsl"
#include "/lib/bloom.glsl"

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
/* RENDERTARGETS: 0,2,4,6 */
layout(location = 0) out vec4 opaqueColorData;
layout(location = 1) out vec4 opaqueBloomData;
layout(location = 2) out vec4 transparentColorData;
layout(location = 3) out vec4 transparentBloomData;

void process(sampler2D bloomTexture,
            out vec4 bloomData) {

    // -- get input buffer values & init output buffers -- //
    // albedo
    // bloomData = texture2D(bloomTexture, uv);
    // vec3 color = vec3(0); float transparency = 0;
    // getColorData(bloomData, color, transparency);

    /* bloom */
    bloomData = bloom(uv, bloomTexture);
    bloomData.rgb = linearToSRGB(bloomData.rgb);
}

/******************************************
****************** Bloom ******************
*******************************************/
void main() {
    process(colortex2, opaqueBloomData);
    process(colortex6, transparentBloomData);

    opaqueColorData = texture2D(colortex0, uv);
    transparentColorData = texture2D(colortex4, uv);
}
