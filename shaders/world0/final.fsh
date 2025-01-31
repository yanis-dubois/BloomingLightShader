#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"

// textures
uniform sampler2D colortex0; // opaque color
uniform sampler2D colortex4; // transparent color
uniform sampler2D depthtex0; // all depth
uniform sampler2D depthtex1; // opaque depth
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColorData;

void process(sampler2D albedoTexture, out vec4 colorData) {
    colorData = texture2D(albedoTexture, uv);
    vec3 color = vec3(0); float transparency = 0;
    getColorData(colorData, color, transparency);

    colorData = vec4(color, transparency);
}

void main() {
    vec4 opaqueColorData = vec4(0);
    vec4 transparentColorData = vec4(0);
    process(colortex0, opaqueColorData);
    process(colortex4, transparentColorData);

    // blend opaque and transparent texture
    outColorData = mix(opaqueColorData, transparentColorData, transparentColorData.a);
    outColorData.rgb = linearToSRGB(outColorData.rgb);
}
