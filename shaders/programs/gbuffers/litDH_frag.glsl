#extension GL_ARB_explicit_attrib_location : enable

#include "/lib/common.glsl"
#include "/lib/utils.glsl"
#include "/lib/space_conversion.glsl"
#include "/lib/light_color.glsl"
#include "/lib/sky.glsl"
#include "/lib/fog.glsl"
#include "/lib/animation.glsl"
#include "/lib/shadow.glsl"
#include "/lib/BRDF.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting.glsl"
#if REFLECTION_TYPE > 0 && defined TRANSPARENT
    #include "/lib/reflection.glsl"
#endif

// uniforms
uniform sampler2D gtexture;

#if REFLECTION_TYPE > 0 && defined TRANSPARENT
    uniform sampler2D colortex4; // opaque color
    uniform sampler2D colortex5; // opaque light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
    uniform sampler2D depthtex1; // opaque depth
#endif

// attributes
in vec4 Valbedo;
in vec3 worldSpacePosition;
in vec3 Vnormal;
in vec2 textureCoordinate;
in vec2 lightMapCoordinate; // light map
flat in int id;

// results
/* RENDERTARGETS: 0,1,4,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec3 normalData;
layout(location = 2) out vec4 reflectionData;
layout(location = 3) out vec4 lightAndMaterialData;

void main() {
    // retrieve data
    vec2 uv = texelToScreen(gl_FragCoord.xy);
    float depth = gl_FragCoord.z;
    vec3 albedo = SRGBtoLinear(Valbedo.rgb);
    float transparency = Valbedo.a;

    vec3 playerSpacePosition = worldToPlayer(worldSpacePosition);

    // avoid transparent DH layer being over the classical opaque one
    #ifdef TRANSPARENT
        float opaqueDepth = texture2D(depthtex1, uv).r;
        vec3 opaquePlayerSpacePosition = screenToPlayer(uv, opaqueDepth);
        if (length(playerSpacePosition) > length(opaquePlayerSpacePosition)) discard;
    #endif

    // blending transition between classic terrain & DH terrain
    float cylindricDistance = max(length(playerSpacePosition.xz), abs(playerSpacePosition.y));
    float dhBlend = smoothstep(0.5*far, far, cylindricDistance);
    dhBlend = pow(dhBlend, 2.0);
    float dither = pseudoRandom(uv + frameTimeCounter / 3600.0);
    if (dhBlend < dither) discard;

    vec3 normal = Vnormal;

    // light data
    float blockLightIntensity = lightMapCoordinate.x;
    float ambientSkyLightIntensity = lightMapCoordinate.y;
    // gamma correct light
    blockLightIntensity = SRGBtoLinear(blockLightIntensity);
    ambientSkyLightIntensity = SRGBtoLinear(ambientSkyLightIntensity);

    // material data
    float smoothness = 0.0, reflectance = 0.0, emissivness = 0.0, ambient_occlusion = 0.0;
    getDHMaterialData(id, albedo, smoothness, reflectance, emissivness, ambient_occlusion);

    // -- apply lighting -- //
    vec4 color = doDHLighting(albedo, transparency, normal, worldSpacePosition, smoothness, reflectance, ambientSkyLightIntensity, blockLightIntensity, emissivness, ambient_occlusion);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        vec3 screenSpacePosition = vec3(uv, depth);
        vec4 reflection = doDHReflection(uv, depth, normal, ambientSkyLightIntensity, smoothness, reflectance);

        // tweak reflection on water
        reflection.a = smoothstep(0.0, 1.0, reflection.a);

        // blindness
        float blindnessFogFactor = getBlindnessFactor(worldSpacePosition, blindnessRange);
        reflection.a = mix(reflection.a, 0.0, blindnessFogFactor * blindness);
        // darkness
        float darknessFogFactor = getBlindnessFactor(worldSpacePosition, darknessRange);
        reflection.a = mix(reflection.a, 0.0, darknessFogFactor * darknessFactor);

        // apply reflection
        color.rgb = mix(color.rgb, reflection.rgb, reflection.a);
    #endif

    // -- fog -- //
    foggify(worldSpacePosition, color.rgb, emissivness);
    // blindness
    doBlindness(worldSpacePosition, color.rgb, emissivness);

    // gamma correct
    color.rgb = linearToSRGB(color.rgb);

    // -- buffers -- //
    colorData = vec4(color);
    normalData = encodeNormal(normal);
    #ifdef TRANSPARENT
        lightAndMaterialData = vec4(0.0, emissivness, 0.0, pow(transparency, 0.25));
    #else
        lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, reflectance);
    #endif
}
