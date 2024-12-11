#version 140

#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 tint;

// results
/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueMaterialData;

void main() {
    /* type */
    float type = 0; // basic=0

    /* buffers */
    opaqueAlbedoData = vec4(tint);
    opaqueMaterialData = vec4(type, 0, 0, 1);
}
