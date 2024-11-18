#version 140
#extension GL_ARB_explicit_attrib_location : enable

#define SHADOW_QUALITY 2
#define SHADOW_SOFTNESS 1

const int shadowMapResolution = 2048;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

// uniforms
uniform sampler2D gtexture;
uniform float alphaTestRef;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item

// results
/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 outColor0;

void main() {
    /* texture value */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);

    /* albedo */
    vec3 albedo = textureColor.rgb * additionalColor.rgb;
    
    /* transparency */
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

    vec3 outColor = albedo;

    // combine color & transparency as result
    outColor0 = vec4(outColor, transparency);
}
