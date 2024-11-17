#version 140
#extension GL_ARB_explicit_attrib_location : enable

uniform float alphaTestRef;

in vec4 tint;

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 colortex0Out;

void main() {
	vec4 textureColor = tint;
	
	float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

	colortex0Out = textureColor;
}