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
#include "/lib/pixelation.glsl"
#include "/lib/lighting.glsl"
#if REFLECTION_TYPE > 0 && defined REFLECTIVE
    #include "/lib/reflection.glsl"
#endif
#if PBR_POM_TYPE > 0
    #include "/lib/POM.glsl"
#endif

// uniforms
uniform sampler2D gtexture;

// PBR
uniform sampler2D normals;
uniform sampler2D specular;

#if REFLECTION_TYPE > 0 && defined REFLECTIVE
    uniform sampler2D colortex4; // opaque color
    uniform sampler2D colortex5; // opaque light & material (ambientSkyLightIntensity, emissivness, smoothness, reflectance)
    uniform sampler2D depthtex1; // opaque depth
#endif

// attributes
in vec3 Vnormal;
in vec3 Vtangent;
in vec3 Vbitangent;
in vec4 additionalColor; // albedo of : foliage, water, particules
in vec3 unanimatedWorldPosition;
in vec3 midBlock;
in vec3 worldSpacePosition;
in vec2 originalTextureCoordinate; // immuable block & item albedo
in vec2 lightMapCoordinate; // light map
in vec4 textureCoordinateOffset;
in vec2 localTextureCoordinate;
flat in int id;

// results
/* RENDERTARGETS: 0,1,4,5 */
layout(location = 0) out vec4 colorData;
layout(location = 1) out vec3 normalData;
layout(location = 2) out vec4 reflectionData;
layout(location = 3) out vec4 lightAndMaterialData;

void main() {

    // fragment data
    vec2 uv = texelToScreen(gl_FragCoord.xy);
    float depth = gl_FragCoord.z;
    vec3 viewDirection = normalize(eyeCameraPosition - worldSpacePosition);

    // blending transition between classic terrain & DH terrain
    #ifdef DISTANT_HORIZONS
        vec3 playerSpacePosition = worldToPlayer(unanimatedWorldPosition);
        float cylindricDistance = max(length(playerSpacePosition.xz), abs(playerSpacePosition.y));
        float dhBlend = smoothstep(0.75*far, far, cylindricDistance);
        float dither = dithering(uv, DH_DITHERING_TYPE);
        if (dhBlend > dither) discard;
    #endif

    mat3 TBN = mat3(
        normalize(Vtangent),
        normalize(Vbitangent),
        normalize(Vnormal)
    );

    // tbn data
    #ifndef PARTICLE
        vec3 tangent = TBN[0];
        vec3 bitangent = TBN[1];
        vec3 normal = TBN[2];

    // particle tbn tweak (every particles normal point to the light source)
    #else
        vec3 normal = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        vec3 tangent = vec3(0.0, 0.0, 1.0);
        vec3 bitangent = cross(tangent, normal);
    #endif

    // initialize normalmap & POM normal
    vec3 normalMap = normal;
    vec3 normalPOM = vec3(0.0);

    vec2 textureCoordinate = originalTextureCoordinate;
    // -- POM -- //
    #if !defined PARTICLE && !defined WEATHER && PBR_TYPE > 0 && PBR_POM_TYPE > 0
        float worldSpaceDistance = length(cameraPosition - worldSpacePosition);
        float POMblend = map(worldSpaceDistance, 0.5*PBR_POM_DISTANCE, PBR_POM_DISTANCE, 0.0, 1.0);
        float POMdither = dithering(uv, PBR_POM_DITHERING_TYPE);

        // POM only apply on object that are inside POM render distance
        if (worldSpaceDistance < PBR_POM_DISTANCE) {
            vec2 POMtextureCoordinate = doPOM(gtexture, normals, TBN, viewDirection, localTextureCoordinate, textureCoordinateOffset, worldSpaceDistance, normalPOM);

            // smooth transition
            if (POMblend <= POMdither) 
                textureCoordinate = POMtextureCoordinate;

            // if the ray hit the side of a pixel, it gets a new normal
            if (length(normalPOM) > 0.0) {
                normalPOM = TBN * normalPOM;
            }
        }
    #endif

    // color data
    #if !defined PARTICLE && !defined WEATHER && PBR_TYPE > 0 && PBR_POM_TYPE > 1
        vec4 textureColor = vec4(0.0);
        if (worldSpaceDistance < PBR_POM_DISTANCE) {
            textureColor = texture2DLod(gtexture, textureCoordinate, 0);
        } else {
            textureColor = texture2D(gtexture, textureCoordinate);
        }
    #else
        vec4 textureColor = texture2D(gtexture, textureCoordinate);
    #endif
    vec3 tint = additionalColor.rgb;
    float vanillaAmbientOcclusion = additionalColor.a;
    vec3 albedo = textureColor.rgb * tint;
    float transparency = textureColor.a;

    // tweak transparency
    if (id == 20010) transparency = clamp(transparency, 0.2, 0.75); // uncolored glass
    if (id == 20011) transparency = clamp(transparency, 0.36, 1.0); // beacon glass
    if (transparency < alphaTestRef) discard;

    // avoid seeing water top surface when underwater
    if (isEyeInWater == 1 && id == 20000 && normal.y > 0.1) {
        discard;
    }

    // apply red flash when mob are hit
    albedo = mix(albedo, entityColor.rgb, entityColor.a);

    // 
    #if PIXELATION_TYPE > 1
        vec2 pixelationOffset = computeTexelOffset(gtexture, originalTextureCoordinate);
    #else
        vec2 pixelationOffset = vec2(0.0);
    #endif

    // light data
    float distanceFromEye = distance(eyePosition, worldSpacePosition);
    float heldLightValue = max(heldBlockLightValue, heldBlockLightValue2);
    float heldBlockLight = heldLightValue >= 1.0 ? max(1.0 - (distanceFromEye / max(heldLightValue, 1.0)), 0.0) : 0.0;
    vec2 lightMap = vec2(
        max(lightMapCoordinate.x, heldBlockLight), 
        smoothstep(0.0, 1.0, lightMapCoordinate.y)
    );
    // gamma correct
    lightMap = SRGBtoLinear(lightMap);
    // retrieve block light & ambient sky light
    float blockLightIntensity = lightMap.x, ambientSkyLightIntensity = lightMap.y;

    // material data
    float smoothness = 0.0, reflectance = 0.0, emissivness = 0.0, ambientOcclusion = 1.0, ambientOcclusionPBR = 1.0, subsurfaceScattering = 0.0, porosity = 0.0;
    // initialize specific material as end portal or glowing particles
    getSpecificMaterial(gtexture, id, textureColor.rgb, tint, albedo, transparency, emissivness, subsurfaceScattering);
    // update PBR values with my own custom data
    getCustomMaterialData(id, normal, midBlock, localTextureCoordinate, textureColor.rgb, albedo, smoothness, reflectance, emissivness, ambientOcclusion, subsurfaceScattering, porosity);  
    // modify these PBR values if PBR textures are enable
    getPBRMaterialData(normals, specular, textureCoordinate, smoothness, reflectance, emissivness, ambientOcclusionPBR, subsurfaceScattering, porosity);

    // gamma correct
    albedo = SRGBtoLinear(albedo);

    // pixelated block light
    #if defined TERRAIN && PIXELATION_TYPE > 1 && PIXELATED_BLOCKLIGHT > 0
        vec2 texelLight = texelSnap(vec2(blockLightIntensity, ambientSkyLightIntensity), pixelationOffset);
        blockLightIntensity = texelLight.x;
        ambientSkyLightIntensity = texelLight.y;
    #endif

    // pixelated ambient occlusion
    #if defined TERRAIN && PIXELATION_TYPE > 1 && PIXELATED_AMBIENT_OCCLUSION > 0
        vec2 texelAmbientOcclusion = texelSnap(vec2(vanillaAmbientOcclusion, ambientOcclusion), pixelationOffset);
        vanillaAmbientOcclusion = texelAmbientOcclusion.x;
        ambientOcclusion = texelAmbientOcclusion.y;
    #endif

    // vanilla ambient occlusion
    #ifdef TERRAIN
        albedo *= vanillaAmbientOcclusion;
    #endif

    // animated normal
    #if ANIMATED_POSITION == 2 && defined REFLECTIVE
        if (isAnimated(id) && length(normalPOM) <= 0.001) {

            // sample noise function
            vec3 actualPosition = doAnimation(id, frameTimeCounter, unanimatedWorldPosition, midBlock, ambientSkyLightIntensity);
            vec3 tangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + tangent / 16.0, midBlock, ambientSkyLightIntensity);
            vec3 bitangentDerivative = doAnimation(id, frameTimeCounter, unanimatedWorldPosition + bitangent / 16.0, midBlock, ambientSkyLightIntensity);

            // calcul derivative
            vec3 newTangent = normalize(tangentDerivative - actualPosition);
            vec3 newBitangent = normalize(bitangentDerivative - actualPosition);

            // get new normal from derivative
            vec3 newNormal = - normalize(cross(newTangent, newBitangent));
            if (dot(newNormal, normal) < 0.0) newNormal *= -1.0;

            // use the new normal if it's visible
            if (dot(viewDirection, newNormal) > 0.0) {
                normalMap = newNormal;
            }
        }
    #endif

    // custom normal map for water
    #if defined TERRAIN && defined REFLECTIVE && WATER_CUSTOM_NORMALMAP > 0
        if (isWater(id)) {
            vec4 seed = texture2DLod(gtexture, textureCoordinate, 0).rgba + 0.35;
            float zeta1 = interleavedGradient(seed), zeta2 = interleavedGradient(seed + 41.43291);
            mat3 animatedTBN = generateTBN(normalMap);

            // sampling data
            float roughness = clamp(pow(1.0 - smoothness, 2.0), 0.1, 0.4);
            roughness *= roughness;

            // view direction from view to tangent space
            vec3 voxelizedViewDirection = normalize(cameraPosition - voxelize(unanimatedWorldPosition));
            vec3 tangentSpaceViewDirection = transpose(animatedTBN) * voxelizedViewDirection;
            // sample normal & convert to view
            vec3 sampledNormal = sampleGGXVNDF(tangentSpaceViewDirection, roughness, roughness, zeta1, zeta2);

            normalMap = mix(normalMap, animatedTBN * sampledNormal, map(seed.r - 0.35, 124.0/255.0, 191.0/255.0, 0.0, 1.0));
        }
    #endif

    // -- normal map -- //
    #if !defined PARTICLE && !defined WEATHER && PBR_TYPE > 0
        // don't apply PBR normalmap on water if the water custom normalmap is activated
        #if WATER_CUSTOM_NORMALMAP > 0
        if (!isWater(id))
        #endif
        {
            vec4 normalMapData = texture2D(normals, textureCoordinate);

            // only if normal texture is specified
            if (normalMapData.x + normalMapData.y > 0.001) {
                // retrieve normal map
                normalMapData.xy = normalMapData.xy * 2.0 - 1.0;
                normalMap = vec3(normalMapData.xy, sqrt(1.0 - min(dot(normalMapData.xy, normalMapData.xy), 1.0)));
                // avoid normal map to be too tilted
                if (normalMap.z <= 0.1) {
                    normalMap.z = 0.1;
                }
                // convert to world space and combine with normal
                normalMap = normalize(normalMap);
                normalMap = TBN * normalMap;
                normalMap = mix(normal, normalMap, 0.5);

                // apply POM normals
                #if PBR_POM_TYPE > 0 && PBR_POM_NORMAL > 0
                    if (length(normalPOM) > 0.0) {
                        // attenuate POM normal
                        normalPOM = mix(normalPOM, normalMap, 0.5);
                        // fade out into the distance
                        normalMap = mix(normalPOM, normalMap, POMblend);
                    }
                #endif

                // clamp non visible normal
                if (dot(normalMap, viewDirection) < 0.0) {
                    normalMap = normalMap - viewDirection * dot(normalMap, viewDirection);
                }

                normalMap = normalize(normalMap);
            }
        }
    #endif

    // -- apply porosity -- //
    #if POROSITY_TYPE > 0
        // retrieve water material data
        float waterSmoothness, waterReflectance;
        getWaterMaterialData(waterSmoothness, waterReflectance);

        float wetnessFactor = inRainyBiome * wetness * smoothstep(0.5, 1.0, ambientSkyLightIntensity);

        // material get smoother and more reflective as it absorb water
        smoothness = mix(smoothness, waterSmoothness, porosity * wetnessFactor);
        reflectance = mix(reflectance, waterReflectance, porosity * wetnessFactor);

        // darken all material
        albedo = mix(albedo, 0.45 * albedo, sqrt(porosity) * wetnessFactor);
    #endif

    // -- apply lighting -- //
    vec4 color = doLighting(id, pixelationOffset, gl_FragCoord.xy, albedo, transparency, normal, tangent, bitangent, normalMap, worldSpacePosition, unanimatedWorldPosition, smoothness, reflectance, 1.0, ambientSkyLightIntensity, blockLightIntensity, ambientOcclusion, ambientOcclusionPBR, subsurfaceScattering, emissivness);

    // -- reflection on transparent material -- //
    #if REFLECTION_TYPE > 0 && defined REFLECTIVE
        #if PIXELATED_REFLECTION > 0
            // avoid position glitche for animated material (like water)
            vec3 screenSpacePosition = worldToScreen((unanimatedWorldPosition));
        #else
            vec3 screenSpacePosition = vec3(uv, depth);
        #endif
        vec4 reflection = doReflection(colortex4, colortex5, depthtex1, screenSpacePosition.xy, screenSpacePosition.z, color.rgb, normalMap, ambientSkyLightIntensity, smoothness, reflectance);

        // tweak reflection for water
        if (id == 20000)
            reflection.a = smoothstep(0.0, 1.0, reflection.a);

        // apply reflection
        color.rgb = mix(color.rgb, reflection.rgb, reflection.a);
    #endif

    // -- fog -- //
    foggify(worldSpacePosition, color.rgb, emissivness);
    // blindness
    doBlindness(worldSpacePosition, color.rgb, emissivness);
    color.rgb += 0.001 * (dithering(uv, 1) * 2.0 - 1.0);

    // gamma correct
    color.rgb = linearToSRGB(color.rgb);

    // no reflections for handeld object
    #ifdef HAND
        reflectance = 0;
        smoothness = 0;
    #endif

    // -- buffers -- //
    colorData = color;
    normalData = encodeNormal(normalMap);
    #ifdef TRANSPARENT
        lightAndMaterialData = vec4(0.0, emissivness, 0.0, pow(transparency, 0.25));
    #else
        lightAndMaterialData = vec4(ambientSkyLightIntensity, emissivness, smoothness, 1.0 - reflectance);
    #endif
}
