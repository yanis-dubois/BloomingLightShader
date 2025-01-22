#version 140
#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/animation.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec4 clipSpacePosition;
in vec2 textureCoordinate; // immuable block & item
flat in int id;

// results
/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    /* texture value */
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    float transparency = textureColor.a;
    vec3 albedo = textureColor.rgb * additionalColor.rgb;

    if (transparency < alphaTestRef) discard;

    if (SHADOW_WATER_ANIMATED==1 && isLiquid(id)) {
        vec3 worldSpacePosition = shadowClipToWorld(clipSpacePosition);
        float noise = doShadowWaterAnimation(frameTimeCounter, worldSpacePosition);
        transparency += noise;
    }

    outColor0 = vec4(albedo, transparency);
}
