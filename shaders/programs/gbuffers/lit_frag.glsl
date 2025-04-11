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
in mat3 TBN;
in vec4 additionalColor; // albedo of : foliage, water, particules
in vec3 unanimatedWorldPosition;
in vec3 midBlock;
in vec3 worldSpacePosition;
in vec2 textureCoordinate; // immuable block & item albedo
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
    vec4 textureColor = texture2D(gtexture, textureCoordinate);
    vec3 tint = additionalColor.rgb;
    vec3 albedo = textureColor.rgb * tint;
    float transparency = textureColor.a;

    vec3 tangent = TBN[0];
    vec3 bitangent = TBN[1];
    vec3 normal = TBN[2];

    // tweak transparency
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;

    // avoid seeing water top surface when underwater
    if (isEyeInWater == 1 && id == 20000 && normal.y > 0.1) {
        discard;
    }

    // apply red flash when mob are hitted
    albedo = mix(albedo, entityColor.rgb, entityColor.a);

    // weather smooth transition
    #ifdef WEATHER
        transparency *= rainStrength;
        transparency = min(transparency, 0.2);
    #endif

    // light data
    float distanceFromEye = distance(eyePosition, worldSpacePosition);
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2);
    float heldBlockLight = heldLightValue >= 1.0 ? max(1.0 - (distanceFromEye / max(heldLightValue, 1.0)), 0.0) : 0.0;
    float blockLightIntensity = max(lightMapCoordinate.x, heldBlockLight);
    float ambientSkyLightIntensity = lightMapCoordinate.y;
    // gamma correct light
    blockLightIntensity = SRGBtoLinear(blockLightIntensity);
    ambientSkyLightIntensity = SRGBtoLinear(ambientSkyLightIntensity);

    // material data
    float smoothness = 0.0, reflectance = 0.0, emissivness = 0.0, ambient_occlusion = 0.0;
    getMaterialData(gtexture, id, normal, midBlock, albedo, smoothness, reflectance, emissivness, ambient_occlusion);  
    // opaque or transparent pass
    #ifdef TRANSPARENT
        bool isTransparent = true;
    #else
        bool isTransparent = false;
    #endif

    // normal
    #ifdef PARTICLE 
        normal = -normalize(playerLookVector);
    #endif
    // animated normal
    #if VERTEX_ANIMATION == 2
        if (isAnimated(id) && smoothness > 0.5) {
            vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock, ambientSkyLightIntensity);
            vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent / 16.0, midBlock, ambientSkyLightIntensity);
            vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent / 16.0, midBlock, ambientSkyLightIntensity);

            vec3 newTangent = normalize(tangentDerivative - actualPosition);
            vec3 newBitangent = normalize(bitangentDerivative - actualPosition);

            vec3 newNormal = - normalize(cross(newTangent, newBitangent));
            if (dot(newNormal, normal) < 0.0) newNormal *= -1.0;

            vec3 viewDirection = normalize(cameraPosition - actualPosition);
            if (dot(viewDirection, newNormal) > 0.1) {
                normal = newNormal;
            }
        }
    #endif

    // glowing particles
    #ifdef PARTICLE
        bool isObsidianTears = isEqual(tint, vec3(130.0, 8.0, 227.0) / 255.0, 2.0/255.0);
        bool isBlossom = isEqual(tint, vec3(80.0, 127.0, 56.0) / 255.0, 2.0/255.0);
        bool isRedstone = tint.r > 0.1 && tint.g < 0.2 && tint.b < 0.1;
        bool isEnchanting = isEqual(tint.r, tint.g, 2.0/255.0) && 10.0/255.0 < (tint.b - tint.r) && (tint.b - tint.r) < 30.0/255.0; // also trigger warpped forest particles
        bool isNetherPortal = 0.0 < (tint.b - tint.r) && (tint.b - tint.r) < 30.0 && 2.0*tint.g < tint.b;
        bool isLava = (albedo.r > 250.0/255.0 && albedo.g > 70.0/255.0 && albedo.b < 70.0/255.0) || tint.r > 250.0/255.0 && tint.g > 70.0/255.0 && tint.b < 70.0/255.0;
        bool isSoulFire = isEqual(textureColor.rgb, vec3(96.0, 245.0, 250.0) / 255.0, 2.0/255.0)
            || isEqual(textureColor.rgb, vec3(1.0, 167.0, 172.0) / 255.0, 2.0/255.0)
            || isEqual(textureColor.rgb, vec3(0.0, 142.0, 146.0) / 255.0, 2.0/255.0);
        bool isCrimsonForest = isEqual(tint, vec3(229.0, 101.0, 127.0) / 255.0, 2.0/255.0);
        bool isGreenGlint = isEqual(textureColor.rgb, vec3(6.0, 229.0, 151.0) / 255.0, 6.0/255.0)
            || isEqual(textureColor.rgb, vec3(4.0, 201.0, 77.0) / 255.0, 6.0/255.0)
            || isEqual(textureColor.rgb, vec3(2.0, 179.0, 43.0) / 255.0, 2.0/255.0)
            || isEqual(textureColor.rgb, vec3(0.0, 150.0, 17.0) / 255.0, 2.0/255.0);
        // is glowing particle ?
        if (isNetherPortal || isRedstone || isObsidianTears || isBlossom || isEnchanting || isLava || isSoulFire || isCrimsonForest || isGreenGlint) {
            ambient_occlusion = 1.0;
            emissivness = 1.0;
            // saturate some of them
            if (isNetherPortal || isRedstone) {
                albedo *= 1.5;
            }
        }
    #endif

    // light animation
    if (LIGHT_EMISSION_ANIMATION == 1 && emissivness > 0.0) {
        float noise = doLightAnimation(id, frameTimeCounter, unanimatedWorldPosition);
        emissivness -= noise;
    }

    // -- apply lighting -- //
    albedo = SRGBtoLinear(albedo);
    vec4 color = doLighting(gl_FragCoord.xy, albedo, transparency, normal, worldSpacePosition, unanimatedWorldPosition, smoothness, reflectance, 1.0, ambientSkyLightIntensity, blockLightIntensity, emissivness, ambient_occlusion, isTransparent, tangent, bitangent);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        vec4 reflection = doReflection(colortex4, colortex5, depthtex1, uv, depth, color.rgb, normal, ambientSkyLightIntensity, smoothness, reflectance);

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
    lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, reflectance);
}
