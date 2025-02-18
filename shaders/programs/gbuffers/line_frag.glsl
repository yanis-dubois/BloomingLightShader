#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 tint;

// results
/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueMaterialData;

void main() {
    /* type */
    float type = typeBasic;

    /* buffers */
    opaqueAlbedoData = vec4(tint);
    opaqueMaterialData = vec4(type, 0, 0, 1);
}
