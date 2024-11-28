#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"

// textures
uniform sampler2D colortex0;

// attributes
in vec2 uv;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 finalColor;

/*******************************************
********* inverse gamma correction *********
********************************************/
void main() {
    vec4 colorData = texture2D(colortex0, uv);
    vec3 color = colorData.rgb;
    float transparency = colorData.a;
    finalColor = vec4(pow(color, vec3(1/2.2)), transparency);
}
