#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item

// results
/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 normalData;
layout(location = 2) out vec4 lightAndMaterialData;

void main() {
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;

    #ifdef BEACON_BEAM
        transparency = 0.5;
        lightAndMaterialData = vec4(0.0, 1.0, 0.0, 1.0);
    #endif

    #ifdef GLOWING
        lightAndMaterialData = vec4(0.0, 1.0, 0.0, 1.0);
    #endif

    colorData = vec4(albedo, transparency);
}
