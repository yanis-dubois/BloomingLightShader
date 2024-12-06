#version 140

#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 tint;

// results
/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightAndTypeData;

void main() {
    /* type */
    float type = 0; // basic=0

    /* buffers */
    opaqueAlbedoData = vec4(tint);
    opaqueLightAndTypeData = vec4(0, 0, type, 1);
}
