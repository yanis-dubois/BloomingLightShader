#extension GL_ARB_explicit_attrib_location : enable

// includes
#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"

// uniforms
uniform sampler2D gtexture;

// attributes
in vec4 additionalColor; // foliage, water, particules
in vec3 worldSpacePosition;
in vec2 textureCoordinate; // immuable block & item

// results
/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec4 lightAndMaterialData;

void main() {
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 albedo = textureColor.xyz * additionalColor.xyz;
    float transparency = textureColor.a;
    if (transparency < alphaTestRef) discard;
    float emissivness = 0.0;

    albedo = SRGBtoLinear(albedo);

    #ifdef BEACON_BEAM
        transparency = 0.5;
        emissivness = 1.0;
    #endif

    #ifdef GLOWING
        albedo *= 2.0;
        emissivness = 1.0;
    #endif

    albedo = clamp(albedo, 0.0, 1.0);

    #ifdef CLOUD
        // blue filter
        albedo *= light10000K * light7500K;

        // apply fog
        float distanceFromCameraXZ = distance(cameraPosition.xz, worldSpacePosition.xz);
        float cloudDistance = 1.5*far;
        float blendFactor = map(distanceFromCameraXZ, max(cloudDistance - 64.0, 0.0), cloudDistance, 0.0, 1.0);
        transparency = 0.75 * (1.0 - blendFactor);
    #endif

    // apply blindness effect
    doBlindness(worldSpacePosition, albedo, emissivness);

    // gamma correct
    albedo = linearToSRGB(albedo);

    colorData = vec4(albedo, transparency);
    #if defined BEACON_BEAM || defined GLOWING
        lightAndMaterialData = vec4(0.0, emissivness, 0.0, 1.0);
    #endif
}
