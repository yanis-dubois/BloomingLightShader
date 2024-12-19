#version 140
#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec2 textureCoordinate; // immuable block & item

// results
/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 opaqueAlbedoData;
layout(location = 1) out vec4 opaqueLightData;
layout(location = 2) out vec4 opaqueMaterialData;

void main() {
    /* albedo */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    // transparency
    float transparency = textureColor.a;
    transparency = mix(transparency, 0, rainStrength);
    if (transparency < alphaTestRef) discard;

    /* light */
    albedo = SRGBtoLinear(albedo) * 1.5;
    float emissivness = (0.2126 * albedo.r + 0.7152 * albedo.g + 0.0722 * albedo.b);
    albedo = linearToSRGB(albedo / 1.5);

    /* type */
    float type = 0; // basic=0

    /* buffers */
    opaqueAlbedoData = vec4(albedo, transparency);
    opaqueLightData = vec4(0, 0, emissivness, 1);
    opaqueMaterialData = vec4(type, 0, 0, 1);
}
