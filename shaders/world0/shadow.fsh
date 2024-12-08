#version 140
#extension GL_ARB_explicit_attrib_location : enable

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item

// results
/* predetermined render target for shadow */
layout(location = 0) out vec4 outColor0;

void main() {
    /* texture value */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec4 albedo = textureColor * additionalColor;
    
    /* transparency */
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

    outColor0 = albedo;
}
