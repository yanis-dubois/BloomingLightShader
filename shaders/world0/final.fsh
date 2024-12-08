#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// textures
uniform sampler2D colortex0; // color

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 color = texture2D(colortex0, uv);

    // final color tweak
    vec3 col = SRGBtoLinear(color.rgb);
    color.rgb = linearToSRGB(col * 1.5);

    outColor = color;
}
