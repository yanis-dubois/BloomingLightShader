#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item
flat in int id;
in vec3 playerSpacePosition;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    /* texture value */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    float transparency = textureColor.a;
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    
    // leaves are perfectly opaque ?
    // if (id == 10030) transparency = 1;

    if (transparency < alphaTestRef) discard;

    outColor0 = vec4(albedo, transparency);
}
