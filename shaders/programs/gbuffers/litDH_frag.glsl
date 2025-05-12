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
uniform sampler2D depthtex1; // opaque depth

#if REFLECTION_TYPE > 0 && defined TRANSPARENT
    uniform sampler2D colortex4; // opaque color
    uniform sampler2D colortex5; // opaque light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
#endif

// attributes
in vec4 Valbedo;
in vec3 worldSpacePosition;
in vec3 Vnormal;
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
        if (texture2D(depthtex1, uv).r < 1.0) discard;
    #endif

    // blending transition between classic terrain & DH terrain
    float cylindricDistance = max(length(playerSpacePosition.xz), abs(playerSpacePosition.y));
    float dhBlend = smoothstep(0.75*far, far, cylindricDistance);
    float dither = dithering(uv, DH_DITHERING_TYPE);
    if (dhBlend < dither) discard;

    vec3 normal = Vnormal;

    // light data
    float blockLightIntensity = lightMapCoordinate.x;
    float ambientSkyLightIntensity = lightMapCoordinate.y;
    // gamma correct light
    blockLightIntensity = SRGBtoLinear(blockLightIntensity);
    ambientSkyLightIntensity = SRGBtoLinear(ambientSkyLightIntensity);

    // material data
    float smoothness = 0.0, reflectance = 0.0, emissivness = 0.0;
    getDHMaterialData(id, albedo, smoothness, reflectance, emissivness);

    // -- apply lighting -- //
    vec4 color = doDHLighting(albedo, transparency, normal, worldSpacePosition, smoothness, reflectance, ambientSkyLightIntensity, blockLightIntensity, emissivness);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        vec3 screenSpacePosition = vec3(uv, depth);
        // vec4 reflection = doDHReflection(uv, depth, normal, ambientSkyLightIntensity, smoothness, reflectance);
        vec4 reflection = doReflection(colortex4, colortex5, depthtex1, screenSpacePosition.xy, screenSpacePosition.z, color.rgb, normal, ambientSkyLightIntensity, smoothness, reflectance);

        // tweak reflection on water
        reflection.a = smoothstep(0.0, 1.0, reflection.a);

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
        lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, 1.0);
    #endif
}
