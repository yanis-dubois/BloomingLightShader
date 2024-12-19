#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// textures
uniform sampler2D colortex0; // color
uniform sampler2D shadowtex0; // all shadow
uniform sampler2D shadowtex1; // only opaque shadow
uniform sampler2D shadowcolor0; // shadow color

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 color = texture2D(colortex0, uv);
    outColor = color;

    // outColor = texture2D(shadowcolor0, uv);
}
